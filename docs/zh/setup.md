[English Version](../en/setup.md)

# 环境与复现指南

## 目的

本文档说明如何将本控制平面仓库与本地嵌套的 Paddle、PaddleX 仓库配合使用，以及如何准备第一次 HIP BF16 复现实验。

## 工作区布局

- 控制平面仓库：`/home/oldzhu/paddle-amd`
- 嵌套 Paddle 仓库：`/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- 嵌套 PaddleX 仓库：`/home/oldzhu/paddle-amd/paddlerepos/PaddleX`

`paddlerepos/` 目录被控制平面仓库刻意忽略。每个嵌套仓库都保留自己的 git 历史、remote、分支与 PR 工作流。

## 已记录的 clone 状态

- Paddle 分支：`develop`
- Paddle commit：`5ea0c3dddf415a7885560c6916e13491d6f597c6`
- PaddleX 分支：`develop`
- PaddleX commit：`c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`

## 推荐工作模式

1. 在本控制平面仓库中维护计划、笔记、证据和补丁导出结果。
2. 在嵌套的 Paddle 与 PaddleX 仓库中进行框架代码修改。
3. 需要时将补丁导出回 `patches/paddle/` 和 `patches/paddlex/`。
4. 每次有实质性技术进展时，在同一个变更窗口更新双语文档。

## 环境职责划分

### WSL

- 编辑与代码审查
- 轻量脚本执行
- 补丁整理
- Issue 与 PR 草稿编写
- 当 WSL 发行版本身具备可用的 ROCm SDK 与构建工具链时，可以在本地编译候选 ROCm wheel

当前本地 WSL 快照：

- Ubuntu 24.04.3 LTS
- Python 3.12.3
- 来自 ROCm 6.4.2 的 `hipcc`
- 已具备 `rocminfo`、`cmake 3.28.3` 与 `ninja 1.11.1`

当前注意点：

- 当前远程 AMD 预装镜像线暴露的是 ROCm 7.2.x，因此虽然在本地 ROCm 6.4.2 上编译 wheel 再部署到远程在技术上可能可行，但更推荐让构建主机与验证主机的 ROCm 大版本或小版本保持一致
- 必须匹配目标环境的 Python ABI；当前远程预装镜像在 `/opt/venv` 中使用的是 Python 3.12

建议采用的“本地构建再远程部署”流程：

1. 先确认本地 WSL 构建主机是否仍尽量贴近目标远程环境：

```bash
scripts/check_local_rocm_build_env.sh
```

2. 如有需要，可以显式覆盖目标值：

```bash
TARGET_PYTHON_VERSION=3.12 TARGET_ROCM_PREFIX=7.2 scripts/check_local_rocm_build_env.sh
```

3. 在 WSL 本地编译候选 ROCm wheel。

本地 configure 示例：

```bash
scripts/build_local_rocm_wheel.sh /home/oldzhu/paddle-amd/paddlerepos/Paddle configure
```

本地 wheel 构建示例：

```bash
scripts/build_local_rocm_wheel.sh /home/oldzhu/paddle-amd/paddlerepos/Paddle build
```

该脚本当前会：

- 预先补齐 `hip_version.h` 与 `rccl.h` 的已知 ROCm 兼容软链接
- 将 CMake 指向自动探测到的 legacy HIP CMake 模块路径
- 使用 `BUILD_WHL_PACKAGE=ON` 配置独立的本地构建目录
- 在 build 模式下构建产出 wheel 的目标 `paddle_copy`

4. 将生成的 wheel 上传到远程 AMD ROCm 实例。

wheel 上传示例：

```bash
scripts/upload_remote_wheel.sh /path/to/paddle_whl.whl uploaded-wheels
```

5. 在远程 `/opt/venv` 中安装该 wheel。

远程安装并执行冒烟测试示例：

```bash
scripts/install_remote_wheel.sh 1 uploaded-wheels/paddle_whl.whl
```

6. 只在远程机器上执行权威的 HIP 或 BF16 测试。

这条流程的停止条件：

- 本地 Python ABI 与远程目标 Python ABI 不匹配
- 本地 ROCm 工具链缺失，或与目标运行时明显不兼容
- 生成的 wheel 依赖本地独有而远程主机并不存在的动态库

### 原生 Linux ROCm 或远程 AMD ROCm 主机

- 权威构建验证
- 算子测试执行
- PaddleOCR-VL BF16 复现与验收验证

## 远程 AMD 集群 Jupyter 环境

已知入口：

- 集群入口页：`http://36.151.243.69:30081`
- Jupyter Lab 实例形式：`http://36.151.243.69:30005/lab`

