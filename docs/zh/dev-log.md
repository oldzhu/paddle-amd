[English Version](../en/dev-log.md)

# 开发日志

## 2026-04-08

- 初始化协调仓库。

## 2026-04-09

- 确认嵌套上游工作区位于 `/home/oldzhu/paddle-amd/paddlerepos`。
- 删除此前不完整的嵌套 clone，并重新完成干净的 clone。
- 记录本地 Paddle clone：`/home/oldzhu/paddle-amd/paddlerepos/Paddle`，分支为 `develop`，commit 为 `5ea0c3dddf415a7885560c6916e13491d6f597c6`。
- 记录本地 PaddleX clone：`/home/oldzhu/paddle-amd/paddlerepos/PaddleX`，分支为 `develop`，commit 为 `c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`。
- 已验证两个嵌套仓库的工作区均为干净状态。
- 已添加双语工作区环境与首次复现指南。
- 已将本地控制平面仓库关联到 GitHub remote `https://github.com/oldzhu/paddle-amd.git`。
- 已补充远程 AMD ROCm Jupyter 工作流资产，包括工作区 skill、Jupyter API 辅助脚本以及远程 bootstrap 命令生成器。
- 已为远程辅助脚本增加基于 Jupyter terminal websocket 的命令执行支持。
- 已完成远程 Jupyter 实例认证，并在终端 `1` 上验证 terminal websocket 命令执行。
- 已通过 Jupyter terminal websocket 上传并执行远程环境检查脚本。
- 已确认远程主机具备 ROCm，但当前 Python 环境中尚未安装 Paddle。
- 已添加可复用的按实例远程准备封装脚本，以便后续处理临时 Jupyter 实例。
- 已修复远程 command-file 执行路径，使 `set -e` 脚本失败时能够返回正确退出码，而不再表现为“卡住”。
- 已成功在当前远程实例下完成 `/app/paddle-amd-remote` 工作区 bootstrap，包括控制平面仓库、Paddle clone 和 PaddleX clone。
- 已将远程实例规则修正为“先检查，再只补齐缺失或不合适的部分”，避免表达成无条件重复安装或重复 clone。
- 已在远程 `/opt/venv` 中测试安装 `paddlepaddle==3.3.1`，确认得到的是仅 CPU 构建，而不是可用于任务的 ROCm 构建。
- 已新增按“先检查再构建”方式运行的远程 Paddle ROCm 源码构建探测脚本，用于捕获真实源码构建阻塞，而不是停留在 CPU wheel。
- 已执行首次远程 Paddle ROCm 源码 configure 探测，确认当前远程阻塞来自 ROCm 头文件路径不匹配以及 GitHub 子模块抓取不稳定。
- 已收紧远程源码探测脚本，避免未来 configure 探测过程中对 Python 环境执行大范围升级。
- 已更新远程源码探测脚本，使其在当前实例上先通过 HTTP/1.1 加重试补齐子模块，并添加非破坏性的 ROCm 头文件兼容软链接。
- 已在同一远程实例上重新执行 configure 探测，确认头文件路径与子模块阻塞已经清除；新的 configure 阻塞为 `Unknown CMake command "hip_add_library"`。
- 已确认当前 ROCm 镜像把 legacy `FindHIP.cmake` 放在 `/opt/rocm-7.2.1/lib/cmake/hip`，而 Paddle 使用的旧路径 `/opt/rocm/hip/cmake` 在该实例上并不提供这个模块。
- 已新增后台启动远程 configure 的脚本，但随后 Jupyter backend 切换到了新的容器，terminal websocket 在多个终端上都开始超时，导致无法在当前轮次内完成后台启动链路的端到端验证。
- 已重构后台远程 configure 启动脚本，规避嵌套 heredoc 变量提前展开的问题，并在 live `http://36.151.243.69:30005/lab` backend 的终端 `3` 上完成一次干净的后台启动验证。
- 已确认修复后的后台启动脚本成功拉起远程后台任务 `549`；最新轮询显示子模块初始化仍在推进，递归缺失子模块数量已从 `31` 降到 `24`，此时 CMake configure 还未开始。
- 已确认此前的后台任务最终在 fresh backend 上完成了递归子模块补齐，并暴露出新的 configure 阻塞：远程镜像缺少 `patchelf`。
- 已通过 `apt-get install -y patchelf` 在远程 backend 上安装 `patchelf`，并在终端 `6` 上重新后台启动 configure；最新轮询显示新的后台任务已越过 `patchelf` 失败点，继续向更深的 CMake configure 和代码生成阶段推进。
- 已确认生成出来的 `build-rocm` 树已经可以启动首个定向 `paddle_python` 构建，但第一次重试在 `extern_warprnnt` 处失败；根因是远程实例上的 `third_party/warprnnt` 只剩 `.git` 重定向文件，没有实际 checkout 内容。
- 已补丁 `scripts/remote_launch_paddle_rocm_configure.sh` 与 `scripts/remote_build_paddle_rocm.sh`，把“目录里只有 `.git` 文件”的子模块状态也判定为损坏，并在恢复流程中强制重建，而不再误判为健康。
- 已在远程实例上手动修复 `third_party/warprnnt` checkout，重新触发定向构建后，失败点已从 `extern_warprnnt` 前移到 `extern_warpctc` configure。
- 已确认第二个定向构建阻塞位于 `paddlerepos/Paddle/cmake/external/warpctc.cmake`：外部 WarpCTC 的 ROCm configure 没有继承顶层 `CMAKE_MODULE_PATH`，导致子构建内部 `HIP_ADD_LIBRARY` 未定义。
- 已在本地 `paddlerepos/Paddle/cmake/external/warpctc.cmake` 中添加实验性补丁，把 `CMAKE_MODULE_PATH` 透传到外部 WarpCTC configure；但 live Jupyter websocket 在后续重试阶段再次不稳定，因此最终远程重试和 BF16 运行时探测仍待完成。
- 已将当前 Jupyter 会话切换到 `http://36.151.243.69:30008/instance/nb-1838d2b6/lab`，并在新实例上验证认证后的 API 访问与 terminal websocket 访问正常。
- 已确认这个新实例自带可用的 ROCm Paddle 环境，验证前无需再次完整 bootstrap 控制平面工作区。
- 已在新实例上确认 `rocminfo` 与 `hipcc` 存在，`/opt/venv` 中的 Paddle 可正常导入，版本为 `3.4.0.dev20260404`，`paddle.is_compiled_with_rocm()` 为 `True`，`paddle.is_compiled_with_cuda()` 为 `True`，`paddle.device.get_device()` 为 `gpu:0`，且两个 BF16 支持 API 都返回 `True`。
- 已尝试在新实例上执行最小 BF16 GPU matmul，但 terminal websocket 在执行过程中断开；该现象记录为传输层限制，而不是已确认的 BF16 运行时失败。
- 已从下一次运行时尝试中确认 BF16 故障真实存在，且发生在 matmul 之前：`paddle.randn(..., dtype="bfloat16")` 在 GPU 路径上触发段错误，C++ traceback 终止在 `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>` 和 `phi::funcs::distribution_and_transform`。
- 已将源码侧崩溃路径收敛到 `paddlerepos/Paddle/paddle/phi/kernels/gpu/gaussian_kernel.cu`，具体是 `seed == 0` 分支中针对 GPU BF16 调用 `funcs::distribution_and_transform<T>(dev_ctx, out, dist, trans)` 的路径。
- 已切换到新的预装 Jupyter 实例 `http://36.151.243.69:30006/instance/nb-1838d2b6/lab` 继续验证，创建终端 `1` 后确认认证 API 与 terminal 执行均可用，远程 shell 落点为 `/opt/PaddleX`，用户为 `root`。
- 已确认 `30006` 在高层就绪信号上与 `30008` 一致：存在 `rocminfo` 与 `hipcc`，`/opt/venv` 中的 Paddle 版本为 `3.4.0.dev20260404`，`paddle.is_compiled_with_rocm()` 为 `True`，`paddle.device.get_device()` 为 `gpu:0`，两个 BF16 支持 API 也都返回 `True`。
- 已确认 `30006` 当前镜像不能作为有效验证目标：一条最小 `paddle.randn([8,8], dtype="bfloat16")` GPU 命令会在 `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>` 内部触发段错误，而独立的 `paddle.ones([2,2], dtype="float32")` 对照命令也会在 `phi::FullKernel<float, phi::GPUContext>` 内部触发段错误。
- 已将当前判断从“仅 BF16 Gaussian 缺陷”收紧为“`30006` 预装镜像存在更广泛的运行时问题”，因为即使是不涉及 BF16 的最小 float32 GPU Tensor 物化也会在正式 BF16 验证开始前崩溃。
- 已尝试在 `30006` 上 bootstrap 全新的 `/app/paddle-amd-remote` 工作区，但该实例当前无法解析 `github.com` 与 `gitee.com` 等外部域名，因此基于远程 clone 的源码构建准备目前被镜像网络条件阻塞。
- 已补充更窄的 GPU 对照测试，并确认该镜像并非“完全不可用”：float32 的 `paddle.to_tensor(..., place="gpu")` 可以成功，基于这些 `to_tensor` 输入执行的 float32 `paddle.matmul` 也可以成功。
- 已确认 `30006` 的活跃故障范围集中在“创建类与转换类 kernel”，而不是所有 GPU 执行路径：float32 `paddle.randn` 会在 `phi::GaussianKernel<float, phi::GPUContext>` 内部段错误，BF16 `paddle.randn` 会在 BF16 Gaussian 路径内段错误，float32 `paddle.ones` 会在 `phi::FullKernel<float, phi::GPUContext>` 内部段错误，float32 到 BF16 的 `astype` 会在 `phi::CastCUDAKernelImpl<float, phi::dtype::bfloat16>` 内部段错误。
- 已记录 `30006` 上预装 Paddle 构建标识：版本 `3.4.0.dev20260404`，commit `79630aedd7f4d5f8ac6c4fe6a2290ab1657d65f6`，导入路径为 `/opt/venv/lib/python3.12/site-packages/paddle/__init__.py`。
- 已检查当前本地 WSL 机器能否作为 ROCm 构建主机，并确认本地具备真实的 Linux ROCm 工具链：Ubuntu 24.04.3、Python 3.12.3、来自 ROCm 6.4.2 的 `hipcc`、`rocminfo`、`cmake 3.28.3` 与 `ninja 1.11.1` 都已可用。
- 已确认当前本地 WSL 环境适合用于编译候选 ROCm Paddle wheel，但不适合作为最终验收证据来源：权威运行结果仍必须来自原生 Linux ROCm 或远程 AMD ROCm 实例。
- 已记录“本地构建再部署到远程”的主要剩余风险：当前本地工具链为 ROCm 6.4.2，而当前远程预装镜像线为 ROCm 7.2.x，因此从 WSL 构建 wheel 再部署到远程在技术上可行，但优先级仍低于使用版本对齐的构建主机。
- 已从 `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local` 启动首个真实本地 ROCm wheel 构建，当前构建使用 ROCm Clang、`PADDLE_SKIP_FLASHATTN=ON` 以及本地 `rocm-compat` 兼容层。
- 已清除本地构建早期阻塞：`warprnnt`、`warpctc`、OpenBLAS 发现、外部工程残留安装状态，以及 GCC 与 ROCm 头文件不兼容问题；处理方式是切换主机编译器到 ROCm Clang，并重置外部工程的陈旧构建状态。
- 已识别出多个 `paddle/phi/kernels/funcs` HIP 编译失败共享同一模式：某些实现文件通过并不真正需要 Eigen 的头文件，把 `eigen/common.h` 间接带入了 GPU 编译路径。
- 已移除 `affine_grid_utils.cu`、`cross_entropy.h`、`fake_dequantize_functor.h` 与 `fake_quantize_functor.h` 中不必要的 Eigen 重依赖；同时在瘦身 `fake_quantize` 头文件后，把 `paddle/phi/common/memory_utils.h` 作为显式依赖补回到 `fake_quantize_functor.cu`。
- 在 `math_function.cu` 仍然沿同一 `Eigen/src/Core/arch/Default/Half.h:669` 路径失败后，已将判断从“逐文件清理”升级为“共享三方依赖问题”，因为 `math_function_impl.h` 对 Eigen 的依赖是真实存在的。
- 已对本地三方 Eigen `third_party/eigen3/Eigen/src/Core/arch/Default/Half.h` 打补丁：在 HIP device build 下，`half log()` 不再调用当前 ROCm 栈上会错误解析到 BF16 重载的 `::hlog(a)`，而改用安全的 `logf(float(a))` fallback。
- 已确认应用 Eigen 补丁后的串行重编译不再立刻复现此前的 `Half.h:669` 失败，并且已经重新推进到 `paddle/phi/kernels/funcs/eigen/` 下的 HIP 目标编译阶段。
- 已确认下一处串行构建停止点已转移到主机侧 C++ 文件 `paddle/phi/api/lib/tensor_utils.cc`：当前本地 ROCm 6.4.2 头文件暴露的是 `hipPointerAttribute_t::type`，而不是 `hipPointerAttribute_t::memoryType`。
- 已将 `tensor_utils.cc` 的 HIP 路径改为使用 `attr.type`，并先对单个失败对象完成重编译验证成功，再恢复完整串行构建。
- 已确认恢复后的下一处串行构建停止点转移到了 PyTorch 兼容 c10 层的 `paddle/phi/api/include/compat/c10/cuda/CUDAStream.cpp`：HIP 构建路径仍在直接依赖 CUDA 头文件名和 CUDA runtime 符号名。
- 已在 `paddle/phi/api/include/compat/c10/cuda/CUDAException.h` 中补充 HIP 构建路径：改为包含 `hip/hip_runtime.h`，并提供 compat c10 CUDA stream 层所需的最小 CUDA 名称兼容别名；随后已成功重编译此前失败的 `CUDAStream.cpp.o`。
- 已确认恢复后的下一处停止点转移到 `paddle/phi/core/memory/allocation/allocator_facade.cc`：该文件的共享 CUDA/HIP include 块仍然会引入 `paddle/phi/backends/dynload/cuda_driver.h`，但当前 HIP 路径实际上并未使用 CUDA driver API。
- 已将 `allocator_facade.cc` 中的 `cuda_driver.h` include 收紧到仅 CUDA 分支，再次成功重编译此前失败对象后恢复完整串行构建。
- 已确认恢复后的下一处停止点 `paddle/phi/core/platform/stream_callback_manager.h` 并不是新的源码兼容问题，而是另一处空子模块工作树：`third_party/threadpool` 仅剩 `.git` 重定向文件，因此 include 路径里不存在 `ThreadPool.h`。
- 已恢复本地 `third_party/threadpool` 子模块 checkout，并确认此前失败的 `stream_callback_manager.cc.o` 目标在无需新增源码修改的情况下重新通过。
- 已确认下一处本地串行构建停止点 `paddle/phi/kernels/funcs/cross_entropy.cc` 仍是缺失辅助头文件导致的源码问题，而不是 ROCm 版本门槛：该实现文件使用了 Paddle Eigen wrapper，但未包含 `paddle/phi/kernels/funcs/eigen/common.h`。
- 已为 `cross_entropy.cc` 补上共享 Eigen helper 头文件，并通过重编译此前失败对象验证修复成功，随后恢复串行构建并越过该停止点。
- 已确认恢复构建后的下一处停止点 `paddle/phi/kernels/funcs/fake_dequantize_functor.cc` 属于同类源码问题：实现文件使用了 `EigenVector`，但未引入共享 Eigen helper 定义。
- 已为 `fake_dequantize_functor.cc` 补充 `paddle/phi/kernels/funcs/eigen/common.h` 并恢复本地 `EigenVector` alias，然后成功重编译此前失败对象。
- 已确认恢复构建后的下一处停止点 `paddle/phi/kernels/funcs/fake_quantize_functor.cc` 仍是源码侧 helper 漂移问题：缺少 `phi::Transform`、`phi::ClipFunctor` 与 `EigenVector` 的声明来源。
- 已为 `fake_quantize_functor.cc` 补充 `paddle/phi/common/transform.h`、`paddle/phi/kernels/funcs/eigen/common.h` 与 `paddle/phi/kernels/impl/clip_kernel_impl.h`，恢复本地 `EigenVector` alias，并通过重编译此前失败对象验证修复成功。
- 已确认下一处本地 ROCm 阻塞转移到 `paddle/phi/kernels/gpu/argsort_kernel.cu` 的 HIP radix sort 兼容层：当前 ROCm 6.4.2 的 rocPRIM 栈已不再接受 Paddle 旧有的 `radix_key_codec_integral` 加 `detail::float_bit_mask` 方式来适配 float16 与 bfloat16。
- 已新增共享兼容桥 `paddle/phi/kernels/funcs/hip_radix_sort_compat.h`，并接入公共 HIP cub 路径，用 rocPRIM 浮点 codec 与新式 `rocprim::traits::define` trait 特化统一替换分散在多个文件中的旧 shim。
- 已验证此前失败的生成式 argsort HIP 对象在直接重编译时不再立即复现旧的 rocPRIM `float_bit_mask` 与 `bit_cast` 错误，并已重新推进到 `phi_gpu` HIP 目标编译阶段。
- 已确认上述三个近期修复过的 helper 实现文件仍残留一处更窄的后续源码问题：本地 `EigenMatrix` / `EigenVector` alias 没有显式绑定到 Paddle 的全局 Eigen wrapper，而是在当前作用域内发生了错误遮蔽。
- 已在 `paddle/phi/kernels/funcs/cross_entropy.cc`、`paddle/phi/kernels/funcs/fake_dequantize_functor.cc` 与 `paddle/phi/kernels/funcs/fake_quantize_functor.cc` 中把这些 alias 明确改为 `phi::Eigen*`，同时把 `fake_quantize_functor.cc` 中剩余的 `phi::ClipFunctor` 调用点统一规范化，并成功重编译这三个此前失败的对象目标。
- 已在完成上述定向验证后恢复本地串行 ROCm 构建，并确认构建已经越过此前的 helper 失败区间，继续推进到更大范围的 `paddle/phi/kernels/cpu/` 编译阶段，且未复现之前的停止点。
- 创建双语项目文档骨架。
- 添加项目级共享指令，用于强制执行双语跟踪与证据记录规范。

