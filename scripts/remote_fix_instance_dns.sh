#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:-1}"
if [[ $# -gt 0 ]]; then
  shift
fi

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

bash scripts/render_remote_dns_repair.sh "$@" > "$tmp_script"

echo "[local] executing remote DNS repair on terminal ${terminal_name}"
python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command-file "$tmp_script"