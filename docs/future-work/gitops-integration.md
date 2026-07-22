# GitOps Integration and Trivy Operator Automated Remediation

## Current State

Today, Trivy runs only in the CI pipeline, scanning an image once, at build time, before it's signed and pushed (`../design-decisions/01-image-signing-cosign-keyless.md`). Once a workload is deployed, there is no ongoing check for whether that same image has since become vulnerable  a CVE disclosed the day after deployment goes completely unnoticed by the platform until someone manually re-scans or redeploys. Separately, deployment itself is not GitOps-managed: manifests are applied directly (via `kubectl` or the CI pipeline pushing changes), meaning there's no single reconciliation loop guaranteeing the cluster's actual state matches what's declared in version control, and no built-in drift detection between the two.

This document covers both gaps together because the fix for one enables the fix for the other: continuous in-cluster vulnerability scanning (Trivy Operator) only becomes *actionable*  not just visible  once there's a GitOps reconciliation loop (ArgoCD or Flux) that can pick up a remediation change and apply it automatically.

## Part 1: Trivy Operator for Continuous In-Cluster Scanning

### What It Adds

The Trivy Operator runs inside the cluster itself, continuously scanning running workloads (not just images at build time) and producing Kubernetes-native custom resources  `VulnerabilityReport`, `ConfigAuditReport`, and related CRDs  for every scanned resource. This closes the gap between "scanned once, before deployment" and "continuously monitored for newly disclosed vulnerabilities in an already-running image."

This complements, rather than replaces, the CI-time Trivy scan (`../design-decisions/01-image-signing-cosign-keyless.md`): the CI scan is a gate before deployment; the Operator is ongoing surveillance after deployment.

### Automated Remediation Flow

```text
Trivy Operator detects new CRITICAL CVE
in a running image (via VulnerabilityReport)
│
▼
Remediation trigger (webhook or controller watching VulnerabilityReport CRDs)
│
▼
Automated pull request opened against the GitOps repo

bumps the image tag/digest to a patched version, if available
OR flags the workload for manual review if no patched version exists yet
│
▼
Human review / approval gate (required for anything beyond a patch-version bump)
│
▼
Merge to the GitOps repo's tracked branch
│
▼
ArgoCD/Flux detects the change and reconciles the cluster to match
│
▼
Old pod rotated out, new (patched) pod rolled in
│
▼
Trivy Operator re-scans, confirms the CVE is resolved
```
### Why a Human Approval Gate Is Required

Consistent with the false-positive/kill trade-off reasoning already established for the response engine (`../design-decisions/04-response-engine-custom-flask.md`), fully automatic image bumps carry real risk: a patched base image could introduce a breaking change, and blindly auto-merging every CVE-driven bump risks an outage in the name of a security fix. The proposed flow treats a **patch-version bump** (same major/minor version, patch-level only) as low-risk enough to potentially auto-merge once tooling maturity justifies it, but treats anything else  a minor/major version bump, or a CVE with no available patched version at all  as requiring explicit human review before merge, every time.

## Part 2: GitOps via ArgoCD or Flux

### Why GitOps at All

Right now, the cluster's actual running state and the version-controlled manifests describing it can silently diverge  someone can `kubectl apply` a manual change that never makes it back into git, and nothing detects or corrects that drift. GitOps closes this gap by making git the single source of truth: a controller inside the cluster continuously reconciles the live state to match what's declared in the repository, and any manual drift is either automatically reverted or explicitly flagged, depending on configuration.

This isn't only an operational-convenience improvement  it directly strengthens the platform's audit story. Every change to what's actually running becomes a git commit, reviewable and attributable, rather than an untracked `kubectl` command run by whoever had cluster access at the time.

### ArgoCD vs. Flux  Considerations

| Consideration | ArgoCD | Flux |
|---|---|---|
| UI | Built-in web UI for visualizing sync state, diffs, and application health | Primarily CLI/CRD-driven; UI exists via separate tooling (e.g., Weave GitOps) |
| Multi-tenancy model | `Application` and `AppProject` CRDs, well-suited to managing many apps from one control plane | Similarly capable via `Kustomization`/`HelmRelease` CRDs, slightly more composable/unix-philosophy in structure |
| Image update automation | ArgoCD Image Updater (separate component) can automate image tag bumps directly | Flux's Image Automation Controller offers similar native image-bump automation |
| Fit with this platform | The built-in UI adds observability value on a single-operator platform where a dashboard view of sync state is genuinely useful (fits its already-strong Grafana dashboarding culture, `../design-decisions/06-observability-stack.md`) | Slightly lighter-weight footprint, which may matter more once genuinely resource-constrained (relevant to the single-node reality, `../design-decisions/07-single-node-k3s-tradeoffs.md`) |

**Recommended direction:** ArgoCD, primarily for the built-in visualization of sync/drift state, which fits this platform's existing emphasis on dashboard-based observability. This is a reasonable default rather than a settled decision  either tool satisfies the core reconciliation requirement, and the choice should be revisited if resource footprint becomes the binding constraint on the current single-node cluster.

### Integration with Existing Admission Control

GitOps reconciliation applies manifests to the cluster the same way any other actor would  meaning every GitOps-applied change still passes through Kyverno admission control and Pod Security Standards exactly as before (`../design-decisions/02-admission-control-kyverno.md`). GitOps doesn't bypass or weaken admission control; it changes *how* manifests arrive at the API server, not what happens once they do.

## Implementation Plan

1. **Stand up the GitOps repository structure** first (separate from or as a directory within the application repository), defining the declarative source of truth before automating anything on top of it.
2. **Deploy ArgoCD (or Flux)** and point it at the GitOps repo, initially in a manual-sync or dry-run mode to validate reconciliation behavior without risking unexpected automatic changes.
3. **Deploy the Trivy Operator** and confirm `VulnerabilityReport` generation against existing running workloads, without any remediation automation yet  establish visibility before automation.
4. **Build the remediation trigger** (webhook or controller) that opens a pull request against the GitOps repo on a new CRITICAL finding, with every merge requiring human review initially.
5. **Only after the manual-approval flow has been proven reliable**, evaluate enabling auto-merge for the narrow patch-version-bump case described above.
6. **Move ArgoCD/Flux to full automatic sync** once confidence in the reconciliation and remediation flow is established.

## Relationship to Other Documents

- `../design-decisions/01-image-signing-cosign-keyless.md`  the existing CI-time Trivy scan this Operator-based approach complements.
- `../design-decisions/04-response-engine-custom-flask.md`  the precedent for requiring a human gate before any high-impact automated action.
- `../production/secrets-management.md`  Sealed Secrets, discussed there, becomes directly relevant once GitOps means secrets need to be safely committed to the same repository as everything else.
- `slsa-level-3.md`  a GitOps-managed deployment flow strengthens the auditability story that SLSA Level 3 and in-toto also depend on.