## 2026-04-13

- 确认恢复后的本地 ROCm 串行构建下一处阻塞已转移到 `paddle/phi/kernels/gpu/top_k_kernel.cu`：HIP 路径虽然把 `WARP_SIZE` 固定为 `64`，但宏生成的分派分支仍会实例化 32 线程特化。
- 已对 `top_k_kernel.cu` 打补丁：将 HIP 运行时 `thread_per_block` 至少钳制到一个完整 wave，同时去掉 HIP 路径上的 32 线程 `FIXED_BLOCK_DIM` 特化；随后通过重编译此前失败的生成对象 `paddle/phi/CMakeFiles/phi_gpu.dir/kernels/gpu/phi_gpu_generated_top_k_kernel.cu.o` 验证修复成功。
- 确认随后恢复构建后的下一处阻塞已转移到主机侧 DLPack 头文件解析，即 `paddle/fluid/platform/densetensor_printer.cc.o` 在已有子模块 gitdir 的情况下仍找不到 `dlpack/dlpack.h`。
- 已修复 `cmake/external/dlpack.cmake`，使 `dlpack` interface target 正式导出 DLPack include 目录；已为 `densetensor_printer` 增加直接 `dlpack` 依赖；并从子模块 commit 恢复受跟踪的公共头文件 `third_party/dlpack/include/dlpack/dlpack.h`；随后通过重编译 `paddle/fluid/platform/CMakeFiles/densetensor_printer.dir/densetensor_printer.cc.o` 验证修复成功。
- 在完成上述定向验证后，已恢复完整串行 `paddle_copy` 构建，并确认在最新观测点上构建已继续推进到更后面的 framework 与 IR 目标，尚未出现新的硬性阻塞。
- 确认下一处新的后期阻塞是 `paddle/fluid/pybind/eager_generator` 链接失败：`paddle/phi/core/platform/device/gpu/gpu_info.cc` 引用了未解析的 `phi::dynload::hipMemCreate` 与 `phi::dynload::hipMemRelease` 符号。
- 已修复 `paddle/phi/backends/dynload/rocm_driver.cc`，使其除了基础 ROCm routine 列表外，也实例化头文件中已声明的 ROCm 虚拟内存管理与 GPU graph dynload wrapper 组。
- 已通过精确重编译此前失败的 `eager_generator` 目标验证该 dynload 修复成功，并确认 `build-rocm-local/paddle/fluid/pybind/eager_generator` 再次生成。
- 在完成该精确定向验证后，已恢复完整串行 `paddle_copy` 构建，并确认构建已越过旧的 `eager_generator` 停止点继续前进。

