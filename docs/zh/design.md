[English Version](../en/design.md)

# 设计

## 范围

本文档用于跟踪在 Paddle 中启用 HIP BF16 的技术设计，以及 Paddle 与 PaddleX 之间的职责边界。

## 设计原则

1. 优先在 Paddle 中修复根因。
2. 保持 Paddle 补丁范围小、便于评审。
3. PaddleX 改动仅作为下游清理。
4. 在拿到证据前，不随意扩大到首个失败算子路径之外的范围。

## 初始疑点区域

- HIP 专有的 BF16 类型迭代或分发门控
- ROCm BF16 数据类型映射缺口
- GPUDNN 或 MIOpen 中卷积与反卷积注册未包含 BF16
- PaddleOCR-VL 执行轨迹进一步暴露出的其他 HIP BF16 算子缺口

## 预期验证链路

1. 算子级回归测试
2. ROCm 上的框架级冒烟验证
3. 在移除当前 PaddleX workaround 后运行 PaddleOCR-VL-1.5 BF16 推理

## 未决问题

- 去掉 workaround 后，最先失败的具体算子是什么？
- conv fuse pass 的禁用是否与 BF16 任务相互独立？
- 修复卷积后是否还会暴露多个阻塞点？

## 设计更新

随着技术理解演进，在此处追加带日期的条目。