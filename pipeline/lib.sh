#!/usr/bin/env bash
# Shared settings and helpers. Sourced by every stage script (not run directly).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${TARGET:-$ROOT}"              # the directory being checked (the demo points this at .demo/insecure)
IMAGE_NAME="${IMAGE_NAME:-devsecops-demo}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"
IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
ARTIFACTS="${ROOT}/artifacts"          # reports, SBOM, results table
VENV="${ROOT}/.venv"
KEYS="${ROOT}/.keys"                   # cosign signing keys (git-ignored)
REGISTRY_HOST="localhost:5000"

# Pinned tool versions. Each can be overridden from the environment, e.g.
#   ZAP_IMAGE=ghcr.io/zaproxy/zaproxy:stable ./scripts/setup.sh
# Dependabot / Renovate would bump these.
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.21.2}"
HADOLINT_IMAGE="${HADOLINT_IMAGE:-hadolint/hadolint:v2.12.0}"
CONFTEST_IMAGE="${CONFTEST_IMAGE:-openpolicyagent/conftest:v0.56.0}"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.58.0}"
COSIGN_IMAGE="${COSIGN_IMAGE:-gcr.io/projectsigstore/cosign:v2.4.1}"
ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy:2.15.0}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-registry:2.8.3}"
ALL_TOOL_IMAGES="$GITLEAKS_IMAGE $HADOLINT_IMAGE $CONFTEST_IMAGE $TRIVY_IMAGE $COSIGN_IMAGE $ZAP_IMAGE $REGISTRY_IMAGE"

# Use docker directly if allowed, otherwise via sudo (right after setup, group membership is not active yet).
dk() {
  if docker info >/dev/null 2>&1; then docker "$@"; else sudo docker "$@"; fi
}

# Containers such as ZAP and Trivy write here as other users.
mkdir -p "$ARTIFACTS" "$ROOT/.cache/trivy"
chmod 777 "$ARTIFACTS" 2>/dev/null || true

stage_header() { echo; echo "==> STAGE: $1"; }

need_venv() {
  if [ ! -x "$VENV/bin/$1" ]; then
    echo "Missing $VENV/bin/$1. Run ./scripts/setup.sh first." >&2
    exit 1
  fi
}

# --- image signing helpers (used by sign.sh and the demo) ----------------

cosign_run() {
  dk run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp -e COSIGN_PASSWORD= \
    -v "$KEYS:/keys" -w /keys "$COSIGN_IMAGE" "$@"
}

ensure_keys() {
  mkdir -p "$KEYS"
  if [ ! -f "$KEYS/cosign.key" ]; then
    echo "Generating a cosign key pair in .keys/ (empty password, demo only)..."
    cosign_run generate-key-pair >/dev/null
  fi
}

ensure_registry() {
  if ! dk ps --format '{{.Names}}' | grep -qx devsecops-registry; then
    dk rm -f devsecops-registry >/dev/null 2>&1 || true
    dk run -d --restart=unless-stopped --name devsecops-registry -p 127.0.0.1:5000:5000 "$REGISTRY_IMAGE" >/dev/null
  fi
  for _ in $(seq 1 30); do
    curl -fsS "http://${REGISTRY_HOST}/v2/" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "Local registry did not start." >&2
  return 1
}