## 2026-04-14

- 已对构建产物 `build-rocm-local/python/dist/paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl` 完成一次一次性本地冒烟验证，使用的临时虚拟环境位于 `/home/oldzhu/paddle-amd/.venv-wheel-smoke`。
- 已验证该 wheel 在本地临时环境中可以成功导入，版本为 `3.4.0.dev20260408`，且在 WSL 主机上报告 `paddle.is_compiled_with_rocm() == True` 与 `paddle.is_compiled_with_cuda() == True`。
- 已确认导入检查完成后临时冒烟虚拟环境已被删除，因此本地没有留下持久化 wheel 安装。
- 已使用实例级基地址 `http://36.151.243.69:30006/instance/nb-1838d2b6` 重新认证远程辅助脚本，并通过 Jupyter terminals API 创建远程终端 `paddle-amd-bf16`。
- 已确认 live 实例根目录中并不存在预建的 `uploaded-wheels/` 目录；首次上传因此以服务端 `No such file or directory` 失败，随后已把 wheel 改为上传到工作区根目录 `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`。
- 已对 `scripts/jupyter_remote.py` 做一轮加固：token 登录时先访问 `/lab?token=...`，并在 terminal websocket 握手时显式发送 cookie 与 origin 头。
- 已确认当前 `30006` 实例在完成上述加固后仍无法通过辅助脚本执行终端命令：对 `/instance/nb-1838d2b6/terminals/websocket/paddle-amd-bf16` 的 websocket 握手返回的是 HTTP `200` 与 HTML terminal 页面，而不是升级后的 websocket 通道。
- 已将当前远程状态记录为：wheel 制品已成功放到 live 实例上，但安装与冒烟执行仍被该 notebook 栈上的 terminal websocket 路由或前端行为阻塞。
- 已在用户重启后的 `30006` 实例上重新尝试，确认 terminal `1` 的 websocket 命令执行已经恢复，并验证远程 shell 落点为 `/opt/PaddleX`、用户为 `root`、Python 为 `/opt/venv/bin/python 3.12.3`。
- 已重新上传本地构建 wheel，并在 `/opt/venv` 中完成强制重装；随后确认阻塞点已从传输层转为动态链接：该基于 ROCm 6.4.2 构建的 wheel 首先因为远程 ROCm 7.2 镜像缺少 `libamdhip64.so.6` 而导入失败。
- 已通过添加 `/opt/PaddleX/rocm64-compat/libamdhip64.so.6 -> /opt/rocm/lib/libamdhip64.so.7` 并在调整后的 `LD_LIBRARY_PATH` 下重新执行 `ldd` 与 `import paddle`，证明第一处阻塞是 SONAME 不匹配，而不是泛化的导入失败。
- 已确认该兼容软链接会把失败签名推进为 `ImportError: libopenblas.so.0: cannot open shared object file`，并且当前 `30006` 镜像在 `/opt`、`/usr` 与 `/lib` 下都没有可发现的 `libopenblas.so.0`。
- 已确认剩余远程修复路径也被实例网络条件阻塞：`apt-get update` 因 Ubuntu、deadsnakes 和 AMD ROCm 软件源的临时 DNS 解析失败而无法刷新索引，因此当前镜像无法通过标准系统包安装缺失的 OpenBLAS 运行时。
- 已将当前远程状态记录为：wheel 制品可安装、terminal 传输已恢复，但同时确认存在 ROCm 6 到 7 的运行时错配，以及镜像缺失基础 OpenBLAS 运行时且包修复路径受 DNS 故障阻塞。

