# Known Limitations

This document is the single, consolidated list of the platform's known gaps  the same gaps defended directly in the EduQual Level 6 oral examination, gathered here in one place rather than left scattered across the architecture and design-decision documents that first introduced them. Nothing here is a newly discovered defect; each item was a known trade-off at the time the corresponding decision was made.

This document intentionally states gaps first, plainly, before any mitigating context  that ordering is deliberate, consistent with this platform's answer framework of stating the honest reality before the trade-off reasoning behind it.

## 1. Admission-Time Signature Verification Is String-Match, Not Cryptographic

**The gap:** Kyverno's `verifyImages` rule checks a signer identity annotation on the image, not a live cryptographic verification against the Fulcio certificate chain and Rekor transparency log at the moment of admission.

**Why it matters:** Real cryptographic trust is established once, at build/sign time. It is not re-verified at deployment. An image with a correctly-formatted but not genuinely valid signer annotation would not be caught by this check alone.

**Where it's fully addressed:** `../design-decisions/01-image-signing-cosign-keyless.md`, `../design-decisions/02-admission-control-kyverno.md`, `../architecture/threat-model.md`.

## 2. Grype and Clair Appear in Design Materials but Are Not Implemented

**The gap:** Early design materials reference a multi-scanner strategy including Grype and Clair alongside Trivy. The live CI pipeline implements Trivy only.

**Why it matters:** Any CVE that Trivy's database misses or is slow to add has no secondary scanner to catch it. Single-scanner coverage is a narrower net than the multi-scanner strategy originally sketched.

**Where it's fully addressed:** `../design-decisions/06-observability-stack.md` references the same single-scanner pattern context; the primary discussion is in `../architecture/threat-model.md` (Layer 1).

## 3. SLSA Level 2, Not Level 3

**The gap:** The pipeline produces signed provenance from a hosted build (GitHub Actions), satisfying SLSA Level 2. It does not implement the isolated/hermetic build environment or two-person-reviewed source requirements needed for Level 3.

**Why it matters:** A compromised CI runner could still influence a build without independent detection  the provenance is trustworthy about *what* was signed, less so about guaranteeing the build environment itself wasn't tampered with.

**Where it's fully addressed:** `../design-decisions/01-image-signing-cosign-keyless.md`, `../architecture/threat-model.md`.

## 4. The False-Positive/Kill Trade-off in Automated Response

**The gap:** Any automated termination policy sits somewhere on a spectrum between "terminate aggressively, risk killing legitimate workloads on a false positive" and "terminate conservatively, risk longer dwell time for real threats." The response engine biases toward termination only on high-confidence CRITICAL-tier rules, with quarantine for lower-confidence matches.

**Why it matters:** This is a tuned trade-off, not an eliminated one. It remains a live operational risk in both directions  a legitimate workload could still be misclassified as CRITICAL, and a genuinely dangerous but lower-confidence event could sit in "quarantine" or "log only" longer than ideal.

**Where it's fully addressed:** `../design-decisions/04-response-engine-custom-flask.md`, `../architecture/runtime.md`, `../architecture/threat-model.md`.

## 5. No Persistent Volumes for Loki or Prometheus

**The gap:** Both run on ephemeral pod-local storage. A pod restart or node reboot loses all accumulated metrics and log history, including Falco alert history and response engine action records.

**Why it matters:** The platform's own audit trail  what it detected and what it did about it  is exactly as ephemeral as everything else running on the node.

**Where it's fully addressed:** `../design-decisions/06-observability-stack.md`, `../production/backup-recovery.md`.

## 6. No Disaster Recovery

**The gap:** As a single-node cluster, there is no control-plane failover, no worker-node failover, and (per item 5) no data backup underneath the observability stack.

**Why it matters:** A node failure is a total platform outage with no automatic recovery path, and  combined with the persistence gap  a loss of operational history that recovery can't restore because there was nothing to restore from.

**Where it's fully addressed:** `../design-decisions/07-single-node-k3s-tradeoffs.md`, `../production/high-availability.md`, `../production/backup-recovery.md`.

## 7. Single-Node Co-location of Trust Zones

**The gap:** The runtime/node trust boundary and the cluster boundary are the same boundary, because everything runs on one host. There is no separation between, for example, a compromised workload and the node's kernel-level integrity the way there would be across separate nodes.

**Why it matters:** A kernel-level compromise beneath Falco's eBPF hook points could blind the detection layer itself, with no second node providing redundant coverage.

**Where it's fully addressed:** `../architecture/trust-boundaries.md`, `../design-decisions/03-runtime-detection-falco-ebpf.md`, `../design-decisions/07-single-node-k3s-tradeoffs.md`.

## 8. No Alert Routing on Top of the Observability Stack

**The gap:** Prometheus, Grafana, and Loki collect and visualize data, but there is no Alertmanager (or equivalent) routing critical signals to a human via Slack, paging, or similar.

**Why it matters:** A critical event is only seen by someone actively looking at a dashboard. There is currently no push notification path from detection to a person.

**Where it's fully addressed:** `../production/monitoring-alerting.md`.

## 9. Secrets Handled via Native Kubernetes Secrets Only

**The gap:** Aside from Cosign's keyless signing (which avoids long-lived key material entirely), all other credentials rely on unencrypted-at-rest-by-default Kubernetes Secrets, with no rotation policy and no centralized secrets audit trail.

**Why it matters:** A leaked credential remains valid indefinitely until manually rotated, and there's no dedicated audit layer distinguishing legitimate secret access from anomalous access.

**Where it's fully addressed:** `../production/secrets-management.md`.

## Summary Table

| # | Gap | Layer/Area | Status |
|---|---|---|---|
| 1 | `verifyImages` is string-match, not cryptographic | Admission control | Known, documented, unresolved |
| 2 | Grype/Clair not implemented | Supply chain | Known, documented, unresolved |
| 3 | SLSA L2, not L3 | Supply chain | Known, documented, unresolved |
| 4 | False-positive/kill trade-off | Automated response | Tuned, inherently ongoing |
| 5 | No PV persistence (Loki/Prometheus) | Observability | Known, documented, unresolved |
| 6 | No disaster recovery | Platform-wide | Known, documented, unresolved |
| 7 | Single-node trust zone co-location | Trust architecture | Known, documented, unresolved |
| 8 | No alert routing | Observability | Known, documented, unresolved |
| 9 | Secrets not rotated/audited | Secrets management | Known, documented, unresolved |

Every item in this list has a defensible reason for existing in the current iteration  see `scope-exclusions.md` for what was deliberately left out of scope entirely, and `assumptions.md` for what the platform assumes to be true rather than verifies.
