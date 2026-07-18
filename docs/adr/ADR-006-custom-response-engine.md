# ADR-006: Build a Custom Python Response Engine Instead of Falco Talon

**Status:** Accepted

## Context

Falco (ADR-005) is detection-only — it produces alerts but takes no enforcement action. The platform required a response layer that consumes Falco alerts (via Falcosidekick) and takes automated action, such as terminating a compromised pod or quarantining it (e.g. isolating it via network policy/label changes), with severity-based decision logic and audit logging feeding the observability stack.

Key requirements included:

- Consuming Falco alerts in near real time
- Configurable mapping from alert severity/rule to a specific action
- Full transparency into the decision logic, given this is a security-critical, defensible design decision for the project
- Ability to tune the false-positive-vs-kill trade-off explicitly rather than relying on a black-box default

---

## Options Considered

### Option 1 — Falco Talon

**Pros**

- Purpose-built response engine for Falco, with native alert format support
- YAML-based rule-to-action mapping, no custom code required
- Maintained by the Falco community, reducing engineering effort

**Cons**

- Was a comparatively young project at the time of evaluation, with a smaller community and a narrower, less battle-tested action library than a fully custom implementation
- Action logic is defined declaratively within Talon's own configuration model, which limits fine-grained customization of response behavior (e.g. custom cooldown windows, per-severity quarantine strategies, structured audit output tailored to this platform's logging pipeline)
- Using a pre-built response engine would leave the enforcement logic itself as a black box — for a project built specifically to be defensible and fully explainable end-to-end, wiring up an external tool provides less demonstrable engineering depth than an owned implementation

---

### Option 2 — Custom Python Flask Response Engine

**Pros**

- Full control and transparency over decision logic — every action can be traced to explicit code, which matters directly for defensibility
- Tailored severity-to-action mapping and false-positive handling (e.g. cooldown/suppression logic) designed around this platform's actual rule set, not a generic default
- Direct integration with the Kubernetes Python client for pod termination and quarantine actions, and with the existing logging/observability pipeline
- Demonstrates original engineering work rather than integration of a third-party tool

**Cons**

- Full maintenance burden falls on the project — no community support, no upstream security fixes
- Single custom component becomes a single point of failure; bugs in the response engine directly translate to missed or incorrect enforcement
- Requires careful, self-managed RBAC scoping for the service account driving pod termination/quarantine actions
- Reinvents functionality that an established tool already provides, at the cost of engineering time

---

## Decision

The platform uses a **custom Python Flask response engine**. It receives Falco alerts via a Falcosidekick HTTP webhook, applies a configurable severity-to-action mapping, and executes pod termination or quarantine actions through the Kubernetes API. Actions and decisions are logged for audit and feed into the observability stack.

Falco Talon was not adopted because it would have reduced this layer to configuration rather than implementation, at odds with the goal of a fully owned and defensible enforcement layer, and because its action model at the time was less customizable than what this platform's severity/trade-off logic required.

---

## Consequences

### Positive

- Complete transparency and explainability of every automated action taken
- Response logic can be tuned precisely to this platform's false-positive/kill trade-off
- Deepens engineering understanding of the full detection-to-response chain rather than treating it as a wired-together black box

### Negative

- No upstream maintenance or community support — all bugs, edge cases, and API compatibility work are owned by the project
- The response engine itself is a security-critical single point of failure and must be reviewed with the same rigor as the detection and admission layers
- Talon (or an equivalent maintained tool) should be re-evaluated in the future as it matures, rather than treating this decision as permanent

---

## References

- https://github.com/falcosecurity/falco-talon
- https://github.com/falcosecurity/falcosidekick
- https://kubernetes.io/docs/reference/using-api/client-libraries/