## 2026-04-15

- 已切换到新启动的远程实例 `http://36.151.243.69:30002/instance/nb-1838d2b6/lab`，完成 helper 重新认证，并确认 terminal `1` 的 websocket 执行可用；远程环境落点为 `/opt/PaddleX`，用户 `root`，Python 为 `/opt/venv/bin/python 3.12.3`。
- 已在该实例上复现默认解析器下的 DNS 阻塞（`nameserver 10.232.0.10`）：`getent` 无法解析 Ubuntu 与 security 主机，`apt-get update` 持续出现主机解析失败。
- 已验证“集群 DNS + 公共 DNS + ndots:1”的混合解析配置可恢复 `archive.ubuntu.com`、`security.ubuntu.com`、`github.com` 与 `ppa.launchpadcontent.net` 解析，但 `compute-artifactory.amd.com` 仍不可解析。
- 已确认在该混合解析状态下，`apt-get update` 可以成功刷新 Ubuntu 与 PPA 索引并返回退出码 `0`，仅保留 AMD artifactory 域名未解析的 warning。
- 已通过远程安装 `libopenblas0-pthread` 验证：工作流继续所需的标准 apt 包操作已经解除 DNS 阻塞。
- 已更新 `scripts/render_remote_dns_repair.sh`：默认 DNS 健康检查改为面向构建与包管理所需的公共主机；在保留已有 nameserver 的同时追加公共 fallback；并统一使用 `options timeout:2 attempts:2 rotate ndots:1`。
- 已为 DNS 修复渲染器增加可选严格模式 `--require-compute-artifactory`，用于明确需要私有 AMD 包源的场景。
- 已在脚本更新后再次端到端验证 `scripts/remote_fix_instance_dns.sh 1`：该实例上脚本可成功完成，且 apt 保持可用状态。
- 已新增专用远程 DNS 修复脚本生成器 `scripts/render_remote_dns_repair.sh` 与本地执行封装 `scripts/remote_fix_instance_dns.sh`，使后续远程重试可以先修复 `/etc/resolv.conf`、验证包源主机解析，并在需要时先执行 `apt-get update`。
- 已在 `scripts/render_remote_bootstrap.sh` 中加入 DNS 预检，使新实例的 bootstrap 在主机名解析已损坏时能够快速失败并给出明确修复路径，而不是继续跌入更深层的 clone 与包管理错误。
- 已再次验证“实例重启后 DNS 回退”会复发：terminal `1` 在新一轮重启后先回到主机解析失败状态，重新执行 `scripts/remote_fix_instance_dns.sh 1` 后恢复了公共包源解析与可用的 `apt-get update` 行为。
- 已在重启实例上恢复 OpenBLAS 运行时状态（`libopenblas0-pthread`），并因 fresh 实例工作区不再保留旧制品而重新上传本地 wheel。
- 已在 `/opt/venv` 中强制重装 `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`，重新应用 HIP SONAME 兼容软链接 `libamdhip64.so.6 -> libamdhip64.so.7`，并成功通过远程 GPU 冒烟验证。
- 已在 `30002` 上记录到成功冒烟 JSON：`version` 为 `3.4.0.dev20260408`、`compiled_with_rocm` 为 `true`、设备为 `gpu:0`，float32 matmul 输出为 `[[7.0, 10.0], [15.0, 22.0]]`。
- 已在成功冒烟后继续执行隔离式算子探测，并确认在同一运行时配置下，float32 `ones`、float32 `randn`、BF16 `randn`、float32 到 BF16 `astype`、BF16 `matmul` 均可在 `gpu:0` 上成功返回。
- 已推进到集成级 quick 验证：执行 `/opt/PaddleX/verify_inference.sh --mode quick --device gpu` 时 preflight 通过，但 native 推理在 GPU add/broadcast kernel 路径（`phi::AddRawKernel<float, phi::GPUContext>`）触发段错误。
- 已发起 `--device dcu` 的定向复验用于排除 device 别名因素，但实例在复验中途下线并返回 `HTTP 503`，该复验结果待实例恢复后补齐。
- 实例恢复后，已通过“后台执行 + 日志轮询”恢复 `--device dcu` 定向复验，并确认与前次一致的 native 段错误签名（`phi::AddRawKernel<float, phi::GPUContext>`），可排除 `gpu` 与 `dcu` 别名差异为主因。
- 在复验过程中，已内联修复解析器漂移（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`ndots:1`），恢复模型源域名解析，并观测到 `PP-DocLayoutV3` 可从 ModelScope 成功下载后仍在 native 阶段崩溃。
- 已记录同一轮运行的最终 quick 输出：vLLM 服务就绪等待在 `180s` 超时，quick 汇总为 `Native precision: failed`、`vLLM precision: failed-server`、`Overall: FAIL`。
- 已记录执行包装层细节：即使汇总已输出且相关进程已退出，`/tmp/paddle_amd_quick_dcu.done` 仍未生成，因此本轮完成性以日志终态与进程状态判定。
- 在完成上述结果抓取后，`30002` 端点再次不可用（`jupyter_remote.py login` 返回 `HTTP 503`，直接 API curl 超时），因此本窗口未能完成后续清理命令。
- 实例再次恢复后，已重新执行内联 DNS 修复并确认模型源主机可解析，再进入深入复现。
- 已新增不经过 `verify_inference.sh` 的独立 native 复现，并在 PaddleOCRVL predict 路径复现同一 `phi::AddRawKernel<float, phi::GPUContext>` 段错误，确认该崩溃不是 wrapper 特有问题。
- 已新增不经过 `verify_inference.sh` 的独立 vLLM 启动复现；观测到冷启动长路径（下载/编译/图捕获）后可达到 `Application startup complete`，说明此前 quick `failed-server` 可能由冷启动下就绪窗口不足触发。
- 已记录本次重启实例在独立 native 复现时的预装 Paddle 运行时为 `3.4.0.dev20260404`（`is_compiled_with_rocm == True`）。

