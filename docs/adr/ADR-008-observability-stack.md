# ADR-008: Use Prometheus, Loki, Promtail, and Grafana for Observability Instead of ELK/EFK

**Status:** Accepted

## Context

The platform required an observability and compliance layer covering metrics (resource usage, alert counts from Falco/response engine), log aggregation (Falco alerts, response engine actions, admission decisions), unified dashboards, and compliance reporting (via kube-bench for CIS benchmarking and Polaris for configuration best practices).

Key requirements included:

- A resource footprint compatible with a single-node K3s cluster (Ubuntu 24, VMware VM) — this constraint dominated the evaluation
- Unified visualization across metrics and logs without maintaining two disjoint tools/query languages
- Native Kubernetes service discovery
- Active, current maintenance — the tooling choice needed to reflect where cloud-native observability is actually heading, not a legacy default carried over from traditional enterprise logging setups

---

## Options Considered

### Option 1 — ELK / EFK Stack (Elasticsearch, Logstash/Fluentd, Kibana)

**Pros**

- Industry-standard, powerful full-text search and indexing
- Mature, feature-rich Kibana UI
- Long track record in enterprise logging

**Cons**

- Elasticsearch's resource requirements (JVM heap sizing, indexing overhead) are disproportionate to a single-node lab cluster, even at modest log volume
- Managing even a single-node Elasticsearch instance adds real operational complexity (JVM tuning, index lifecycle management) for a one-engineer project
- A second, disjoint UI and query language (Kibana/KQL or Lucene) alongside Grafana/PromQL doubles the tooling surface to maintain and explain
- Elastic's licensing changes and the resulting OpenSearch fork have fragmented the ecosystem, making "ELK" a less stable long-term reference point than it once was

---

### Option 2 — Prometheus + Loki + Promtail + Grafana

**Pros**

- Loki indexes only metadata labels rather than full log text — the same philosophy as Prometheus for metrics — which keeps resource usage dramatically lower than Elasticsearch for this workload
- One UI (Grafana) and one label-based query paradigm (PromQL for metrics, LogQL for logs) across the whole observability layer, reducing operational and cognitive overhead
- Native Kubernetes service discovery integrates directly with the existing K3s setup
- Prometheus is a CNCF graduated project and Loki/Grafana are actively developed by Grafana Labs — this is the current, actively evolving standard in cloud-native observability, keeping the platform's tooling aligned with where the ecosystem (and the industry's hiring expectations) are actually moving, rather than defaulting to a legacy enterprise stack out of familiarity
- Falcosidekick already has native Prometheus output support, simplifying the alert-to-metrics pipeline

**Cons**

- LogQL is less powerful than Elasticsearch's full-text search for complex ad hoc log queries
- Loki's label-based model requires more upfront thought about label cardinality to remain efficient

---

### Option 3 — Commercial SaaS observability (e.g. Datadog)

**Pros**

- Fully managed, minimal operational effort
- Rich feature set out of the box

**Cons**

- Cost prohibitive for a self-funded student project
- Ships cluster data off-premises, at odds with a security-focused project's preference for self-hosted control over its own telemetry
- Reduces hands-on engineering depth, which matters for a project meant to demonstrate implementation skill

---

### Option 4 — `kubectl logs` / `metrics-server` only

**Pros**

- Zero additional infrastructure

**Cons**

- No aggregation, no retention, no dashboards
- Cannot satisfy compliance/audit reporting requirements (kube-bench, Polaris output still needs somewhere to land and be visualized)

---

## Decision

The platform uses **Prometheus** for metrics, **Loki** with **Promtail** for log aggregation, and **Grafana** as the unified dashboard layer, supplemented by **kube-bench** (CIS Kubernetes Benchmark) and **Polaris** (configuration best-practice scanning) for compliance reporting.

ELK/EFK was not adopted primarily due to Elasticsearch's resource footprint being disproportionate to a single-node cluster, and secondarily because a label-based Loki/Prometheus/Grafana stack keeps the platform aligned with the current, actively maintained direction of cloud-native observability tooling rather than a heavier legacy stack.

---

## Consequences

### Positive

- Substantially lower resource footprint fits the single-node constraint
- One dashboarding tool and one query paradigm across metrics and logs
- Tooling choice tracks with the current cloud-native ecosystem rather than legacy defaults

### Negative

- LogQL's query power is more limited than Elasticsearch full-text search for complex log investigation
- No persistent volumes are currently configured for Prometheus or Loki — data does not survive a pod restart, an already-documented gap acceptable for a lab/demo scope but not production-ready
- Grafana is a single instance and a single point of failure for visibility into the whole platform
- No long-term retention or backup strategy is currently implemented for metrics/logs

---

## References

- https://prometheus.io/docs/introduction/overview/
- https://grafana.com/docs/loki/latest/
- https://grafana.com/docs/grafana/latest/
- https://github.com/aquasecurity/kube-bench
- https://polaris.docs.fairwinds.com/
- https://www.elastic.co/guide/index.html
