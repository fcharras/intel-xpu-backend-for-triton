//===-TritonGENToLLVMIRTranslation.cpp - TritonGEN Dialect to LLVM IR -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a translation between the TritonGEN dialect and LLVM IR.
//
//===----------------------------------------------------------------------===//

#include "Target/LLVMIR/Dialect/TritonGEN/TritonGENToLLVMIRTranslation.h"

#include "Dialect/TritonGEN/IR/TritonGENDialect.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Support/LogicalResult.h"
#include "mlir/Target/LLVMIR/LLVMTranslationInterface.h"
#include "mlir/Target/LLVMIR/ModuleTranslation.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"

namespace {
using namespace mlir;
class TritonGENDialectLLVMIRTranslationInterface
    : public LLVMTranslationDialectInterface {
public:
  using LLVMTranslationDialectInterface::LLVMTranslationDialectInterface;

  LogicalResult
  convertOperation(Operation *operation, llvm::IRBuilderBase &builder,
                   LLVM::ModuleTranslation &moduleTranslation) const override {
    return TypeSwitch<Operation *, LogicalResult>(operation)
        .Case([&builder,
               &moduleTranslation](triton::TritonGEN::CacheControls op) {
          llvm::Value *ptr = moduleTranslation.lookupValue(op.getPtr());
          llvm::MDNode *cacheControl = translateCacheControl(
              builder, op.getCacheLevel(), op.getCacheControl());
          moduleTranslation.mapValue(op, ptr);
          return TypeSwitch<llvm::Value *, LogicalResult>(ptr)
              .Case([cacheControl](llvm::Instruction *inst) {
                constexpr StringLiteral mdName = "spirv.Decorations";
                // TODO: Needed to specify more than one decoration
                assert(!inst->hasMetadata(mdName) && "Not yet implemented");
                inst->setMetadata(mdName, cacheControl);
                return success();
              })
              .Case([&builder, cacheControl](llvm::Argument *arg) {
                llvm::Function *func = arg->getParent();
                constexpr StringLiteral mdName = "spirv.ParameterDecorations";
                // TODO: Needed to specify more than one decoration on a
                // parameter or decorations on more than one parameter
                assert(!func->hasMetadata(mdName) && "Not yet implemented");
                llvm::MDNode *empty =
                    llvm::MDNode::get(builder.getContext(), {});
                SmallVector<llvm::Metadata *> paramMD(func->arg_size(), empty);
                paramMD[arg->getArgNo()] = cacheControl;
                func->setMetadata(
                    mdName, llvm::MDNode::get(builder.getContext(), paramMD));
                return success();
              })
              .Default([op](llvm::Value *val) {
                // TODO: Add relevant message
                return op->emitError("unexpected LLVM value kind");
              });
        })
        .Default([](auto *op) {
          return op->emitError("unsupported TritonGEN operation: ")
                 << op->getName();
        });
  }

private:
  template <typename IntTy>
  static llvm::Metadata *getConstantIntMD(llvm::Type *type, IntTy val) {
    return llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(type, val));
  }

  static llvm::MDNode *translateCacheControl(llvm::IRBuilderBase &builder,
                                             uint32_t cacheLevel,
                                             uint32_t cacheControl) {
    llvm::LLVMContext &ctx = builder.getContext();
    llvm::Type *type = builder.getInt32Ty();

    constexpr uint32_t cacheControlDecoration = 6443;
    llvm::Metadata *cacheControlDecorationMetadata =
        getConstantIntMD(type, cacheControlDecoration);
    llvm::Metadata *cacheLevelMetadata = getConstantIntMD(type, cacheLevel);
    llvm::Metadata *cacheControlMetadata = getConstantIntMD(type, cacheControl);
    return llvm::MDNode::get(
        builder.getContext(),
        llvm::MDNode::get(builder.getContext(),
                          {cacheControlDecorationMetadata, cacheLevelMetadata,
                           cacheControlMetadata}));
  }
};
} // namespace

namespace mlir {
void registerTritonGENDialectTranslation(DialectRegistry &registry) {
  registry.insert<triton::TritonGEN::TritonGENDialect>();
  registry.addExtension(
      +[](MLIRContext *ctx, triton::TritonGEN::TritonGENDialect *dialect) {
        dialect->addInterfaces<TritonGENDialectLLVMIRTranslationInterface>();
      });
}

void registerTritonGENDialectTranslation(MLIRContext &context) {
  DialectRegistry registry;
  registerTritonGENDialectTranslation(registry);
  context.appendDialectRegistry(registry);
}
} // namespace mlir
