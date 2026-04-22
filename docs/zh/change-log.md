[English Version](../en/change-log.md)

# 变更日志

## 2026-04-08

- 初始化 git 仓库
- 创建项目目录结构

## 2026-04-09

- 创建已忽略的嵌套上游工作区 `paddlerepos/`
- 删除不稳定的嵌套 clone，并重新完成两个仓库的干净 clone
- 验证本地 Paddle `develop` clone，并记录其路径与 commit
- 验证本地 PaddleX `develop` clone，并记录其路径与 commit
- 添加双语工作区环境与复现指南
- 为控制平面仓库添加 GitHub origin remote
- 添加远程 AMD Jupyter 工作流 skill 与辅助脚本
- 添加 Jupyter terminal websocket 自动化支持
- 记录首次通过认证的远程 ROCm 环境检查运行结果
- 添加可复用的按实例远程准备自动化流程
- 修复远程 bootstrap 完成态处理，并在真实 Jupyter 实例上验证按实例 bootstrap 成功
- 将远程实例策略从“无条件重新准备”修正为“先检查再准备”
- 记录 `paddlepaddle==3.3.1` 在当前远程环境中安装后为仅 CPU wheel
- 添加按“先检查再构建”方式运行的远程 Paddle ROCm 源码构建探测脚本
- 记录首次远程 ROCm 源码 configure 阻塞，并收紧脚本对 Python 环境的修改范围
- 为远程源码探测脚本增加 HTTP/1.1 子模块重试逻辑和 ROCm 头文件兼容软链接
- 将远程 configure 探测推进到新的 `hip_add_library` 兼容性阻塞点
- 新增后台启动远程 configure 的脚本，并记录 fresh backend 上当前的 terminal websocket 不稳定问题
- 修复后台远程 configure 启动脚本中的嵌套 heredoc 展开失败问题，并在 live `30005` backend 的终端 `3` 上验证重新启动成功
- 识别出 fresh backend 上下一条 configure 阻塞为缺少 `patchelf`，完成远程安装后再次启动 configure，并推进到更深的 CMake 阶段
- 加固远程子模块恢复辅助脚本，把“只有 `.git` 重定向文件的空工作树”也视为损坏状态
- 修复远程 `third_party/warprnnt` checkout，并将首个定向 `paddle_python` 构建推进到原始 `extern_warprnnt` 失败点之后
- 识别出新的远程构建阻塞：外部 WarpCTC 的 ROCm configure 未透传 `CMAKE_MODULE_PATH`，导致 `HIP_ADD_LIBRARY` 未定义
- 添加本地 Paddle 实验性补丁，使 `cmake/external/warpctc.cmake` 向外部 WarpCTC configure 透传 `CMAKE_MODULE_PATH`
- 验证了新的 `30008` AMD 预装实例，该实例已自带可用的 ROCm Paddle 构建，并在 `gpu:0` 上报告 BF16 支持 API 为 ready
- 记录了该实例上后续实时 BF16 matmul 受 terminal websocket 断开影响，属于传输层限制，而不是已确认的运行时失败
- 记录了同一 `30008` 实例上的已确认 BF16 GPU 运行时崩溃：尽管 BF16 支持 API 返回 `True`，`paddle.randn(..., dtype="bfloat16")` 仍会在 Gaussian kernel 路径内部触发段错误
- 验证了更新的 `30006` 预装实例当前不能作为有效验证目标：虽然 ROCm 与 BF16 就绪 API 都报告正常，但直接 BF16 `randn` 会段错误，连 float32 GPU `ones` 也会在 `phi::FullKernel` 内部段错误
- 细化了 `30006` 的判断：该镜像当前无法从外部 clone，`to_tensor` 加 float32 `matmul` 仍可运行，但 GPU `full`、`gaussian` 与 float32 到 BF16 的 `cast` 路径都会段错误
- 记录了当前本地 WSL 机器具备可用的 ROCm 构建工具链，可以作为候选本地 Paddle ROCm wheel 构建主机，同时明确标注本地 ROCm 6.4.2 与远程 ROCm 7.2.x 之间的版本错配风险
- 启用了首条本地 ROCm Paddle wheel 构建路径，当前使用 ROCm Clang、`PADDLE_SKIP_FLASHATTN=ON` 与本地 `rocm-compat` 兼容层
- 修复了本地 ROCm 构建在 `warprnnt`、`warpctc`、OpenBLAS 检测以及编译器切换后外部工程残留安装状态上的阻塞
- 从多个 `paddle/phi/kernels/funcs` HIP 编译单元中移除了不必要的 Eigen 依赖链，并为 `fake_quantize_functor.cu` 恢复了其真正需要的显式 `memory_utils` 头文件依赖
- 对本地三方 Eigen `Half.h` 打补丁，使 HIP half `log()` 在当前 ROCm 栈上避开失效的 `::hlog(a)` 路径，改走 float fallback
- 将本地串行 ROCm 构建重新推进到 `paddle/phi/kernels/funcs/eigen/` 下的 HIP 目标编译阶段，不再立刻卡在此前反复出现的 `Half.h:669` 失败点
- 修复了下一处本地 ROCm 串行构建阻塞：`paddle/phi/api/lib/tensor_utils.cc` 在 HIP 指针属性判断中使用了当前 ROCm 6.4.2 不再暴露的 `memoryType`，现已切换为正确字段 `type`
- 已先对此前失败的 `tensor_utils.cc` 单对象重编译验证成功，然后再恢复完整串行构建
- 修复了恢复构建后的下一处本地 ROCm 串行阻塞：compat c10 CUDA 层在 HIP 构建下仍直接依赖 CUDA 头文件与 CUDA 名称，现已在 `paddle/phi/api/include/compat/c10/cuda/CUDAException.h` 中补充 HIP 兼容映射
- 已通过重编译此前失败的 `paddle/phi/api/include/compat/c10/cuda/CUDAStream.cpp.o` 验证该 compat 层修复成功
- 修复了恢复构建后的下一处本地 ROCm 串行阻塞：`paddle/phi/core/memory/allocation/allocator_facade.cc` 在共享 CUDA/HIP 路径中仍无条件引入 `cuda_driver.h`，现已收紧为仅 CUDA 分支包含
- 已通过重编译此前失败的 `allocator_facade.cc.o` 验证该 allocator facade 修复成功
- 在恢复构建因 `stream_callback_manager.h` 缺少 `ThreadPool.h` 失败后，已恢复空的 `third_party/threadpool` 子模块工作树
- 已通过重编译此前失败的 `paddle/phi/core/platform/stream_callback_manager.cc.o` 目标验证该子模块恢复成功，且无需新增源码修改
- 已为 `paddle/phi/kernels/funcs/cross_entropy.cc` 补充缺失的共享 Eigen helper include，使本地 ROCm 串行构建中的 `EigenMatrix` wrapper 与 `Eigen::DSizes` 引用能够正确解析
- 已为 `paddle/phi/kernels/funcs/fake_dequantize_functor.cc` 补充缺失的共享 Eigen helper include 与本地 `EigenVector` alias
- 已为 `paddle/phi/kernels/funcs/fake_quantize_functor.cc` 补充缺失的 `transform.h`、共享 Eigen helper include、clip kernel helper include，以及本地 `EigenVector` alias
- 已新增共享 HIP rocPRIM 兼容桥 `paddle/phi/kernels/funcs/hip_radix_sort_compat.h`，用于统一适配 Paddle float16 与 bfloat16 的 radix sort trait
- 已将共享 HIP radix sort 兼容桥接入 `paddle/phi/kernels/funcs/cub.h` 与 `paddle/phi/kernels/funcs/top_k_function_cuda.h`
- 已移除 `paddle/phi/kernels/gpu/argsort_kernel.cu`、`paddle/phi/kernels/gpu/argsort_grad_kernel.cu` 与 `paddle/phi/kernels/funcs/top_k_function_cuda.h` 中陈旧且分散的 rocPRIM radix sort shim
- 已修复 `cross_entropy.cc`、`fake_dequantize_functor.cc` 与 `fake_quantize_functor.cc` 中残留的后续 alias 问题，把本地 Eigen helper alias 显式绑定到 `phi::EigenMatrix` 与 `phi::EigenVector`
- 已统一规范 `fake_quantize_functor.cc` 中剩余的 `phi::ClipFunctor` 调用点，并通过定向重编译验证这三个此前失败对象全部修复成功
- 已在定向验证后恢复本地串行 ROCm 构建，并将构建推进到更大范围的 CPU kernel 编译阶段，越过此前的 helper 失败区间
- 添加双语计划、设计、决策、验证与开发日志文档
- 添加项目级 Copilot 指令，用于约束文档与跟踪规范

