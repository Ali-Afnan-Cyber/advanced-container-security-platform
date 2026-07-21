# Assumptions

This document states what the platform assumes to be true about its environment and threat model, rather than actively verifies. Every control described in `../architecture/` and `../design-decisions/` was designed against these assumptions  if any of them don't hold in a given deployment, the corresponding controls may provide less protection than described, and that should be understood explicitly rather than discovered later.

## 1. The Container Registry Is Trusted

**Assumption:** The registry that stores and serves signed images (referenced throughout `../design-decisions/01-image-signing-cosign-keyless.md`) is itself not compromised  that it faithfully stores and serves back exactly what was pushed, without substitution.

**What this means in practice:** Cosign signing and Rekor's transparency log protect against a *tampered image being accepted as valid*  if an attacker altered an image, the signature check would fail. They do not protect against a compromised registry serving a *different, unsigned* image outright and having that fact go unnoticed if nothing ever checks the registry's integrity independent of the pull itself, or a registry that suppresses/misreports pull requests. The platform assumes registry-level infrastructure integrity as a precondition, not something it independently verifies.

**Where this assumption is load-bearing:** `../design-decisions/01-image-signing-cosign-keyless.md`, `../architecture/data-flow.md`, `../architecture/trust-boundaries.md` (Zone 1).

## 2. Single-Tenant Environment

**Assumption:** The cluster runs workloads belonging to a single trust domain  there is no expectation of isolating mutually untrusted parties from one another on the same cluster.

**What this means in practice:** Kyverno policies and PSS Restricted (`../design-decisions/02-admission-control-kyverno.md`) enforce a security *baseline* for all workloads, but they were not designed or evaluated as a tenant isolation boundary. A workload that passes admission is trusted to the same degree as every other workload on the cluster  there is no assumption that one workload's owner might be actively adversarial toward another's.

**Where this assumption is load-bearing:** `../limitations/scope-exclusions.md` (multi-tenancy exclusion), `../architecture/trust-boundaries.md`.

## 3. The Threat Model Boundary Is the Node/Cluster, Not Beyond It

**Assumption:** The platform's five layers defend the software supply chain, admission process, and runtime behavior *of workloads running on this cluster*. They do not extend to threats originating from outside that boundary  for example, compromise of the underlying VMware hypervisor, physical access to the host, or compromise of the developer's own workstation before code is ever committed.

**What this means in practice:** A compromise below the layers this platform actually observes (hypervisor, host OS below the container runtime, physical infrastructure) is out of scope for detection or response here, by design  not because it's unimportant, but because it sits outside the boundary the five layers were built to defend. This mirrors the point made in `../architecture/trust-boundaries.md`: the kernel and eBPF subsystem are trusted; a compromise beneath them voids the guarantees built on top.

**Where this assumption is load-bearing:** `../architecture/trust-boundaries.md` (Zone 3), `../design-decisions/03-runtime-detection-falco-ebpf.md`, `../design-decisions/07-single-node-k3s-tradeoffs.md`.

## 4. CI/CD Identity (GitHub Actions OIDC) Is Not Itself Compromised

**Assumption:** The OIDC token issued by GitHub Actions, which roots the entire Cosign keyless signing chain, is assumed to be issued correctly and only to the legitimate workflow run it claims to represent.

**What this means in practice:** Every signature's trustworthiness is ultimately only as strong as this assumption. If GitHub Actions' OIDC issuance were itself compromised or flawed, every signature issued through it would inherit that compromise  a risk the platform accepts as external to its own control, consistent with the reasoning already given in `../design-decisions/01-image-signing-cosign-keyless.md`.

**Where this assumption is load-bearing:** `../design-decisions/01-image-signing-cosign-keyless.md`, `../architecture/trust-boundaries.md` (Zone 1).

## 5. The Response Engine's Kubernetes API Credentials Are Not Themselves the Attack Vector

**Assumption:** The scoped service account used by the Flask response engine (`../design-decisions/04-response-engine-custom-flask.md`) is assumed to be protected at least as well as any other credential on the cluster, and its scoping is assumed sufficient to bound damage if the engine itself is compromised.

**What this means in practice:** The response engine's privilege scoping limits blast radius *if* it's compromised, but the platform assumes that scoping is correctly maintained over time (e.g. not accidentally broadened during a future change) and that the credential itself isn't separately exfiltrated through a channel the platform doesn't otherwise defend (see assumption 3 and item 9 in `known-limitations.md` on secrets handling generally).

**Where this assumption is load-bearing:** `../design-decisions/04-response-engine-custom-flask.md`, `../architecture/trust-boundaries.md` (Zone 4), `../production/secrets-management.md`.

## 6. Falco's Rule Set Reflects the Actual Threat Landscape

**Assumption:** The custom Falco rules (`../design-decisions/03-runtime-detection-falco-ebpf.md`) are assumed to cover the categories of malicious behavior actually relevant to this platform's workloads  the rule set is a bet on which attack patterns matter, not a guarantee of universal coverage.

**What this means in practice:** Detection quality is bounded by how well the anticipated threat scenarios match real-world attacker behavior. A genuinely novel technique outside the rule set's assumptions won't be caught by Layer 3 alone  this is why the Isolation Forest intelligence layer exists as a complementary, pattern-agnostic signal (`../design-decisions/05-ml-anomaly-detection-isolation-forest.md`), though even that layer assumes the platform's own baseline traffic is a reasonable proxy for "normal."

**Where this assumption is load-bearing:** `../design-decisions/03-runtime-detection-falco-ebpf.md`, `../design-decisions/05-ml-anomaly-detection-isolation-forest.md`, `../architecture/threat-model.md`.

## Why This Document Matters

Every control in this platform was designed to be correct *given* these assumptions. None of the assumptions above are unusual or unreasonable for a lab-grade, single-tenant platform  but stating them explicitly means anyone adapting this platform to a different environment (multi-tenant, a different registry, a different CI system) knows exactly which foundations they'd need to re-examine first, rather than inheriting an assumption silently.

## Relationship to Other Documents

- `scope-exclusions.md`  several exclusions (multi-tenancy, multi-cluster) exist precisely because the assumptions above were taken as given rather than engineered around.
- `known-limitations.md`  gaps within scope; this document instead covers what's assumed *true* rather than known to be *imperfect*.
- `../architecture/trust-boundaries.md`  the trust-zone model these assumptions underpin.
