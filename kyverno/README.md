# Kyverno Admission Control

**Layer 2 of the Advanced Container Security Platform**  policy-as-code admission control that rejects (or flags) non-compliant workloads at the Kubernetes API, before a pod is ever scheduled.

---

## At a Glance

| | |
|---|---|
| **Engine** | Kyverno ClusterPolicies  policy written as native Kubernetes YAML, no separate policy language |
| **Policy count** | 7 |
| **Enforcing (blocking)** | 5 |
| **Audit (report-only)** | 2 |
| **Scope** | `default` and `demo-sec` namespaces |
| **Complementary baseline** | Pod Security Standards (Restricted profile)  documented at the platform level in `../docs/architecture/overview.md`; not part of this directory's manifests |

Kyverno was chosen over alternatives like OPA/Gatekeeper specifically so policy could be authored and reviewed in the same YAML idiom as the rest of the platform's manifests  the full reasoning is in [`../docs/design-decisions/02-admission-control-kyverno.md`](../docs/design-decisions/02-admission-control-kyverno.md).

---

## Policy Set

| Policy | Purpose | Action | Background scan |
|---|---|---|---|
| `verify-image-signature` | Restricts pods in `default`/`demo-sec` to a single approved image reference | **Enforce** | No |
| `require-resource-limits` | Requires CPU and memory limits on every container | **Enforce** | Yes |
| `require-probes` | Requires liveness and readiness probes | Audit | Yes |
| `require-non-root` | Requires `runAsNonRoot: true` in the container security context | **Enforce** | Yes |
| `disallow-privileged-containers` | Blocks `privileged: true` | **Enforce** | Yes |
| `disallow-latest-tag` | Flags images tagged `:latest` | Audit | Yes |
| `disallow-hostpath` | Blocks any `hostPath` volume | **Enforce** | Yes |

---

## How These Policies Work

Kyverno's `validate` rules in this set use two distinct mechanisms:

**Pattern matching**  a declarative schema the resource must conform to. Used by `require-resource-limits`, `require-probes`, `require-non-root`, `disallow-privileged-containers`, and `disallow-latest-tag`. For example, `require-non-root` requires the literal shape:
```yaml
pattern:
  spec:
    containers:
    - securityContext:
        runAsNonRoot: true
```
Anything not matching this shape fails validation.

**Deny conditions**  a JMESPath-based boolean expression, used where a simple schema pattern can't express the check. `verify-image-signature` and `disallow-hostpath` both use this form. `disallow-hostpath`, for instance, denies when the JMESPath expression `request.object.spec.volumes[].hostPath | length(@)` evaluates greater than zero  i.e., when at least one volume in the pod spec has a `hostPath` field set.

**`validationFailureAction: Enforce` vs `Audit`**  `Enforce` rejects the admission request outright; the pod is never created. `Audit` allows the pod through but records the violation as a `PolicyReport` object for later review. Every policy in this set is one or the other, deliberately: security-blocking controls (image restriction, resource limits, non-root, privilege, hostPath) are `Enforce`; operational-hygiene controls (probes, tag pinning) are `Audit`, on the reasoning that a missing readiness probe or a `:latest` tag is a reliability concern worth surfacing, not a security violation worth blocking a deployment over.

**`background: true` vs `false`**  controls whether Kyverno also scans *already-existing* resources on a schedule and reports violations against them, independent of new admission requests. It does not retroactively enforce or block anything  `Enforce` policies only ever block at the moment of admission, regardless of this flag. `verify-image-signature` is the one policy in this set with `background: false`, meaning pods that predate the policy (or were created through some other path) are never retroactively flagged.

---

## Enforcement Breakdown

**Enforcing (5):** `verify-image-signature`, `require-resource-limits`, `require-non-root`, `disallow-privileged-containers`, `disallow-hostpath`.

**Audit-only (2):** `require-probes`, `disallow-latest-tag`.

In practice, a single non-compliant pod submitted to `default` or `demo-sec` is very likely to be rejected by more than one Enforce policy simultaneously  this is defense-in-depth working as intended within the admission layer itself, not just across the platform's five broader layers. A pod with no resource limits, no non-root security context, and running the wrong image will fail `require-resource-limits`, `require-non-root`, and `verify-image-signature` all at once; Kyverno's admission response reflects whichever rule evaluation surfaces first.

---

## Namespace Scope