## 2026-04-13

- 修复了 `paddle/phi/kernels/gpu/top_k_kernel.cu` 中的本地 HIP top-k 构建阻塞：将 HIP 运行时 block 选择钳制到至少一个完整 wave，并从生成分派中移除 HIP 32 线程特化
- 已通过重编译 `paddle/phi/CMakeFiles/phi_gpu.dir/kernels/gpu/phi_gpu_generated_top_k_kernel.cu.o` 验证 top-k 修复成功
- 修复了 `cmake/external/dlpack.cmake` 中 DLPack include 传播问题，使 `dlpack` target 正式导出 interface include 目录
- 为 `paddle/fluid/platform/densetensor_printer` 增加了直接 `dlpack` 依赖
- 在确认子模块仓库元数据存在但工作树缺失公共头文件后，恢复了受跟踪的 `third_party/dlpack/include/dlpack/dlpack.h`
- 已通过重编译 `paddle/fluid/platform/CMakeFiles/densetensor_printer.dir/densetensor_printer.cc.o` 验证 DLPack 侧修复成功
- 在两次精确定向验证完成后，已恢复完整本地串行 `paddle_copy` 构建，并将构建推进到更后面的 framework 与 IR 目标
- 修复了 `paddle/phi/backends/dynload/rocm_driver.cc` 中后期出现的 ROCm dynload 链接阻塞：在基础 ROCm wrapper 列表之外，补齐已声明但未实例化的 VMM 与 GPU graph wrapper 组
- 已通过精确重编译此前失败的 `eager_generator` 目标并重新生成 `build-rocm-local/paddle/fluid/pybind/eager_generator` 可执行文件，验证 dynload 修复成功
- 在完成该 dynload 精确定向验证后，已恢复完整本地串行 `paddle_copy` 构建，并将构建推进到旧的 `eager_generator` 停止点之后

