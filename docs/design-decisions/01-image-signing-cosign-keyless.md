# 01. Image Signing: Cosign Keyless

## Context

Every image built by the pipeline needs a way to prove, later, that it came from this pipeline and hasn't been substituted or tampered with between build and deployment. That proof needs to survive being checked by something other than the pipeline itself   ultimately, at admission time, by Kyverno.

The traditional way to do this is public-key signing: generate a keypair, sign the image digest with the private key, distribute the public key to whatever needs to verify it. That's a well-understood model, but it comes with a well-understood operational problem: the private key has to live somewhere, and wherever it lives is now a standing secret that has to be protected, rotated, and eventually explained in an incident report if it leaks.

## Decision

Use **Cosign in keyless mode**, backed by Sigstore's Fulcio (short-lived certificate issuance) and Rekor (public transparency log), with signing identity rooted in the GitHub Actions OIDC token issued to the specific workflow run that builds the image.

The flow: GitHub Actions issues an OIDC token scoped to the running workflow → Fulcio exchanges that token for a short-lived (minutes-long) signing certificate binding the identity to that specific workflow run → Cosign uses the ephemeral keypair to sign the image digest → the signature, certificate, and image digest are recorded as a public entry in Rekor → the certificate and private key are discarded immediately after signing.

## Alternatives Considered

**Long-lived keypair (traditional Cosign, key-based).** Simpler to reason about at a glance   one public key, checked everywhere. Rejected because the private key becomes a permanent secret with its own lifecycle: it has to be stored (in GitHub Secrets, a KMS, or a vault), rotated on a schedule, and revoked and re-distributed everywhere if it's ever suspected of compromise. For a small platform without a dedicated secrets management team, this is a standing liability that keyless signing removes entirely.

**No signing, scan-only.** Trivy scanning alone would catch known vulnerabilities but says nothing about *provenance*   it can't answer "did this image actually come from our pipeline, unmodified." Rejected because provenance and vulnerability status are different questions, and admission control needs an answer to the first one that scanning can't provide.

**Notary / Notary v2 (TUF-based signing).** A legitimate alternative with a different trust model (delegation-based, not identity-based). Rejected primarily on integration maturity with the rest of the chosen toolchain (Kyverno's native Cosign-annotation support) and on the operational simplicity of Sigstore's keyless flow for a single small team, rather than any correctness objection to Notary itself.

## Trade-offs

**Gained:**
- No private key to store, rotate, or leak. The signing identity is only as long-lived as a single CI run.
- Signatures are cryptographically bound to a specific workflow run's OIDC identity, not to a reusable secret   a leaked GitHub Actions log can't be replayed to forge a valid signature after the fact.
- Rekor's public transparency log means a signature's existence is independently auditable outside the platform's own infrastructure   even if the platform's records were altered, Rekor's entry stands.

**Given up:**
- **Dependency on Sigstore's public infrastructure.** Fulcio and Rekor are external services the pipeline depends on at build time. An outage there blocks the ability to sign new images (though it doesn't affect verification of already-signed images already recorded in Rekor).
- **The signature is only as trustworthy as the OIDC token issuer.** Trust is rooted in GitHub Actions' OIDC implementation   a flaw or compromise there would undermine every signature issued through it, in a way that's outside this platform's direct control.
- **Verification at admission is not yet re-checking the live chain.** As documented in `threat-model.md`, Kyverno's current `verifyImages` rule checks a signer identity annotation rather than performing a live cryptographic verification against Fulcio/Rekor at admission time. The keyless signing infrastructure is in place and correct; the gap is on the *verification* side, not the *signing* side, and is tracked as a known follow-on improvement.
