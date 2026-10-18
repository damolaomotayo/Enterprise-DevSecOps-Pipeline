#!/usr/bin/env bash
# Stage: SAST, static application security testing (bandit). Reads the source code and flags dangerous patterns
# such as shell injection, eval, unsafe deserialisation and weak hashes. Fails on MEDIUM severity and above.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "sast (bandit)"
need_venv bandit

"$VENV/bin/bandit" -r "$TARGET/app" -ll -q
echo "PASS: no medium or high severity code issues"
