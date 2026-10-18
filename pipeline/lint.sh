#!/usr/bin/env bash
# Stage: DOCKERFILE LINT (hadolint). Flags insecure or sloppy Dockerfile practices
# (running as root, unpinned images, ADD instead of COPY...). Fails on warnings and errors.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "lint (hadolint)"

dk run --rm -i "$HADOLINT_IMAGE" hadolint --failure-threshold warning - < "$TARGET/app/Dockerfile"
echo "PASS: Dockerfile follows best practices"
