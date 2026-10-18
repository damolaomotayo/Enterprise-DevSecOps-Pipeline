#!/usr/bin/env bash
# Stage: POLICY AS CODE (conftest + Open Policy Agent). Checks Kubernetes manifests against the rules in
# policy/kubernetes.rego (non-root, no privileged containers, resource limits, pinned image tags...).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "policy (conftest)"

dk run --rm \
  -v "$TARGET/k8s:/project/k8s:ro" -v "$ROOT/policy:/project/policy:ro" \
  "$CONFTEST_IMAGE" test k8s --policy policy
echo "PASS: manifests satisfy all policies"
