#!/usr/bin/env bash
# Run the pipeline stages in order and print a results table.
#   ./pipeline/run-all.sh                 fail-fast: stops at the first failing gate (like a real pipeline)
#   KEEP_GOING=1 ./pipeline/run-all.sh    runs every stage and reports all results
#   STAGES="secrets sast" ./pipeline/run-all.sh    run only some stages
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS="$DIR/../artifacts"
mkdir -p "$ARTIFACTS"
RESULTS="$ARTIFACTS/results.tsv"
: > "$RESULTS"

STAGES="${STAGES:-secrets sast sca lint policy build scan sbom sign dast}"
KEEP_GOING="${KEEP_GOING:-0}"
failed=0
stopped=0

for stage in $STAGES; do
  if [ "$stopped" = 1 ]; then
    printf '%s\tSKIPPED\t-\n' "$stage" >> "$RESULTS"
    continue
  fi
  start=$SECONDS
  if "$DIR/$stage.sh"; then status=PASS; else status=FAIL; failed=1; fi
  printf '%s\t%s\t%ss\n' "$stage" "$status" "$((SECONDS - start))" >> "$RESULTS"
  if [ "$status" = FAIL ] && [ "$KEEP_GOING" != 1 ]; then
    echo; echo "Stage '$stage' failed: pipeline stopped. Nothing after this gate may ship."
    stopped=1
  fi
done

echo
echo "================ PIPELINE RESULTS ================"
printf '%-10s %-8s %s\n' STAGE RESULT TIME
while IFS=$'\t' read -r name status secs; do
  printf '%-10s %-8s %s\n' "$name" "$status" "$secs"
done < "$RESULTS"
echo "=================================================="
if [ "$failed" = 0 ]; then echo "PIPELINE PASSED"; else echo "PIPELINE FAILED"; fi
exit "$failed"
