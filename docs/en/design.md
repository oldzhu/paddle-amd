[中文版](../zh/design.md)

# Design

## Scope

This document tracks the technical design for enabling HIP BF16 in Paddle and the dependency boundary between Paddle and PaddleX.

## Design Principles

1. Fix the root cause in Paddle first.
2. Keep the Paddle patch reviewable and narrow.
3. Treat PaddleX changes as downstream cleanup only.
4. Require evidence before expanding scope beyond the first failing operator path.

## Initial Suspected Areas

- HIP-only BF16 type iteration or dispatch gates
- ROCm BF16 datatype mapping gaps
- GPUDNN or MIOpen conv and conv-transpose registration excluding BF16
- additional HIP BF16 operator gaps revealed by PaddleOCR-VL execution traces

## Expected Validation Chain

1. operator-level regression test
2. framework-level smoke validation on ROCm
3. PaddleOCR-VL-1.5 BF16 inference without the current PaddleX workaround

## Open Questions

- ~~Which exact operator fails first when the workaround is removed?~~ **Resolved**: `fused_conv2d_add_act` kernel is missing on ROCm — the conv2d fuse passes generate it but no HIP kernel is registered.
- ~~Is the conv fuse-pass disablement independent from the BF16 task?~~ **Resolved**: Yes. The fuse passes fail on ROCm regardless of dtype because the `fused_conv2d_add_act` kernel itself is `#ifdef PADDLE_WITH_CUDA`-only. The BF16 task and the fuse-pass task are the same root cause.
- Are there multiple blockers after conv is fixed? — Still open; needs validation with a built Paddle binary.

## Design Updates

### 2026-04-22 — Root-cause confirmed and fix implemented

**Root cause**:  
`paddle/phi/kernels/fusion/gpu/fused_conv2d_add_act_kernel.cu` is wrapped in `#ifdef PADDLE_WITH_CUDA`, so the `fused_conv2d_add_act` kernel is not compiled or registered for ROCm/HIP. The two PIR fuse passes (`conv2d_add_act_fuse_pass` and `conv2d_add_fuse_pass`) run as part of the inference GPU pass pipeline and attempt to rewrite `conv2d + add + act` subgraphs into `FusedConv2dAddActOp` calls. On ROCm these rewritten ops have no registered kernel and cause runtime errors.

**Confirmed non-issues**:  
- `conv2d` itself: BF16 is fully registered in `paddle/phi/kernels/gpu/conv_kernel.cu` for both CUDA and ROCm (via `GPUDNN` backend). No change needed.
- `paddle.amp.is_bfloat16_supported()` on ROCm: Already returns `True` via `#ifdef PADDLE_WITH_HIP` in `paddle/fluid/pybind/place.cc`. No change needed.

**Paddle fix** (`paddle-hip-conv2d-fuse-pass-guard.patch`):  
Added `#ifdef PADDLE_WITH_HIP … return ps; #endif` at the top of `InitializePatterns()` in both:
- `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc`
- `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc`

This makes both passes no-ops on ROCm without touching the CUDA code path.

**PaddleX cleanup** (`paddlex-remove-rocm-workaround.patch`):  
After the Paddle fix, PaddleX no longer needs to call `config.delete_pass()` for these two passes on ROCm. Four redundant blocks were removed from `paddlex/inference/models/common/static_infer.py`. Additionally, `"dcu"` was added to the allowed device type list in `paddlex/inference/utils/misc.py:is_bfloat16_available()` so that Hygon DCU devices can also use BF16 (DCU is an AMD-derived ROCm platform where `paddle.amp.is_bfloat16_supported()` also returns `True`).

**Patch files**:  
- `patches/paddle-hip-conv2d-fuse-pass-guard.patch` — Paddle upstream fix  
- `patches/paddlex-remove-rocm-workaround.patch` — PaddleX cleanup