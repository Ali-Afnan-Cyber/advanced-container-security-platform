# Trust Boundaries

This document identifies the distinct trust zones in the platform, what crosses each boundary, and what is implicitly trusted within each zone.

## Zone 1: Supply Chain (External to the Cluster)

**Scope:** GitHub Actions, the container registry, Fulcio, Rekor.

**Trust basis:** Identity is rooted in the GitHub Actions OIDC token issued to a specific workflow run. Fulcio issues a short-lived signing certificate bound to that identity; Cosign uses it to sign the image; Rekor records the event publicly and immutably.

**What crosses this boundary:** A signed image reference, its SBOM, and its provenance attestation — pushed to the registry and made available for deployment.

**Implicit trust within this zone:** The GitHub Actions runner environment itself is trusted to have built the image faithfully from source — this is the SLSA L2 vs L3 gap noted in `threat-model.md`. Trust in the pipeline is trust in GitHub's runner isolation, not in a hermetic build the platform controls independently.

---

## Zone 2: Admission Boundary

**Scope:** The K3s API server and Kyverno's admission webhook.

**Trust basis:** Any manifest submitted to the API server is treated as untrusted until it passes Kyverno ClusterPolicies and Pod Security Standards checks.

**What crosses this boundary:** A workload manifest, evaluated once, at submission time, and never re-evaluated for the life of the pod.

**Implicit trust within this zone:** Once a pod passes admission, nothing in this layer re-checks it. Trust established at admission is not continuously re-verified — this is why Layer 3 (runtime detection) exists as an independent, non-overlapping control rather than a redundant one.

---

## Zone 3: Runtime / Node Boundary

**Scope:** The single K3s node — kernel, container runtime, all running pods, Falco's eBPF probes.

**Trust basis:** Falco observes syscall-level behavior continuously and treats deviation from expected patterns (as defined by its rule set) as untrusted.

**What crosses this boundary:** Nothing is expected to "cross" this zone in normal operation — this boundary is about what's observable *within* it. The important property is that this is also the **cluster boundary**, because the platform is single-node: compute, control plane, and storage are co-located. There is no separate control-plane trust zone isolated from the workload trust zone the way there would be in a multi-node cluster.

**Implicit trust within this zone:** The kernel and the eBPF subsystem itself are trusted. If either is compromised beneath the hook points Falco relies on, this entire trust zone's guarantees are void — noted in `threat-model.md` as a co-location risk specific to the single-node design.

---

## Zone 4: Response & Observability Boundary

**Scope:** The Flask response engine, Prometheus, Grafana, Loki, kube-bench, Polaris.

**Trust basis:** These components hold elevated Kubernetes API permissions (the response engine can terminate/quarantine pods; the observability stack can read cluster-wide metrics and logs) and are themselves a trust boundary by virtue of that access — a compromise of the response engine would be a compromise of the platform's own enforcement mechanism.

**What crosses this boundary:** Falco alerts (in), Kubernetes API calls (out, from the response engine), and metrics/log data (out, to Prometheus/Loki, read-only from the rest of the cluster's perspective).

**Implicit trust within this zone:** The response engine's service account is scoped to the specific actions it needs (pod termination, labeling, network policy application) rather than cluster-admin, limiting blast radius if this component were itself compromised. This scoping is the primary mitigation for the risk this zone represents.

---

## Zone 5: Intelligence Layer (Isolation Forest)

**Scope:** The ML anomaly detection service.

**Trust basis:** Explicitly untrusted for enforcement — this zone can read from the observability data but has no write/action path back into the cluster.

**What crosses this boundary:** Metrics and log data flow in (read-only); an anomaly score/flag flows out, to a human reviewer, not to any automated actor.

**Implicit trust within this zone:** None extended beyond read access. This is a deliberate one-way boundary — the platform does not trust this layer's output enough to let it act autonomously, which is the entire rationale for keeping it advisory-only.
