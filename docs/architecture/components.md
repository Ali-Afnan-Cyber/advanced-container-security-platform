# Components

Each component below is documented with its purpose in the platform, the technology chosen, and why it was chosen over alternatives.

---

## Kyverno

**Purpose:** Admission control — the gatekeeper between a submitted workload manifest and a running pod. Enforces policy-as-code before scheduling.

**Technology:** Kyverno ClusterPolicies combined with Kubernetes Pod Security Standards, Restricted profile.

**Why chosen:** Kyverno policies are written as native Kubernetes YAML rather than a separate policy language (unlike OPA/Gatekeeper's Rego), which lowers the barrier for policy review and audit. PSS Restricted is layered on top as a baseline so that even in the absence of a custom Kyverno policy, the strictest built-in pod security profile still applies.

**Integration notes:** Enforces resource limits, disallows privileged containers and host namespace access, and includes a `verifyImages` rule intended to gate on image signature. This rule currently performs string-match validation rather than live cryptographic verification — see `threat-model.md`.

---

## Falco

**Purpose:** Runtime threat detection — observes live syscall activity inside containers and the host to catch behavior that admission-time controls cannot: something that only becomes malicious once a process is running.

**Technology:** Falco 0.43.1, using the modern eBPF driver, with a custom rule set layered on top of Falco's default rule library.

**Why chosen:** The modern eBPF driver avoids the kernel-module compatibility issues of Falco's older kernel-module driver and has a lower operational footprint than the legacy eBPF probe. Custom rules were written to target the platform's specific threat scenarios (e.g. shell spawned in a container that shouldn't have one, unexpected outbound connections) rather than relying solely on Falco's generic default ruleset.

---

## Cosign + Rekor

**Purpose:** Supply chain integrity — Cosign signs container images at build time; Rekor provides a public, append-only transparency log recording that a signature was issued.

**Technology:** Cosign keyless signing (Sigstore), backed by Fulcio for short-lived certificate issuance via OIDC identity, with signature and provenance metadata recorded to Rekor.

**Why chosen:** Keyless signing avoids the operational burden and risk of long-lived private key management. Identity is tied to the CI/CD OIDC token (GitHub Actions), so a signature is cryptographically bound to the specific workflow run that produced it rather than to a static secret that could leak or be reused.

---

## Trivy + Syft

**Purpose:** Vulnerability scanning (Trivy) and Software Bill of Materials generation (Syft), both run in the CI pipeline before an image is signed.

**Technology:** Trivy for CVE/vulnerability scanning; Syft for SBOM generation (SPDX/CycloneDX format).

**Why chosen:** Trivy was selected as the single scanner integrated into the pipeline for its speed and broad coverage of OS packages and language dependencies in one tool. Note: Grype and Clair are referenced in design materials as candidates for a multi-scanner strategy but are not implemented in the current pipeline — see `threat-model.md`.

---

## GitHub Actions

**Purpose:** CI/CD orchestration — drives the build → scan → sign → attest → push sequence on every commit.

**Technology:** GitHub Actions workflows, using OIDC token issuance for keyless Cosign signing.

**Why chosen:** Native OIDC support removes the need to store Cosign private key material as a repository secret, and keeps the build identity auditable directly against the workflow run.

---

## Flask Response Engine

**Purpose:** Automated response — receives runtime detection events from Falco and executes a response action (pod termination or quarantine) without waiting for manual triage.

**Technology:** Custom Python service built on Flask, receiving Falco alert output over HTTP and calling the Kubernetes API to act.

**Why chosen:** A custom engine was built rather than relying on Falco Talon or a similar off-the-shelf responder, in order to implement a tunable decision layer between "alert fired" and "action taken" — specifically to manage the false-positive/kill trade-off explicitly rather than accept a fixed default policy. See `runtime.md` for the decision flow.

---

## Isolation Forest (ML Anomaly Detection)

**Purpose:** Intelligence-only anomaly detection layer. Surfaces statistically unusual behavior across metrics/log data that rule-based detection (Falco) might miss, without acting on it.

**Technology:** Isolation Forest, an unsupervised anomaly detection algorithm well-suited to high-dimensional data without labeled training examples.

**Why chosen:** Isolation Forest doesn't require a labeled attack dataset, which isn't available for this platform, and scales well to the metrics/log volume produced by a small cluster. It was deliberately scoped as advisory-only — it has no enforcement authority in the response engine — to avoid the operational risk of an unsupervised model autonomously terminating workloads on a false positive.

---

## Prometheus

**Purpose:** Metrics collection across the cluster and platform components.

**Technology:** Prometheus, scraping metrics endpoints from cluster components and platform services.

**Why chosen:** De facto standard for Kubernetes metrics, with a query language (PromQL) and alerting model that integrates directly with Grafana.

---

## Grafana

**Purpose:** Visualization layer — dashboards for cluster health, security events, and compliance posture.

**Technology:** Grafana, sourcing from Prometheus (metrics) and Loki (logs).

**Why chosen:** Single pane of glass across both metrics and logs, avoiding a separate visualization tool per data source.

---

## Loki

**Purpose:** Log aggregation for Falco events, response engine actions, and platform component logs.

**Technology:** Grafana Loki, using label-based indexing rather than full-text indexing.

**Why chosen:** Lower resource footprint than a full-text log store (e.g. Elasticsearch), appropriate for a single-node cluster's resource budget, and integrates natively with Grafana. Note: no persistent volume is currently attached to Loki — see `threat-model.md` for the retention gap this creates.

---

## kube-bench

**Purpose:** CIS Kubernetes Benchmark compliance scanning against the cluster configuration.

**Technology:** Aqua Security's kube-bench, run as a scheduled job.

**Why chosen:** Standard, widely recognized benchmark tooling that produces auditable pass/fail evidence against a named industry standard rather than a custom checklist.

---

## Polaris

**Purpose:** Kubernetes configuration best-practice validation (resource limits, security context, health checks, image tagging practices) across deployed workloads.

**Technology:** Fairwinds Polaris.

**Why chosen:** Complements kube-bench (cluster-level CIS compliance) with workload-level configuration hygiene, giving compliance evidence at both the cluster and the manifest level.
