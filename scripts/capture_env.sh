#!/usr/bin/env bash

set -euo pipefail

output_dir="${1:-evidence/env}"
mkdir -p "$output_dir"

timestamp="$(date +%Y%m%d_%H%M%S)"
report="$output_dir/env_${timestamp}.txt"

{
  echo "timestamp: $(date -Iseconds)"
  echo "cwd: $(pwd)"
  echo
  echo "== uname =="
  uname -a || true
  echo
  echo "== os-release =="
  cat /etc/os-release || true
  echo
  echo "== python =="
  command -v python || true
  python --version || true
  echo
  echo "== pip =="
  command -v pip || true
  pip --version || true
  echo
  echo "== git =="
  git --version || true
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
} > "$report" 2>&1

echo "Saved environment report to $report"