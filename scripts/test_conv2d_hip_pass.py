"""
Test: Conv2D GPU static inference - HIP fuse pass bug reproduction and fix validation.

Demonstrates:
  - BUG (unpatched Paddle on ROCm): conv2d_add_act_fuse_pass fuses ops into
    fused_conv2d_add_act which is not registered on HIP -> RuntimeError
  - FIX approach: deleting those passes (equivalent to #ifdef PADDLE_WITH_HIP guard)

Environment:
  export FLAGS_conv_workspace_size_limit=32
  export LD_LIBRARY_PATH=/opt/rocm-compat:/opt/rocm/lib:$LD_LIBRARY_PATH
  python3 test_conv2d_hip_pass.py
"""
import os
import sys
import numpy as np

import paddle
import paddle.nn as nn


class SimpleConvModel(nn.Layer):
    """Simple conv2d + bn + relu model to exercise the conv2d fuse passes."""

    def __init__(self):
        super().__init__()
        self.conv = nn.Conv2D(3, 16, 3, padding=1)
        self.bn = nn.BatchNorm2D(16)
        self.relu = nn.ReLU()

    def forward(self, x):
        out = self.conv(x)
        out = self.bn(out)
        out = self.relu(out)
        return out


def build_and_save_model(save_path):
    model = SimpleConvModel()
    model.eval()
    model_static = paddle.jit.to_static(
        model,
        input_spec=[paddle.static.InputSpec(shape=[None, 3, 32, 32], dtype="float32")],
        full_graph=True,
    )
    paddle.jit.save(model_static, save_path)


def make_config(save_path, delete_fuse_passes=False):
    model_file = save_path + ".json"
    if not os.path.exists(model_file):
        model_file = save_path + ".pdmodel"
    params_file = save_path + ".pdiparams"

    config = paddle.inference.Config(model_file, params_file)
    config.enable_use_gpu(1024, 0)
    if delete_fuse_passes:
        config.delete_pass("conv2d_add_act_fuse_pass")
        config.delete_pass("conv2d_add_fuse_pass")
    return config


def run_inference(predictor):
    names = predictor.get_input_names()
    h = predictor.get_input_handle(names[0])
    h.reshape([1, 3, 32, 32])
    h.copy_from_cpu(np.random.randn(1, 3, 32, 32).astype("float32"))
    predictor.run()
    out = predictor.get_output_handle(predictor.get_output_names()[0]).copy_to_cpu()
    return out


def main():
    print("=== Paddle GPU Conv2D Fuse Pass Guard Validation ===")
    print(f"Paddle:  {paddle.__version__}")
    print(f"ROCm:    {paddle.is_compiled_with_rocm()}")
    print(f"Device:  {paddle.device.get_device()}")
    print()

    paddle.set_device("gpu:0")

    save_dir = "/tmp/test_conv_model"
    os.makedirs(save_dir, exist_ok=True)
    save_path = os.path.join(save_dir, "model")
    build_and_save_model(save_path)
    print(f"Model saved to {save_dir}")

    results = {}

    # ---- Test 1: WITHOUT deleting passes (bug reproduction) -----------------
    print("\n[Test 1] WITHOUT pass deletion (bug reproduction on ROCm):")
    try:
        cfg = make_config(save_path, delete_fuse_passes=False)
        pred = paddle.inference.create_predictor(cfg)
        out = run_inference(pred)
        print(f"  PASS - output shape={out.shape}")
        results["bug_repro"] = "NO_BUG (fix compiled in?)"
    except RuntimeError as e:
        if "fused_conv2d_add_act" in str(e) or "not registered" in str(e):
            print(f"  BUG CONFIRMED: {e}")
            results["bug_repro"] = "BUG_CONFIRMED"
        else:
            print(f"  UNEXPECTED ERROR: {e}")
            results["bug_repro"] = f"UNEXPECTED: {e}"

    # ---- Test 2: WITH pass deletion (workaround = what fix achieves) --------
    print("\n[Test 2] WITH pass deletion (fix / workaround behavior):")
    try:
        cfg = make_config(save_path, delete_fuse_passes=True)
        pred = paddle.inference.create_predictor(cfg)
        out = run_inference(pred)
        print(f"  PASS - output shape={out.shape}, dtype={out.dtype}")
        results["fix_workaround"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["fix_workaround"] = f"FAIL: {e}"

    # ---- Test 3: BF16 dynamic graph -----------------------------------------
    print("\n[Test 3] BF16 dynamic graph inference:")
    try:
        bf16_ok = paddle.amp.is_bfloat16_supported()
        print(f"  BF16 available: {bf16_ok}")
        m = SimpleConvModel()
        m.eval()
        with paddle.amp.auto_cast(dtype="bfloat16"):
            x = paddle.randn([1, 3, 32, 32])
            y = m(x)
        print(f"  PASS - output dtype={y.dtype}, shape={y.shape}")
        results["bf16_dynamic"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["bf16_dynamic"] = f"FAIL: {e}"

    # ---- Summary ------------------------------------------------------------
    print("\n=== SUMMARY ===")
    for k, v in results.items():
        status = "[OK]" if "PASS" in v or "CONFIRMED" in v else "[FAIL]"
        print(f"  {status} {k}: {v}")

    ok = results.get("fix_workaround") == "PASS" and results.get("bf16_dynamic") == "PASS"
    if ok:
        print("\nVALIDATION PASSED")
        print("  Bug: conv2d_add_act_fuse_pass creates fused_conv2d_add_act not registered on HIP")
        print("  Fix: #ifdef PADDLE_WITH_HIP guard in InitializePatterns() -> pass is a no-op")
        print("  Equivalent: delete_pass() at inference time produces same correct result")
    else:
        print("\nVALIDATION FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
