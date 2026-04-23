# HIP BF16 第二阶段进展 — 2026-04-23
<!-- English version: docs/progress/2026-04-23-hip-bf16-phase2-plan.md -->

## 状态：暂停等待 — 等待主办方回复确认后继续

第一阶段所有提交事项已完成。本文档记录了第二阶段审计发现的问题和工作计划，
收到继续推进的确认后可直接从此文档恢复开发。

---

## 已完成工作（截至本检查点）

| 事项 | 链接 | 状态 |
|------|------|------|
| Paddle Issue #78759 | https://github.com/PaddlePaddle/Paddle/issues/78759 | ✅ |
| Paddle 上游 PR #78760 | https://github.com/PaddlePaddle/Paddle/pull/78760 | ✅（参考） |
| **Paddle 黑客松 PR ROCm/Paddle#49** | https://github.com/ROCm/Paddle/pull/49 | ✅ **主提交** |
| PaddleX Issue #5111 | https://github.com/PaddlePaddle/PaddleX/issues/5111 | ✅ |
| PaddleX PR #5112 | https://github.com/PaddlePaddle/PaddleX/pull/5112 | ✅ |
| 验证证据 | evidence/bf16_pipeline_validation_gfx1100.{png,log} | ✅ |
| 提交邮件 | 通过 Outlook 网页手动发送 | ✅ |
| 主办方回复 | 要求 PR 目标改为 ROCm/Paddle:paddle_hackthon | ✅ |
| PR 重定向 | 已创建 ROCm/Paddle#49 | ✅ |

### ROCm/Paddle#49 包含的改动

1. `paddle/phi/kernels/gpu/layer_norm_kernel.cu` — HIP `PD_REGISTER_KERNEL` 中添加 `phi::bfloat16`
2. `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc` — `#ifdef PADDLE_WITH_HIP return ps; #endif`
3. `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc` — 同上
4. `test/legacy_test/test_layer_norm_bf16_hip.py` — 新增单元测试（6个方法）

---

## 第二阶段审计发现

对 `paddle/phi/kernels/gpu/*.cu` 进行系统扫描，查找 `#ifdef PADDLE_WITH_HIP` 块中
注册了 `phi::float16` 但**未注册** `phi::bfloat16` 的情况（而对应的 CUDA `#else` 块已包含）。

### A类 — 安全的 Kernel 注册缺口（优先实施）

这些纯属注册宏遗漏。底层 kernel 模板已通过 C++ 模板支持 BF16，可在 HIP 上编译运行。
只需修改 `PD_REGISTER_KERNEL` 宏，无需修改 kernel 实现逻辑。

| 优先级 | 文件 | Kernel | HIP 当前 | CUDA 有 | 操作 |
|--------|------|--------|---------|---------|------|
| 🔴 P1 | `activation_kernel.cu` | `relu` | `float, double, float16` | + `bfloat16` | 添加 `phi::bfloat16` |
| 🔴 P1 | `activation_grad_kernel.cu` | `relu_grad`, `relu_double_grad` | `float, double, float16` | + `bfloat16` | 添加 `phi::bfloat16` |
| 🔴 P1 | `batch_norm_grad_kernel.cu` | `batch_norm_grad` | `float, float16` | + `bfloat16` | 添加 `phi::bfloat16` |
| 🔴 P1 | `sync_batch_norm_kernel.cu` | `sync_batch_norm` | `float, float16` | + `bfloat16` | 添加 + dtype cast 块 |
| 🔴 P1 | `sync_batch_norm_grad_kernel.cu` | `sync_batch_norm_grad` | `float, float16` | + `bfloat16` | 添加 + dtype cast 块 |
| 🔴 P1 | `cross_entropy_kernel.cu` | `cross_entropy_with_softmax` | `float, float16` | + `bfloat16` | 添加 `phi::bfloat16` |
| 🟡 P2 | `cum_kernel.cu` | `cumsum` | 缺 `bfloat16` | ✓ | 添加 |
| 🟡 P2 | `cum_kernel.cu` | `logcumsumexp` | 仅 `float, double`（连 float16 都没有！） | `float16, bfloat16` | 添加两者 |
| 🟡 P2 | `cum_grad_kernel.cu` | `cumsum_grad` | 缺 `bfloat16` | ✓ | 添加 |
| 🟡 P2 | `logcumsumexp_grad_kernel.cu` | `logcumsumexp_grad` | 仅 `float, double` | `float16, bfloat16` | 添加两者 |

### B类 — PIR Pass 缺少 HIP Guard（与A类同步实施）

| 文件 | 问题 | 操作 |
|------|------|------|
| `paddle/fluid/pir/transforms/gpu/fused_bn_add_act_pass.cc` | 该 pass 融合生成 `fused_bn_add_activation` op，但该 op 的 HIP kernel 无 BF16 注册。在 HIP+BF16 下会触发 kernel 未注册崩溃，与已修复的 conv2d fuse pass 属同类问题。 | 在 `InitializePatterns()` 开头添加 `#ifdef PADDLE_WITH_HIP return ps; #endif` |

### C类 — 需要 GPU 验证后再修复（等待确认后进行）

| 文件 | Kernel | 阻塞原因 |
|------|--------|---------|
| `instance_norm_kernel.cu` | `instance_norm` | CUDA BF16 路径需要 cuDNN ≥ 8.1。需在 gfx1100 ROCm 7.2 上验证 MIOpen 是否支持 BF16 instance norm |
| `instance_norm_grad_kernel.cu` | `instance_norm_grad`, `instance_norm_double_grad` | 同上 |

---

## 恢复开发指引

收到主办方确认后：

1. **新建分支**：
   ```bash
   cd /home/oldzhu/paddle-amd/paddlerepos/Paddle
   git checkout -b hip-bf16-kernel-coverage-p2
   ```

2. **实施 A 类修改**（7个文件，10个 kernel，纯注册宏添加）

3. **实施 B 类修改**（1个 pass 文件加 HIP guard）

4. **编写单元测试**（参照 `test_layer_norm_bf16_hip.py`）

5. **提交 PR**：
   ```bash
   gh pr create \
     --repo ROCm/Paddle \
     --head "oldzhu:hip-bf16-kernel-coverage-p2" \
     --base paddle_hackthon \
     --title "[HIP/ROCm] Extend BF16 kernel coverage: relu/batch_norm/sync_bn/cross_entropy/cumsum"
   ```

6. **C 类验证**：在远程 GPU 上测试 instance_norm BF16

---

## 环境参考

- 远程 GPU：AMD Radeon RX 7900 GRE (gfx1100)，ROCm 7.2.0
- JupyterLab：`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`（密码：`amd-oneclick`）
- Paddle wheel：`paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- Python 3.12，venv：`/opt/venv`
- gh CLI：`~/bin/gh`，`GH_TOKEN=<见本地环境变量 / 不存储于此>`
- Paddle 仓库：`/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- PaddleX 仓库：`/home/oldzhu/paddle-amd/paddlerepos/PaddleX`
- 控制面板仓库：`/home/oldzhu/paddle-amd`
