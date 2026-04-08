#!/usr/bin/env bash

set -euo pipefail

cat <<'EOF'
Reproduction checklist

1. Record Paddle commit.
2. Record PaddleX commit.
3. Record ROCm version and GPU model.
4. Capture environment using scripts/capture_env.sh.
5. Run with current PaddleX workaround enabled.
6. Run with workaround removed or bypassed.
7. Save logs and screenshots under evidence/.
8. Update docs/en/validation.md and docs/zh/validation.md.
9. Update docs/en/dev-log.md and docs/zh/dev-log.md.
EOF