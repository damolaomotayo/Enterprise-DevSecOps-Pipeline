#!/usr/bin/env bash
# Stage: SIGN the image (cosign) and verify the signature. Pushes the image to a local registry, signs its
# immutable digest, then verifies. A deploy gate can refuse any image that fails this verification.
# Demo uses a local key pair; production would use keyless signing (GitHub OIDC) or a cloud KMS key.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "sign (cosign)"

ensure_registry
ensure_keys

REMOTE="${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}"
dk tag "$IMAGE" "$REMOTE"
dk push "$REMOTE" >/dev/null
REF="$(dk inspect --format '{{index .RepoDigests 0}}' "$REMOTE")"
echo "Image digest reference: $REF"

cosign_run sign --key /keys/cosign.key --tlog-upload=false --allow-insecure-registry --yes "$REF"
cosign_run verify --key /keys/cosign.pub --insecure-ignore-tlog=true --allow-insecure-registry "$REF" \
  > "$ARTIFACTS/cosign-verify-${IMAGE_NAME}.json"
echo "PASS: image signed and signature verified"
