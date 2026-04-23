[English Version](../en/decision-log.md)

# 决策日志

## 2026-04-08 - 将本仓库作为协调仓库使用

- 状态：已接受
- 背景：该任务同时涉及 Paddle、PaddleX、跨环境验证以及提交物整理。
- 决策：本仓库仅作为文档、补丁与证据的控制平面，不内嵌上游源码树。
- 影响：Paddle 和 PaddleX 将在独立 clone 中开发，本仓库保持稳定与聚焦。

## 2026-04-08 - 以原生 Linux ROCm 作为最终验证标准

- 状态：已接受
- 背景：当前本地工作环境为 WSL，AMD GPU 执行稳定性尚不足以作为最终依据。
- 决策：WSL 仅用于编辑与编排，权威验证依赖原生 Linux ROCm 硬件或远程 ROCm 机器。
- 影响：脚本与补丁流必须支持跨机器执行。

## 2026-04-09 - 远程 Jupyter 执行采用 API 加 websocket 自动化模式

- 状态：已接受
- 背景：当前 AMD 集群通过 HTTP 暴露 Jupyter Lab，实例创建需要手动完成。认证后的 API 可访问，terminal websocket 也可用于命令执行。
- 决策：远程验证采用混合工作流：手动创建实例、在有凭据时通过脚本访问 Jupyter API，并在远程终端可用时通过 websocket 执行命令。
- 影响：后续每次远程测试仍应记录哪些步骤是自动化完成的，哪些步骤需要人工介入。

## 2026-04-09 - 每个新建 Jupyter 实例都需要先检查再准备

- 状态：已接受
- 背景：远程 AMD 集群实例属于临时环境，新建实例可能既没有 Paddle，也没有项目工作区。
- 决策：将远程实例准备视为必须复用的固定流程，但先进行环境检查，再只补齐缺失或不符合要求的部分；只有在 Paddle 缺失或构建不合适时才安装或编译。
- 影响：远程测试自动化必须以环境核验和 Paddle 可用性检查为起点，同时避免不必要的重复安装。

## 2026-04-09 - 仅 CPU 的 pip Paddle 不能作为远程验证终点

- 状态：已接受
- 背景：在当前远程 `/opt/venv` 中安装 `paddlepaddle==3.3.1` 虽然成功，但所得包报告 `is_compiled_with_rocm() == False`。
- 决策：通用 pip Paddle 安装仅作为快速可用性探测手段。对本任务而言，任何不报告 ROCm 支持的远程 Paddle 构建都视为不合适，下一步必须转入源码构建探测。
- 影响：远程准备流程需要显式支持 ROCm 源码 configure 或 build 路径，不能依赖通用 pip 安装结束。

## 2026-04-10 - 远程子模块健康检查必须验证真实工作树，而不能只看子模块元数据

- 状态：已接受
- 背景：首个定向 `paddle_python` 构建在 `extern_warprnnt` 处失败，但此前的 `git submodule status --recursive` 并未报告缺失项。现场实例上的 `third_party/warprnnt` 实际只有 `.git` 重定向文件，没有任何 checkout 内容。
- 决策：只有同时具备子模块元数据和非空工作树时，才把子模块视为健康。远程辅助脚本必须把空工作树视为损坏状态并强制恢复，而不能只信任状态输出。
- 影响：远程准备与 configure 辅助脚本现在需要增加一次工作树内容校验；相比旧的“更快但更弱”的检查，这一步更重要。

## 2026-04-10 - BF16 支持 API 不能作为充分的验收证据

- 状态：已接受
- 背景：在新的 `30008` ROCm 实例上，Paddle 虽然报告 `is_compiled_with_rocm() == True`、`paddle.device.is_bf16_supported() == True`、`paddle.cuda.is_bf16_supported() == True`，但实时 BF16 `paddle.randn` 路径仍会在 GPU Gaussian kernel 内部触发段错误。
- 决策：将 BF16 capability API 仅视为初始 ready 信号。该任务的最终验证必须至少包含一次真实的 BF16 Tensor 创建与执行路径，而不能只停留在 capability 查询。
- 影响：后续每次验收运行都必须包含具体的 BF16 运行时操作；凡是仅有 API 查询成功的结果，都必须明确标注为“不充分”。

## 2026-04-10 - 预装 ROCm 镜像在做 BF16 验证前必须先过 float32 GPU 冒烟检查

- 状态：已接受
- 背景：在 `30006` 上，预装镜像虽然报告 ROCm 支持、`gpu:0` 和 BF16 支持 API 全部 ready，但连 `paddle.ones([2,2], dtype="float32")` 这样的最小 GPU 路径都会在 `phi::FullKernel<float, phi::GPUContext>` 内部段错误。
- 决策：对任何预装镜像，在投入 BF16 专项验证之前，先执行至少一个最小 float32 GPU Tensor 物化对照，例如 `paddle.ones` 或 `paddle.full`。
- 影响：凡是连 float32 GPU 冒烟检查都失败的镜像，立即排除出验证目标列表，因为在其之上做 BF16 专项诊断会被更底层的运行时故障混淆。

