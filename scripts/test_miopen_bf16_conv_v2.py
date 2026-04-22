"""
Test v2: MIOpen BF16 conv2d correctness on ROCm — improved metrics.

Uses SNR (signal-to-noise ratio) and mean absolute error instead of max relative
error, which is dominated by near-zero cancellation artifacts with random weights.

SNR >= 20 dB is considered acceptable for BF16 inference (typical is 30-40 dB
for well-behaved BF16 implementations; <20 dB indicates a real correctness bug).

Also tests with non-random, well-conditioned weights to isolate actual bugs.

Usage:
  LD_LIBRARY_PATH=/opt/rocm-compat:/opt/rocm/lib /opt/venv/bin/python test_miopen_bf16_conv_v2.py
"""

import sys
import numpy as np
import paddle
import paddle.nn.functional as F


def snr_db(ref, test):
    """Signal-to-noise ratio in dB. Higher = closer to reference."""
    signal_power = float(np.mean(ref ** 2))
    noise_power = float(np.mean((ref - test) ** 2))
    if noise_power == 0:
        return float("inf")
    if signal_power == 0:
        return -float("inf")
    return 10 * np.log10(signal_power / noise_power)


def run_conv_bf16(batch, in_ch, out_ch, h, w, ksize=3, padding=1, label="", seed=42):
    np.random.seed(seed)

    # Use positive bounded weights to avoid cancellation artifacts
    x_np = (np.random.rand(batch, in_ch, h, w).astype("float32") - 0.5) * 2  # [-1,1]
    weight_np = np.random.rand(out_ch, in_ch, ksize, ksize).astype("float32") * 0.1
    bias_np = np.zeros(out_ch, dtype="float32")

    # FP32 reference on GPU
    x32 = paddle.to_tensor(x_np, dtype="float32", place="gpu")
    w32 = paddle.to_tensor(weight_np, dtype="float32", place="gpu")
    b32 = paddle.to_tensor(bias_np, dtype="float32", place="gpu")
    y32 = F.conv2d(x32, w32, b32, padding=padding)
    y32_np = y32.cpu().numpy()

    # BF16 on GPU
    x16 = x32.cast("bfloat16")
    w16 = w32.cast("bfloat16")
    b16 = b32.cast("bfloat16")
    y16 = F.conv2d(x16, w16, b16, padding=padding)
    y16_np = y16.cpu().cast("float32").numpy()

    snr = snr_db(y32_np, y16_np)
    mae = float(np.mean(np.abs(y32_np - y16_np)))
    max_abs = float(np.max(np.abs(y32_np - y16_np)))
    ref_std = float(np.std(y32_np))

    # BF16 typically achieves 25-40 dB SNR for conv.
    # <20 dB = serious bug; 20-30 dB = degraded but functional; >30 dB = healthy.
    threshold_snr = 20.0
    passed = snr >= threshold_snr
    status = "PASS" if passed else "FAIL"
    print(
        f"[{status}] {label:40s}: SNR={snr:6.1f} dB  MAE={mae:.5f}  "
        f"max_abs={max_abs:.4f}  ref_std={ref_std:.4f}"
    )
    return passed, snr


def test_bf16_cast_roundtrip():
    """
    Test that BF16 roundtrip error is within 1 BF16 ULP for each value.
    BF16 ULP(x) = 2^(floor(log2(|x|)) - 7)
    """
    vals = [0.0, 1.0, -1.0, 0.5, 100.0, -3.14, 0.001, 12345.0]
    x = paddle.to_tensor(vals, dtype="float32", place="gpu")
    x_bf16 = x.cast("bfloat16")
    x_back = x_bf16.cast("float32").cpu().numpy()
    orig = np.array(vals, dtype=np.float32)

    all_ok = True
    for v, v_back in zip(orig, x_back):
        if v == 0.0:
            ulp = 2**-133  # very small
        else:
            ulp = 2 ** (int(np.floor(np.log2(abs(float(v))))) - 7)
        err = abs(float(v) - float(v_back))
        ok = err <= ulp + 1e-10  # 1 ULP tolerance
        if not ok:
            all_ok = False
            print(f"  BF16 cast FAIL: {v} -> {v_back}, err={err:.6f}, 1ulp={ulp:.6f}")

    status = "PASS" if all_ok else "FAIL"
    print(f"[{status}] BF16 tensor cast roundtrip (within 1 ULP)")
    return all_ok


