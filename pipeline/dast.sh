#!/usr/bin/env bash
# Stage: DAST, dynamic application security testing (OWASP ZAP baseline). Starts the built image, attacks it
# like a scanner would over HTTP, and fails if required browser-security headers are missing
# (the rules marked FAIL in dast/zap-rules.conf). Takes about 2 to 3 minutes.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stage_header "dast (OWASP ZAP baseline)"

NAME="devsecops-dast"
cleanup() { dk rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

dk run -d --rm --name "$NAME" -p 127.0.0.1:8080:8080 "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
  curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1 && break
  sleep 1
done
if ! curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
  echo "App did not start:" >&2
  dk logs "$NAME" >&2 || true
  exit 1
fi

cp "$ROOT/dast/zap-rules.conf" "$ARTIFACTS/zap-rules.conf"
dk run --rm --network host -v "$ARTIFACTS:/zap/wrk:rw" "$ZAP_IMAGE" \
  zap-baseline.py -t http://127.0.0.1:8080 -c zap-rules.conf -I -m 1 -r "zap-${IMAGE_NAME}.html"
echo "PASS: no required-header failures (report: artifacts/zap-${IMAGE_NAME}.html)"
