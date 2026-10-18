#!/usr/bin/env bash
# NEGATIVE TEST: "test your tests". Every security gate must FAIL on a deliberately insecure copy of the app.
# If a gate passed here, it would be giving false confidence.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source pipeline/lib.sh

./scripts/make_insecure.sh

echo
echo "Running the full pipeline against the insecure copy (keep going, so every gate reports)..."
TARGET="$ROOT/.demo/insecure" IMAGE_NAME=devsecops-insecure IMAGE_TAG=demo \
  STAGES="secrets sast sca lint policy build scan dast" KEEP_GOING=1 ./pipeline/run-all.sh
cp "$ARTIFACTS/results.tsv" "$ARTIFACTS/results-insecure.tsv"

result() { awk -F'\t' -v s="$1" '$1 == s {print $2}' "$ARTIFACTS/results-insecure.tsv"; }
bad=0
echo
echo "---------------- NEGATIVE TEST ASSERTIONS ----------------"
for gate in secrets sast sca lint policy scan dast; do
  if [ "$(result "$gate")" = FAIL ]; then
    printf 'ok    gate %-8s correctly FAILED the insecure app\n' "$gate"
  else
    printf 'FAIL  gate %-8s did NOT catch the insecure app (result: %s)\n' "$gate" "$(result "$gate")"
    bad=1
  fi
done
if [ "$(result build)" = PASS ]; then
  echo "ok    build is a plain step and passed (as expected)"
else
  echo "FAIL  build should have passed for the insecure image"
  bad=1
fi

# An unsigned image must be rejected by signature verification.
ensure_registry
ensure_keys
printf 'FROM busybox:1.36\n' | dk build -q -t "${REGISTRY_HOST}/unsigned-demo:1" - >/dev/null
dk push "${REGISTRY_HOST}/unsigned-demo:1" >/dev/null
UNSIGNED_REF="$(dk inspect --format '{{index .RepoDigests 0}}' "${REGISTRY_HOST}/unsigned-demo:1")"
if cosign_run verify --key /keys/cosign.pub --insecure-ignore-tlog=true --allow-insecure-registry "$UNSIGNED_REF" >/dev/null 2>&1; then
  echo "FAIL  an UNSIGNED image passed signature verification"
  bad=1
else
  echo "ok    unsigned image was rejected by signature verification"
fi

echo "----------------------------------------------------------"
if [ "$bad" = 0 ]; then echo "All negative tests passed: the gates catch what they claim to catch."; fi
exit "$bad"
