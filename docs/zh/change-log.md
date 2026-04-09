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
- 添加双语计划、设计、决策、验证与开发日志文档
- 添加项目级 Copilot 指令，用于约束文档与跟踪规范