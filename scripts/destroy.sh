#!/usr/bin/env bash
# Remove containers, images and generated files created by the pipeline.
# To stop all AWS cost, also terminate the EC2 instance.
set -uo pipefail
cd "$(dirname "$0")/.."
source pipeline/lib.sh

dk rm -f devsecops-registry devsecops-dast >/dev/null 2>&1
dk rmi -f "devsecops-demo:1.0.0" "devsecops-insecure:demo" \
  "${REGISTRY_HOST}/devsecops-demo:1.0.0" "${REGISTRY_HOST}/unsigned-demo:1" >/dev/null 2>&1
rm -rf artifacts .demo .keys
sudo rm -rf .cache
echo "Removed pipeline containers, images and generated files."
