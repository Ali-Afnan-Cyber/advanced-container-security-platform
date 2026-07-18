# ADR-007: Use Kyverno for Admission Control Instead of OPA Gatekeeper

**Status:** Accepted

## Context

The platform required an admission control layer to enforce policy at deploy time: Pod Security Standards (Restricted profile), image signature verification against Cosign keyless signatures, and other cluster-wide constraints, implemented as Kubernetes `ValidatingAdmissionWebhook` policies.

Key requirements included:

- Enforceable, auditable policies for pod security, image provenance, and resource constraints
- Native support (or a clear integration path) for verifying Cosign/Sigstore image signatures
- Maintainability by a single engineer, favoring readability and a low barrier to writing/reviewing policy over raw expressive power
- Reasonable operational overhead on a single-node cluster

---

## Options Considered

### Option 1 — OPA Gatekeeper

**Pros**

- Widely adopted, CNCF project, backed by the general-purpose Open Policy Agent engine
- Highly expressive policy language (Rego) capable of arbitrarily complex logic
- Strong ecosystem and enterprise track record

**Cons**

- Rego is a separate declarative logic language with a real learning curve, distinct from native Kubernetes manifest syntax — this adds friction for writing, reviewing, and defending policy logic
- Policies are split across `ConstraintTemplate` and `Constraint` objects, adding indirection compared to a single policy resource
- Image signature verification (Cosign) is not native — it requires external data providers/provider plugins, adding moving parts for a capability this platform needed as a core control, not an add-on
- Higher overall complexity for a project scoped to a single-node, single-maintainer environment

---

### Option 2 — Kyverno

**Pros**

- Policies are written as native Kubernetes-style YAML resources (`ClusterPolicy`), no new DSL to learn — directly readable by anyone familiar with Kubernetes manifests
- Native `verifyImages` rule type for Cosign/Sigstore signature verification, without external plugins
- Built-in support for the Pod Security Standards profiles, used directly for the Restricted profile enforcement
- Single engine handles validate, mutate, and generate policy types, useful beyond pure validation
- Lower barrier to entry and review, well matched to a single-engineer project where every policy needs to be explainable

**Cons**

- Smaller advanced-use-case ecosystem than Gatekeeper in some enterprise contexts
- Kyverno's admission webhook is a single point of failure for the policies it governs, mitigated but not eliminated by `failurePolicy` configuration
- Adds per-request latency to the admission path
- The current `verifyImages` implementation performs verification based on registry/attestation lookups against the configured attestor rather than a fully custom cryptographic pipeline — a known limitation already documented as a gap in this platform's image verification coverage

---

## Decision

The platform uses **Kyverno** with `ClusterPolicy` resources for admission control, including enforcement of the Pod Security Standards Restricted profile and `verifyImages`-based validation of Cosign-signed images.

OPA Gatekeeper was not adopted because its Rego-based policy model and reliance on external providers for image verification added complexity disproportionate to this project's single-node, single-maintainer scope, where Kyverno's native YAML policies and built-in image verification directly matched the requirements with less indirection.

---

## Consequences

### Positive

- Policies are readable and directly defensible without translating Rego logic during review
- Native image verification removes a dependency on external provider plugins
- Generate/mutate capability leaves room to extend policy automation (e.g. auto-applying NetworkPolicies) without adding a second engine

### Negative

- The admission webhook remains a single point of failure for policy enforcement on this single-node cluster
- The `verifyImages` gap (registry/attestation-based verification rather than a fully independent cryptographic check) remains an open, documented limitation
- Should Gatekeeper's image verification integrations mature or the project's policy complexity grow significantly, this decision should be revisited

---

## References

- https://kyverno.io/docs/
- https://kyverno.io/docs/writing-policies/verify-images/
- https://open-policy-agent.github.io/gatekeeper/website/docs/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
