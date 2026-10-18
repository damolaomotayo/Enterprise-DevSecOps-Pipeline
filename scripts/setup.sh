#!/usr/bin/env bash
# One-time host setup (Amazon Linux 2023 or Ubuntu 22.04+):
# Docker, git, Python + a venv with the Python-based scanners, and the scanner container images.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y git docker python3 python3-pip
elif command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git docker.io python3 python3-venv python3-pip curl
else
  echo "Unsupported OS: install git, docker, python3 manually." >&2
  exit 1
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

python3 -m venv .venv
.venv/bin/pip install -q -r requirements-dev.txt

source pipeline/lib.sh
echo "Pulling scanner images (several GB in total, 5 to 10 minutes the first time)..."
for image in $ALL_TOOL_IMAGES; do
  echo "  $image"
  if ! dk pull -q "$image" >/dev/null; then
    echo "Could not pull $image." >&2
    echo "If that tag no longer exists, override it (see pipeline/lib.sh), e.g.:" >&2
    echo "  ZAP_IMAGE=ghcr.io/zaproxy/zaproxy:stable ./scripts/setup.sh" >&2
    exit 1
  fi
done

echo
echo "Setup complete. Next: .venv/bin/python -m unittest discover -s tests, then ./pipeline/run-all.sh"