当前工作模式：

1. 由你手动创建或恢复远程实例
2. 如果提供 token 或 password，本仓库可以准备命令并访问 Jupyter API
3. 当 Jupyter terminal websocket 可用时，本仓库可以直接执行终端命令
4. 真实运行结果仍需作为验证证据单独记录

重要实例规则：

1. 每个新建的 Jupyter 实例都应视为临时环境
2. 不要假设新实例中已经安装 Paddle
3. 每次创建新实例后都应先检查环境，再只补齐缺失或过期的部分
4. 如果 Paddle 已经存在且可满足任务要求，就不要重复安装

远程辅助资产：

- `scripts/jupyter_remote.py`：用于 Jupyter API 登录、终端列表或创建、session 列表、文件上传以及基于 terminal websocket 的命令执行
- `scripts/render_remote_dns_repair.sh`：用于生成远程 resolver 修复脚本，并可选地连带执行 `apt-get update` 验证
- `scripts/remote_fix_instance_dns.sh`：用于在活动 Jupyter 终端上执行上述 resolver 修复脚本
- `scripts/render_remote_bootstrap.sh`：生成可直接在远程终端执行的 bootstrap 脚本，用于 clone 或刷新本仓库、Paddle 和 PaddleX
- `scripts/render_remote_env_check.sh`：生成远程环境检查脚本
- `scripts/remote_prepare_instance.sh`：用于对当前 Jupyter 终端执行整套远程准备流程
- `scripts/remote_ensure_paddle.sh`：用于在 `/opt/venv` 中按“先检查再安装”的方式尝试提供 Paddle
- `scripts/remote_build_paddle_rocm.sh`：用于按“先检查再构建”的方式执行远程 Paddle ROCm 源码配置或构建探测
- `scripts/remote_launch_paddle_rocm_configure.sh`：用于在 terminal websocket 不稳定时后台启动远程 Paddle ROCm configure 任务
- `.github/skills/remote-rocm-jupyter/SKILL.md`：供后续 Copilot 复用的远程 ROCm 工作流说明

使用 token 登录示例：

```bash
python3 scripts/jupyter_remote.py login \
	--url http://36.151.243.69:30005 \
	--token YOUR_TOKEN
```

使用 password 登录示例：

```bash
python3 scripts/jupyter_remote.py login \
	--url http://36.151.243.69:30005 \
	--password YOUR_PASSWORD
```

终端管理与上传示例：

```bash
python3 scripts/jupyter_remote.py list-terminals
python3 scripts/jupyter_remote.py create-terminal
python3 scripts/jupyter_remote.py upload scripts/repro_checklist.sh repro_checklist.sh
```

terminal websocket 执行示例：

```bash
python3 scripts/jupyter_remote.py exec --command "bash paddle_amd_remote_env_check.sh"
python3 scripts/jupyter_remote.py exec --command-file /tmp/remote_bootstrap.sh
```

如果远程 clone、pip 或 apt 操作开始出现 `Temporary failure resolving ...`，应先修复 DNS：

```bash
scripts/remote_fix_instance_dns.sh 1
```

该辅助脚本默认会：

- 检查当前实例是否能解析本工作流需要的包源与 clone 目标主机
- 仅在当前解析失败时才重写 `/etc/resolv.conf`，写入一组简短的候选 nameserver
- 在重写后再次验证主机名解析是否恢复
- 将 `apt-get update` 作为修复后的验证步骤一起执行

