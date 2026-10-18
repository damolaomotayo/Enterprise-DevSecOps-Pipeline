#!/usr/bin/env bash
# End-to-end proof (about 15 minutes):
#   1. The clean app passes every stage of the pipeline.
#   2. A deliberately insecure copy is stopped by every security gate.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "############ PART 1: clean app must PASS the whole pipeline ############"
if ! ./pipeline/run-all.sh; then
  echo
  echo "FAIL: the clean app did not pass. Read the failing stage output above."
  exit 1
fi
cp artifacts/results.tsv artifacts/results-clean.tsv

echo
echo "############ PART 2: insecure app must be STOPPED by every gate ############"
if ! ./scripts/demo_insecure.sh; then
  echo "FAIL: at least one gate let the insecure app through."
  exit 1
fi

echo
echo "All checks passed."
