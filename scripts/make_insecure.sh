#!/usr/bin/env bash
# Creates a deliberately INSECURE copy of the project in .demo/insecure.
# Used to prove that every security gate really catches what it claims to catch.
#
# The fake secrets are assembled at run time so this repository never contains
# anything that looks like a real credential (GitHub would block the push).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.demo/insecure}"

rm -rf "$OUT"
mkdir -p "$OUT/app" "$OUT/k8s"
cp "$ROOT/app/app.py" "$ROOT/app/requirements.txt" "$OUT/app/"
cp "$ROOT/k8s/service.yaml" "$OUT/k8s/"

# Flaw 1, secrets: hard-coded credentials committed to code.
{
  echo '"""Settings (insecure demo)."""'
  printf 'AWS_ACCESS_KEY_ID = "%s%s"\n' "AKIA" "QYLPMN5HHHFPZAM2"
  printf 'GITHUB_TOKEN = "%s%s"\n' "ghp_" "R4nD0mT0kEnV4lu3Xy9Zq8Wm7Jk6Hg5Fd3Sa"
} > "$OUT/app/config.py"

# Flaw 2, SAST: dangerous code patterns (never imported by the app, only scanned).
cat > "$OUT/app/insecure.py" <<'EOF'
import hashlib
import subprocess

import yaml


def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True)  # command injection


def calc(expr):
    return eval(expr)  # arbitrary code execution


def load(text):
    return yaml.load(text)  # unsafe deserialisation


def fingerprint(password):
    return hashlib.md5(password.encode()).hexdigest()  # broken hash
EOF

# Flaw 3, SCA: dependencies with known vulnerabilities.
printf 'requests==2.19.1\nPyJWT==1.5.0\n' >> "$OUT/app/requirements.txt"

# Flaw 4, Dockerfile: root user, ADD instead of COPY, no pip cache flag.
cat > "$OUT/app/Dockerfile" <<'EOF'
FROM python:3.12
WORKDIR /app
ADD . /app
RUN pip install -r requirements.txt
USER root
EXPOSE 8080
CMD ["gunicorn", "--bind", ":8080", "app:app"]
EOF

# Flaw 5, Kubernetes: privileged root container, mutable tag, no limits.
cat > "$OUT/k8s/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure-demo
  template:
    metadata:
      labels:
        app: insecure-demo
    spec:
      hostNetwork: true
      containers:
        - name: app
          image: insecure-demo:latest
          securityContext:
            privileged: true
            runAsUser: 0
EOF

# Flaw 6, DAST: strip the security-header block from the app.
sed -i '/SECURITY-HEADERS-BEGIN/,/SECURITY-HEADERS-END/d' "$OUT/app/app.py"

echo "Insecure copy created in ${OUT}"
