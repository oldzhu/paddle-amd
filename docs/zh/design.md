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

- ~~去掉 workaround 后，最先失败的具体算子是什么？~~ **已解决**：是 `fused_conv2d_add_act` 内核在 ROCm 上缺失——conv2d 融合 pass 会生成该 op，但没有注册对应的 HIP 内核。
- ~~conv fuse pass 的禁用是否与 BF16 任务相互独立？~~ **已解决**：是同一根因。fuse pass 在 ROCm 上失败与数据类型无关，因为 `fused_conv2d_add_act` 内核本身就被 `#ifdef PADDLE_WITH_CUDA` 限定，BF16 任务与 fuse-pass 任务实为同一根因。
- 修复卷积后是否还会暴露多个阻塞点？——仍待明确；需在真实构建的 Paddle 二进制上验证。

## 设计更新

### 2026-04-22 — 根因确认并完成修复

**根本原因**：  
`paddle/phi/kernels/fusion/gpu/fused_conv2d_add_act_kernel.cu` 被 `#ifdef PADDLE_WITH_CUDA` 包裹，因此 `fused_conv2d_add_act` 内核在 ROCm/HIP 编译时不会被编译或注册。两个 PIR 融合 pass（`conv2d_add_act_fuse_pass` 和 `conv2d_add_fuse_pass`）作为推理 GPU pass 流水线的一部分运行，尝试将 `conv2d + add + act` 子图改写为 `FusedConv2dAddActOp` 调用。在 ROCm 上，这些改写后的 op 没有注册任何内核，因此会在运行时报错。

**已确认的非问题点**：  
- `conv2d` 本身：BF16 已在 `paddle/phi/kernels/gpu/conv_kernel.cu` 中通过 `GPUDNN` 后端为 CUDA 和 ROCm 均完整注册，无需修改。
- ROCm 上的 `paddle.amp.is_bfloat16_supported()`：已通过 `paddle/fluid/pybind/place.cc` 中的 `#ifdef PADDLE_WITH_HIP` 返回 `True`，无需修改。

**Paddle 修复**（`paddle-hip-conv2d-fuse-pass-guard.patch`）：  
在以下两个文件的 `InitializePatterns()` 顶部添加 `#ifdef PADDLE_WITH_HIP … return ps; #endif`：
- `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc`
- `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc`

该修改使两个 pass 在 ROCm 上变为空操作，不影响 CUDA 代码路径。

**PaddleX 清理**（`paddlex-remove-rocm-workaround.patch`）：  
Paddle 修复后，PaddleX 不再需要在 ROCm 上为这两个 pass 调用 `config.delete_pass()`。已从 `paddlex/inference/models/common/static_infer.py` 中删除四处冗余代码块。同时，在 `paddlex/inference/utils/misc.py:is_bfloat16_available()` 的设备类型允许列表中添加了 `"dcu"`，使 Hygon DCU 设备也能使用 BF16（DCU 是基于 AMD 的 ROCm 平台，`paddle.amp.is_bfloat16_supported()` 同样返回 `True`）。

**补丁文件**：  
- `patches/paddle-hip-conv2d-fuse-pass-guard.patch` — Paddle 上游修复  
- `patches/paddlex-remove-rocm-workaround.patch` — PaddleX 清理