## 2026-04-14

- 已用一次性虚拟环境对本地构建的 `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl` 完成冒烟验证，并在验证后删除该虚拟环境
- 已记录该本地 wheel 导入后版本为 `3.4.0.dev20260408`，且在 WSL 主机上报告 ROCm 与 CUDA 编译标志都为 `True`
- 已加固 `scripts/jupyter_remote.py` 的 token 登录与 websocket 建立流程，使其在 token 登录期间建立浏览器风格 cookie，并在 terminal websocket 尝试时发送 cookie 与 origin 头
- 已在 live `30006` 实例级 Jupyter 端点上创建远程终端 `paddle-amd-bf16`
- 已记录 live 实例上向 `uploaded-wheels/` 上传会失败，因为 Jupyter contents 根目录下不存在该目录
- 已将构建得到的 wheel 成功上传到 live 远程工作区根目录，文件名为 `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- 已记录当前远程阻塞：针对 live `30006` notebook 栈的 terminal websocket 执行返回的是 HTML terminal 页面，而不是 websocket 升级，因此远程安装与冒烟执行仍待完成
- 已在重启后的 `30006` 实例上重试，并确认远程终端 `1` 的 terminal websocket 执行已恢复
- 已在远程强制重装构建得到的 wheel，并确认预装的 `paddlepaddle-dcu 3.4.0.dev20260404` 已被替换为 `3.4.0.dev20260408`
- 已确认第一条远程运行时阻塞是 ROCm SONAME 错配：wheel 依赖 `libamdhip64.so.6`，而镜像提供的是 `libamdhip64.so.7`
- 已通过 `/opt/PaddleX/rocm64-compat` 下的窄范围兼容软链接证明该 SONAME 诊断成立，并把后续导入失败推进到缺少 `libopenblas.so.0`
- 已确认当前 `30006` 镜像中不存在可发现的 OpenBLAS 运行时，而且基于系统包的修复路径也被阻塞，因为 `apt-get update` 的外部 DNS 解析失败
- 已将本轮重试的最终状态记录为“镜像不适合作为验证目标”而不是“传输层问题”：terminal 执行可用、wheel 安装可用，但该远程运行时对当前 wheel 仍不完整

## 2026-04-15

- 已切换到新实例 `http://36.151.243.69:30002/instance/nb-1838d2b6/lab` 继续远程流程，验证 helper 登录成功，并确认 terminal `1` websocket 命令执行可用
- 已复现默认解析器下的 DNS 故障，并确认原始解析状态下 `apt-get update` 会失败
- 已验证“保留集群 DNS + 追加公共 DNS + ndots:1”的混合解析策略，可恢复 Ubuntu/security/PPA/GitHub 域名解析
- 已确认 `apt-get update` 现在可成功刷新 Ubuntu 与 PPA 索引（仅对未解析的 `compute-artifactory.amd.com` 保留 warning）
- 已通过成功安装 `libopenblas0-pthread` 验证：远程 apt 包操作已解除阻塞
- 已更新 `scripts/render_remote_dns_repair.sh`：保留已有 nameserver、追加 fallback 解析器、默认以公共主机解析就绪为成功标准，并新增可选严格参数 `--require-compute-artifactory`
- 已通过 `scripts/remote_fix_instance_dns.sh 1` 完成更新后 helper 的端到端验证
- 已新增 `scripts/render_remote_dns_repair.sh`，用于为损坏的 Jupyter 实例生成定向的远程 resolver 修复流程
- 已新增 `scripts/remote_fix_instance_dns.sh`，用于通过活动 Jupyter 终端执行该 DNS 修复流程
- 已为 `scripts/render_remote_bootstrap.sh` 加入 DNS 预检，使远程 bootstrap 在所需主机无法解析时能够快速失败并给出明确修复步骤
- 已在双语 setup 指南中补充 DNS 修复工作流说明
- 已确认 DNS 故障会在实例重启后复发，并验证重新执行 `scripts/remote_fix_instance_dns.sh 1` 可以在 `30002` 上恢复包源主机解析
- 已在重启后的 `30002` 实例上重新上传本地 wheel，并在 `/opt/venv` 中完成强制重装
- 已重新应用 `/opt/PaddleX/rocm64-compat` 下的 HIP SONAME 兼容软链接
- 已完成远程 GPU 冒烟成功验证：`paddlepaddle-dcu 3.4.0.dev20260408` 在 `gpu:0` 上运行正常，float32 matmul 输出正确
- 已在同一重启后的 `30002` 实例上完成 BF16 算子级探测：BF16 `randn`、float32 到 BF16 `astype`、BF16 `matmul` 均成功
- 已执行集成 quick 验证 `/opt/PaddleX/verify_inference.sh --mode quick --device gpu`；preflight 通过，但 native 推理在 GPU kernel 路径（`phi::AddRawKernel<float, phi::GPUContext>`）段错误
- 已启动 `--device dcu` 定向复验，但实例中途下线并返回 `HTTP 503`，该复验暂挂起
- 实例恢复后已重启 `--device dcu` 定向复验，并确认与 `--device gpu` 相同的 native 段错误路径，可排除简单 device 别名因素
- 已在 live 实例内联修复 resolver（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`ndots:1`），恢复模型源域名解析，并观测到 `PP-DocLayoutV3` 从 ModelScope 成功下载后仍在 native 阶段崩溃
- 已记录恢复后 `--device dcu` quick 复验的最终结果：native 段错误失败，vLLM 在 180s 就绪等待后 `failed-server`，汇总为 `Overall: FAIL`
- 已记录标记细节：尽管汇总已输出且工作进程已退出，包装层 done 文件 `/tmp/paddle_amd_quick_dcu.done` 仍未生成
- 已记录结果抓取后的基础设施阻塞：`30002` 端点再次下线（`HTTP 503` 与 API 超时），导致同一窗口内无法执行最后清理命令
- 在下一次实例恢复后，已重新应用内联 DNS 修复并确认公共模型源域名解析正常
- 已新增不经过 `verify_inference.sh` 的独立 native 复现，并复现同一路径 `phi::AddRawKernel<float, phi::GPUContext>` 段错误
- 已新增不经过 `verify_inference.sh` 的独立 vLLM 启动复现；在冷启动长路径后可达到 API 启动完成（`Application startup complete`）
- 已记录分流判断：native 路径仍是硬崩溃阻塞；vLLM quick 失败更像冷启动就绪窗口敏感问题

