# Backup & Recovery

This document states plainly what the platform's current data durability posture is, and what Recovery Time Objective (RTO) and Recovery Point Objective (RPO) would look like if this were a production deployment rather than a lab-grade platform.

## Current State: No Persistent Volume Backing

As noted in `../design-decisions/06-observability-stack.md` and `../architecture/threat-model.md`, **neither Loki nor Prometheus currently has a persistent volume attached.** Both store data on the pod's local, ephemeral filesystem. In practice, this means:

- **A pod restart loses all accumulated metrics and log history.** This includes Falco alert history and response engine action records stored in Loki  the platform's own audit trail of what it detected and did about it is exactly as ephemeral as everything else.
- **A node reboot loses everything.** Given the single-node design (`../design-decisions/07-single-node-k3s-tradeoffs.md`), there is no second copy of this data anywhere else to fall back on.
- **There is currently no backup job, snapshot schedule, or export process** capturing this data to any external or durable location.

## What Is *Not* at Risk

It's worth being precise about what this gap does and doesn't affect:

- **Signed image provenance is not at risk.** Cosign signatures and Rekor transparency log entries live in Sigstore's public infrastructure, external to this platform entirely (`../design-decisions/01-image-signing-cosign-keyless.md`). A node failure here has no effect on the durability of that data.
- **Platform configuration (Kyverno policies, Falco rules, Kubernetes manifests) is not at risk**, to the extent it's kept in version control (git). Redeploying the platform's *configuration* after a total node loss is a rebuild, not a data-recovery problem  assuming the git repository itself is the source of truth and is not the thing being lost.
- **What is genuinely at risk is operational history**: the record of what happened on the cluster  metrics over time, Falco alert history, response engine action logs, dashboard state.

## RTO / RPO If This Were Production

Stated honestly, in the platform's current form:

- **RPO (Recovery Point Objective) is effectively unbounded / total loss.** There is no backup, so the "point in time we could recover to" for observability data is undefined  recovery isn't possible at all for anything not still sitting in the live pod's ephemeral storage at the moment of failure.
- **RTO (Recovery Time Objective) is bounded by infrastructure rebuild time, not data restore time**, since there's no data to restore. Given the platform's configuration is code (Kubernetes manifests, Kyverno policies, Falco rules), a full rebuild on new infrastructure is realistically achievable, but it would be a **rebuild**, not a **recovery**  the platform would come back up with no memory of its own operational history.

For a genuine production deployment, reasonable targets might look like:

| Target | Example value | Rationale |
|---|---|---|
| RPO for metrics/logs | ≤ 15–60 minutes | Acceptable loss window for observability data in an incident  losing the last few minutes before a crash is tolerable; losing all history is not |
| RTO for the platform as a whole | ≤ 1–4 hours | Time to restore both infrastructure and the most recent backed-up data to a working state |

These are illustrative starting points, not commitments  actual targets should be set against real operational requirements once this moves toward production.

## What Would Be Required to Close This Gap

1. **Attach persistent volumes to Prometheus and Loki**, backed by durable storage  options range from a local durable disk with redundancy (e.g. Longhorn on a multi-node cluster) to cloud block storage, depending on where the platform is ultimately hosted.
2. **etcd snapshotting.** K3s's embedded etcd (or external datastore) needs a regular snapshot schedule, so cluster state itself  not just application data  can be restored after a node loss. This is distinct from, and in addition to, persistent volumes for the observability stack.
3. **A backup tool for Kubernetes resources and volumes**, such as Velero, to capture both cluster object state and PV contents on a schedule, shipped to storage outside the cluster (e.g. an S3-compatible bucket) so a full node loss doesn't also take the backups with it.
4. **Off-node/off-cluster storage for backups.** Given the single-node design, any backup stored only on that same node provides no real protection  durability requires the backup to live somewhere independent of the thing being backed up.
5. **A tested restore process**, not just a backup job. An untested backup is an assumption, not a guarantee  the RTO/RPO targets above are only meaningful if recovery has actually been exercised at least once.

## Relationship to Other Documents

- `../design-decisions/06-observability-stack.md`  the original design note on the missing persistent volumes.
- `../design-decisions/07-single-node-k3s-tradeoffs.md`  why there's no second node or datastore to fall back on today.
- `high-availability.md`  availability and durability are related but distinct; this document is specifically about data, not uptime.