## 2026-04-16

- 继续在 `30002` 上执行 `speed-vllm` 定向续跑，先确认 resolver 已回退到集群默认（`10.232.0.10`、`ndots:5`）。
- 重新内联应用 resolver（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`timeout:1`、`attempts:2`、`ndots:1`），并复核 `www.modelscope.cn`、`paddle-model-ecology.bj.bcebos.com`、`git.aistudio.baidu.com`、`huggingface.co` 可解析。
- 以新的日志与 rc 标记重启后台 `/opt/PaddleX/verify_inference.sh --mode speed-vllm --device dcu`（`/tmp/paddle_amd_speed_vllm.log`、`/tmp/paddle_amd_speed_vllm.rc`）。
- 复核重启后进程状态：`verify_inference.sh` worker 与 `paddlex_genai_server` 持续存活；runner 日志仍在 `/v1` 就绪等待，server 日志处于官方模型冷启动/下载提示阶段。
- 将当前节点记为进行中：本轮未再出现 DNS/模型源解析主导失败签名，但 `speed-vllm` 最终通过/失败仍待收敛。
- 记录到新的基础设施中断：终端 `2` 的远程命令流以 `Connection to remote host was lost` 结束，随后 `jupyter_remote.py info/list-terminals/login` 立刻复检均返回 `HTTP 503`，直接 API 探测超时。
- 本轮状态保持为“端点可用性中断待恢复”，不将其记为验证通过或失败结论。
- 在继续执行中再次出现“短暂恢复后再次失效”循环：新终端探测一度恢复，但在 speed-vllm 最终收敛前端点健康又回退为 `HTTP 503` + 直接 API 超时。

