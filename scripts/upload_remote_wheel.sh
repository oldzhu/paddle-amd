#!/usr/bin/env bash

set -euo pipefail

local_wheel_path="${1:?usage: $0 /path/to/wheel.whl [remote_dir]}"
remote_dir="${2:-uploaded-wheels}"

if [[ ! -f "$local_wheel_path" ]]; then
  echo "wheel not found: $local_wheel_path" >&2
  exit 1
fi

remote_path="${remote_dir%/}/$(basename "$local_wheel_path")"
python3 scripts/jupyter_remote.py upload "$local_wheel_path" "$remote_path"
echo "$remote_path"