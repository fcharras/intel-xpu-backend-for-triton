#include "softmax.h"
#include "kernel_func.hpp"
#include "test.hpp"
#include <torch/extension.h>

using namespace gpu::xetla;
using namespace cl::sycl;

template <typename Config>
void softmax_forward(void *input, void *output, sycl::queue &queue) {
  // Accept incoming parameters
  size_t mat_n = Config::mat_n;
  size_t mat_m = Config::mat_m;
  constexpr size_t sg_n = Config::sg_n;
  constexpr size_t sg_m = Config::sg_m;
  constexpr size_t wg_n = Config::wg_n;
  constexpr size_t wg_m = Config::wg_m;

  using data_type_in = typename Config::data_type_in;
  using data_type_acc = typename Config::data_type_acc;
  using data_type_out = typename Config::data_type_out;

  data_type_in *buffer_in = static_cast<data_type_in *>(input);
  data_type_out *buffer_out = static_cast<data_type_out *>(output);
  data_type_acc sqrt_dk_inv = 0.125f;

  size_t group_range_m = (mat_m + wg_m - 1) / wg_m;
  size_t group_range_n = (mat_n + wg_n - 1) / wg_n;
  size_t subgroup_range_m = (wg_m + sg_m - 1) / sg_m;
  size_t subgroup_range_n = (wg_n + sg_n - 1) / sg_n;

  cl::sycl::range<3> group_range{1, group_range_m, group_range_n};
  cl::sycl::range<3> local_range{1, subgroup_range_m, subgroup_range_n};
  cl::sycl::nd_range<3> nd_range(group_range * local_range, local_range);

  std::cout << " group_num_x: " << group_range_n << ",  group_num_y: " << group_range_m << "\n";
  std::cout << " group_size_x: " << subgroup_range_n << ",  group_size_y: " << subgroup_range_m << std::endl;
  std::cout << " mat_m: " << mat_m << ",  mat_n: " << mat_n << "\n";
  std::cout << " wg_m: " << wg_m << ",  wg_n: " << wg_n << "\n";
  std::cout << " sg_m: " << sg_m << ",  sg_n: " << sg_n<< "\n";

  auto context = queue.get_info<info::queue::context>();
  std::vector<kernel_id> kernelId = {get_kernel_id<Config>()};

  static std::once_flag jit_once;
  std::call_once(jit_once, [&]() {
    auto inputBundle =
        get_kernel_bundle<bundle_state::input>(context, kernelId);
    setenv("SYCL_PROGRAM_COMPILE_OPTIONS",
           " -vc-codegen -doubleGRF  -Xfinalizer ' "
           "-printregusage -enableBCR  "
           "-DPASTokenReduction '",
           1);
    kernel_bundle<bundle_state::executable> exeBundle = build(inputBundle);
    unsetenv("SYCL_PROGRAM_COMPILE_OPTIONS");
  });

  auto exeBundle =
      get_kernel_bundle<bundle_state::executable>(context, kernelId);
  try {
    // const auto start = std::chrono::system_clock::now();
    auto e_softmax_fwd = queue.submit([&](handler &cgh) {
      cgh.use_kernel_bundle(exeBundle);
      cgh.parallel_for<Config>(nd_range, [=](nd_item<3> item) KERNEL_MAIN {
        using softmax_fwd_func =
            softmax_fwd_test_func<data_type_in, data_type_out, data_type_acc,
                                  wg_n, wg_m, sg_n, sg_m>;
        constexpr uint32_t barrier_count = softmax_fwd_func::barrier_count;
        constexpr uint32_t slm_size = softmax_fwd_func::slm_size;
        if constexpr (barrier_count != 0) {
          xetla_nbarrier_init<barrier_count>();
        }
        if constexpr (slm_size != 0) {
          xetla_local_init<slm_size>();
        }
        softmax_fwd_func::run(item, buffer_in, buffer_out, mat_m, mat_n, mat_n,
                              sqrt_dk_inv);
      });
    });
    // const auto end = std::chrono::system_clock::now();
    // double elapsed_time_ms =
    //     std::chrono::duration<double, std::milli>(end - start).count();
    e_softmax_fwd.wait();
    double time = (e_softmax_fwd.template get_profiling_info<
                       info::event_profiling::command_end>() -
                   e_softmax_fwd.template get_profiling_info<
                       info::event_profiling::command_start>()) /
                  (1000.0f * 1000.0f * 1000.f);

    printf(
        "M: %d, Data_type_in: %d, Bandwidth: GB/S: %f \n", mat_m,sizeof(data_type_in),
        ((mat_m * mat_n * sizeof(data_type_in) * 2 / 1e9) / time));
    // printf("GFLOPS: %f \n", ((2 * matrix_m * matrix_k * matrix_n)/1e9)/
    // time); printf("Bandwidth: GB/S: %f \n", ((((matrix_m * matrix_k) *
    // sizeof(data_type_a) + (matrix_m * matrix_n) * sizeof(data_type_c) +
    // (matrix_n * matrix_k) * sizeof(data_type_b)) /1e9)/ time));

  } catch (cl::sycl::exception const &e) {
    std::cout << "SYCL exception caught: " << e.what() << '\n';
  }
}

template void softmax_forward<mat0_96x2048x2048_bf16>(void *input, void *output,
                                                      sycl::queue &queue);
template void softmax_forward<mat1_96x2048x2048_bf16>(void *input, void *output,
                                                      sycl::queue &queue);
template void softmax_forward<mat1_256x256_bf16_cfg0>(void *input, void *output,
                                                      sycl::queue &queue);
template void softmax_forward<mat1_1024x1024_bf16_cfg0>(void *input,
                                                        void *output,
                                                        sycl::queue &queue);
template void softmax_forward<mat1_2048x2048_bf16_cfg0>(void *input,
                                                        void *output,
                                                        sycl::queue &queue);
template void softmax_forward<mat1_4096x4096_bf16_cfg0>(void *input,
                                                        void *output,
                                                        sycl::queue &queue);
