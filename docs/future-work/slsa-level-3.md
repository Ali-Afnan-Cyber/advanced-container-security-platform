# SLSA Level 3 and Full in-toto Framework Implementation

## Current State

The pipeline today achieves **SLSA Level 2**: Cosign keyless signing rooted in GitHub Actions OIDC identity, a Rekor transparency log entry, and a provenance attestation generated from a hosted build service (`../design-decisions/01-image-signing-cosign-keyless.md`). This proves *that a signature was issued by a specific workflow run* but does not prove the build environment itself was isolated from tampering, nor does it provide step-by-step, non-repudiable evidence across the *entire* pipeline  only a final attestation over the finished artifact.

This is the most significant documented supply-chain gap in the platform (`../limitations/known-limitations.md` #3). This document describes what closing it fully  to SLSA Level 3, backed by a complete in-toto layout  requires.

## Two Separate Things Being Solved Here

It's worth being precise that SLSA Level 3 and a full in-toto implementation are related but distinct improvements:

- **SLSA Level 3** is about the *build environment's* isolation and non-falsifiability  ensuring the provenance itself can't be forged or influenced by the source repository's own workflow definition.
- **in-toto** is a *framework* for defining and verifying a multi-step supply chain as a whole  not just "was the final artifact signed," but "did every step from source checkout to final image push happen in the expected order, performed by an authorized party, with each step's output matching the next step's expected input."

The current pipeline has partial SLSA L2 and no formal in-toto layout at all. Both are addressed below.

## Path to SLSA Level 3

SLSA Level 3 requires the build to run in a **hardened, isolated build platform** where the provenance generation is controlled by infrastructure the source repository's own workflow file cannot influence or falsify  specifically, an ephemeral, isolated environment per build, with the provenance-signing step managed by a trusted control plane outside the repository's own scriptable workflow.

**Concrete approach:** adopt the `slsa-framework/slsa-github-generator` reusable workflow (or an equivalent trusted builder) rather than generating provenance from within the repository's own custom workflow steps. This project runs the actual provenance generation and signing in a separate, GitHub-hosted reusable workflow that the calling repository cannot modify  meaning even a fully compromised application repository (a malicious change to the workflow file itself) cannot forge or manipulate the resulting provenance, which is the specific property Level 2 lacks.

**What changes in the pipeline:**
1. Replace the current custom provenance-generation step with a call to the trusted generator's reusable workflow.
2. Confirm build hermeticity  the build step itself should not depend on unpinned, mutable external inputs (e.g., unpinned base images, unpinned action versions) during the build, since any unpinned input is a channel through which the build could be influenced even if the provenance generation itself is trustworthy.
3. Verify the resulting provenance includes the stronger non-falsifiable guarantees Level 3 requires (build parameters, materials list, builder identity) and that Kyverno's `verifyImages` policy (once upgraded per the note in `../architecture/threat-model.md`) can check against this stronger provenance, not just a signer annotation string.

## Path to Full in-toto Layout Implementation

### The Layout

An in-toto **layout** formally defines every step in the supply chain, who is authorized to perform each step, and what materials/products each step is expected to consume and produce. For this pipeline, the layout would define steps such as:

```text
Step 1: checkout  authorized: GitHub Actions runner identity
Step 2: sbom-generate  authorized: Syft, run as part of the pipeline
Step 3: vulnerability-scan  authorized: Trivy, run as part of the pipeline
Step 4: build  authorized: the pinned build step
Step 5: sign  authorized: Cosign keyless (Fulcio-issued identity)
```

Each step, once it runs, produces a signed **link metadata** file recording exactly what materials it consumed and what products it produced (e.g., step 4's link records the exact source commit hash it built from and the exact image digest it produced)  creating a verifiable chain where step 5's material must match step 4's product, and so on, all the way back to the original commit.

### Verification

At deployment time (or as part of the GitOps reconciliation flow in `gitops-integration.md`), `in-toto-verify` can check the complete chain of link metadata against the layout  confirming not just "the final image is signed" but "every step that was supposed to happen, happened, in order, by an authorized party, with each step's inputs and outputs matching the next." This is a materially stronger guarantee than final-artifact-only signing: it would, for example, catch a scenario where the SBOM was generated against a different commit than the one actually built  an inconsistency final-artifact signing alone would never surface.

### Functionary Identity

Each step's link metadata needs to be signed by an authorized "functionary" for that step. Consistent with the platform's existing preference for keyless signing (`../design-decisions/01-image-signing-cosign-keyless.md`), functionary identity for CI-driven steps should be rooted in the same GitHub Actions OIDC-derived identity used for Cosign, rather than introducing a separate, long-lived functionary keypair per step  keeping the "no standing private key to protect" property consistent across the whole chain rather than reintroducing it only at the in-toto layer.

## Implementation Plan

1. **Adopt the trusted SLSA L3 generator workflow** first, since it's the more self-contained change and directly closes the platform's most-cited documented gap.
2. **Audit and pin all build inputs** (base images, action versions, dependency sources) to achieve genuine build hermeticity  a prerequisite for Level 3's guarantees to actually hold in practice, not just on paper.
3. **Define the in-toto layout** covering the full pipeline (checkout → SBOM → scan → build → sign), starting with the steps that already exist rather than adding new ones simultaneously.
4. **Instrument each existing pipeline step to emit signed link metadata**, reusing OIDC-derived identity per step rather than static functionary keys.
5. **Add `in-toto-verify` as a gate**  initially informational/logged only, then promoted to a hard gate (failing the pipeline or blocking admission) once confidence in the layout's correctness is established.
6. **Update Kyverno's `verifyImages` policy** to check against the stronger provenance now available, closing the string-match gap noted in `../architecture/threat-model.md` as part of the same effort, since both changes touch the same verification surface.

## Relationship to Other Documents

- `../design-decisions/01-image-signing-cosign-keyless.md`  the existing keyless signing foundation this work builds on rather than replaces.
- `../architecture/threat-model.md` and `../limitations/known-limitations.md`  where the SLSA L2 ceiling and the `verifyImages` string-match gap are first documented as known limitations this work directly closes.
- `gitops-integration.md`  the GitOps reconciliation flow that `in-toto-verify` can be wired into as an additional deployment gate.
- `../design-decisions/02-admission-control-kyverno.md`  the admission-layer policy that needs updating once stronger provenance is available to check against.
