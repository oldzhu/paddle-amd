#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <repo_path> <output_dir> [base_ref]"
  exit 1
fi

repo_path="$1"
output_dir="$2"
base_ref="${3:-origin/develop}"

mkdir -p "$output_dir"

git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null
git -C "$repo_path" format-patch "$base_ref" -o "$output_dir"

echo "Exported patches from $repo_path into $output_dir"