#!/usr/bin/env bash
# Stage: CONTAINER IMAGE SCAN (Trivy). Scans the built image's OS packages and Python libraries for known
# vulnerabilities. Fails on HIGH and CRITICAL findings that already have a fix available.
# (The first run downloads the vulnerability database, about a minute.)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "scan (trivy image)"

dk run --rm -e TRIVY_DB_REPOSITORY \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$ROOT/.cache/trivy:/root/.cache/" \
  "$TRIVY_IMAGE" image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress "$IMAGE" \
  | tee "$ARTIFACTS/trivy-${IMAGE_NAME}.txt"
echo "PASS: no fixable HIGH or CRITICAL vulnerabilities in $IMAGE"
