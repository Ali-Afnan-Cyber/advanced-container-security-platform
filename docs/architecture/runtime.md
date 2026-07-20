# Runtime Behavior

This document describes what happens on the live cluster once a workload is running — how Falco observes it, how events move through the pipeline, and how the response engine decides what to do.

## 1. Falco eBPF Hooking

Falco 0.43.1 runs with the **modern eBPF driver**, which attaches probes to kernel tracepoints and syscall entry/exit points rather than requiring an out-of-tree kernel module. On pod start:

1. The container runtime creates the container's namespaces (PID, network, mount, etc.).
2. Falco's eBPF probes, already loaded and running at the node level, begin observing syscalls made within those namespaces — no per-pod probe attachment step is required, since the probes operate at the kernel level across the whole node and Falco correlates events back to the originating container via cgroup/namespace metadata.
3. Observed syscalls are matched in-kernel where possible against loaded rule conditions, minimizing the volume of events passed up to userspace.

This means detection coverage is bounded by what is observable at the syscall/tracepoint level. Activity that doesn't touch a monitored syscall (e.g. purely in-memory computation) is invisible to this layer by design — this is a known scope limit, not a gap, since it defines the boundary of what runtime syscall monitoring can ever cover.

## 2. Custom Rule Structure

Rules are layered on top of Falco's default rule library rather than replacing it. Custom rules target platform-specific scenarios, including:

- An interactive shell spawned inside a container that has no legitimate reason to spawn one.
- Unexpected outbound network connections from a workload.
- Privilege escalation attempts (e.g. `setuid`, capability changes) inside a running container.
- Writes to sensitive paths (e.g. package manager directories, credential paths) at runtime.

Each rule specifies a priority level (e.g. `WARNING`, `CRITICAL`) which determines how it's treated downstream by the response engine.

## 3. Event Pipeline

```text
Kernel syscall
│
▼
eBPF probe (in-kernel filtering)
│
▼
Falco userspace engine (rule matching)
│
├─▶ No rule match → discarded (or logged at low verbosity)
│
▼ Rule match
Falco alert generated (JSON output)
│
├─▶ Shipped to Loki (all alerts, regardless of severity)
│
▼
HTTP POST to Flask response engine webhook
```

Falco is configured with an HTTP output channel pointed at the response engine's webhook endpoint, in addition to its standard log output that feeds Loki. This means every alert is durably logged even if the response engine is unavailable — the response path and the audit trail are decoupled.

## 4. How the Response Engine Gets Triggered

The Flask response engine exposes a webhook endpoint that receives Falco's alert payload directly. On receipt:

1. **Parse and classify** — the alert's rule name and priority are mapped to a severity tier.
2. **Apply decision logic** — this is where the false-positive/kill trade-off is operationalized (see `threat-model.md` for the trade-off itself):
   - **CRITICAL, high-confidence rules** (e.g. reverse shell patterns) → immediate pod termination via the Kubernetes API.
   - **WARNING-tier or lower-confidence rules** → quarantine action (e.g. network policy applied to isolate the pod, or a label change removing it from service) rather than outright termination, preserving the workload for forensic inspection.
   - **INFO-tier or ambiguous matches** → logged only, no automated action, left for human review via Grafana/Loki.
3. **Execute** — the chosen action is issued against the Kubernetes API using a scoped service account.
4. **Record** — the action taken (or the decision to take no action) is itself logged and exposed as a Prometheus metric, so response engine behavior is auditable independently of the original Falco alert.

## 5. Operational Notes

- The response engine's Kubernetes API permissions are deliberately scoped (see `trust-boundaries.md`) — it can terminate/label/isolate pods but does not hold cluster-admin-level access.
- Because this is a single-node cluster, the response engine, Falco, and the workloads it monitors all run on the same physical/virtual host. A full node compromise below the eBPF hook layer (e.g. a kernel exploit) is out of scope for this layer's detection guarantees — see `threat-model.md`.