如果只想先修复 resolver，而不马上执行 apt：

```bash
scripts/remote_fix_instance_dns.sh 1 --no-apt-update
```

如果你的地区或集群需要不同的 DNS 服务器，也可以显式传入：

```bash
scripts/remote_fix_instance_dns.sh 1 223.5.5.5 223.6.6.6 1.1.1.1
```

按实例执行准备流程示例：

```bash
scripts/remote_prepare_instance.sh 1 /app/paddle-amd-remote
```

现在生成出的 bootstrap 脚本会在执行任何 clone 或 fetch 前先做一次 DNS 预检。如果所需主机无法解析，它会立即停止，并提示先运行 `scripts/remote_fix_instance_dns.sh`。

按“先检查再安装”方式提供 Paddle 的示例：

```bash
scripts/remote_ensure_paddle.sh 1 paddlepaddle==3.3.1
```

该脚本只有在 `import paddle` 失败时才安装 Paddle，并会在安装后打印结果是否报告 ROCm 支持。

当前发现：

- 在当前远程环境中执行 `scripts/remote_ensure_paddle.sh 1 paddlepaddle==3.3.1` 会安装一个仅 CPU 的 wheel
- 这条路径只能作为快速可用性探测，不能作为本任务可接受的 ROCm 运行时

按“先检查再构建”方式执行 ROCm 源码配置探测示例：

```bash
scripts/remote_build_paddle_rocm.sh 1 /app/paddle-amd-remote configure
```

如果当前 Python 环境已经报告为可用的 ROCm Paddle，该脚本会直接跳过。否则它会在 `paddlerepos/Paddle` 下执行远程源码构建探测，记录检测到的 GPU 架构，在仓库内置 ROCm target 列表未覆盖该架构时给出警告，并运行一次 CMake configure 以捕获第一个真实阻塞点。

如果 live instance 上的 terminal websocket 已经不稳定，也可以改为后台启动 configure：

```bash
scripts/remote_launch_paddle_rocm_configure.sh 1 /app/paddle-amd-remote
```

这个脚本用于处理长时间 configure 无法稳定附着在 websocket 会话上的情况。

用于远程终端手动执行的命令包生成示例：

```bash
scripts/render_remote_bootstrap.sh > /tmp/remote_bootstrap.sh
```

随后可以将该脚本上传到 Jupyter、将生成的输出直接粘贴到远程终端中执行，或通过 `scripts/jupyter_remote.py exec` 执行。

## 首次复现清单

1. 在 ROCm 验证机器上使用 `scripts/capture_env.sh` 采集环境。
2. 记录该次运行使用的 Paddle 与 PaddleX commit。
3. 确认当前 PaddleX workaround 在 ROCm 上的行为。
4. 在保留 workaround 的情况下运行目标 BF16 流程。
5. 去掉或绕过 workaround，并定位第一个失败的算子或代码路径。
6. 将日志、命令和截图保存到 `evidence/`。
7. 更新 `docs/en/validation.md`、`docs/zh/validation.md`、`docs/en/dev-log.md` 和 `docs/zh/dev-log.md`。

## 当前应优先审查的 PaddleX workaround 位置

- `paddlex/inference/utils/misc.py`
- `paddlex/inference/models/common/static_infer.py`
- `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`

## 当前应优先审查的 Paddle 位置

- `paddle/fluid/framework/data_type.h`
- `paddle/phi/backends/gpu/rocm/miopen_desc.h`
- `paddle/phi/backends/gpu/rocm/miopen_helper.h`
- `paddle/phi/kernels/gpudnn/conv_kernel.cu`
- `paddle/phi/kernels/gpudnn/conv_transpose_kernel.cu`

## 说明

凡是尚未通过真实 ROCm 运行确认的结论，都必须在中英文文档中明确标注为假设。