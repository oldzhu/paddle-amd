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
3. 在远程环境中真正执行 shell 命令，当前仍视为需要单独核实的手动步骤；除非后续补充 terminal websocket 自动化

远程辅助资产：

- `scripts/jupyter_remote.py`：用于 Jupyter API 登录、终端列表或创建、session 列表与文件上传
- `scripts/render_remote_bootstrap.sh`：生成可直接在远程终端执行的 bootstrap 脚本，用于 clone 或刷新本仓库、Paddle 和 PaddleX
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

用于远程终端手动执行的命令包生成示例：

```bash
scripts/render_remote_bootstrap.sh > /tmp/remote_bootstrap.sh
```

随后可以将该脚本上传到 Jupyter，或将生成的输出直接粘贴到远程终端中执行。

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