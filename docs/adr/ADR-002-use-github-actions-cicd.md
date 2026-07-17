# ADR-002: Use GitHub Actions as the CI/CD and Supply Chain Automation Platform

**Status:** Accepted

## Context

The project required an automated CI/CD pipeline capable of building container images, enforcing vulnerability scanning, generating software supply chain metadata, signing container images, and producing provenance attestations.

The selected platform also needed to integrate directly with the project's GitHub repository, support modern identity-based authentication, and execute security controls without requiring dedicated build infrastructure.

Key requirements included:

- Automated execution on source code changes
- Container image build and publishing
- Vulnerability scanning with policy enforcement
- Software Bill of Materials (SBOM) generation
- Keyless image signing using Sigstore Cosign
- SLSA provenance generation
- Secure secret management
- Minimal operational overhead

---

## Options Considered

### Option 1 — Jenkins

**Pros**

- Highly customizable
- Extensive plugin ecosystem
- Widely adopted in enterprise environments
- Supports complex pipeline workflows

**Cons**

- Requires dedicated infrastructure
- Ongoing maintenance and plugin management
- Greater operational complexity
- Higher administrative overhead for a single-project environment

---

### Option 2 — GitLab CI/CD

**Pros**

- Integrated DevOps platform
- Strong CI/CD capabilities
- Built-in security features
- Excellent pipeline visualization

**Cons**

- Best suited for GitLab-hosted repositories
- Additional migration effort required
- Limited benefit for a GitHub-based project

---

### Option 3 — Azure DevOps Pipelines

**Pros**

- Enterprise-grade CI/CD
- Strong Microsoft ecosystem integration
- Advanced deployment capabilities

**Cons**

- Additional configuration complexity
- Better aligned with Azure-centric environments
- Less seamless integration with GitHub-hosted workflows

---

### Option 4 — CircleCI

**Pros**

- Fast cloud-hosted runners
- Good Docker support
- Mature pipeline features

**Cons**

- Separate platform and account management
- Usage limitations under free plans
- Less integrated developer experience compared to GitHub Actions

---

### Option 5 — GitHub Actions

**Pros**

- Native integration with GitHub repositories
- Event-driven workflow automation
- Hosted runners requiring no infrastructure management
- Secure secret management
- OpenID Connect (OIDC) support for keyless authentication
- Large ecosystem of reusable actions
- Direct integration with Sigstore, Docker, Trivy, and artifact storage

**Cons**

- Limited runner resources compared to dedicated infrastructure
- Workflow execution quotas under free plans
- Vendor-specific workflow syntax

---

## Decision

The project will use **GitHub Actions** as the CI/CD and supply chain automation platform.

The repository is hosted on GitHub, making GitHub Actions the most practical solution due to its native integration, hosted execution environment, and extensive ecosystem of reusable actions.

The workflow automates the complete secure container lifecycle by:

- Building Docker images
- Performing vulnerability scanning using Trivy
- Blocking builds containing critical vulnerabilities
- Publishing trusted container images
- Signing images using Sigstore Cosign with GitHub OIDC
- Generating SPDX Software Bills of Materials (SBOMs)
- Creating SLSA provenance attestations
- Uploading build artifacts for auditing and traceability
- Verifying signatures against the Sigstore Rekor transparency log

This decision minimizes infrastructure management while providing a reproducible, security-focused CI/CD pipeline aligned with modern software supply chain security practices.

---

## Consequences

### Positive

- Fully automated build pipeline
- Native integration with the source repository
- No self-hosted build infrastructure required
- Security validation occurs before deployment
- Automated generation of SBOM and provenance artifacts
- Supports Sigstore keyless signing through GitHub OIDC
- Improves software supply chain integrity and traceability

### Negative

- Dependent on GitHub-hosted infrastructure
- Workflow syntax is platform-specific
- Runner resource limits may impact larger workloads
- Advanced enterprise capabilities require higher-tier GitHub plans

---

## References

- https://docs.github.com/actions
- https://github.com/features/actions
- https://www.jenkins.io/
- https://docs.gitlab.com/ee/ci/
- https://circleci.com/docs/
- https://learn.microsoft.com/azure/devops/pipelines/
- https://slsa.dev/
- https://www.sigstore.dev/
