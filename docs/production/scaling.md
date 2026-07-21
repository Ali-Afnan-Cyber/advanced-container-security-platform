# Scaling

This document describes the platform's current single-node capacity limits and what would need to change to scale it to multiple nodes. It is a companion to `../design-decisions/07-single-node-k3s-tradeoffs.md`, which explains *why* the single-node decision was made; this document focuses on *what specifically* breaks or needs rework as load grows.

## Current State: Single-Node Limits

Every component in the platform  the K3s control plane, Falco, the Flask response engine, Prometheus, Grafana, Loki, kube-bench, Polaris, and the Isolation Forest service  runs on one node (Ubuntu 24, VMware). This creates a shared, finite resource pool with several concrete limits:

- **CPU/memory contention across unrelated components.** The control plane, the observability stack, and the security tooling all compete for the same CPU and memory budget. A spike in one (e.g. Loki ingesting a burst of Falco alerts during an active incident) can degrade another (e.g. the API server's responsiveness to admission requests) with no isolation between them.
- **No horizontal scaling for any component.** Every deployment currently runs as a single replica. Kyverno's admission webhook, the response engine, Prometheus, Grafana, and Loki are all single points of processing  there is no second instance to absorb load or take over if the first is saturated.
- **Falco's per-node design means it doesn't need to "scale" on a single node**  it already runs once per node. But this also means detection coverage on a multi-node cluster would require Falco running as a DaemonSet across every node, not a scaling change so much as a topology change.
- **The response engine is a single Flask process.** Under a burst of simultaneous Falco alerts (e.g. a rule matching across many pods at once), requests queue behind whatever the process can handle serially, which affects how quickly a real, high-confidence alert gets acted on.
- **Prometheus scrape and Loki ingestion volume is bounded by one node's disk and memory,** and  as noted in `../design-decisions/06-observability-stack.md`  neither currently has persistent storage at all, which is a separate but related constraint (see `backup-recovery.md`).

## What Changes for Multi-Node

Moving to multiple nodes is not simply "add more machines"  several components need re-architecting to actually benefit from additional nodes:

| Component | Single-node today | Multi-node requirement |
|---|---|---|
| K3s control plane | Runs on the one node, no quorum | 3 or 5 control-plane nodes for etcd quorum and control-plane HA (see `high-availability.md`) |
| Falco | One instance, implicitly covers the one node | DaemonSet  one Falco instance per node, each with its own eBPF probes, all shipping to a shared Loki backend |
| Kyverno admission webhook | Single pod | Multiple replicas behind a `PodDisruptionBudget`, so admission control doesn't stop cluster-wide if one pod restarts |
| Response engine | Single Flask process | Multiple stateless replicas behind a Service, with idempotent action handling so two replicas can't both act on the same alert and produce a duplicate/conflicting response |
| Prometheus | Single instance, local scrape only | Federation, or a remote-write setup to a system like Thanos/Cortex/Mimir, to aggregate metrics across nodes without one Prometheus instance being a bottleneck |
| Loki | Single instance | Distributed mode (separate ingester/querier/distributor components) with a replication factor, rather than the monolithic single-binary deployment mode suitable for one node |
| Grafana | Single instance, no shared state needed | Stateless replicas behind a load balancer, backed by a shared database for dashboards/users rather than local storage |
| kube-bench / Polaris | Run once, check the one node/cluster | Run per-node (kube-bench) and cluster-wide (Polaris), aggregated centrally rather than read individually |

## Additional Considerations for Multi-Node

- **Network segmentation across nodes.** A single-node cluster has no meaningful east-west network boundary between components (see `../architecture/trust-boundaries.md`). Multi-node introduces real network paths between nodes that would need Kubernetes NetworkPolicies to keep the same trust boundaries meaningful rather than implicit.
- **Node affinity and anti-affinity.** Security-critical components (Kyverno webhook replicas, response engine replicas) would need anti-affinity rules so that a single node failure can't take down every replica of a critical control simultaneously  defeating the purpose of adding nodes at all.
- **CI/CD and image distribution** would need to account for images being pulled to multiple nodes rather than one, though this is a comparatively minor change given the registry-based distribution model already in place (`../design-decisions/01-image-signing-cosign-keyless.md`).

## Relationship to Other Documents

- `../design-decisions/07-single-node-k3s-tradeoffs.md`  why single-node was chosen for this iteration of the platform.
- `high-availability.md`  the redundancy requirements that overlap heavily with scaling, but are driven by failure tolerance rather than load capacity.
- `../architecture/trust-boundaries.md`  how the trust zones described there would need to be re-drawn once compute is no longer co-located on one host.