## 2026-04-16

- 在确认 resolver 已回退到默认集群 DNS 状态后，继续推进 `30002` 上的 `speed-vllm` 续跑
- 重新应用带公共 fallback 的内联 resolver，并验证 ModelScope、BOS、Aistudio、Hugging Face 相关模型源域名可解析
- 以新的 `/tmp/paddle_amd_speed_vllm.log` 与 `/tmp/paddle_amd_speed_vllm.rc` 标记，重新后台启动 `/opt/PaddleX/verify_inference.sh --mode speed-vllm --device dcu`
- 在本轮续跑窗口确认 worker 与 `paddlex_genai_server` 进程存活，并抓取到“vLLM 就绪等待 + 官方模型冷启动/下载”日志状态
- 记录当前检查点为进行中：此前 DNS `NameResolutionError` 签名暂未主导，本轮 speed-vllm 最终通过/失败结果仍待收敛
- 在清理/轮询过程中再次捕获端点中断：终端流返回 `Connection to remote host was lost`，随后健康探测出现 `HTTP 503` 与 API 超时
- 将本轮状态维持为“基础设施可用性中断待恢复”
- 在继续推进时再次记录“短暂恢复后再中断”循环：端点短时可创建新终端，但在 speed-vllm 产出最终 rc 前又回到 `HTTP 503` + API 超时