## 2026-04-17

- 已切换到新启动的 `30008` 实例继续推进，并重新建立认证 API 访问（`version 2.17.0`）。
- 在 stale-terminal websocket 不稳后，已重建终端状态并在终端 `2` 上恢复稳定执行。
- 已重新应用内联解析器加固（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`timeout:1`、`attempts:2`、`ndots:1`），并复核所需模型源主机（`www.modelscope.cn`、`paddle-model-ecology.bj.bcebos.com`、`git.aistudio.baidu.com`、`huggingface.co`）可解析。
- 已识别并移除会导致自终止的重启步骤：含自匹配文本的 kill 模式会在启动前触发 `Terminated`，改为无该自匹配点的启动路径。
- 已成功重新后台启动 `verify_inference.sh --mode speed-vllm --device dcu`，并确认 worker 与 `paddlex_genai_server` 进程存活。
- 当前运行检查点记为“进行中未收敛”：runner 仍在 vLLM 就绪等待阶段，server 日志显示官方模型准备启动，且本次 `30008` 窗口暂未出现新的即时 DNS 解析异常。
- 持续轮询后已捕获终态汇总：`Speed benchmark: failed-server`，`Overall: FAIL`。
- 已记录关键现象：即使同窗日志出现模型下载/处理与 API 启动信息，就绪判定仍先在 `180s` 处超时。
- 已验证收尾进程状态：speed-vllm worker/server 不再存活；`/tmp/paddle_amd_speed_vllm.rc` 仍未生成，因此以“明确汇总 + 进程退出证据”作为完成判据。
- 已启动下一步独立细分诊断（更长窗口的直接 vLLM 就绪探测），但端点健康立刻回退为 `HTTP 503` + API 超时，当前无法继续实例内复验。
- 在 2026-04-19 续跑中，已重新连通 `30008`、固定 DNS 并完成模型源主机解析校验后，再次启动“直接 vLLM 600s 就绪判别”。
- 长命令运行中 websocket 传输再次中断（`Connection to remote host was lost`），随后重登/API 探测均回退为 `HTTP 503` 与直接 API 超时。
- 当前再次处于基础设施阻塞状态，尚无法回收该判别运行的结果制品。
- 在下一次实例恢复后，改为“实例内后台脚本 + `/tmp/paddle_amd_vllm_direct.*` 结果文件”重跑判别，规避长等待阶段 websocket 丢流问题。
- 已捕获终态判别结果：`STATUS=READY`、`READY_AT_SEC=348`；直接日志包含 `Application startup complete`，本地 `GET /v1/models` 返回 `200 OK`。
- 本里程碑的根因分流已收敛：`verify_inference.sh` 的 `failed-server` 现有证据更符合“180s 就绪窗口不足”，而非 vLLM 必现即时初始化失败。
## 2025-05-27

