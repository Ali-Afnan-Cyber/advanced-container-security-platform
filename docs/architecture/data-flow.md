# Data Flow

This document traces a single container image from commit to running workload, through every layer of the platform.

## End-to-End Flow

```text
Developer commit
│
▼
GitHub Actions workflow triggered
│
├─▶ Syft generates SBOM (SPDX/CycloneDX)
├─▶ Trivy scans image for known CVEs
│
▼
Cosign keyless signing
│   - OIDC token issued by GitHub Actions
│   - Short-lived certificate issued by Fulcio
│   - Image digest signed
│
▼
Image + SBOM + attestation pushed to registry
│
▼
Signature + provenance metadata recorded in Rekor
│   (public, append-only transparency log)
│
▼
SLSA Level 2 provenance attestation generated
│
▼
──────────────────── CI/CD Boundary ────────────────────
│
▼
Deployment manifest applied to K3s cluster
│
▼
Kyverno ClusterPolicies evaluate the request
│   - Pod Security Standards (Restricted)
│   - verifyImages signer annotation check
│   - Resource limits / capability checks
│
├─▶ FAIL → Request rejected (pod never created)
│
▼ PASS
Pod scheduled onto the node
│
▼
Falco eBPF probes attach to the running container
│   - Continuous syscall monitoring begins
│
▼
Custom Falco rules evaluate runtime behaviour
│
├─▶ No match → Activity logged to Loki
│
▼ Match (Security Event)
Falco alert sent to Flask Response Engine (HTTP)
│
▼
Response Engine decision
│   - Severity classification
│   - False-positive / kill trade-off
│
├─▶ Terminate pod
├─▶ Quarantine pod
└─▶ Log only (human review)
│
▼
Event + action recorded
│
├─▶ Loki
├─▶ Prometheus
│
▼
Grafana dashboards updated
│
▼
Isolation Forest consumes logs + metrics (read-only)
│
▼
Anomaly score generated for human review
(No enforcement action)
```

## Notes on the Flow

- **Build-time trust is established once, at signing.** Nothing after the Rekor entry re-verifies the cryptographic signature. Admission-time `verifyImages` checks a signer identity annotation, not the live signature chain. This is the largest trust discontinuity in the platform and is discussed further in `threat-model.md`.

- **Runtime detection is continuous.** Falco's eBPF probes attach when the pod starts and monitor the workload throughout its lifetime.

- **Response is immediate; observability is asynchronous.** Pod termination or quarantine happens immediately after an alert, while Prometheus scraping and dashboard updates occur on their normal collection intervals.

- **The intelligence layer is advisory only.** Isolation Forest reads existing logs and metrics. It never blocks deployments or runtime response actions.
