# High Availability

This document lists the platform's current single points of failure (SPOFs) and what would be required to remove each one. As established in `../design-decisions/07-single-node-k3s-tradeoffs.md`, the platform was deliberately built without HA in its current iteration; this document is the concrete follow-on to that decision  what closing the gap would actually involve.

## Current Single Points of Failure

| SPOF | Impact if it fails |
|---|---|
| The single K3s node itself | Total platform outage. Control plane, all five security layers, and the intelligence layer all go down simultaneously  there is nothing left running. |
| K3s control plane (co-located, no quorum) | Same as above  on a single node, the control plane has no separate failure domain from the workloads it schedules. |
| Kyverno admission webhook (single pod) | If the pod is down, admission control behavior depends on the webhook's configured failure policy  either the cluster fails closed (no new workloads can be scheduled at all) or fails open (admission control is silently bypassed until the pod recovers). Neither is acceptable in production without a second replica. |
| Flask response engine (single pod) | Falco alerts have nowhere to go for automated action. Detection (Falco) keeps working, but the platform reverts to alert-only during the outage  the exact dwell-time risk automation was built to close (see `../design-decisions/04-response-engine-custom-flask.md`). |
| Prometheus (single instance) | Metrics collection stops entirely during the outage; the gap in the time series is permanent once the instance recovers, since there is no redundant scraper to have covered the gap. |
| Grafana (single instance) | Dashboards become unavailable; underlying data in Prometheus/Loki is unaffected, but visibility into the platform's live state is lost until the instance is back. |
| Loki (single instance) | New logs  including Falco alerts and response engine action records  are not durably captured during the outage. Combined with the lack of persistent storage (see `backup-recovery.md`), any logs generated during this window may be unrecoverable even after Loki comes back. |

## What HA Would Require

**Control plane:**
- Move to a 3-node (minimum) or 5-node K3s/Kubernetes control-plane topology, so etcd retains quorum and can tolerate the loss of one node without losing write availability.
- Separate control-plane nodes from worker nodes where possible, so a workload-level failure (e.g. a runaway pod) can't starve control-plane resources.

**Admission control (Kyverno):**
- Run at least two replicas of the Kyverno admission webhook, with a `PodDisruptionBudget` ensuring at least one is always available during rolling updates or node maintenance.
- Explicitly define and test the webhook's failure policy (`Fail` vs. `Ignore`) so behavior during a full webhook outage is a deliberate choice, not a default.

**Response engine:**
- Run multiple stateless replicas behind a Kubernetes Service.
- Because multiple replicas could theoretically receive the same Falco alert (e.g. if Falco's HTTP output fans out, or during a retry), the engine would need idempotent action handling  e.g. checking pod state before acting, or a distributed lock  so two replicas can't issue conflicting actions (one terminating, one quarantining) against the same pod.

**Observability stack:**
- **Prometheus:** run HA pairs (two independently scraping instances) or move to a remote-write architecture (Thanos, Cortex, or Mimir) for both redundancy and long-term storage, decoupling retention from any single instance's local disk.
- **Loki:** move from single-binary mode to distributed mode with a replication factor, so log ingestion survives the loss of one ingester.
- **Grafana:** run stateless replicas behind a load balancer, backed by a shared external database (rather than local SQLite) for dashboards and configuration.

**General:**
- Node anti-affinity rules for every critical component's replicas, so a single node failure cannot take down every replica of the same component at once.
- A load balancer or ingress layer that itself has more than one instance, so it isn't a new SPOF introduced by solving the others.

## What This Does Not Cover

HA addresses **availability**  the platform staying up through a component or node failure. It does not by itself address **data durability**  whether logs and metrics generated before or during a failure are recoverable. That is covered separately in `backup-recovery.md`, since a highly available system can still permanently lose data if it has no persistent storage or backup strategy underneath it.

## Relationship to Other Documents

- `../design-decisions/07-single-node-k3s-tradeoffs.md`  the original rationale for accepting these SPOFs in this iteration of the platform.
- `scaling.md`  many of the same architectural changes (multiple replicas, distributed observability components) serve both HA and scaling goals simultaneously.
- `backup-recovery.md`  data durability, which HA alone does not solve.
