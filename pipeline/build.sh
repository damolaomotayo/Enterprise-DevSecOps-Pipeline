#!/usr/bin/env bash
# Stage: BUILD the container image. Only reached after the source-level gates pass.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "build (docker)"

dk build -t "$IMAGE" "$TARGET/app"
echo "PASS: built $IMAGE"