Every policy in this set matches only `["default", "demo-sec"]`. This is a narrower guarantee than a cluster-wide baseline: a workload deployed to any namespace outside these two is **not evaluated by any of these seven policies at all**. This is a deliberate choice for a demo/lab-scoped platform targeting a specific workload namespace, but it should be read precisely  this is not the same as "cluster-wide admission control," and is called out explicitly in [Known Gaps](#known-gaps--hardening-notes) below.

---

## Deployment

**Prerequisites:** Kyverno itself must already be installed on the cluster (e.g., via `helm install kyverno kyverno/kyverno -n kyverno --create-namespace`, from the [Kyverno Helm chart](https://kyverno.github.io/kyverno/)). This directory contains only the `ClusterPolicy` manifests that run on top of that installation  not the Kyverno controller itself.

```bash
# Apply every ClusterPolicy manifest in this directory
kubectl apply -f kyverno/
```

**Verifying policies loaded correctly:**

```bash
kubectl get clusterpolicy
```

Expect `ready: true` and `background: True/False` (matching the table above) for all 7 policies.

**Smoke-testing enforcement**  attempt to schedule a pod that should be rejected on multiple grounds at once:

```bash
kubectl run test-violation \
  --image=nginx \
  --namespace demo-sec \
  --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"test-violation","image":"nginx","securityContext":{"privileged":true}}]}}'
```

This should be denied  `nginx` isn't the approved image (`verify-image-signature`), no resource limits are set (`require-resource-limits`), no non-root context is declared (`require-non-root`), and `privileged: true` is set directly (`disallow-privileged-containers`). The admission response will report at least one of these; seeing the request rejected at all confirms the webhook is live and enforcing.

**Checking Audit-mode findings** (these won't block anything, so they need to be checked separately):

```bash
kubectl get policyreport -n demo-sec
```

---

## Known Gaps & Hardening Notes

Consistent with this platform's practice of stating gaps plainly (see [`../docs/limitations/known-limitations.md`](../docs/limitations/known-limitations.md)):

- **`verify-image-signature` does not verify a Cosign signature.** Despite its title and description ("Verify Cosign Image Signature," blocking images "not signed... via Cosign keyless signing on Rekor"), the rule's actual implementation is a `deny` condition checking that `request.object.spec.containers[0].image` exactly equals the string `ali20052025/secure-app:latest`. It never inspects a signature, a certificate, or a Rekor transparency log entry  it does not use Kyverno's native `verifyImages` rule type at all. This is a more basic gap than the "signer-annotation string-match" already described in [`../docs/architecture/threat-model.md`](../docs/architecture/threat-model.md) and [`../docs/design-decisions/02-admission-control-kyverno.md`](../docs/design-decisions/02-admission-control-kyverno.md)  those documents should be read as describing the *intended* mechanism; this is the mechanism as actually implemented today, and the two should be reconciled once cryptographic verification is added.
- **The one image this policy allows through is itself tagged `:latest`.** `ali20052025/secure-app:latest` is the sole value `verify-image-signature` permits  yet `disallow-latest-tag` (Audit-only) exists specifically to flag `:latest` as bad practice elsewhere in this same policy set. The platform's only admissible image is, today, an instance of the exact pattern its own tagging policy warns against. This is worth resolving in the same pass as fixing the signature-verification gap above, since a real Cosign/Rekor check would naturally verify a specific image *digest* rather than a mutable tag, closing both gaps together.
- **A single hardcoded image reference doesn't scale.** Every new component or image the platform adds requires a manual edit to this policy. A routine version bump (`secure-app:latest` → `secure-app:v2`) would fail closed unless this policy is updated in lockstep with the image release  this is a maintenance fragility, not just a correctness gap.
- **`disallow-privileged-containers` uses a conditional anchor** (`=(securityContext): =(privileged): false`), meaning the check only applies *if* `securityContext.privileged` is present in the manifest at all. A pod that omits `securityContext` entirely still passes, relying on Kubernetes' own default (`privileged: false` when unset) rather than requiring an explicit declaration. In practice this is benign  the default is safe  but it's a materially weaker guarantee than a pattern requiring `securityContext` to be explicitly declared, and is worth knowing precisely rather than assuming the strictest possible reading.
- **Scope is `default` and `demo-sec` only.** None of these seven policies apply to any other namespace. A workload deployed elsewhere on the cluster has none of these controls  not resource limits, not non-root enforcement, not the hostPath restriction  applied to it at all.
- **`verify-image-signature` runs with `background: false`.** Pods already running in `default`/`demo-sec` before this policy existed (or created outside the normal path) are never retroactively scanned or flagged, unlike the other six policies, which at least generate a `PolicyReport` against pre-existing resources even though they can't retroactively block them either.
- **`require-probes` and `disallow-latest-tag` are Audit-only by design**, not oversight  the intent is to surface these as operational-hygiene signals without blocking a deployment over them. Anyone reviewing this platform's admission posture should check `PolicyReport` objects directly, since these two checks produce no admission-time signal at all.

---

## Related Documentation

- [`../docs/architecture/overview.md`](../docs/architecture/overview.md)  where admission control sits in the platform's five-layer defense-in-depth model
- [`../docs/architecture/threat-model.md`](../docs/architecture/threat-model.md)  what Layer 2 defends against, and the `verifyImages` gap as originally documented
- [`../docs/architecture/trust-boundaries.md`](../docs/architecture/trust-boundaries.md)  the admission boundary as a trust zone, and why nothing re-checks a pod after it passes admission
- [`../docs/design-decisions/02-admission-control-kyverno.md`](../docs/design-decisions/02-admission-control-kyverno.md)  why Kyverno was chosen over OPA/Gatekeeper, and PSS Restricted as the complementary baseline
- [`../docs/design-decisions/01-image-signing-cosign-keyless.md`](../docs/design-decisions/01-image-signing-cosign-keyless.md)  the Cosign keyless signing infrastructure this policy set is meant to eventually verify against
- [`../docs/limitations/known-limitations.md`](../docs/limitations/known-limitations.md)  the platform-wide gap inventory this README's findings feed into