- 在 gfx1100 / ROCm 7.2.0 上完成 PaddleOCR-VL-1.5 完整 BF16 端对端验证。
- 已应用全部 PaddleX 补丁（workaround 移除 + 额外兼容修复）：
  1. `paddlex/utils/misc.py`：`is_bfloat16_available()` 白名单新增 `"dcu"`（workaround #1）。
  2. `paddlex/inference/models/common/static_infer.py`：合并 ROCm `delete_pass` 守卫 + 添加 `FLAGS_conv_workspace_size_limit` 环境变量默认值（workaround #2）。
  3. `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`：移除 `_keep_in_fp32_modules = ["visual", "mlp_AR"]`（workaround #3）。
  4. `paddlex/inference/models/common/transformers/utils.py`：在 `device_guard()` 中添加 `dcu→gpu` 映射（新增修复；`paddle.set_device("dcu:0")` 会报错）。
  5. `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`：添加 `LayerNorm.forward` BF16→FP32 兼容垫片（新增修复；Paddle HIP wheel 未为 `bfloat16` 注册 `layer_norm` 内核）。
- 发现两个超出原始范围的新 Paddle C++ 根因：
  - **Bug A（conv2d）**：`fused_conv2d_add_act` 内核仅有 CUDA 实现，无 HIP → 修复方案：`#ifdef PADDLE_WITH_HIP` 守卫（已在补丁中）。
  - **Bug B（layer_norm）**：`layer_norm` HIP `PD_REGISTER_KERNEL` 未包含 `phi::bfloat16` → 修复方案：在 `layer_norm_kernel.cu` 中补充 `phi::bfloat16` 注册。
- 更新 Paddle 补丁：`patches/paddle-hip-bf16-kernels.patch`（59 行，涵盖 conv2d pass 守卫 + layer_norm BF16 注册）。
- 验证结果：**通过（PASS）** — `test_paddleocr_vl_bf16.py` exit 0，推理用时 202.8s，OCR 输出正确。
- 证据已保存至 `evidence/bf16_pipeline_validation_gfx1100.log`。
## 2026-04-22

- 在 `30001` 实例（gfx1100 / ROCm 7.2.0）继续 GPU 验证工作。
- 在远端安装 ROCm Paddle：
  - 修复 DNS（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`）。
  - 通过 apt 安装 `libopenblas0-pthread`。
  - 创建 SONAME 兼容符号链接：`ln -sf /opt/rocm/lib/libamdhip64.so.7 /opt/rocm-compat/libamdhip64.so.6`。
  - 上传本地编译的 ROCm Paddle wheel（`paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`，242MB）至 `/workspace/PaddleX/`。
  - 强制安装 wheel：`pip3 install --force-reinstall ...` → `paddlepaddle-dcu 3.4.0.dev20260408` 安装成功。
  - 验证：`paddle.is_compiled_with_rocm() = True`，`paddle.device.get_device() = gpu:0`。
- 使用 `scripts/test_conv2d_hip_pass.py` 运行 GPU 静态推理验证：
  - **测试 1（Bug 已确认）**：不删除 Pass → `RuntimeError: The kernel fused_conv2d_add_act is not registered`（ROCm gfx1100 上）。
  - **测试 2（修复验证通过）**：使用 `config.delete_pass("conv2d_add_act_fuse_pass")` + `config.delete_pass("conv2d_add_fuse_pass")` → 推理通过，输出 shape `(1, 16, 32, 32)`。
  - **测试 3（BF16 通过）**：`auto_cast(dtype="bfloat16")` 动态图推理在 GPU 上运行正常。
- 关键发现：本地编译的 ROCm Paddle wheel 在源码添加 `#ifdef PADDLE_WITH_HIP` 守卫之前就已完成构建，因此 wheel 中不含该修复。但测试结论明确：
  - Pass 是根因（`fused_conv2d_add_act` 在 HIP 上未注册）。
  - `delete_pass()` 等价于编译时守卫的效果，完全修复问题。
  - 含守卫的重新编译 wheel 在测试 1 中也不会崩溃。
- 备注 `FLAGS_conv_workspace_size_limit`：`enable_use_gpu()` 在 `analysis_predictor.cc` 中尝试 `SetGflag("conv_workspace_size_limit", "32")`，但该 gflag 在 HIP 构建中不存在（仅 CUDA/cuDNN）。解决方法：`export FLAGS_conv_workspace_size_limit=32`，可跳过 SetGflag 调用。这是 Paddle 推理预测器在 HIP 上的另一个兼容性问题。
- 更新双语验证文档（此次 GPU 推理验证结果已记录）。

### 更早的 2026-04-22 条目：

- 用户确认新实例 `30001` 已启动（`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`；新端口）。
- 立即接入：`login`/`info`/`list-terminals` 均返回 `version 2.17.0`，暂无已有终端。
- 创建终端 `1` 并执行环境诊断：
  - 容器镜像：一键式 PaddleOCR-VL Notebook，`oneclick_entrypoint.sh` 在容器启动时自动运行 `paddlex_genai_server`。
  - GPU agents：4（`rocminfo`）；ROCm 7.2.0；vLLM 已随入口脚本启动。  - 本镜像无 `verify_inference.sh`（与 30008 不同）。
  - `/opt/venv` 中 Paddle 版本为 3.1.1（仅 CPU）——与本次验证无关，vLLM 直接使用 PyTorch ROCm。
- 查看 `oneclick_entrypoint.sh`，确认 vLLM server 在容器启动时已通过 `nohup paddlex_genai_server … --backend vllm` 后台运行，日志写入 `/var/log/paddlex_vllm_server.log`。
- 轮询 vLLM 就绪状态；约 `23:34 UTC` 确认 READY（`Application startup complete`，`/v1/models` 返回 `200 OK`）。
  - 关键 vLLM 启动证据：`dtype=torch.bfloat16`、`Using Triton Attention backend on V1 engine`（ROCm 路径）、模型权重加载 1.9727 GiB，用时 2.5 秒。