## 2026-04-10 - 对预装镜像要区分“创建类 kernel 故障”和“GPU 全面失效”

- 状态：已接受
- 背景：在 `30006` 上，`paddle.ones`、`paddle.randn` 与 GPU 上的 float32 到 BF16 `astype` 都会段错误，但 `paddle.to_tensor(..., place="gpu")` 与 float32 `paddle.matmul` 仍然可以成功。
- 决策：当预装镜像先在创建类 kernel 冒烟测试上失败时，再补一个非创建类对照，例如 `paddle.to_tensor(..., place="gpu")` 加一个简单的 float32 `matmul`，再判断该镜像是否属于“GPU 全面失效”。
- 影响：后续排障可以把“镜像上的局部 kernel 失效”和“整个 GPU 运行时无法工作”区分开，从而让问题报告与 workaround 讨论更准确。

## 2026-04-11 - 允许在 WSL 本地做 ROCm 构建，但远程验证仍是权威标准

- 状态：已接受
- 背景：当前本地机器是 WSL2 Ubuntu 24.04.3，具备 Python 3.12.3、来自 ROCm 6.4.2 的 `hipcc`、`rocminfo`、`cmake` 与 `ninja`。当前远程预装镜像线使用的是 Python 3.12 与 ROCm 7.2.x。
- 决策：当本地 WSL 已具备完整工具链时，允许其作为候选 Paddle ROCm 构建主机；但权威运行与验收仍只依赖原生 Linux ROCm 或远程 AMD ROCm 执行结果。
- 影响：采用“本地构建 wheel、远程部署并测试”的工作流是合理的，但必须把本地构建主机与远程验证主机之间的 ROCm 和 Python 版本对齐视为兼容性要求，而不是事后再处理的问题。

## 2026-04-11 - 当 HIP 编译失败收敛到 Eigen `Half.h` 时，优先做共享兼容修复而不是继续堆叠逐文件 workaround

- 状态：已接受
- 背景：多个彼此无关的本地 ROCm HIP 编译失败先后出现在 `affine_grid_utils.cu`、`cross_entropy.cu`、`fake_dequantize_functor.cu`、`fake_quantize_functor.cu`，以及后来的 `math_function.cu` 中，但终端特征都收敛到同一条 Eigen 失败路径：`Eigen/src/Core/arch/Default/Half.h:669` 中的 `half log()` 调用了 `::hlog(a)`，而当前 ROCm 栈会把该调用错误地解析到 BF16 重载。
- 决策：对于明显“头文件过宽”的场景，先做小范围逐文件 include 收敛；但一旦某个真正依赖 Eigen 的翻译单元也命中同一失败路径，就转而对本地 Eigen 做一个最小共享修复，而不是继续叠加脆弱的文件级 workaround。
- 影响：当前本地构建流程已经依赖 Eigen `Half.h` 中的一个窄范围 HIP 兼容补丁；后续 HIP 编译继续推进时，应视为对共享修复有效性的验证，而不是把每个剩余翻译单元都当成独立修复的结果。

## 2026-04-13 - 在 HIP top-k 上保持 wave64 语义，并移除无效的 32 线程特化

- 状态：已接受
- 背景：本地 ROCm 构建在生成式 top-k HIP 代码中失败，原因是 HIP 路径把 `WARP_SIZE` 固定为 `64`，但分派宏仍会实例化 32 线程特化，从而在编译期生成零长度共享数组。
- 决策：保持 HIP 实现与 wave64 假设一致，而不是尝试强行引入 wave32 语义。具体做法是把 HIP 运行时 block 选择钳制到至少一个完整 wave，并从生成分派中去掉 HIP 32 线程特化。
- 影响：该修复保持了最小改动并与当前 ROCm 执行模型一致；此前失败的生成式 top-k 对象现已可干净重编译，而无需引入更大范围的 launch policy 重写。

## 2026-04-14 - 在 live Jupyter 栈上将“远程制品落盘”和“远程命令执行”视为两个独立检查点

- 状态：已接受
- 背景：在 live `30006` 实例上，基于实例级 URL 的认证 Jupyter API、终端创建与 contents 上传都可以工作，但 terminal websocket 执行当前会返回 HTML terminal 页面，而不是升级为 websocket 连接。
- 决策：将远程制品传输与远程命令执行记录为两个独立验证检查点。当 websocket 执行受阻但 contents API 仍可用时，先立即把 wheel 放到实例上，并把剩余缺口明确标注为传输层或 notebook 栈阻塞。
- 影响：即使 terminal 通道回退，live 远程部署进度也不会丢失；后续解阻工作可以聚焦在命令传输，而不会与制品可用性混在一起。

