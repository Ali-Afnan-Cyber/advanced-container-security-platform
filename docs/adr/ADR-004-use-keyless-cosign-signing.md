# ADR-004: Use Sigstore Cosign Keyless Signing for Container Image Integrity

**Status:** Accepted

## Context

The project required a mechanism to establish the authenticity and integrity of container images before deployment into the Kubernetes environment.

The signing solution needed to:

- Verify that images originated from the project's CI/CD pipeline
- Prevent deployment of unsigned or untrusted images
- Integrate with Kubernetes admission policies
- Support automated signing within the CI/CD workflow
- Minimize operational overhead associated with key management

An early design considered traditional static signing keys. However, managing long-lived private keys introduces additional operational and security challenges, particularly in automated CI/CD environments.

These challenges include secure key generation, storage, rotation, distribution, backup, and protection against compromise. A leaked signing key could allow attackers to produce seemingly legitimate signed container images until the key is revoked.

---

## Options Considered

### Option 1 — No Image Signing

**Pros**

- Simplest implementation
- No additional tooling
- No key management

**Cons**

- No cryptographic proof of image authenticity
- Kubernetes cannot verify image origin
- Increased risk of deploying tampered or malicious images

---

### Option 2 — Static Key-Based Cosign Signing

**Pros**

- Mature and widely supported
- Cryptographic verification of container images
- Compatible with Kubernetes admission controllers

**Cons**

- Requires secure storage of private keys
- Key rotation introduces operational overhead
- Risk of long-lived credential compromise
- Additional secret management within CI/CD pipelines

---

### Option 3 — Sigstore Cosign Keyless Signing

**Pros**

- Eliminates long-lived private keys
- Uses GitHub OpenID Connect (OIDC) identity
- Short-lived certificates issued by Fulcio
- Transparency through the Rekor public log
- Reduced secret management
- Well aligned with modern software supply chain security practices

**Cons**

- Depends on external Sigstore infrastructure
- Requires OIDC-compatible CI/CD platform
- More complex trust model than traditional static keys

---

## Decision

The project will use **Sigstore Cosign Keyless Signing** for container image signing.

Rather than storing long-lived signing keys within the CI/CD environment, the pipeline authenticates using GitHub's OpenID Connect (OIDC) identity provider. Sigstore Fulcio issues a short-lived signing certificate that is used by Cosign to sign the container image.

The generated signature is recorded in the Rekor transparency log, allowing independent verification of both the image signature and the identity that produced it.

This approach significantly reduces operational overhead while improving the overall security posture of the software supply chain.

---

## Consequences

### Positive

- Eliminates management of long-lived signing keys
- Reduces secret storage requirements
- Provides cryptographic image integrity
- Enables Kubernetes admission policy verification
- Produces transparent and auditable signatures
- Integrates seamlessly with GitHub Actions through OIDC

### Negative

- Depends on Sigstore services (Fulcio and Rekor)
- Requires internet connectivity during signing and verification
- More difficult to understand than traditional key-based signing
- Not all container tooling fully supports keyless verification

---

## References

- https://www.sigstore.dev/
- https://docs.sigstore.dev/
- https://github.com/sigstore/cosign
- https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- https://slsa.dev/
