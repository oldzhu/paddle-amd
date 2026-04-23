# HIP BF16 Phase 2 Progress — 2026-04-23
<!-- Chinese version: docs/progress/2026-04-23-hip-bf16-phase2-plan.zh.md -->

## Status: HOLDING — Awaiting organizer reply to confirm continuation

All Phase 1 submission deliverables are complete. This document captures the findings
from the Phase 2 audit and the work plan to resume once the green light is received.

---

## Completed Work (as of this checkpoint)

| Item | Link | Status |
|------|------|--------|
| Paddle Issue #78759 | https://github.com/PaddlePaddle/Paddle/issues/78759 | ✅ |
| Paddle upstream PR #78760 | https://github.com/PaddlePaddle/Paddle/pull/78760 | ✅ (reference) |
| **Paddle hackathon PR ROCm/Paddle#49** | https://github.com/ROCm/Paddle/pull/49 | ✅ **PRIMARY** |
| PaddleX Issue #5111 | https://github.com/PaddlePaddle/PaddleX/issues/5111 | ✅ |
| PaddleX PR #5112 | https://github.com/PaddlePaddle/PaddleX/pull/5112 | ✅ |
| Validation evidence | evidence/bf16_pipeline_validation_gfx1100.{png,log} | ✅ |
| Submission email | Sent manually via Outlook web | ✅ |
| Organizer reply received | Retarget to ROCm/Paddle:paddle_hackthon | ✅ |
| PR retargeted | ROCm/Paddle#49 created | ✅ |

### What ROCm/Paddle#49 Contains

1. `paddle/phi/kernels/gpu/layer_norm_kernel.cu` — add `phi::bfloat16` to HIP `PD_REGISTER_KERNEL`
2. `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc` — `#ifdef PADDLE_WITH_HIP return ps; #endif`
3. `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc` — same guard
4. `test/legacy_test/test_layer_norm_bf16_hip.py` — new unit test (6 methods)

---

## Phase 2 Audit Findings

Systematic scan of `paddle/phi/kernels/gpu/*.cu` for `#ifdef PADDLE_WITH_HIP` blocks
that register `phi::float16` but **not** `phi::bfloat16`, while the corresponding
`#else` (CUDA) block does register `phi::bfloat16`.

### Category A — Safe Kernel Registration Gaps (implement first)

These are pure registration additions. The underlying kernel templates already
handle BF16 via standard C++ templating — they compile and work on HIP.
No kernel logic changes required, only the `PD_REGISTER_KERNEL` macro.

| Priority | File | Kernel(s) | HIP now | CUDA has | Action |
|----------|------|-----------|---------|----------|--------|
| 🔴 P1 | `activation_kernel.cu` | `relu` | `float, double, float16` | + `bfloat16` | Add `phi::bfloat16` |
| 🔴 P1 | `activation_grad_kernel.cu` | `relu_grad`, `relu_double_grad` | `float, double, float16` | + `bfloat16` | Add `phi::bfloat16` |
| 🔴 P1 | `batch_norm_grad_kernel.cu` | `batch_norm_grad` | `float, float16` | + `bfloat16` | Add `phi::bfloat16` |
| 🔴 P1 | `sync_batch_norm_kernel.cu` | `sync_batch_norm` | `float, float16` | + `bfloat16` | Add `phi::bfloat16` + dtype cast block |
| 🔴 P1 | `sync_batch_norm_grad_kernel.cu` | `sync_batch_norm_grad` | `float, float16` | + `bfloat16` | Add `phi::bfloat16` + dtype cast block |
| 🔴 P1 | `cross_entropy_kernel.cu` | `cross_entropy_with_softmax` | `float, float16` | + `bfloat16` | Add `phi::bfloat16` |
| 🟡 P2 | `cum_kernel.cu` | `cumsum` | `float, float16, double, int16_t, int, int64_t` | + `bfloat16` | Add `phi::bfloat16` |
| 🟡 P2 | `cum_kernel.cu` | `logcumsumexp` | `float, double` (no float16!) | `float16, bfloat16` | Add both `phi::float16, phi::bfloat16` |
| 🟡 P2 | `cum_grad_kernel.cu` | `cumsum_grad` | `float, double, float16, int16_t, int, int64_t` | + `bfloat16` | Add `phi::bfloat16` |
| 🟡 P2 | `logcumsumexp_grad_kernel.cu` | `logcumsumexp_grad` | `float, double` (no float16!) | `float16, bfloat16` | Add both |

### Category B — PIR Pass Guard Missing (implement with Category A)

