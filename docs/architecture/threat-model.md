# Threat Model

This document maps what each layer defends against, and states known gaps explicitly rather than leaving them implicit. Gaps here are documented deliberately — they reflect scoped trade-offs made for a single-node lab-grade platform, not oversights discovered after the fact.

---

## Layer 1: Supply Chain Security

**Defends against:**
- Tampered or unauthorized container images entering the deployment path.
- Images with known, unpatched vulnerabilities reaching production.
- Unverifiable build provenance (i.e. "where did this image actually come from").
- Long-lived signing key compromise (mitigated by keyless signing).

**Known gaps:**
- **SLSA Level 2, not Level 3.** The pipeline produces signed provenance from a hosted build service, satisfying SLSA L2. It does not implement the isolated/hermetic build environment or two-person-reviewed source requirements needed for L3 — a compromised CI runner could still influence a build without independent detection.
- **Single-scanner coverage.** Grype and Clair appear in platform design materials as candidates for a multi-scanner strategy, but only Trivy is implemented in the live pipeline. Any CVE that Trivy's database misses or is slow to add has no secondary scanner to catch it.

---

## Layer 2: Admission Control

**Defends against:**
- Privileged containers, host namespace access, disallowed Linux capabilities.
- Workloads violating Pod Security Standards (Restricted profile).
- Missing or excessive resource requests/limits.

**Known gaps:**
- **`verifyImages` is string-match, not cryptographic verification.** The Kyverno policy intended to gate deployment on a valid Cosign signature currently checks a signer identity string on an image annotation, rather than performing a live cryptographic verification against the Fulcio certificate chain and Rekor transparency log at admission time. In effect, real cryptographic trust is established once at build/sign time (Layer 1) and is not re-verified at the point of deployment — an image with a correctly-formatted but not genuinely valid signer annotation would not be caught by this check alone.

---

## Layer 3: Runtime Detection

**Defends against:**
- Interactive shells spawned in containers that shouldn't have one.
- Privilege escalation attempts inside a running container.
- Unexpected outbound network connections indicating C2 or exfiltration.
- Suspicious file writes to sensitive paths at runtime.

**Known gaps:**
- **Custom rule coverage is not exhaustive.** Rules target specific, anticipated attack patterns; behavior outside the ruleset's scope will not generate an alert.
- **Detection is bounded by syscall/tracepoint visibility.** Activity that never touches a monitored kernel interface is invisible to eBPF-based observation by design.
- **Single-node co-location risk.** Falco, the response engine, and monitored workloads all run on the same node. A kernel-level compromise below the eBPF hook layer could potentially blind or disable the detection layer itself, with no second node to fall back on.

---

## Layer 4: Automated Response

**Defends against:**
- Dwell time of an active threat — converts detection into action without waiting on human triage.
- Inconsistent or missed manual response during off-hours.

**Known gaps:**
- **False-positive/kill trade-off.** Any automated termination policy has to choose a point on the spectrum between "terminate aggressively, risk killing legitimate workloads on a false positive" and "terminate conservatively, risk longer dwell time for real threats." The current engine biases toward termination only on high-confidence, CRITICAL-tier rules, and quarantine (rather than termination) for lower-confidence matches — this is a tuned trade-off, not an eliminated one, and remains a live operational risk in either direction.

---

## Layer 5: Observability & Compliance

**Defends against:**
- Blind spots in what's happening across the cluster.
- Undetected configuration drift from security baselines.
- Lack of auditable evidence for compliance posture (CIS benchmarks, workload config hygiene).

**Known gaps:**
- **No persistent volumes for Loki or Prometheus.** Both run without PV-backed storage, meaning log and metric history is lost on pod restart or node reboot. There is no long-term retention or backup for this data on the current single-node setup.
- **No disaster recovery.** As a single-node cluster, there is no failover for the control plane, the workloads, or the observability stack itself. A node failure is a total platform outage with no automatic recovery path.

---

## Intelligence Layer: Isolation Forest (Scope Note, not a Defended Gap)

The Isolation Forest service is intelligence-only by design and has no enforcement authority in the response engine. This is a deliberate scope boundary rather than an unaddressed gap: false positives or false negatives from this layer do not result in an automated action, only a surfaced anomaly score for human review. Its absence of enforcement authority is the mitigation for the operational risk an autonomous ML-driven response would otherwise introduce.