## 2026-04-17

- 已切换续跑端点到新启动的 `30008` 实例，并恢复认证 API 访问
- 已重建远程终端清单，并在新终端 `2` 上恢复执行
- 已重新固定解析器（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`timeout:1`、`attempts:2`、`ndots:1`），并复核 ModelScope、BOS、Aistudio、Hugging Face 相关模型源域名可解析
- 已定位重启脚本陷阱：自匹配 kill 模式会导致启动 shell 被 `Terminated`；随后切换为无自匹配启动路径
- 已成功重新后台启动 `verify_inference.sh --mode speed-vllm --device dcu`，并确认 worker 与 `paddlex_genai_server` 进程存活
- 当前结果记录为进行中（`RC=PENDING`）：runner 停留在 vLLM 就绪等待，server 处于官方模型准备阶段
- 持续轮询到终态汇总后，已记录本轮最终结果为 `Speed benchmark: failed-server`，`Overall: FAIL`
- 已记录门限关系：即使后续日志出现模型下载与 API 启动信息，失败仍由 180s 就绪超时先触发
- 已记录完成性细节：speed-vllm worker/server 进程已退出，但 `/tmp/paddle_amd_speed_vllm.rc` 未写出
- 在汇总后立刻尝试独立细分诊断时，端点可用性回退到 `HTTP 503` 与直接 API 超时，本窗口无法继续远程诊断
- 在 2026-04-19 续跑中，已重连 `30008`、固定 DNS 并启动“直接 vLLM 600s 就绪判别”；命令运行中 websocket 中断，端点随即回退为 `HTTP 503` + API 超时，无法回收结果制品
- 在下一次恢复后，改为后台脚本并落盘结果文件重跑“直接 vLLM 判别”，已捕获 `STATUS=READY` 与 `READY_AT_SEC=348`
- 已确认直接 vLLM 日志达到 `Application startup complete`，并对 `GET /v1/models` 返回 `200 OK`
- 已记录判别结论：`verify_inference.sh` 的 `failed-server` 主要是冷启动下 180s 就绪预算不足，而非后端必现即时初始化失败

