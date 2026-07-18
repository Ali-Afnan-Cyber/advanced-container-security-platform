# ADR-005: Use Falco for Runtime Threat Detection

**Status:** Accepted

## Context

The platform required a runtime detection layer capable of observing container and host behavior in real time — process execution, file access, network activity, and privilege changes — and flagging anomalous behavior against a rule set, independent of the admission control layer (which only evaluates objects at deploy time, not runtime behavior).

Key requirements included:

- Kernel-level visibility into syscalls with low overhead, since the platform runs on a single-node K3s cluster (Ubuntu 24, VMware) with limited resources
- A mature, expressive rule engine supporting both community-maintained and custom detection rules
- Kubernetes-aware context enrichment (pod, namespace, container image) attached to alerts
- An output mechanism that could feed downstream systems (the response engine, the observability stack)
- A detection-only scope for this project, with enforcement handled by a separate component

---

## Options Considered

### Option 1 — Falco (CNCF, modern eBPF driver)

**Pros**

- CNCF graduated project with a mature, well-documented rule syntax
- Modern eBPF driver provides kernel-level syscall visibility without a kernel module, avoiding kernel version coupling and out-of-tree module risk
- Large library of community rules plus straightforward support for custom rules
- Native Kubernetes metadata enrichment (`k8s.ns.name`, `k8s.pod.name`, etc.)
- Falcosidekick provides a ready integration path to forward alerts to webhooks, Prometheus, and other outputs
- Low resource footprint relative to the visibility it provides, suitable for a single-node cluster

**Cons**

- Detection only — no native enforcement, requiring a separate response layer
- Rule tuning required to manage false positives in a live environment
- Modern eBPF driver requires a sufficiently recent kernel

---

### Option 2 — Tracee (Aqua Security)

**Pros**

- eBPF-based, with strong forensic/tracing capabilities
- Good for deep syscall-level investigation

**Cons**

- Smaller rule ecosystem and community compared to Falco at the time of evaluation
- Less mature Kubernetes-native alert enrichment and downstream integration tooling
- Less established as a standalone Kubernetes runtime security control plane

---

### Option 3 — Tetragon (Cilium)

**Pros**

- Modern eBPF, kernel-level observability with tracing policies
- Capable of both observation and in-kernel enforcement (process/network blocking), not detection-only

**Cons**

- Enforcement-first design goes beyond this project's detection-only scope for the runtime layer — enforcement was deliberately kept in a separate, explainable response engine rather than folded into the detection tool
- Smaller rule/community ecosystem for prebuilt detection content compared to Falco at the time
- Better suited to a project scoped specifically around eBPF-native enforcement (a direction considered separately, outside this platform's scope)

---

### Option 4 — Sysdig Secure

**Pros**

- Built on Falco's detection engine with additional enterprise tooling and support

**Cons**

- Commercial/managed product — introduces cost and external dependency unsuitable for a self-hosted, single-node lab platform
- Reduces transparency/control over the underlying detection logic, which matters for a fully explainable system

---

## Decision

The platform uses **Falco 0.43.1 with the modern eBPF driver** for runtime detection, with custom rules layered on top of the default rule set. Falcosidekick forwards alerts out of Falco to the custom response engine and to the observability stack.

Falco was selected as detection-only by design — enforcement logic is intentionally kept in a separate component (see ADR-006) so that detection and response remain independently testable, auditable, and explainable.

---

## Consequences

### Positive

- Mature, well-supported detection engine with a large existing rule corpus to build custom rules on top of
- Kubernetes-native alert context simplifies both response engine logic and dashboarding
- Low overhead fits the single-node resource envelope
- Detection-only scope keeps the enforcement blast radius isolated to a separately reviewed component

### Negative

- No native enforcement — the platform depends entirely on the custom response engine to act on alerts, meaning a failure there leaves detections as alerts only
- Custom rules require ongoing tuning to control false-positive rate
- Kernel compatibility must be revisited if the underlying host kernel changes

---

## References

- https://falco.org/docs/
- https://github.com/falcosecurity/falco
- https://github.com/falcosecurity/falcosidekick
- https://tetragon.io/
- https://github.com/aquasecurity/tracee
