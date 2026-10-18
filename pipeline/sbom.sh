#!/usr/bin/env bash
# Stage: SBOM, software bill of materials (CycloneDX format, via Trivy). A complete inventory of what is inside
# the image, so that when a new vulnerability is announced you can answer "are we affected?" in seconds.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "sbom (cyclonedx)"

OUT="sbom-${IMAGE_NAME}.cdx.json"
dk run --rm -e TRIVY_DB_REPOSITORY \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$ROOT/.cache/trivy:/root/.cache/" \
  -v "$ARTIFACTS:/out" \
  "$TRIVY_IMAGE" image --format cyclonedx --output "/out/${OUT}" --no-progress "$IMAGE"

python3 - "$ARTIFACTS/$OUT" <<'EOF'
import json, sys
bom = json.load(open(sys.argv[1]))
count = len(bom.get("components", []))
assert bom.get("bomFormat") == "CycloneDX" and count > 0, "SBOM is empty or not CycloneDX"
print(f"SBOM lists {count} components")
EOF
echo "PASS: SBOM saved to artifacts/${OUT}"
