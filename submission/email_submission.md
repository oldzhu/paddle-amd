[中文版](../../docs/zh/validation.md)

# Hackathon Submission Email

## Recipients

- **To:** ext_paddle_oss@baidu.com
- **CC:** Zijun.Wei@amd.com, Huaqiang.Fang@amd.com, bingqing.guo@amd.com

## Subject

[AMD Hackathon 10th] Enable HIP BF16 for PaddleOCR-VL — Paddle PR #78760 + PaddleX PR #5112

## Body

Dear Paddle / AMD Hackathon Team,

I am submitting the deliverables for the AMD Hackathon 10th task:
**"为 Paddle 框架适配 HIP BF16 精度类型"** (Enable HIP BF16 precision in Paddle for PaddleOCR-VL).

---

### Deliverables

| # | Type | Link |
|---|------|------|
| 1 | Paddle Issue | https://github.com/PaddlePaddle/Paddle/issues/78759 |
| 2 | **Paddle PR** | https://github.com/PaddlePaddle/Paddle/pull/78760 |
| 3 | PaddleX Issue | https://github.com/PaddlePaddle/PaddleX/issues/5111 |
| 4 | **PaddleX PR** | https://github.com/PaddlePaddle/PaddleX/pull/5112 |
| 5 | Evidence / control repo | https://github.com/oldzhu/paddle-amd |

---

### Paddle PR #78760 — Changes

Three files changed in `PaddlePaddle/Paddle` (branch `develop`):

1. `paddle/phi/kernels/gpu/layer_norm_kernel.cu`  
   Add `phi::bfloat16` to the HIP `PD_REGISTER_KERNEL`. The kernel implementation
   already uses templated CUDA-compatible intrinsics that compile and run correctly
   on ROCm; the omission of `bfloat16` was the sole blocker.

2. `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc`  
   Add `#ifdef PADDLE_WITH_HIP return ps; #endif` guard in `InitializePatterns()`.
   The fused op (`FusedConv2dAddActOp`) is only compiled under `PADDLE_WITH_CUDA`;
   on ROCm the pass generates un-dispatchable nodes.

3. `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc`  
   Same `PADDLE_WITH_HIP` guard as above.

4. `test/legacy_test/test_layer_norm_bf16_hip.py` *(new)*  
   Unit tests for LayerNorm BF16 on HIP: 2D/3D/4D shapes, dtype preservation,
   SNR >= 30 dB vs FP32 reference.

---

### PaddleX PR #5112 — Changes

Four files changed in `PaddlePaddle/PaddleX` (branch `develop`):

1. `paddlex/inference/utils/misc.py`  
   Add `'dcu'` to the device allowlist in `is_bfloat16_available()`.

2. `paddlex/inference/models/common/static_infer.py`  
   Remove 4 scattered `if paddle.is_compiled_with_rocm(): config.delete_pass(...)` blocks.

3. `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`  
   - Remove `_keep_in_fp32_modules = ["visual", "mlp_AR"]`.  
   - Add temporary `LayerNorm.forward` BF16 shim (casts BF16→FP32→BF16) for Paddle
     wheel versions that predate the kernel fix. Remove after Paddle PR merges.

4. `paddlex/inference/models/common/transformers/utils.py`  
   Add `'dcu' → 'gpu'` mapping in `device_guard()`.

---

### Validation Evidence

**Hardware:** AMD Radeon RX 7900 GRE (gfx1100)  
**Software:** ROCm 7.2.0, Python 3.12, Paddle 3.4.0.dev20260408  

| Check | Result |
|-------|--------|
| `is_compiled_with_rocm()` | ✅ True |
| `is_bfloat16_available('dcu:0')` | ✅ True |
| `_keep_in_fp32_modules` | ✅ None (removed) |
| BF16 conv2d SNR vs FP32 | ✅ 44 dB |
| PaddleOCR-VL-1.5 BF16 full pipeline | ✅ **PASS — 202.8s, EXIT:0** |
| OCR output correctness | ✅ 5 blocks detected, text verified |

Screenshot and full log:  
https://github.com/oldzhu/paddle-amd/blob/main/evidence/bf16_pipeline_validation_gfx1100.png  
https://github.com/oldzhu/paddle-amd/blob/main/evidence/bf16_pipeline_validation_gfx1100.log

---

Best regards,  
oldzhu (GitHub: https://github.com/oldzhu)

---

## Attachment

`evidence/bf16_pipeline_validation_gfx1100.png`
