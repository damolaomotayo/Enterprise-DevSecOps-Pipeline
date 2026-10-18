# Enterprise DevSecOps Pipeline

A security-gated delivery pipeline: every change is scanned for secrets, insecure code, vulnerable dependencies, insecure Dockerfiles and Kubernetes manifests, vulnerable container images and runtime weaknesses, then gets an SBOM and a cryptographic signature. A deliberately **insecure copy of the app is generated and run through the same pipeline to prove every gate really blocks it**.

> Start with [STEPS.md](STEPS.md): prerequisites first, then copy-paste commands.

```
 commit
   │  BEFORE the image exists (fast, cheap)                       AFTER the image exists
   ▼ ───────────────────────────────────────────────────────  ─────────────────────────────────────────────────▶
 secrets ─▶ SAST ─▶ SCA ─▶ Dockerfile ─▶ K8s policy ─▶ build ─▶ image scan ─▶ SBOM ─▶ sign ─▶ DAST ─▶ (deploy)
 gitleaks   bandit  pip-    hadolint     conftest/OPA   docker   trivy       trivy    cosign   OWASP
                    audit                                                    (cyclonedx)         ZAP
```

Fail-fast: the first failing gate stops the pipeline, so nothing after it can ship.

## The gates

| Stage | Tool | What it catches | Fails when |
|---|---|---|---|
| secrets | gitleaks | Passwords, API keys, tokens in files **and git history** | any secret is found |
| sast | bandit | Dangerous code: shell injection, `eval`, unsafe YAML, weak hashes | medium severity or higher |
| sca | pip-audit | Dependencies with known CVEs | any known vulnerability |
| lint | hadolint | Root user, `ADD` vs `COPY`, unpinned images, no pip cache flag | any warning or error |
| policy | conftest + OPA (Rego) | Kubernetes manifests that are privileged, run as root, lack limits, use `:latest`... | any `deny` rule |
| build | docker | Builds the image | build error |
| scan | Trivy | OS and Python vulnerabilities inside the image | fixable HIGH or CRITICAL |
| sbom | Trivy (CycloneDX) | Produces a bill of materials of everything in the image | SBOM empty or invalid |
| sign | cosign + local registry | Signs the image digest, then verifies the signature | signing or verification fails |
| dast | OWASP ZAP baseline | Runs the app and attacks it: missing CSP, clickjacking and MIME-sniffing protections | a required header is missing (`dast/zap-rules.conf`) |

## The negative test (the part most pipelines skip)

`scripts/demo_insecure.sh` generates a copy of the app with six planted flaws (hard-coded secrets, dangerous code, vulnerable dependencies, root Dockerfile, privileged Kubernetes pod, no security headers), runs the pipeline on it, and **asserts that every gate fails**. It also checks that an unsigned image is rejected. The fake secrets are assembled at run time, so this repo never contains anything that looks like a real credential.

## How it runs

The same scripts run in three places, so there is no "works on CI only" gap:

- On your EC2 instance: `./pipeline/run-all.sh`
- In GitHub Actions: `.github/workflows/devsecops.yml` (least-privilege token, full git history for secret scanning, reports uploaded as artifacts)
- Single stage: `./pipeline/sast.sh`, `./pipeline/policy.sh`, ...

Tools run as pinned container versions (`pipeline/lib.sh`), so results are reproducible and nothing needs installing beyond Docker. `.github/dependabot.yml` opens update PRs for Python packages, the base image and Actions.

## Repo layout

```
app/          Hardened Flask service (security headers, input validation, non-root image)
k8s/          Hardened Deployment + Service
policy/       kubernetes.rego: the Kubernetes rules (policy as code)
dast/         zap-rules.conf: which ZAP findings fail the build
pipeline/     one script per stage, lib.sh (versions + helpers), run-all.sh
scripts/      setup, verify, demo_insecure, make_insecure, destroy
tests/        unit tests for the app
.gitleaks.toml  secret-scanner config
```

## Key ideas to be able to explain

- **Shift left:** find problems at the cheapest point. A leaked key found at commit time costs minutes; found in production it costs an incident.
- **SAST vs SCA vs DAST:** SAST reads *your* code, SCA checks *other people's* code you depend on, DAST attacks the *running* app.
- **Secrets live in git history:** deleting a leaked key from a file does not remove it from old commits, so history is scanned too, and the key must be rotated.
- **Policy as code:** security rules written in Rego are versioned, reviewed, tested and enforced automatically, instead of living in a wiki.
- **SBOM:** when the next Log4Shell lands, you search your SBOMs instead of guessing.
- **Signing and verification:** signing proves *who built* an image and that it was *not modified*. A cluster admission policy can then refuse unsigned images (supply-chain security, SLSA).
- **Testing the gates:** a scanner that never fails proves nothing. The negative test shows each gate can say no.
- **Fail-fast and least privilege:** stop at the first failing gate; give the CI token only `contents: read`.

## Limitations (kept simple on purpose)

- Signing uses a local key pair and local registry. Production: keyless signing with GitHub OIDC (Sigstore) or a cloud KMS key, pushing to ECR/GHCR.
- There is no cluster in this project. Manifests are checked by policy; see the `progressive-delivery-gitops` project for deployment, and combine them by adding signature verification (e.g. Kyverno or Sigstore policy-controller) at admission.
- DAST is a baseline scan of a tiny app. Real systems add authenticated scans and API fuzzing.
- Findings are not uploaded to GitHub code scanning because that needs GitHub Advanced Security on private repos. Reports are saved as workflow artifacts instead.
- Gates are strict on purpose (any CVE in your pinned dependencies fails). Real teams add a time-boxed exception process for findings they accept.