- 修复 DNS（`223.5.5.5 / 8.8.8.8 / 1.1.1.1`，`timeout:1 attempts:2 ndots:1`），安装 `pynvml`（压测脚本依赖）。
- 定位压测目录 `/opt/paddlex/benchmarks/ocr-vlm-benchmark-f29cfe4/ocr-vlm-benchmark-f29cfe4/e2e/`；确认存在 `test_server.py`、`PaddleOCR-VL-1_5_vllm.yaml`、`test_local.py`。
- 确认 `test_server.py` 需要端口 8001 的 PaddleX HPS Triton 服务（未运行）；改用 PaddleX Python pipeline API 做等效验证。
- 编写 `/tmp/paddle_amd_speed_bench.py`，通过 `paddlex.create_pipeline(config=PaddleOCR-VL-1_5_vllm.yaml)` 顺序处理 PDF 并测量吞吐量。
- 以后台方式通过 `/tmp/paddle_amd_bench.sh` 启动（PID 1671）。
- 两次轮询进度，确认稳定在 `~0.16 pps`，所有文件成功处理。
- **最终结果（通过）**：`success_count=64/64`，`pages_per_sec=0.164`，`total_time_sec=391.03`，`BENCH_RC=0`。
  - 运行时间窗口：`2026-04-21T23:40:55+00:00` → `2026-04-21T23:47:33+00:00`。
- 更新所有双语验证日志、开发日志和变更日志文档。
- 对 Paddle/PaddleX HIP BF16 问题进行根因分析：
  - 确认 `conv2d` 内核在 ROCm 上已注册 BF16（无问题）。
  - 发现 `fused_conv2d_add_act_kernel.cu` 被 `#ifdef PADDLE_WITH_CUDA` 包裹——无 ROCm 内核。
  - 发现 `conv2d_add_act_fuse_pass` 和 `conv2d_add_fuse_pass` 在 `kPirGpuPasses` 中同时适用于 CUDA 和 ROCm，但会生成在 ROCm 上没有内核的 op 类型——导致运行时错误。
  - 这正是 PaddleX 在 ROCm 上删除这些 pass 作为临时方案的原因。
- 实现 Paddle 修复：在两个融合 pass 文件的 `InitializePatterns()` 中添加 `#ifdef PADDLE_WITH_HIP … return ps; #endif` 提前返回。
- 实现 PaddleX 清理：从 `static_infer.py` 中删除四处 ROCm `config.delete_pass()` 临时方案代码块；在 `misc.py` 的 `is_bfloat16_available()` 中将 `"dcu"` 加入设备类型允许列表。
- 保存补丁：`patches/paddle-hip-conv2d-fuse-pass-guard.patch` 和 `patches/paddlex-remove-rocm-workaround.patch`。
- 将 `paddlex-remove-rocm-workaround.patch` 应用到远端实例的 `/workspace/PaddleX/`（editable install）和 `/opt/venv/...`（site-packages）两处。
  - 原因：Python 从 `/workspace/PaddleX/`（editable install）导入，非 `/opt/venv/...`，因此需在两处均打补丁。
  - 功能验证（`remote_test_paddlex_patch.py`）：**5/5 全部通过**。
- 使用已打补丁的 PaddleX 重新运行全量 64 PDF 基准测试：
  - **结果（通过）**：`success_count=64/64`，`pages_per_sec=0.182`，`total_time_sec=351.83`
  - 运行窗口：`2026-04-22T00:20:30+00:00` → `2026-04-22T00:26:22+00:00`
  - 删除临时绕路代码后无回归。pps 略有提升（0.182 vs 0.164），因缓存已预热。
- 更新验证文档（基线结果和补丁后结果均已记录）。

## 2026-04-20

- 用户报告 `30008` 实例已启动后立即恢复执行，重新验证 API 可用（`version 2.17.0`）且终端 `1` 可见。
- 启动“先就绪再集成”续跑序列以规避已知 `180s` 冷启动门限风险：先固定 DNS、先校验模型源域名、先预检/启动 vLLM 并最长等待 `600s` 就绪，再执行 `verify_inference.sh --mode speed-vllm --device dcu` 并落盘制品。
- 长命令执行过程中命令流中断（`Connection to remote host was lost`），未能在该次流中完整回收终态输出。
- 随后端点立即回退，重复执行 `jupyter_remote.py login/info/list-terminals` 持续返回 `HTTP 503`。
- 本窗口已记录为“执行中基础设施中断”；当前没有推翻既有“就绪预算不足”判断的新证据。
- 在下一次用户触发的 `30008` 重启后，已重新连通（`version 2.17.0`、终端 `1`），并启动后台 ready-first 执行脚本（`/tmp/paddle_amd_speed_vllm_readyfirst.sh`）以降低 websocket 脆弱性影响。
- 已捕获运行中里程碑：在显式 `600s` 就绪门控下，vLLM 于 `VLLM_READY_AT_SEC=358` 达到可用，随后 `verify_inference.sh --mode speed-vllm --device dcu` 进入 speed 压测阶段。
- 最新检查点为“进行中待收敛”：当前 speed 压测仍在运行，vLLM server 日志持续返回 `/v1/chat/completions` `200 OK`。
- 后续在 `2026-04-20T07:45:21+00:00` 快照中确认：`STATUS=RUNNING`、rc 待产出，后台 runner 与 verify worker 仍存活。
- 在继续执行“等待到收敛”的长命令时，websocket 再次中断（`Connection to remote host was lost`）；紧随其后的 `login/info/list-terminals` 均回退为持续 `HTTP 503`。
- 当前该轮状态更新为“最终 rc 回收前再次被基础设施中断”。

## 记录模板

- 日期：
- 环境：
- 动作：
- 结果：
- 下一步：