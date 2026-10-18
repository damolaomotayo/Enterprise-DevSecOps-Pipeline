# STEPS: Enterprise DevSecOps Pipeline

## Prerequisites (set these up BEFORE step 1)

| Need | Details |
|---|---|
| EC2 instance | Ubuntu 22.04/24.04 or Amazon Linux 2023, **t3.large (2 vCPU, 8 GB) or bigger**, **30 GB disk** (scanner images and built images take several GB), outbound internet (Docker Hub, ghcr.io, gcr.io, GitHub, PyPI). Inbound: SSH (port 22) from your IP only. No IAM role needed. |
| SSH access | Your key pair `.pem` file: `ssh -i key.pem ubuntu@<public-ip>` (Amazon Linux: `ec2-user@`). |
| The code on the instance | **Option A (private GitHub repo):** create a fine-grained token (GitHub → Settings → Developer settings → Fine-grained tokens), this repo only, **Contents: Read**. Use it as the password when `git clone` asks. **Option B (no GitHub):** from your laptop run `scp -i key.pem devsecops-pipeline.tar.gz ubuntu@<ip>:~` then on the instance `tar xzf devsecops-pipeline.tar.gz`. |
| Optional: GitHub Actions | Push the repo to a private GitHub repo and make sure Actions is enabled. The same pipeline then runs on every push (free plan includes 2,000 minutes per month for private repos). Not needed to verify the project on EC2. |
| Docker Hub limits | Anonymous pulls are limited per IP. Setup pulls 7 images, which is normally fine. If you see `toomanyrequests`, run `sudo docker login` with a free Docker Hub account and rerun setup. |

Time: setup about 15 minutes (mostly image downloads), full verification about 20 minutes. Cost: cents per hour. Do the last step when finished.

## Steps (run on the EC2 instance)

```bash
# 1. Get the code (Option A shown; for Option B just: cd devsecops-pipeline)
git clone https://github.com/<you>/devsecops-pipeline.git && cd devsecops-pipeline

# 2. Install Docker + Python scanners, pull the 7 scanner images (10-15 min)
./scripts/setup.sh

# 3. Unit tests for the demo app
.venv/bin/python -m unittest discover -s tests

# 4. Run the whole pipeline on the clean app (8-10 min). Ends with "PIPELINE PASSED"
./pipeline/run-all.sh

# 5. Negative test: plant flaws and prove every gate catches them (8-10 min)
./scripts/demo_insecure.sh      # ends with "All negative tests passed"

# (Steps 4 and 5 together, as one command:  ./scripts/verify.sh   -> "All checks passed.")

# 6. Look around
./pipeline/sast.sh              # run a single stage on its own
cat artifacts/results-clean.tsv # per-stage results (after verify.sh)
ls artifacts/                   # SBOM, Trivy report, ZAP HTML report

# 7. Clean up, then terminate the EC2 instance
./scripts/destroy.sh
```

## What you should see

- Step 4: ten stages (secrets, sast, sca, lint, policy, build, scan, sbom, sign, dast), all `PASS`, then `PIPELINE PASSED`.
- Step 5: the insecure copy FAILS secrets, sast, sca, lint, policy, scan and dast (`build` passes, it is just a build), then `ok` lines for each gate, an unsigned image being rejected, and the final success message.
- The failures in step 5 are the point: the "tests of the tests" prove the gates are not giving false confidence.

## If something goes wrong

| Symptom | Fix |
|---|---|
| `Could not pull <image>` / `manifest unknown` in step 2 | That image tag no longer exists. Override it, e.g. `ZAP_IMAGE=ghcr.io/zaproxy/zaproxy:stable ./scripts/setup.sh` (names are in `pipeline/lib.sh`: `TRIVY_IMAGE`, `ZAP_IMAGE`, ...). Use the same variable when you run the pipeline. |
| `permission denied` on docker | The scripts fall back to `sudo` for you. For manual docker commands use `sudo docker ...`, or log out and back in once. |
| `toomanyrequests` while pulling or in the `scan` stage | Docker Hub / ghcr rate limit. For images: `sudo docker login`. For the Trivy database: `export TRIVY_DB_REPOSITORY=public.ecr.aws/aquasecurity/trivy-db:2` and rerun. |
| `scan` fails on the CLEAN app | A new vulnerability was published after this project was written. This is the gate working. Rebuild with fresh packages: `sudo docker pull python:3.12-slim`, bump the pinned version named in the report in `app/requirements.txt`, rerun. |
| `sca` fails on the CLEAN app | Same idea: a dependency now has a known CVE. Bump that pin in `app/requirements.txt` (and keep `requirements-dev.txt` consistent). |
| `dast` stage fails to start the app | Check nothing else uses port 8080 (`sudo ss -ltnp \| grep 8080`) and that the `build` stage passed. |
| `sign` stage fails | Check the local registry is up: `curl http://localhost:5000/v2/` should answer. Rerun the stage: `./pipeline/sign.sh`. |
| Anything else | Copy the full output of the failing stage and send it to me. |
