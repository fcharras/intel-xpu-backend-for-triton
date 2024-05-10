// RUN: triton-translate -triton-to-llvmir -split-input-file %s | FileCheck %s

llvm.func @foo() -> !llvm.ptr

// CHECK-LABEL: define ptr @cache_control_op() {
llvm.func @cache_control_op() -> !llvm.ptr {
  // CHECK: call ptr @foo(), !spirv.Decorations ![[#CACHE_CONTROL:]]
  %ptr = llvm.call @foo() : () -> !llvm.ptr
  %annotated_ptr = triton_gen.cache_control %ptr, 0, 1 : !llvm.ptr
  llvm.return %annotated_ptr : !llvm.ptr
}

// CHECK-LABEL: define ptr @cache_control_arg(
// CHECK-SAME:  !spirv.ParameterDecorations ![[#PARAM_CACHE_CONTROL:]]
llvm.func @cache_control_arg(%foo: !llvm.ptr, %ptr: !llvm.ptr) -> !llvm.ptr {
  %annotated_ptr = triton_gen.cache_control %ptr, 0, 1 : !llvm.ptr
  llvm.return %annotated_ptr : !llvm.ptr
}

// CHECK-DAG: ![[#CACHE_CONTROL]] = !{![[#CACHE_CONTROL_SPEC:]]}
// CHECK-DAG: ![[#CACHE_CONTROL_SPEC]] = !{i32 6443, i32 0, i32 1}
// CHECK-DAG: ![[#PARAM_CACHE_CONTROL]] = !{![[#EMPTY:]], ![[#CACHE_CONTROL]]}
// CHECK-DAG: ![[#EMPTY]] = !{}
