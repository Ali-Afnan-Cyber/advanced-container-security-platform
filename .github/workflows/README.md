# Container Supply Chain Security Pipeline

## Purpose

This GitHub Actions workflow implements automated supply chain security for the containerized Flask application. It builds, scans, signs, and attests a container image on every push or pull request to `main`, producing a verifiable chain of custody from source code to registry.

This document covers the CI/CD pipeline itself (`.github/workflows/pipeline.yml`). Application-level documentation (Flask app, Dockerfile, API, health endpoint) lives in `app/README.md`.

---

## Pipeline Architecture

Checkout → Build Image → Vulnerability Scan → Push Image → Sign (Cosign/OIDC) → Generate SBOM → Generate Provenanc → Attest SBOM + Provenance → Verify Signature (Rekor)

The pipeline runs on `ubuntu-latest` as a single job (`supply-chain-security`) with `id-token: write` permission, enabling keyless signing via GitHub's OIDC identity provider — no long-lived signing keys are stored as secrets.

---

## Workflow Triggers

The pipeline runs on:

- `push` to `main`
- `pull_request` targeting `main`

Both triggers are scoped to changes under `app/**` or the workflow file itself (`.github/workflows/pipeline.yml`), so unrelated commits don't trigger a rebuild.

---

## Pipeline Stages

| Stage | Purpose |
|---|---|
| Checkout | Retrieves repository source code |
| Set Image Name | Builds a deterministic, lowercase image tag from the Docker Hub username and commit SHA |
| Install Cosign / Syft | Installs signing and SBOM tooling |
| Docker Buildx Setup | Configures the build backend |
| Docker Hub Login | Authenticates to the registry |
| Build Docker Image | Builds the image locally (`load: true`, `push: false`) without cache |
| Inspect Built Image | Dumps image metadata for the build log |
| Check Base OS | Reads `/etc/os-release` from the built image |
| Trivy Scan (blocking) | Fails the build on fixable CRITICAL vulnerabilities |
| Trivy JSON Report | Produces a full, non-blocking vulnerability report as a build artifact |
| Push Image | Pushes the image tagged with both the commit SHA and `latest` |
| Set Full Image Reference | Resolves the immutable digest from the push step |
| Cosign Sign (Keyless) | Signs the image digest using GitHub OIDC |
| Generate SBOM | Produces an SPDX SBOM with Syft |
| Attach SBOM Attestation | Signs and attaches the SBOM to the image via Cosign |
| Generate Provenance Predicate | Builds a SLSA-style provenance document from workflow metadata |
| Attach Provenance Attestation | Signs and attaches the provenance predicate via Cosign |
| Upload SBOM / Provenance | Stores both as workflow artifacts |
| Verify Signature | Confirms the signature against the expected OIDC issuer and workflow identity |

---

## Security Controls

- **Keyless signing** — Cosign signs the image using the GitHub Actions OIDC token (`sigstore/cosign-installer`), so there is no private key to leak or rotate.
- **Immutable references** — All post-push operations (signing, SBOM attestation, provenance attestation, verification) act on the resolved image **digest**, not the mutable tag.
- **Least-privilege permissions** — The job only requests `contents: read`, `packages: write`, and `id-token: write`.
- **Signature verification gate** — The final step verifies the signature against a `certificate-identity-regexp` scoped to this repository's workflows and the expected OIDC issuer (`token.actions.githubusercontent.com`), rejecting signatures from any other source.
- **Transparency log** — Because signing is keyless, Cosign publishes the signature to the public Rekor transparency log by default, giving an auditable, tamper-evident record independent of the registry.

---

## Trivy Vulnerability Policy

The pipeline runs Trivy twice with different intents:

1. **Blocking scan** — `severity: CRITICAL`, `exit-code: 1`, `vuln-type: os,library`, `ignore-unfixed: true`. This fails the build only on CRITICAL vulnerabilities that have an available fix.
2. **Reporting scan** — full JSON report, `exit-code: 0`, uploaded as a build artifact regardless of outcome, so unfixed/lower-severity findings remain visible for review without blocking delivery.

---

## Why `ignore-unfixed` Was Enabled

**Background:** During implementation, Trivy consistently flagged three CRITICAL vulnerabilities in the Debian `perl-base` package inherited from the base image. These originated from the OS layer, not the application — the application's own dependencies scanned clean.

**Problem:** No patched version of the affected Debian packages was available upstream at the time. Every build failed, but there was nothing a developer could fix to resolve it — the pipeline was blocking delivery without improving the actual security posture.

**Decision:** Enable `ignore-unfixed: true`. This does **not** disable scanning. It changes the policy to:

- Block the build on any CRITICAL vulnerability that **has** a fix available.
- Continue detecting and reporting CRITICAL vulnerabilities with **no** fix available, without blocking the build.

**Impact:** Trivy still scans every OS package and application dependency on every run. The pipeline still fails on anything the team could actually remediate. It only stops failing on vulnerabilities that are, by definition, unpatchable at build time — those remain visible in the uploaded JSON report for ongoing tracking.

---

## Supply Chain Security Features

- **SBOM (SPDX)** — Generated with Syft against the pushed image digest, giving a complete software bill of materials.
- **SBOM Attestation** — The SBOM is attached to the image as a signed, verifiable attestation via `cosign attest --type spdxjson`.
- **Provenance (SLSA-style)** — A provenance predicate is generated at build time, capturing build type, builder identity, source commit, workflow entry point, and run metadata.
- **Provenance Attestation** — Signed and attached via `cosign attest --type slsaprovenance`.
- **Rekor transparency log** — All Cosign signing operations are recorded publicly and immutably, independent of the container registry.

> **Known gap:** the provenance predicate is hand-built from workflow context rather than generated by a dedicated SLSA provenance generator, and materials/completeness fields are self-reported rather than independently verified. This corresponds to SLSA Level 2 (signed provenance from a hosted build service), not Level 3 (isolated, non-forgeable provenance).

---

## Generated Security Artifacts

Each run produces the following, uploaded as GitHub Actions artifacts:

| Artifact | Contents |
|---|---|
| `trivy-report` | Full Trivy JSON vulnerability scan |
| `sbom` | SPDX-format SBOM (`sbom.json`) |
| `provenance` | SLSA-style provenance predicate (`provenance.json`) |

---

## Future Improvements

- Replace the hand-built provenance predicate with a dedicated SLSA provenance generator to move toward SLSA Level 3.
- Add a scheduled (non-push-triggered) scan to catch newly disclosed CVEs in already-published images.
- Persist Trivy JSON reports outside of workflow artifacts (e.g. to a central dashboard) for trend tracking rather than per-run snapshots.
- Re-evaluate `ignore-unfixed` periodically — it should be revisited whenever the base image is updated, not left permanent.
