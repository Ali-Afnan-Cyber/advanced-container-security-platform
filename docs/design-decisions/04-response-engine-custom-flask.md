# 04. Response Engine: Custom Flask Service

## Context

A Falco alert on its own is just a log line until something acts on it. Left as alert-only, real threats sit for however long it takes a human to notice, triage, and respond  which, outside business hours or under alert fatigue, can be a long time. Closing that gap means converting detection into action automatically. But "automatically terminate on any alert" and "just log everything for a human" are both bad defaults on their own: the first risks killing legitimate workloads on a false positive, the second reintroduces the dwell-time problem automation was meant to solve.

## Decision

Build a **custom Python/Flask service** that receives Falco alerts directly over HTTP (via Falco's configured HTTP output) and applies tiered decision logic before acting:

- **CRITICAL, high-confidence rule matches** → immediate pod termination via the Kubernetes API.
- **WARNING-tier or lower-confidence matches** → quarantine (network isolation or a label change removing the pod from service) rather than termination, preserving the workload for inspection.
- **INFO-tier or ambiguous matches** → logged only, surfaced for human review via Grafana/Loki, no automated action.

The engine runs with a Kubernetes service account scoped specifically to the actions it needs (terminate, label, apply network policy)  not cluster-admin.

## Alternatives Considered

**Falco Talon (or a similar off-the-shelf Falco response tool).** The most direct alternative  an existing, purpose-built responder for Falco alerts. Rejected in favor of a custom engine specifically to get full control over the severity-tiering and the false-positive/kill trade-off, rather than accepting whatever default action-mapping an off-the-shelf tool ships with. Building it in-house also meant the decision logic itself could be defended in detail as part of the platform's design, rather than treated as an opaque dependency.

**Alert-only (no automated response, human triage for everything).** The simplest option, and the one many smaller deployments default to. Rejected because it reintroduces exactly the dwell-time problem automation is meant to close  a real, active threat sits unaddressed for however long it takes a human to see and act on the alert, which on a single-operator platform could be substantial.

**Terminate on every match, no tiering.** The most aggressive automated option. Rejected because it maximizes the false-positive cost: a single overly broad custom rule (see `03-runtime-detection-falco-ebpf.md`) could take down a legitimate workload with no intermediate step, and there'd be no mechanism to preserve a pod for forensic review before it's gone.

## Trade-offs

**Gained:**
- Automated response with a tunable, defensible decision layer between "alert fired" and "action taken"  not an all-or-nothing automation.
- Quarantine as a middle tier preserves evidence for lower-confidence alerts instead of forcing an immediate binary decision.
- Scoped service account limits blast radius if the response engine itself were ever compromised (see `trust-boundaries.md`).
- Every action taken (or the decision to take none) is itself logged and exposed as a metric, making the response engine's own behavior auditable.

**Given up:**
- **The false-positive/kill trade-off is tuned, not eliminated.** Biasing toward termination only on high-confidence CRITICAL rules reduces false-positive terminations but necessarily means some real threats sit in "quarantine" or "log only" tiers longer than an aggressive terminate-everything policy would allow. This is a live, ongoing operational risk in either direction, not a solved problem (see `threat-model.md`).
- **A custom service is a custom maintenance burden.** Unlike an off-the-shelf tool, there's no upstream community fixing bugs or expanding rule-mapping coverage  that responsibility sits entirely with whoever operates this platform.
- **The response engine is itself a new component with elevated privileges,** meaning it's also a new trust boundary and a new thing that can fail or be attacked (see `trust-boundaries.md`).
