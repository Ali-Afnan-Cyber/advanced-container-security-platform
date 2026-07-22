# Future Work Roadmap

This document ties together every planned enhancement to the platform, in rough priority order, and distinguishes between **enhancements to the current platform** and **the next standalone project**. Each item links to its own detailed document; this file is the map, not the destination.

## How Priority Was Set

Priority here is a function of two things: **how much detection/response risk the gap currently represents** (per `../limitations/known-limitations.md`), and **how much other work depends on it being done first**. Cheaper, self-contained wins are sequenced early; items that reshape the platform's architecture or that depend on infrastructure not yet in place (multi-node, per `../production/scaling.md`) are sequenced later, regardless of how interesting they are.

## Track 1: The Next Project (Not a Platform Enhancement)

| Item | Document |
|---|---|
| Tetragon eBPF kernel enforcement platform | [`tetragon-ebpf-enforcement.md`](./tetragon-ebpf-enforcement.md) |

This is deliberately **not** on the priority-ordered backlog below. It's a new, narrowly scoped, standalone project  not an incremental patch to the existing five-layer platform  built on the same lessons this platform's runtime detection layer surfaced. See the document itself for why it's being built separately rather than folded into this repository.

## Track 2: Platform Enhancement Backlog, in Priority Order

| Priority | Item | Effort | Closes | Document |
|---|---|---|---|---|
| 1 | Falco rule expansion | Low | Detection coverage gap (`known-limitations.md` #3, referencing rule scope) | [`falco-rules-expansion.md`](./falco-rules-expansion.md) |
| 2 | Proper pod quarantine implementation | Low–Medium | Vague "quarantine" action in the response engine (`known-limitations.md` #4) | [`pod-quarantine-implementation.md`](./pod-quarantine-implementation.md) |
| 3 | AI anomaly detection as a proper enforcement-adjacent layer | Medium–High | Isolation Forest's advisory-only isolation from response (`../design-decisions/05-ml-anomaly-detection-isolation-forest.md`) | [`ai-anomaly-enforcement-layer.md`](./ai-anomaly-enforcement-layer.md) |
| 4 | GitOps integration + Trivy Operator automated remediation | Medium–High | No continuous in-cluster scanning, no GitOps reconciliation (`../production/secrets-management.md` GitOps gap, general operational maturity) | [`gitops-integration.md`](./gitops-integration.md) |
| 5 | SLSA Level 3 + full in-toto framework | High | SLSA L2 ceiling (`known-limitations.md` #3) | [`slsa-level-3.md`](./slsa-level-3.md) |
| 6 | Multi-cluster federation | Highest | Explicitly out of scope today (`../limitations/scope-exclusions.md`) | [`multi-cluster-federation.md`](./multi-cluster-federation.md) |

## Why This Order

**1–2 first (Falco rules, quarantine):** Both are contained changes to components that already exist  no new architecture, no new trust boundary, no new component to secure. They directly harden the weakest, most concretely-named gaps in `../limitations/known-limitations.md` and can be done independently of everything else on this list.

**3 next (AI enforcement layer):** This is a genuine architecture change  it moves the Isolation Forest service from a read-only observer to something with a defined (if still constrained) path into the response engine. It depends conceptually on quarantine being properly implemented first (priority 2), since any new automated action this layer takes should reuse that same quarantine mechanism rather than invent a second one.

**4 next (GitOps + Trivy Operator):** This is an operational-maturity investment  closing the gap between "we scan at build time" and "we know if a running image later became vulnerable," and between "changes are applied by hand" and "changes are reconciled declaratively from git." It's sequenced after 1–3 because it's additive operational tooling rather than a security-control gap, but it's a prerequisite for doing SLSA L3 well (item 5), since a hermetic, auditable build environment is easier to reason about once deployment itself is GitOps-managed and auditable.

**5 next (SLSA L3 / in-toto):** The deepest supply-chain investment on this list, requiring both hermetic build tooling and a full attestation chain across every pipeline step, not just the final image. It's high-value but high-effort, and benefits from the GitOps foundation being in place first.

**6 last (multi-cluster federation):** This is explicitly the most architecturally disruptive item, and it has a hard prerequisite that isn't on this list at all: multi-*node* operation within a single cluster, covered in `../production/scaling.md` and `../production/high-availability.md`. Federating clusters that are each still single points of failure internally doesn't buy much  this only becomes worth doing once the single-cluster HA story is solid.

## Relationship to Other Documents

- `../limitations/known-limitations.md` and `../limitations/scope-exclusions.md` are the gap inventories this roadmap works through.
- `../production/` describes production-readiness work (scaling, HA, secrets, monitoring, backup) that runs in parallel to this roadmap rather than in sequence with it  the two tracks address different kinds of readiness and can proceed independently.
- Each document in this folder states its own current state, target design, and implementation plan in detail; this file only sets the order they should be tackled in.