| File | Issue | Action |
|------|-------|--------|
| `paddle/fluid/pir/transforms/gpu/fused_bn_add_act_pass.cc` | Pass fuses to `fused_bn_add_activation` op which has no HIP BF16 kernel. On HIP+BF16 this causes an unregistered-kernel crash — same class of bug as the conv2d passes we already fixed. | Add `#ifdef PADDLE_WITH_HIP return ps; #endif` guard at start of `InitializePatterns()` |

### Category C — Needs GPU Verification Before Fix (do AFTER organizer confirmation)

| File | Kernel(s) | Blocker |
|------|-----------|---------|
| `instance_norm_kernel.cu` | `instance_norm` | CUDA BF16 path requires cuDNN ≥ 8.1. Need to verify MIOpen supports BF16 instance norm on gfx1100 ROCm 7.2 |
| `instance_norm_grad_kernel.cu` | `instance_norm_grad`, `instance_norm_double_grad` | Same |

---

## Resume Instructions

When the organizer confirms we can continue:

1. **Create new branch** in `/home/oldzhu/paddle-amd/paddlerepos/Paddle`:
   ```bash
   cd /home/oldzhu/paddle-amd/paddlerepos/Paddle
   git checkout paddle_hackthon 2>/dev/null || git checkout develop
   git checkout -b hip-bf16-kernel-coverage-p2
   ```
   > Note: base the branch on `ROCm/Paddle:paddle_hackthon` if it can be fetched,
   > otherwise base on current `develop` and the cross-fork PR will work regardless.

2. **Apply Category A fixes** (10 kernels across 7 files) — all mechanical additions.
   Files to edit:
   - `paddle/phi/kernels/gpu/activation_kernel.cu` (line ~316)
   - `paddle/phi/kernels/gpu/activation_grad_kernel.cu` (line ~431)
   - `paddle/phi/kernels/gpu/batch_norm_grad_kernel.cu` (line ~1449)
   - `paddle/phi/kernels/gpu/sync_batch_norm_kernel.cu` (line ~178)
   - `paddle/phi/kernels/gpu/sync_batch_norm_grad_kernel.cu` (line ~59)
   - `paddle/phi/kernels/gpu/cross_entropy_kernel.cu` (line ~2076)
   - `paddle/phi/kernels/gpu/cum_kernel.cu` (line ~522)
   - `paddle/phi/kernels/gpu/cum_grad_kernel.cu` (line ~58)
   - `paddle/phi/kernels/gpu/logcumsumexp_grad_kernel.cu` (line ~24)

3. **Apply Category B fix**:
   - `paddle/fluid/pir/transforms/gpu/fused_bn_add_act_pass.cc` — add HIP guard

4. **Write unit tests** (follow pattern of `test_layer_norm_bf16_hip.py`):
   - `test/legacy_test/test_relu_bf16_hip.py`
   - `test/legacy_test/test_batch_norm_bf16_hip.py`
   - `test/legacy_test/test_cross_entropy_bf16_hip.py`

5. **Push and create PR**:
   ```bash
   git push fork hip-bf16-kernel-coverage-p2
   gh pr create \
     --repo ROCm/Paddle \
     --head "oldzhu:hip-bf16-kernel-coverage-p2" \
     --base paddle_hackthon \
     --title "[HIP/ROCm] Extend BF16 kernel coverage: relu/batch_norm/sync_bn/cross_entropy/cumsum" \
     --body "..."
   ```

6. **Category C** — on remote GPU, run:
   ```python
   import paddle
   x = paddle.randn([2, 4, 8, 8], dtype='bfloat16')
   m = paddle.nn.InstanceNorm2D(4)
   m.to(dtype='bfloat16')
   y = m(x)
   print(y.dtype)  # should be bfloat16
   ```

---

## Environment Reference

- Remote GPU: AMD Radeon RX 7900 GRE (gfx1100), ROCm 7.2.0
- JupyterLab: `http://36.151.243.69:30001/instance/nb-1838d2b6/lab` (password: `amd-oneclick`)
- Paddle wheel: `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- Python: 3.12, venv: `/opt/venv`
- SONAME shim: `/opt/rocm-compat/libamdhip64.so.6 → /opt/rocm/lib/libamdhip64.so.7`
- gh CLI: `~/bin/gh`, `GH_TOKEN=<see local env / not stored here>`
- Paddle clone: `/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- PaddleX clone: `/home/oldzhu/paddle-amd/paddlerepos/PaddleX`
- Control plane: `/home/oldzhu/paddle-amd`