## 2026-04-22

- 重新接入新实例 `30001`（端口从此前 `30008` 变更）
- 确认一键式容器已自动启动 vLLM；首次检查时 vLLM 即处于 READY 状态，`dtype=torch.bfloat16`，ROCm Triton 后端已激活
- 确认本镜像无 `verify_inference.sh`；改用 PaddleX Python pipeline API 做等效验证
- 以 `paddlex.create_pipeline`（使用 `PaddleOCR-VL-1_5_vllm.yaml` 配置：版面检测 + vLLM-server VL 识别）启动后台压测脚本
- **通过：64/64 个 PDF 处理成功，吞吐量 0.164 pps，BENCH_RC=0** — AMD ROCm 上首次完整端对端 BF16 验证通过
- 更新所有双语验证日志、开发日志和变更日志文档，包含通过结果与完整证据- 确认根因：`fused_conv2d_add_act` 内核仅有 `#ifdef PADDLE_WITH_CUDA` 编译，conv2d 融合 pass 在 ROCm 上生成该 op 导致运行时错误
- 实现 Paddle 修复：在 `conv2d_add_act_fuse_pass.cc` 和 `conv2d_add_fuse_pass.cc` 的 `InitializePatterns()` 中添加 `#ifdef PADDLE_WITH_HIP` 提前返回
- 实现 PaddleX 清理：从 `static_infer.py` 删除 4 处 ROCm `config.delete_pass()` 临时方案代码块；在 `misc.py` 的 `is_bfloat16_available()` 中将 `"dcu"` 加入允许列表
- 保存补丁：`patches/paddle-hip-conv2d-fuse-pass-guard.patch`、`patches/paddlex-remove-rocm-workaround.patch`
- 将 `paddlex-remove-rocm-workaround.patch` 应用至远端实例 `/workspace/PaddleX/`（editable install，Python 实际导入来源）和 `/opt/venv/lib/python3.12/site-packages/paddlex/`
- 运行 `remote_test_paddlex_patch.py`：**5/5 全部通过** — "dcu" 已加入允许列表，delete_pass 临时绕路代码已删除，create_pipeline 导入正常
- 使用已打补丁的 PaddleX 重新运行全量 64 PDF 基准测试：**通过：64/64，0.182 pps** — 删除临时绕路代码后无回归
## 2026-04-20

- 在用户报告新 `30008` 实例启动后恢复执行，并重新确认初始 API 可用（`version 2.17.0`）与终端 `1`
- 启动“先就绪再集成”续跑序列（DNS 固定、模型源校验、vLLM 最长 600s 预热就绪，再执行 `verify_inference.sh --mode speed-vllm --device dcu` 并落盘制品）
- 长命令中途丢失终端流（`Connection to remote host was lost`），未能完整回收该轮输出
- 丢流后端点立即回退，重复 API 重试持续返回 `HTTP 503`
- 已将该窗口记为基础设施中断，不作为最终验证结论
- 在下一次 `30008` 重启后已恢复连接，并启动后台 ready-first 执行脚本（`/tmp/paddle_amd_speed_vllm_readyfirst.sh`），同时完成 DNS 固定与主机校验
- 已记录新的运行中里程碑：在显式 `600s` 门控下，vLLM 就绪达到 `VLLM_READY_AT_SEC=358`
- 已确认就绪后进入 benchmark 阶段（`verify_inference.sh --mode speed-vllm --device dcu` 对本地已就绪 vLLM 进入 speed 压测）
- 当前状态记录为“进行中待收敛”，等待压测结束产出最终结果
- 已记录运行中快照（`2026-04-20T07:45:21+00:00`）：`STATUS=RUNNING`、rc 待产出，后台 runner 与 verify 进程存活
- 在进一步长等待收敛时再次丢流，且端点健康立刻回退为持续 `HTTP 503`
- 已将最新状态更新为“最终 rc 回收前再次被基础设施中断”