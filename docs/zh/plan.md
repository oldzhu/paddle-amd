[English Version](../en/plan.md)

# 计划

## 目标

在 ROCm 平台上为 Paddle 启用 HIP BF16 支持，使 PaddleOCR-VL-1.5 能够在 AMD GPU 上以 BF16 正确运行；随后移除 PaddleX 当前的 workaround，并提交所需的上游 Issue 和 PR。

## 已记录的本地上游路径

- Paddle：`/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- Paddle 分支：`develop`
- Paddle commit：`5ea0c3dddf415a7885560c6916e13491d6f597c6`
- PaddleX：`/home/oldzhu/paddle-amd/paddlerepos/PaddleX`
- PaddleX 分支：`develop`
- PaddleX commit：`c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`

## 里程碑

1. 初始化本协调仓库与双语跟踪体系。
2. 在原生 Linux ROCm 环境中复现当前 ROCm BF16 限制。
3. 定位 Paddle 根因并定义最小可上游化修复方案。
4. 在 Paddle 中实现修复并补充聚焦测试。
5. 在 AMD GPU 上验证 PaddleOCR-VL-1.5 的 BF16 执行。
6. 移除 PaddleX workaround 并提交清理 PR。
7. 整理评审与比赛提交所需证据。

## 工作流

### 1. 协调仓库

- 维护双语文档与项目级指令
- 汇总补丁、证据与 Issue 草稿
- 跟踪跨环境状态

### 2. Paddle 上游修复

- 检查 HIP 专有的 BF16 类型门控与分发逻辑
- 检查 GPUDNN 与 MIOpen 中卷积相关 BF16 支持
- 添加测试并在 ROCm 上验证行为

### 3. PaddleX 清理

- 在上游修复就绪后移除 BF16 禁用逻辑
- 在不再需要时移除强制 FP32 回退
- 对仍保留的 ROCm 限制进行单独说明，不与 BF16 任务混淆

## 环境策略

- WSL：编辑、脚本编写、补丁整理
- 原生 Linux ROCm 或远程 AMD ROCm 机器：权威验证环境

## 当前假设

最可能的首个根因是：Paddle 中 HIP BF16 在 helper 层已有部分支持，但在卷积相关的 GPUDNN 与 MIOpen 注册或分发路径中仍被排除或实现不完整。该判断必须先通过复现确认，不能直接当作结论。

## 近期步骤

1. 准备上游 clone 路径并固定 commit 记录方式。
2. 编写可复现的环境采集与 repro 脚本。
3. 在保留与移除 PaddleX workaround 两种条件下分别复现 BF16 问题。