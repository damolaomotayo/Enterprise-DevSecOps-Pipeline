#!/usr/bin/env bash
# Stage: SCA, software composition analysis (pip-audit). Checks every pinned dependency against
# public vulnerability databases. Needs internet access to query them.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "sca (pip-audit)"
need_venv pip-audit

"$VENV/bin/pip-audit" -r "$TARGET/app/requirements.txt" --no-deps --disable-pip --progress-spinner off 2>&1 \
  | grep -v -e '^WARNING:pip_audit' | tee "$ARTIFACTS/pip-audit-${IMAGE_NAME}.txt"
echo "PASS: no known vulnerable dependencies"
