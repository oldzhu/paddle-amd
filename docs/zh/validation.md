[English Version](../en/validation.md)

# 验证日志

## 验证清单

- 已记录环境信息
- 已记录 Paddle commit
- 已记录 PaddleX commit
- 已记录 ROCm 版本
- 已记录 GPU 型号
- 已记录精确命令
- 已保存输出日志
- 如需要，已保存截图

## 计划中的验收证据

1. HIP 上 BF16 算子级测试结果
2. PaddleOCR-VL-1.5 在 AMD GPU 上成功执行 BF16
3. 正确性证据与截图
4. 简明的 FP32 与 BF16 显存和运行时间对比

## 运行记录

### 2026-04-09 - 远程 Jupyter 环境检查

- 验证目标：AMD 集群 Jupyter 实例 `http://36.151.243.69:30005/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`1`
- 命令脚本路径：上传后的 `/app/paddle_amd_remote_env_check.sh`
- 执行命令：`python3 scripts/jupyter_remote.py exec --terminal 1 --command "bash /app/paddle_amd_remote_env_check.sh"`
- 操作系统：Ubuntu 22.04.5 LTS
- Python：`/opt/venv/bin/python`，版本 `3.10.12`
- pip：`/opt/venv/bin/pip`，版本 `26.0.1`
- ROCm 证据：
	- 存在 `/opt/rocm` 与 `/opt/rocm-7.2.1`
	- `rocminfo` 执行成功
	- 检测到 GPU agent 为 `gfx1100`
	- `rocm-smi` 执行成功
	- `hipcc` 位于 `/opt/rocm/bin/hipcc`
	- HIP 版本报告为 `7.2.1`
- Paddle 证据：
	- `import paddle` 失败，报错为 `ModuleNotFoundError: No module named 'paddle'`
	- `pip list` 未显示当前环境已安装 Paddle 包
- 初步结论：
	- 该远程实例适合作为基于 ROCm 的验证环境。
	- 在开始框架级复现之前，需要先在远程环境中安装或编译 Paddle。

### 2026-04-09 - 远程按实例 bootstrap 验证

- 验证目标：同一 AMD 集群 Jupyter 实例
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`2`
- 准备脚本：`scripts/remote_prepare_instance.sh 2 /app/paddle-amd-remote`
- 已验证结果：
	- 控制平面仓库已 clone 到 `/app/paddle-amd-remote`
	- Paddle 已 clone 到 `/app/paddle-amd-remote/paddlerepos/Paddle`
	- PaddleX 已 clone 到 `/app/paddle-amd-remote/paddlerepos/PaddleX`
	- 远程控制平面 commit：`7d037f0`
	- 远程 Paddle commit：`5ae373f`
	- 远程 PaddleX commit：`c18f2b0`
	- 环境采集结果已保存到 `/app/paddle-amd-remote/evidence/env/`
- 剩余阻塞：
	- `/opt/venv/bin/python` 中仍无法导入 Paddle
- 结论：
	- 可复用的按实例准备流程已经跑通。
	- 下一步远程环境任务是为当前 Python 环境安装或编译 Paddle。