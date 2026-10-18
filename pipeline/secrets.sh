#!/usr/bin/env bash
# Stage: SECRET SCANNING (gitleaks). Finds passwords, API keys and tokens in files and in git history.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "secrets (gitleaks)"

UIDGID="$(id -u):$(id -g)"

echo "Scanning files..."
dk run --rm --user "$UIDGID" \
  -v "$TARGET:/repo:ro" -v "$ROOT/.gitleaks.toml:/config/gitleaks.toml:ro" \
  "$GITLEAKS_IMAGE" dir /repo --config /config/gitleaks.toml --no-banner --redact --exit-code 1

if [ -d "$TARGET/.git" ]; then
  echo "Scanning git history (a secret deleted from a file is still in old commits)..."
  dk run --rm --user "$UIDGID" \
    -v "$TARGET:/repo:ro" -v "$ROOT/.gitleaks.toml:/config/gitleaks.toml:ro" \
    "$GITLEAKS_IMAGE" git /repo --config /config/gitleaks.toml --no-banner --redact --exit-code 1
fi
echo "PASS: no secrets found"
