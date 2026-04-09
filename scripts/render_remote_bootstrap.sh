#!/usr/bin/env bash

set -euo pipefail

remote_root="${1:-/app/paddle-amd-remote}"
control_repo_url="${2:-https://github.com/oldzhu/paddle-amd.git}"
paddle_url="${3:-https://github.com/PaddlePaddle/Paddle.git}"
paddlex_url="${4:-https://github.com/PaddlePaddle/PaddleX.git}"

cat <<EOF
set -euo pipefail

REMOTE_ROOT="${remote_root}"
CONTROL_REPO_URL="${control_repo_url}"
PADDLE_URL="${paddle_url}"
PADDLEX_URL="${paddlex_url}"

mkdir -p "\$REMOTE_ROOT"

if [[ ! -d "\$REMOTE_ROOT/.git" ]]; then
  git clone "\$CONTROL_REPO_URL" "\$REMOTE_ROOT"
else
  git -C "\$REMOTE_ROOT" fetch origin
  git -C "\$REMOTE_ROOT" checkout main
  git -C "\$REMOTE_ROOT" pull --ff-only origin main
fi

mkdir -p "\$REMOTE_ROOT/paddlerepos"

if [[ ! -d "\$REMOTE_ROOT/paddlerepos/Paddle/.git" ]]; then
  git -c http.version=HTTP/1.1 clone --depth 1 --branch develop --single-branch "\$PADDLE_URL" "\$REMOTE_ROOT/paddlerepos/Paddle"
else
  git -C "\$REMOTE_ROOT/paddlerepos/Paddle" fetch origin develop --depth 1
  git -C "\$REMOTE_ROOT/paddlerepos/Paddle" checkout develop
  git -C "\$REMOTE_ROOT/paddlerepos/Paddle" reset --hard origin/develop
fi

if [[ ! -d "\$REMOTE_ROOT/paddlerepos/PaddleX/.git" ]]; then
  git -c http.version=HTTP/1.1 clone --depth 1 --branch develop --single-branch "\$PADDLEX_URL" "\$REMOTE_ROOT/paddlerepos/PaddleX"
else
  git -C "\$REMOTE_ROOT/paddlerepos/PaddleX" fetch origin develop --depth 1
  git -C "\$REMOTE_ROOT/paddlerepos/PaddleX" checkout develop
  git -C "\$REMOTE_ROOT/paddlerepos/PaddleX" reset --hard origin/develop
fi

cd "\$REMOTE_ROOT"
./scripts/capture_env.sh

echo
echo "== remote paddle import check =="
/opt/venv/bin/python - <<'PY'
try:
  import paddle
  print("paddle_version:", getattr(paddle, "__version__", "unknown"))
  print("compiled_with_rocm:", paddle.is_compiled_with_rocm())
except Exception as exc:
  print("paddle_import_failed:", repr(exc))
PY

git rev-parse HEAD
git -C paddlerepos/Paddle rev-parse HEAD
git -C paddlerepos/PaddleX rev-parse HEAD

echo "Remote workspace is ready under \$REMOTE_ROOT"
EOF