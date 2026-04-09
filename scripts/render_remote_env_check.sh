#!/usr/bin/env bash

set -euo pipefail

cat <<'EOF'
set -euo pipefail

echo "== uname =="
uname -a || true

echo
echo "== os-release =="
cat /etc/os-release || true

echo
echo "== pwd =="
pwd || true

echo
echo "== python =="
command -v python || true
python --version || true

echo
echo "== pip =="
command -v pip || true
pip --version || true

echo
echo "== rocminfo =="
rocminfo || true

echo
echo "== rocm-smi =="
rocm-smi || true

echo
echo "== hipcc =="
command -v hipcc || true
hipcc --version || true

echo
echo "== python paddle import =="
python - <<'PY'
try:
    import paddle
    print("paddle_version:", getattr(paddle, "__version__", "unknown"))
    print("compiled_with_rocm:", paddle.is_compiled_with_rocm())
    print("compiled_with_cuda:", paddle.is_compiled_with_cuda())
except Exception as exc:
    print("paddle_import_failed:", repr(exc))
PY

echo
echo "== pip paddle packages =="
pip list | grep -Ei 'paddle|rocm|hip' || true

echo
echo "== gpu device probe =="
python - <<'PY'
try:
    import paddle
    if paddle.is_compiled_with_rocm() or paddle.is_compiled_with_cuda():
        print("device:", paddle.device.get_device())
    else:
        print("device: cpu-only build or no GPU backend")
except Exception as exc:
    print("device_probe_failed:", repr(exc))
PY
EOF