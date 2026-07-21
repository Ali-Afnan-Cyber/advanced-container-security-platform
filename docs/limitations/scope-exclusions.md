# Scope Exclusions

This document lists what was **deliberately excluded** from this platform's scope  as distinct from `known-limitations.md`, which lists gaps *within* the implemented scope. The distinction matters: a known limitation is something the platform tries to do and does imperfectly; a scope exclusion is something the platform never set out to do at all.

## Multi-Cluster

**Excluded:** Federation across multiple Kubernetes clusters, cross-cluster policy propagation, or any multi-cluster failover/scheduling capability.

**Why:** The platform is scoped to demonstrate defense-in-depth within a single cluster, deliberately, on a single node (`../design-decisions/07-single-node-k3s-tradeoffs.md`). Multi-cluster concerns  cluster-to-cluster trust, federated policy consistency, cross-cluster observability aggregation  are a meaningfully different (and larger) engineering problem than deepening the five layers already implemented, and would have diluted focus away from them.

**Not to be confused with:** Multi-*node* scaling within a single cluster, which is a near-term, in-scope evolution covered in `../production/scaling.md`. Multi-cluster is a further step beyond that, not addressed here at all.

## Multi-Tenancy

**Excluded:** Namespace-level tenant isolation hardening, per-tenant resource quotas and network policies, tenant-scoped RBAC boundaries, or any capability for multiple untrusted parties to safely share the cluster.

**Why:** This is explicitly a single-tenant platform (see `assumptions.md`). Multi-tenancy introduces its own security model  isolating tenants from each other, not just workloads from the platform's control plane  which is a distinct threat model from the one this platform defends against. Kyverno and PSS Restricted (`../design-decisions/02-admission-control-kyverno.md`) enforce workload-level security posture, but neither was configured or evaluated for tenant-to-tenant isolation, and doing so properly would require dedicated network policy design, resource quota enforcement, and likely a different RBAC structure than currently exists.

## Compliance Certifications

**Excluded:** Formal compliance certification against named regulatory or industry standards  for example, SOC 2, ISO 27001, PCI-DSS, HIPAA, or FedRAMP.

**Why:** The platform produces **compliance-relevant evidence**  kube-bench's CIS Kubernetes Benchmark results and Polaris's configuration posture checks (`../design-decisions/06-observability-stack.md`)  but evidence toward a benchmark is not the same as certification against a regulatory framework. Certification involves a formal audit process, often by a third party, against a specific standard's full control set, which is out of scope for what is a technical architecture project rather than a compliance program. The platform's CIS/Polaris output could reasonably feed into a future compliance effort, but achieving certification itself was never a goal.

## High Availability and Disaster Recovery (as delivered scope, not as documented gap)

**Excluded from this iteration's build, though fully documented as a forward path:** Multi-node control-plane HA, persistent-volume-backed observability, and formal RTO/RPO-driven backup processes.

**Why this is listed here and not only in `known-limitations.md`:** These were not attempted-and-imperfect within this build; they were scoped out from the start as a deliberate consequence of the single-node decision (`../design-decisions/07-single-node-k3s-tradeoffs.md`). The full path to closing this gap is described in `../production/high-availability.md` and `../production/backup-recovery.md`  those documents exist precisely because this was a scope exclusion with a known, well-understood remediation path, not an oversight.

## What Remains In Scope

To be clear about the boundary: the five defense-in-depth layers themselves (supply chain security, admission control, runtime detection, automated response, observability/compliance) plus the advisory-only intelligence layer are fully in scope and implemented, with their specific gaps tracked in `known-limitations.md` rather than excluded outright. The exclusions above are architectural expansions *beyond* that core scope, not weaknesses within it.

## Relationship to Other Documents

- `known-limitations.md`  gaps *within* the implemented scope.
- `assumptions.md`  what the platform assumes to be true about its environment, several of which directly justify the exclusions above (e.g. the single-tenant assumption justifies excluding multi-tenancy hardening).
- `../design-decisions/07-single-node-k3s-tradeoffs.md`  the root decision most of these exclusions trace back to.
