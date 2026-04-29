# Demo Application

Hardened Flask application used to demonstrate the supply chain pipeline.

## Security Properties

- Multi-stage Docker build (builder + runtime)
- Base image: python:3.12-slim (actively patched)
- Non-root user: appuser (no shell, no login)
- Zero CRITICAL CVEs confirmed by Trivy
- Signed with Cosign keyless (Rekor transparency log)
- SBOM attached as cosign attestation (SPDX JSON)
- SLSA L2 provenance attached as cosign attestation

## Endpoints

| Endpoint | Description |
|----------|-------------|
| GET / | Platform info |
| GET /health | Health check |

## Run Locally

```bash
pip install -r app/requirements.txt
python app/app.py
```

## Build

```bash
docker build -t secure-app:local .
docker run -p 5000:5000 secure-app:local
```

## Pipeline Stages
GitHub commit
↓
Build image (multi-stage, non-root)
↓
Trivy scan — FAIL on CRITICAL CVE
↓
Push to DockerHub
↓
Cosign keyless sign → Rekor
↓
Syft SBOM → cosign attest
↓
SLSA provenance → cosign attest
↓
Cosign verify → confirm Rekor entry
