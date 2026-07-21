# 06. Observability Stack: Prometheus, Grafana, Loki, kube-bench, Polaris

## Context

A platform with five active security layers is only as trustworthy as its ability to show, after the fact, what happened and when. That requires metrics (is the platform healthy, how many events fired), logs (what exactly happened, with full context), and compliance evidence (is the cluster's configuration actually meeting a recognized standard, not just "probably fine"). These are three different kinds of data with different query needs, and the stack was chosen component-by-component around that split.

## Decision

- **Prometheus** for metrics  scraping cluster and platform component metrics endpoints, queried via PromQL.
- **Grafana** for visualization  a single dashboarding layer over both Prometheus (metrics) and Loki (logs).
- **Loki** for log aggregation  Falco alerts, response engine actions, and platform component logs, using label-based (not full-text) indexing.
- **kube-bench** for CIS Kubernetes Benchmark compliance scanning against the cluster configuration.
- **Polaris** for workload-level Kubernetes configuration best-practice validation (resource limits, security context, image tagging).

## Alternatives Considered

**Elasticsearch (ELK/EFK stack) instead of Loki.** The more traditional choice for Kubernetes log aggregation, with full-text indexing and a more mature query ecosystem. Rejected primarily on resource footprint  Elasticsearch's full-text indexing is materially heavier than Loki's label-based approach, and on a single-node cluster with a constrained resource budget, that difference is decisive. Loki's label-based model is a reasonable fit here specifically because logs are already well-structured (Falco JSON output, response engine action logs) rather than free-form text needing full-text search.

**Datadog or a commercial observability SaaS.** Would reduce operational burden (no self-hosted stack to maintain) and offer more mature correlation/alerting out of the box. Rejected to keep the platform fully self-hosted and open-source, consistent with the rest of the toolchain, and to avoid a recurring cost and an external data dependency for what is a lab-grade, single-operator platform.

**OPA Gatekeeper's built-in audit results (as a substitute for Polaris).** Gatekeeper does produce its own audit/compliance reporting, but this was a moot alternative once Kyverno was chosen over Gatekeeper (`02-admission-control-kyverno.md`)  Polaris was chosen instead specifically because it's tool-agnostic and evaluates workload configuration hygiene independent of whichever admission controller is in place, rather than being tied to one.

**Skipping kube-bench or Polaris entirely, relying on Kyverno policy alone for compliance evidence.** Rejected because Kyverno policies describe what's *enforced going forward*; they don't produce point-in-time evidence against a named external standard (the CIS Benchmark) the way kube-bench does, nor do they check workload manifest hygiene the way Polaris does. Compliance evidence needs to be independently verifiable against a recognized standard, not just "the policy exists."

## Trade-offs

**Gained:**
- A single dashboarding pane (Grafana) over both metrics and logs, rather than a separate tool per data source.
- Lower resource footprint appropriate to a single-node cluster (Loki vs. Elasticsearch).
- Compliance evidence at two levels  cluster-wide (kube-bench/CIS) and per-workload (Polaris)  rather than one blended, less specific check.
- Fully self-hosted and open-source, with no external SaaS dependency or recurring cost.

**Given up:**
- **No persistent volumes are currently attached to Loki or Prometheus.** Both run without PV-backed storage, so log and metric history is lost on pod restart or node reboot. There is no long-term retention on the current single-node setup  this is the most significant gap in this layer (see `threat-model.md`) and the most straightforward one to close in a future iteration.
- **Loki's label-based indexing trades away full-text search flexibility.** Ad hoc, unanticipated log queries that don't align with existing labels are harder to run than they would be in Elasticsearch  a deliberate trade against the resource savings.
- **No SIEM-grade correlation across sources.** Grafana/Loki/Prometheus give strong visualization and basic alerting, but don't provide the kind of multi-source event correlation a dedicated SIEM would  out of scope for this platform's current size (see `overview.md`).