def test_known_correct_conv():
    """
    Test with analytically verifiable weights: identity kernel (weight=1/N_accum).
    With uniform weights and bounded inputs, BF16 should give close to FP32.
    """
    # 1-channel, 1x1 conv with weight=1.0 — trivial case, no accumulation
    x_np = np.array([[[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]]], dtype="float32")
    w_np = np.array([[[[1.0]]]], dtype="float32")  # identity 1x1 conv
    b_np = np.array([0.0], dtype="float32")

    x32 = paddle.to_tensor(x_np, place="gpu")
    w32 = paddle.to_tensor(w_np, place="gpu")
    b32 = paddle.to_tensor(b_np, place="gpu")
    y32 = F.conv2d(x32, w32, b32, padding=0)

    x16 = x32.cast("bfloat16")
    w16 = w32.cast("bfloat16")
    b16 = b32.cast("bfloat16")
    y16 = F.conv2d(x16, w16, b16, padding=0)

    y32_np = y32.cpu().numpy()
    y16_np = y16.cpu().cast("float32").numpy()
    max_err = float(np.max(np.abs(y32_np - y16_np)))

    # Identity conv: output == input exactly, BF16 should match FP32 exactly
    passed = max_err < 0.001
    status = "PASS" if passed else "FAIL"
    print(f"[{status}] Identity 1x1 BF16 conv (max_err={max_err:.6f}, expected ~0)")
    return passed


def main():
    print(f"paddle version: {paddle.__version__}")
    print(f"compiled_with_rocm: {paddle.is_compiled_with_rocm()}")
    print()

    if not paddle.is_compiled_with_rocm():
        print("ERROR: Not a ROCm build.")
        sys.exit(1)

    paddle.set_device("gpu")
    results = []

    print("=== Basic correctness ===")
    results.append(test_bf16_cast_roundtrip())
    results.append(test_known_correct_conv())
    print()

    print("=== Conv SNR tests (SNR threshold: 20 dB) ===")
    shapes = [
        (1, 1, 1, 8, 8, 1, 0, "trivial_1ch_1x1"),
        (1, 3, 16, 32, 32, 3, 1, "small_3ch_3x3"),
        (1, 32, 64, 16, 16, 3, 1, "mid_32ch_3x3"),
        (1, 64, 64, 8, 8, 1, 0, "pointwise_1x1"),
        (1, 3, 768, 224, 224, 14, 0, "siglip_patch_embed"),
        (1, 768, 768, 16, 16, 3, 1, "siglip_deep_conv"),
    ]

    for batch, in_ch, out_ch, h, w, ksize, pad, label in shapes:
        try:
            p, snr = run_conv_bf16(batch, in_ch, out_ch, h, w, ksize, pad, label)
            results.append(p)
        except Exception as exc:
            print(f"[FAIL] {label}: exception: {exc}")
            results.append(False)

    print()
    passed = sum(results)
    total = len(results)
    print("=" * 60)
    print(f"RESULT: {passed}/{total} tests passed")

    if passed == total:
        print("VERDICT: MIOpen BF16 conv is CORRECT (within BF16 expected precision).")
        print("         SAFE to remove _keep_in_fp32_modules from PaddleX.")
    elif passed >= total - 1:
        print("VERDICT: MIOpen BF16 conv is MOSTLY CORRECT. Manual review needed.")
        print("         Check failed cases — may still be safe to remove workaround.")
    else:
        print("VERDICT: MIOpen BF16 conv has ERRORS (SNR too low).")
        print("         Keep _keep_in_fp32_modules workaround until MIOpen is fixed.")
    print("=" * 60)

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