## 2026-04-14 - 当远程镜像的基础运行时修复路径在依赖排查后仍受阻时，直接判定其不适合作为验证目标

- 状态：已接受
- 背景：在重启后的 `30006` 实例恢复 terminal 执行后，部署上去的本地 ROCm 6.4.2 wheel 首先因缺少 `libamdhip64.so.6` 导入失败；加入窄范围 SONAME 兼容软链接后，失败继续前移到缺少 `libopenblas.so.0`。当前镜像中没有可发现的 OpenBLAS 运行时，而 `apt-get update` 又因无法解析标准 Ubuntu、deadsnakes 与 AMD 软件源域名而失败。
- 决策：一旦 terminal 传输恢复，就继续做精确依赖排查，直到 wheel 成功导入，或者明确证明该镜像缺少基础运行时组件且无法通过正常系统包路径修复。达到后一种条件时，直接将该镜像排除为验证目标，而不是继续叠加更深层的临时运行时 shim。
- 影响：当前 `30006` 实例已被归类为不适合作为本地构建 wheel 的验收环境；下一步有效验证目标必须要么提供版本对齐的 ROCm 运行时和基础数学库，要么至少具备可正常安装这些依赖的包管理与网络能力。

## 2026-04-15 - 默认以公共包源可达性作为 DNS 成功门槛，私有 artifactory 解析改为按需严格检查

- 状态：已接受
- 背景：在新的 `30002` 实例上，混合解析配置已经恢复 Ubuntu/security/PPA/GitHub 解析并解除 apt 包操作阻塞，但 `compute-artifactory.amd.com` 仍不可解析。
- 决策：对“本地改动后远程 sync/build/deploy/test”工作流，默认把“公共包源解析可用且 apt 索引可刷新”作为 DNS 成功标准；仅在当前任务明确需要私有 AMD 包源时，才启用对 artifactory 域名的严格解析检查。
- 影响：DNS 修复自动化可以在更多实例上优先解阻标准包依赖流程，同时仍保留按需启用的私有域名严格约束能力。

## 2026-04-15 - 将 DNS 修复视为临时实例“每次重启后的必做预检”

- 状态：已接受
- 背景：在 `30002` 上，即使同一实例此前已通过 DNS 检查，重启后仍再次出现主机解析回退；重新执行 DNS 修复后 apt 与运行时准备路径恢复。
- 决策：对每次重启或新建的 Jupyter 实例，在部署与验证命令之前都先执行 DNS 修复并做简短包源主机解析预检。
- 影响：远程验证流程对实例重启更具韧性，可避免在可预期的解析回退上重复浪费验证轮次。
## 2025-05-27 - 在上游 Paddle wheel 修复合并前，使用 Python 猴子补丁解决 BF16 layer_norm 内核缺失问题

- 状态：已接受
- 背景：Paddle ROCm wheel（3.4.0.dev20260408）未在 `layer_norm` HIP `PD_REGISTER_KERNEL` 中注册 `phi::bfloat16`。在当前验证时间窗口内无法重新编译 wheel。`layer_norm_kernel.cu` 的 C++ 修复已完成，将作为上游 PR 提交。
- 决策：在 `_paddleocr_vl.py`（VLM worker 子进程入口）中添加 `LayerNorm.forward` 猴子补丁，在 layer_norm 调用前后执行 BF16→FP32→BF16 类型转换。该垫片放置于 VLM 子进程文件中，确保在正确的进程上下文中生效。C++ 修复写入 `patches/paddle-hip-bf16-kernels.patch` 用于上游 PR。
- 影响：无需重新编译 wheel 即可完成完整 BF16 流水线验证。待上游 Paddle PR 合并并发布新 wheel 后，Python 垫片可直接删除。

## 2025-05-27 - 通过 os.environ.setdefault 在 create_predictor 前设置 FLAGS_conv_workspace_size_limit

- 状态：已接受
- 背景：`paddle.inference.create_predictor(config)` 调用 `SetGflags()`，该函数尝试从环境变量中设置 `FLAGS_conv_workspace_size_limit`。该 gflag 在 ROCm/HIP 构建中不存在，若环境变量缺失会导致致命错误。
- 决策：在 `static_infer.py` ROCm 代码块中于 `create_predictor()` 调用前执行 `os.environ.setdefault("FLAGS_conv_workspace_size_limit", "32")`。使用 `setdefault` 可避免覆盖用户已设置的值。
- 影响：ROCm 上 Paddle analysis predictor 创建成功。该 gflag 仅存在于进程环境中，CUDA 构建上未使用的 gflag 无负面影响。
## 记录模板

- 日期：
- 状态：
- 背景：
- 决策：
- 影响：