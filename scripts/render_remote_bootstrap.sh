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

required_dns_hosts=(github.com archive.ubuntu.com security.ubuntu.com)

resolve_required_host() {
  local host="\$1"
  getent ahostsv4 "\$host" >/dev/null 2>&1 || getent hosts "\$host" >/dev/null 2>&1
}

retry() {
  local attempts="\$1"
  shift
  local try_index=1
  while true; do
    if "\$@"; then
      return 0
    fi
    if [[ "\${try_index}" -ge "\${attempts}" ]]; then
      return 1
    fi
    echo "retry \${try_index}/\${attempts} failed for: \$*" >&2
    try_index="\$((try_index + 1))"
  done
}

retry_clone() {
  local attempts="\$1"
  local repo_url="\$2"
  local target_dir="\$3"
  shift 3
  local try_index=1
  while true; do
    rm -rf "\$target_dir"
    if command -v timeout >/dev/null 2>&1; then
      if timeout 300 git -c http.version=HTTP/1.1 clone "\$@" "\$repo_url" "\$target_dir"; then
        return 0
      fi
    elif git -c http.version=HTTP/1.1 clone "\$@" "\$repo_url" "\$target_dir"; then
      return 0
    fi
    if [[ "\${try_index}" -ge "\${attempts}" ]]; then
      return 1
    fi
    echo "retry clone \${try_index}/\${attempts} failed for: \$repo_url -> \$target_dir" >&2
    try_index="\$((try_index + 1))"
  done
}

echo "== remote DNS preflight =="
for host in "\${required_dns_hosts[@]}"; do
  if ! resolve_required_host "\$host"; then
    echo "required host lookup failed: \$host" >&2
    echo "remote DNS is unhealthy; run scripts/remote_fix_instance_dns.sh <terminal> before retrying bootstrap" >&2
    exit 1
  fi
done

mkdir -p "\$REMOTE_ROOT"

if [[ ! -d "\$REMOTE_ROOT/.git" ]]; then
  retry_clone 3 "\$CONTROL_REPO_URL" "\$REMOTE_ROOT"
else
  retry 3 git -C "\$REMOTE_ROOT" -c http.version=HTTP/1.1 fetch origin
  git -C "\$REMOTE_ROOT" checkout main
  retry 3 git -C "\$REMOTE_ROOT" -c http.version=HTTP/1.1 pull --ff-only origin main
fi

mkdir -p "\$REMOTE_ROOT/paddlerepos"

if [[ ! -d "\$REMOTE_ROOT/paddlerepos/Paddle/.git" ]]; then
  retry_clone 3 "\$PADDLE_URL" "\$REMOTE_ROOT/paddlerepos/Paddle" --depth 1 --branch develop --single-branch
else
  retry 3 git -C "\$REMOTE_ROOT/paddlerepos/Paddle" -c http.version=HTTP/1.1 fetch origin develop --depth 1
  git -C "\$REMOTE_ROOT/paddlerepos/Paddle" checkout develop
  git -C "\$REMOTE_ROOT/paddlerepos/Paddle" reset --hard origin/develop
fi

if [[ ! -d "\$REMOTE_ROOT/paddlerepos/PaddleX/.git" ]]; then
  retry_clone 3 "\$PADDLEX_URL" "\$REMOTE_ROOT/paddlerepos/PaddleX" --depth 1 --branch develop --single-branch
else
  retry 3 git -C "\$REMOTE_ROOT/paddlerepos/PaddleX" -c http.version=HTTP/1.1 fetch origin develop --depth 1
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