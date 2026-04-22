#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:-1}"
remote_root="${2:-/app/paddle-amd-remote}"

tmp_bootstrap="$(mktemp)"
tmp_env_check="$(mktemp)"
cleanup() {
  rm -f "$tmp_bootstrap"
  rm -f "$tmp_env_check"
}
trap cleanup EXIT

bash scripts/render_remote_bootstrap.sh "$remote_root" > "$tmp_bootstrap"
bash scripts/render_remote_env_check.sh > "$tmp_env_check"

python3 scripts/jupyter_remote.py upload "$tmp_env_check" paddle_amd_remote_env_check.sh >/dev/null

echo "[local] executing remote bootstrap on terminal ${terminal_name}"
python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command-file "$tmp_bootstrap"

echo
echo "[local] running remote environment check"
python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command "bash /app/paddle_amd_remote_env_check.sh"