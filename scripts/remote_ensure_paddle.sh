#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:-1}"
package_spec="${2:-paddlepaddle==3.3.1}"

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

cat > "$tmp_script" <<EOF
set -euo pipefail

if /opt/venv/bin/python - <<'PY'
try:
    import paddle
    print("paddle_version:", getattr(paddle, "__version__", "unknown"))
    print("compiled_with_rocm:", paddle.is_compiled_with_rocm())
    raise SystemExit(0)
except Exception:
    raise SystemExit(1)
PY
then
  echo "Paddle already importable; skipping install"
else
  /opt/venv/bin/python -m pip install --upgrade pip
  /opt/venv/bin/python -m pip install ${package_spec}
fi

echo
echo "== paddle post-install check =="
/opt/venv/bin/python - <<'PY'
try:
    import paddle
    print("paddle_version:", getattr(paddle, "__version__", "unknown"))
    print("compiled_with_rocm:", paddle.is_compiled_with_rocm())
    print("compiled_with_cuda:", paddle.is_compiled_with_cuda())
    if paddle.is_compiled_with_rocm() or paddle.is_compiled_with_cuda():
        print("device:", paddle.device.get_device())
except Exception as exc:
    print("paddle_import_failed:", repr(exc))
    raise
PY
EOF

python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command-file "$tmp_script"