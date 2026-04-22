#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:?usage: $0 <terminal> <remote_whl_path>}"
remote_wheel_path="${2:?usage: $0 <terminal> <remote_whl_path>}"

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

cat > "$tmp_script" <<EOF
set -euo pipefail

echo "== remote wheel install =="
echo "wheel: ${remote_wheel_path}"

/opt/venv/bin/python -m pip uninstall -y paddlepaddle paddlepaddle-rocm paddlepaddle-gpu || true
/opt/venv/bin/python -m pip install --force-reinstall --no-deps ${remote_wheel_path}

echo
echo "== remote wheel smoke =="
/opt/venv/bin/python - <<'PY'
import json
import paddle
import paddle.version as pv

result = {
    "version": paddle.__version__,
    "commit": getattr(pv, "commit", lambda: "unknown")() if callable(getattr(pv, "commit", None)) else getattr(pv, "commit", "unknown"),
    "compiled_with_rocm": paddle.is_compiled_with_rocm(),
    "compiled_with_cuda": paddle.is_compiled_with_cuda(),
}

try:
    paddle.set_device("gpu")
    x = paddle.to_tensor([[1.0, 2.0], [3.0, 4.0]], place="gpu")
    y = paddle.matmul(x, x)
    result["device"] = paddle.device.get_device()
    result["to_tensor_dtype"] = str(x.dtype)
    result["matmul_dtype"] = str(y.dtype)
    result["matmul_value"] = y.cpu().numpy().tolist()
except Exception as exc:
    result["gpu_smoke_error"] = repr(exc)

print(json.dumps(result, indent=2, sort_keys=True))
PY
EOF

python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --timeout 300 --command-file "$tmp_script"