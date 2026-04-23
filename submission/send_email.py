#!/usr/bin/env python3
"""
Send the AMD Hackathon submission email.

Usage:
    export SMTP_USER="your.address@gmail.com"
    export SMTP_PASS="xxxx xxxx xxxx xxxx"   # Gmail App Password (16 chars)
    python3 submission/send_email.py

For Gmail: create an App Password at https://myaccount.google.com/apppasswords
(requires 2-Step Verification enabled on your Google account).
"""

import os
import smtplib
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from pathlib import Path

# ── Credentials (from env) ──────────────────────────────────────────────────
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")

if not SMTP_USER or not SMTP_PASS:
    sys.exit(
        "ERROR: set SMTP_USER and SMTP_PASS environment variables before running.\n"
        "  export SMTP_USER='you@gmail.com'\n"
        "  export SMTP_PASS='xxxx xxxx xxxx xxxx'   # Gmail App Password"
    )

# ── Addresses ───────────────────────────────────────────────────────────────
TO = ["ext_paddle_oss@baidu.com"]
CC = ["Zijun.Wei@amd.com", "Huaqiang.Fang@amd.com", "bingqing.guo@amd.com"]

# ── Subject ─────────────────────────────────────────────────────────────────
SUBJECT = (
    "[AMD Hackathon 10th] Enable HIP BF16 for PaddleOCR-VL — "
    "Paddle PR #78760 + PaddleX PR #5112"
)

# ── Body ────────────────────────────────────────────────────────────────────
BODY = """\
Dear Paddle / AMD Hackathon Team,

I am submitting the deliverables for the AMD Hackathon 10th task:
"为 Paddle 框架适配 HIP BF16 精度类型" (Enable HIP BF16 precision in Paddle for PaddleOCR-VL).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deliverables
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Paddle Issue  https://github.com/PaddlePaddle/Paddle/issues/78759
2. Paddle PR     https://github.com/PaddlePaddle/Paddle/pull/78760
3. PaddleX Issue https://github.com/PaddlePaddle/PaddleX/issues/5111
4. PaddleX PR    https://github.com/PaddlePaddle/PaddleX/pull/5112
5. Evidence repo https://github.com/oldzhu/paddle-amd

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Paddle PR #78760 — Changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. paddle/phi/kernels/gpu/layer_norm_kernel.cu
   Add phi::bfloat16 to the HIP PD_REGISTER_KERNEL.
   The kernel implementation already uses templated CUDA-compatible intrinsics
   that compile and run correctly on ROCm; the omission of bfloat16 was the
   sole blocker.

2. paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc
   Add #ifdef PADDLE_WITH_HIP return ps; #endif guard in InitializePatterns().
   The fused op (FusedConv2dAddActOp) is only compiled under PADDLE_WITH_CUDA;
   on ROCm the pass generates un-dispatchable nodes.

3. paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc
   Same PADDLE_WITH_HIP guard as above.

4. test/legacy_test/test_layer_norm_bf16_hip.py  (new)
   Unit tests for LayerNorm BF16 on HIP: 2D/3D/4D shapes, dtype preservation,
   SNR >= 30 dB vs FP32 reference.
   https://github.com/oldzhu/Paddle/blob/hip-bf16-layer-norm-and-conv2d-fix/test/legacy_test/test_layer_norm_bf16_hip.py

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PaddleX PR #5112 — Changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. paddlex/inference/utils/misc.py
   Add 'dcu' to the device allowlist in is_bfloat16_available().

2. paddlex/inference/models/common/static_infer.py
   Remove 4 scattered ROCm delete_pass() workaround blocks.

3. paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py
   - Remove _keep_in_fp32_modules = ["visual", "mlp_AR"].
   - Add temporary LayerNorm BF16 shim (BF16->FP32->BF16) for Paddle wheel
     versions that predate the kernel fix. Remove after Paddle PR merges.

4. paddlex/inference/models/common/transformers/utils.py
   Add 'dcu' -> 'gpu' mapping in device_guard().

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validation Evidence
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hardware : AMD Radeon RX 7900 GRE (gfx1100)
Software : ROCm 7.2.0, Python 3.12, Paddle 3.4.0.dev20260408

  is_compiled_with_rocm()          : True
  is_bfloat16_available('dcu:0')   : True
  _keep_in_fp32_modules            : None (removed)
  BF16 conv2d SNR vs FP32          : 44 dB
  PaddleOCR-VL-1.5 BF16 pipeline  : PASS — 202.8s, EXIT:0
  OCR output correctness           : 5 blocks detected, text verified

Screenshot : https://github.com/oldzhu/paddle-amd/blob/main/evidence/bf16_pipeline_validation_gfx1100.png
Full log   : https://github.com/oldzhu/paddle-amd/blob/main/evidence/bf16_pipeline_validation_gfx1100.log

(Screenshot also attached to this email.)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Best regards,
oldzhu
GitHub: https://github.com/oldzhu
"""

# ── Attachment ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).parent.parent
SCREENSHOT = REPO_ROOT / "evidence" / "bf16_pipeline_validation_gfx1100.png"

# ── Build message ────────────────────────────────────────────────────────────
msg = MIMEMultipart()
msg["From"] = SMTP_USER
msg["To"] = ", ".join(TO)
msg["Cc"] = ", ".join(CC)
msg["Subject"] = SUBJECT
msg.attach(MIMEText(BODY, "plain", "utf-8"))

if SCREENSHOT.exists():
    with open(SCREENSHOT, "rb") as f:
        part = MIMEBase("image", "png")
        part.set_payload(f.read())
    encoders.encode_base64(part)
    part.add_header(
        "Content-Disposition",
        f'attachment; filename="{SCREENSHOT.name}"',
    )
    msg.attach(part)
    print(f"Attachment: {SCREENSHOT.name}")
else:
    print(f"WARNING: screenshot not found at {SCREENSHOT}, sending without attachment.")

# ── Send ─────────────────────────────────────────────────────────────────────
all_recipients = TO + CC
print(f"Connecting to smtp.gmail.com:587 as {SMTP_USER} ...")
with smtplib.SMTP("smtp.gmail.com", 587) as server:
    server.ehlo()
    server.starttls()
    server.login(SMTP_USER, SMTP_PASS)
    server.sendmail(SMTP_USER, all_recipients, msg.as_bytes())

print("Email sent successfully to:")
for addr in all_recipients:
    print(f"  {addr}")
