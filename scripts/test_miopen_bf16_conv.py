"""
Test: MIOpen BF16 conv2d correctness on ROCm.

Validates that paddle.nn.Conv2D in BF16 dtype produces numerically
correct results on ROCm (within acceptable tolerance vs FP32 reference).

If this test PASSES, it is safe to remove _keep_in_fp32_modules from PaddleX.
If this test FAILS, MIOpen BF16 conv is still buggy and the workaround must remain.

Usage:
  python3 test_miopen_bf16_conv.py

Exit code: 0 = all tests passed, 1 = one or more tests failed.
"""

import sys
import numpy as np
import paddle
import paddle.nn as nn


def run_conv_bf16_vs_fp32(batch, in_ch, out_ch, h, w, ksize=3, padding=1, label=""):
    """
    Run a single conv2d in BF16 and FP32. Compare outputs.
    Returns (passed, max_rel_err, max_abs_err).
    """
    np.random.seed(42)
    x_np = np.random.randn(batch, in_ch, h, w).astype("float32")
    weight_np = np.random.randn(out_ch, in_ch, ksize, ksize).astype("float32")
    bias_np = np.random.randn(out_ch).astype("float32")

    # FP32 reference on GPU
    x_fp32 = paddle.to_tensor(x_np, dtype="float32", place="gpu")
    w_fp32 = paddle.to_tensor(weight_np, dtype="float32", place="gpu")
    b_fp32 = paddle.to_tensor(bias_np, dtype="float32", place="gpu")
    y_fp32 = paddle.nn.functional.conv2d(x_fp32, w_fp32, b_fp32, padding=padding)

    # BF16 on GPU
    x_bf16 = paddle.to_tensor(x_np, dtype="bfloat16", place="gpu")
    w_bf16 = paddle.to_tensor(weight_np, dtype="bfloat16", place="gpu")
    b_bf16 = paddle.to_tensor(bias_np, dtype="bfloat16", place="gpu")
    y_bf16 = paddle.nn.functional.conv2d(x_bf16, w_bf16, b_bf16, padding=padding)

    # Compare: cast BF16 result to FP32 for numeric comparison
    y_fp32_np = y_fp32.cpu().cast("float32").numpy()
    y_bf16_np = y_bf16.cpu().cast("float32").numpy()

    abs_err = np.abs(y_fp32_np - y_bf16_np)
    # Relative error, guarded against near-zero fp32 outputs
    rel_err = abs_err / (np.abs(y_fp32_np) + 1e-6)

    max_abs = float(abs_err.max())
    max_rel = float(rel_err.max())
    mean_abs = float(abs_err.mean())

    # BF16 has ~7 bits of mantissa vs 23 for FP32.
    # Acceptable: max relative error < 2% for a single conv (generous).
    # Typical BF16 rounding for conv: ~0.5-1% rel error.
    threshold_rel = 0.05  # 5% - very generous, flags real bugs

    passed = max_rel < threshold_rel
    status = "PASS" if passed else "FAIL"
    print(
        f"[{status}] {label or f'conv({batch},{in_ch},{out_ch},{h}x{w},k{ksize})'}: "
        f"max_rel={max_rel:.4f} max_abs={max_abs:.4f} mean_abs={mean_abs:.6f}"
    )
    return passed, max_rel, max_abs


def test_bf16_available():
    ok = paddle.amp.is_bfloat16_supported()
    status = "PASS" if ok else "FAIL"
    print(f"[{status}] BF16 supported on current device: {ok}")
    return ok


def test_bf16_tensor_cast():
    """BF16 tensor creation and cast back to FP32 should be lossless for representable values."""
    vals = [0.0, 1.0, -1.0, 0.5, 100.0, -3.14]
    x = paddle.to_tensor(vals, dtype="float32", place="gpu")
    x_bf16 = x.cast("bfloat16")
    x_back = x_bf16.cast("float32")
    orig = x.cpu().numpy()
    back = x_back.cpu().numpy()
    max_err = float(np.abs(orig - back).max())
    # BF16 rounds float32; for these values error < 0.5%
    passed = max_err < 0.01
    status = "PASS" if passed else "FAIL"
    print(f"[{status}] BF16 tensor cast roundtrip: max_err={max_err:.6f}")
    return passed


def main():
    print(f"paddle version: {paddle.__version__}")
    print(f"compiled_with_rocm: {paddle.is_compiled_with_rocm()}")
    print()

    if not paddle.is_compiled_with_rocm():
        print("ERROR: Not a ROCm build. Aborting.")
        sys.exit(1)

    paddle.set_device("gpu")

    results = []

    # Basic checks
    results.append(test_bf16_available())
    results.append(test_bf16_tensor_cast())
    print()

    # Conv2D correctness: various shapes representative of SigLIP visual encoder
    # SigLIP uses patch embedding (large kernels) and standard conv blocks
    shapes = [
        # (batch, in_ch, out_ch, h, w, ksize, pad, label)
        (1, 3, 32, 64, 64, 3, 1, "small_conv_3x3"),
        (1, 32, 64, 32, 32, 3, 1, "mid_conv_3x3"),
        (1, 64, 128, 16, 16, 3, 1, "large_chan_conv"),
        (2, 3, 768, 224, 224, 14, 0, "siglip_patch_embed_14x14"),
        (1, 768, 768, 16, 16, 3, 1, "siglip_attn_proj"),
        (4, 64, 64, 8, 8, 1, 0, "pointwise_1x1"),
    ]

    for batch, in_ch, out_ch, h, w, ksize, pad, label in shapes:
        try:
            p, rel, abs_ = run_conv_bf16_vs_fp32(
                batch, in_ch, out_ch, h, w, ksize, pad, label
            )
            results.append(p)
        except Exception as exc:
            print(f"[FAIL] {label}: exception: {exc}")
            results.append(False)

    print()
    passed = sum(results)
    total = len(results)
    print(f"{'='*50}")
    print(f"RESULT: {passed}/{total} tests passed")
    if passed == total:
        print("MIOpen BF16 conv is CORRECT. Safe to remove _keep_in_fp32_modules.")
    else:
        print("MIOpen BF16 conv has ERRORS. Keep _keep_in_fp32_modules workaround.")
    print(f"{'='*50}")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
