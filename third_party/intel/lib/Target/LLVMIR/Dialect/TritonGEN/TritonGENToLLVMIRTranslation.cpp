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
    return failure();
  }

  LogicalResult
  amendOperation(Operation *op, ArrayRef<llvm::Instruction *> instructions,
                 NamedAttribute attribute,
                 LLVM::ModuleTranslation &moduleTranslation) const final {
    if (isKernel(op)) {
      op->dump();
    }
    assert(false);
    return failure();
  }

private:
  bool isKernel(Operation *op) const {
    auto fn = dyn_cast<LLVM::LLVMFuncOp>(op);
    return fn && fn.getCConv() == LLVM::CConv::SPIR_KERNEL;
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
