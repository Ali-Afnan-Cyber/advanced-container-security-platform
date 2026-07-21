# 02. Admission Control: Kyverno

## Context

Runtime detection (Falco) can only catch a problem after a pod is already running. Some categories of risk are better closed off entirely  a privileged container, a missing resource limit, an image from an unrecognized source  by refusing to schedule the pod in the first place. That requires a policy engine that hooks into the Kubernetes admission chain and can accept or reject a workload manifest before the API server persists it.

## Decision

Use **Kyverno ClusterPolicies**, layered on top of Kubernetes' built-in **Pod Security Standards (Restricted profile)**, as the admission control mechanism.

PSS Restricted provides a baseline that applies cluster-wide regardless of any custom policy authored later  it disallows privileged containers, host namespace access, and enforces a non-root, capability-dropped security context by default. Kyverno ClusterPolicies sit on top of that baseline to add platform-specific rules: resource limit enforcement, and an image-signature check (`verifyImages`) intended to gate deployment on Cosign-signed images.

## Alternatives Considered

**OPA / Gatekeeper.** The most direct competitor  also a mature, widely adopted Kubernetes admission controller. Rejected in favor of Kyverno primarily because Kyverno policies are written as native Kubernetes-style YAML, while Gatekeeper policies are written in Rego, a separate policy language. For a single-person platform without a dedicated policy-engineering background, writing and auditing policy in the same YAML idiom as the rest of the manifests lowers the barrier to correctly reviewing what a policy actually does  a meaningful factor when policy correctness is itself a security control.

**PSS alone, no Kyverno.** Pod Security Standards alone would cover the built-in security context baseline (no privileged containers, no host access) but has no mechanism for custom rules like image signature verification or platform-specific resource governance. Rejected as insufficient on its own  PSS was kept as the baseline layer specifically *because* Kyverno is additive to it, not a replacement for it.

**No admission control, rely on runtime detection only.** Rejected outright. This would mean every misconfiguration or policy violation is only ever caught after the fact by Falco, if at all  a materially weaker posture that trades a preventive control for a purely detective one.

## Trade-offs

**Gained:**
- Misconfigured or non-compliant workloads are rejected before they ever run  no window of exposure between "scheduled" and "caught."
- Policy authored in the same YAML idiom as the rest of the Kubernetes manifests, keeping the policy review surface consistent with the rest of the platform's configuration.
- PSS Restricted provides a baked-in floor that holds even if a custom Kyverno policy has a bug or gap.

**Given up:**
- **`verifyImages` currently checks a signer annotation string, not a live cryptographic signature.** This is the platform's most significant admission-layer gap (see `threat-model.md`)  the policy engine and the signing infrastructure (`01-image-signing-cosign-keyless.md`) are both correctly built, but the check connecting them at admission time isn't yet doing full cryptographic re-verification.
- **Admission is a one-time check, not continuous.** Once a pod passes admission, Kyverno has no further say over it for the life of the pod  this is by design (see `trust-boundaries.md`), but it does mean a policy change doesn't retroactively apply to already-running workloads without a manual rollout.
- **Kyverno itself is a new component with its own attack surface**  a bug or misconfiguration in the admission webhook could itself become an availability risk (e.g. a webhook that fails closed and blocks all deployments) or a security gap (a webhook that fails open).
