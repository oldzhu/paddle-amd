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
- 创建双语项目文档骨架。
- 添加项目级共享指令，用于强制执行双语跟踪与证据记录规范。

## 记录模板

- 日期：
- 环境：
- 动作：
- 结果：
- 下一步：