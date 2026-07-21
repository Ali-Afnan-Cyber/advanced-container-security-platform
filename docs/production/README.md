# Production Readiness

This directory documents the gap between the platform **as built**  a single-node, lab-grade defense-in-depth system  and what it would take to run it **in production**: at scale, resilient to failure, with real secrets hygiene, real alerting, and real data durability.

Where `../architecture/` describes the system as it exists and `../design-decisions/` explains why it was built that way, this directory looks forward: for each production concern below, what's missing today, and concretely what closing that gap would require.

## Documents

| Document | Covers |
|---|---|
| [`scaling.md`](./scaling.md) | Current single-node capacity limits; what changes structurally to support multiple nodes |
| [`high-availability.md`](./high-availability.md) | Current single points of failure; what removing each one requires |
| [`secrets-management.md`](./secrets-management.md) | Current secrets handling (Kubernetes Secrets, Cosign keyless), its gaps, and Vault/Sealed Secrets as the next step |
| [`monitoring-alerting.md`](./monitoring-alerting.md) | The existing Prometheus/Grafana/Loki setup and the missing alert-routing layer on top of it |
| [`backup-recovery.md`](./backup-recovery.md) | The current lack of persistent volume backing, and what realistic RTO/RPO targets would require |

## How These Documents Relate to Each Other

These five concerns overlap more than they're independent, and each document cross-references the others where that overlap matters:

- **Scaling** and **high availability** both call for multiple replicas of the same components (Kyverno webhook, response engine, observability stack)  one for load, one for failure tolerance  and the changes largely coincide.
- **High availability** solves for uptime; **backup & recovery** solves for data durability. A fully redundant platform can still permanently lose its own operational history if the underlying data was never persisted or backed up in the first place  the two are related but not substitutes for each other.
- **Secrets management** and **monitoring & alerting** are both, in effect, "trust but verify" gaps: secrets exist but aren't rotated or centrally audited; metrics exist but aren't routed to anyone when they matter. Both are cases of the data being collected correctly with no closed loop on top of it.

## Why This Directory Exists Separately

Every gap catalogued here traces back to the same root decision documented in `../design-decisions/07-single-node-k3s-tradeoffs.md`: this platform was deliberately scoped to demonstrate defense-in-depth within a constrained, single-node environment, not to be production-hardened from day one. Rather than let that scoping decision quietly become an unstated limitation, this directory names each production concern explicitly, so anyone evaluating the platform  including its own author  has an honest, specific account of what "not yet production-ready" actually means, gap by gap, rather than a vague disclaimer.

## Reading Order

There's no strict dependency between these five documents, but a reasonable order is:

1. `high-availability.md`  establishes the SPOFs, which is the most immediately visible gap.
2. `scaling.md`  builds on the same component list with a load-capacity lens rather than a failure-tolerance one.
3. `backup-recovery.md`  the data-durability gap that HA alone doesn't solve.
4. `secrets-management.md`  an orthogonal but equally concrete gap in current secrets hygiene.
5. `monitoring-alerting.md`  the observability stack exists (`../design-decisions/06-observability-stack.md`), but the last-mile "tell a human" step does not.
