# Secrets Management

This document describes how secrets are currently handled across the platform, where the gaps are, and what a production-grade next step would look like.

## Current State

**Image signing (Cosign keyless).** As detailed in `../design-decisions/01-image-signing-cosign-keyless.md`, image signing deliberately avoids long-lived private key material entirely. Signing identity is rooted in a GitHub Actions OIDC token, exchanged for a short-lived certificate via Fulcio, used once, and discarded. This is the one part of the platform's secrets posture that is already close to a production-grade design  there is no Cosign private key sitting in a secret store to protect or rotate in the first place.

**Everything else runs on native Kubernetes Secrets.** This includes registry credentials for pulling images, the response engine's Kubernetes service account token (scoped per `../design-decisions/04-response-engine-custom-flask.md`), and any credentials used by the observability stack (e.g. Grafana admin credentials, data source connection details).

Kubernetes Secrets, used as-is, have well-known limitations:
- **Base64 is not encryption.** By default, Secret values are only base64-encoded in etcd, not encrypted  anyone with read access to etcd (or a backup of it) can trivially recover plaintext values unless encryption-at-rest has been separately configured.
- **No rotation policy.** Secrets are created once and persist indefinitely; there is no mechanism currently in place to rotate registry credentials, service account tokens, or dashboard credentials on a schedule.
- **No centralized audit trail for secret access.** Kubernetes' native audit logging can capture API-level access to Secret objects, but there is no dedicated secrets-access audit layer distinguishing "someone read this Secret" from ordinary API traffic.
- **Single-node exposure.** As noted throughout `../architecture/trust-boundaries.md`, this platform's single-node design means etcd, the workloads, and everything else are co-located  a node-level compromise has a direct path to every Secret stored in etcd, encrypted-at-rest or not, if the encryption key itself is also on that node.

## Gaps, Summarized

| Gap | Risk |
|---|---|
| No etcd encryption-at-rest confirmed/enforced | Secret values recoverable in plaintext from an etcd snapshot or direct access |
| No secret rotation | A leaked credential (registry, service account token) remains valid indefinitely until manually rotated |
| No centralized secrets audit | Harder to answer "was this secret accessed, by what, and when" during an incident |
| Secrets management is not GitOps-friendly | Secret values can't be safely committed alongside the rest of the platform's version-controlled configuration, creating a gap between what's in git and what's actually deployed |

## Next Step: Vault or Sealed Secrets

Two credible, commonly adopted paths forward, with different trade-offs:

**HashiCorp Vault**
- Centralized secret storage with fine-grained access policies, full audit logging of every secret read, and support for **dynamic secrets**  e.g. short-lived, auto-generated credentials issued per-request rather than long-lived static ones (directly analogous to the keyless-signing philosophy already applied to Cosign).
- Higher operational overhead: Vault itself needs to be deployed, unsealed, and kept highly available  introducing a new critical component that would itself need the HA treatment described in `high-availability.md`.
- The stronger long-term choice if the platform's secret surface grows (more services, more credential types, a need for dynamic database credentials, etc.).

**Sealed Secrets (Bitnami)**
- A much lighter-weight approach: secrets are encrypted client-side against a cluster-specific public key, producing a `SealedSecret` object that is safe to commit directly to git. The in-cluster controller decrypts it back into a normal Kubernetes Secret at apply time.
- Solves the GitOps gap directly  secrets become part of the same version-controlled, auditable deployment flow as everything else in the platform (mirroring the "policy as native YAML" reasoning behind choosing Kyverno in `../design-decisions/02-admission-control-kyverno.md`).
- Does not solve rotation or dynamic secret issuance  it's fundamentally still a static secret, just safely encrypted at rest in git. Underlying Kubernetes Secret encryption-at-rest in etcd is still a separate, unaddressed concern.

**Recommended framing:** Sealed Secrets is the lower-effort, immediately achievable improvement that closes the GitOps and at-rest-in-git gap with minimal new operational surface. Vault is the more complete long-term answer, but its own HA and operational requirements make it a larger undertaking  appropriate once the platform's secret surface or team size grows enough to justify it.

## Relationship to Other Documents

- `../design-decisions/01-image-signing-cosign-keyless.md`  the one part of the secrets story already handled with a production-appropriate pattern (short-lived, keyless credentials).
- `../architecture/trust-boundaries.md`  why single-node co-location makes secret exposure a cluster-wide concern rather than a contained one.
- `high-availability.md`  relevant if Vault is chosen, since Vault itself becomes a new component requiring HA.
