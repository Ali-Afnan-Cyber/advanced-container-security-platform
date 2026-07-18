# ADR-003: Handling Unfixed CRITICAL Vulnerabilities in Trivy Scans

**Status:** Accepted

## Context

The pipeline's Trivy scan stage is configured to fail the build (`exit-code: 1`) whenever a CRITICAL vulnerability is detected in the container image, covering both OS packages and application libraries (`vuln-type: os,library`).

During implementation, this policy consistently and permanently blocked every build. Trivy reported three CRITICAL vulnerabilities in the Debian `perl-base` package, inherited from the official `python:3.12-slim` base image. Investigation showed:

- The application's own Python dependencies scanned clean — zero vulnerabilities.
- The vulnerabilities originated entirely from the OS layer of the base image.
- No patched version of the affected Debian packages was available upstream at the time.

Because no fix existed to apply, the build could not be remediated by any change within the project's control. A strict fail-on-any-CRITICAL policy meant software delivery was permanently blocked without any corresponding improvement to the security posture of the application.

A decision was required on how to handle CRITICAL vulnerabilities that have no available upstream fix, without weakening the pipeline's ability to catch vulnerabilities that *can* be fixed.

---

## Options Considered

### Option 1 — Keep strict fail-on-any-CRITICAL policy

**Pros**

- Simplest possible policy — zero tolerance
- No risk of an unfixed CRITICAL slipping through unnoticed

**Cons**

- Blocks all delivery indefinitely whenever an unfixable upstream CVE exists
- Provides no path forward until the base image vendor ships a patch
- Does not distinguish between vulnerabilities the team can act on and those it can't
- Encourages workarounds like disabling scanning entirely, which is worse

---

### Option 2 — Ignore all CRITICAL vulnerabilities in the base OS layer

**Pros**

- Would unblock the build immediately
- Simple to configure (`vuln-type: library` only)

**Cons**

- Blind to future fixable OS-level CRITICAL vulnerabilities
- Removes OS scanning coverage entirely, not just the unfixable subset
- Far too broad a trade-off for a narrow, temporary problem

---

### Option 3 — Pin to a different base image without the affected package

**Pros**

- Could eliminate the specific vulnerable package
- No pipeline policy change required

**Cons**

- No guarantee an alternative base image avoids all unfixed CVEs long-term
- Base image churn introduces its own compatibility and maintenance risk
- Treats a symptom rather than the underlying policy gap (unfixed CVEs will recur)

---

### Option 4 — Enable Trivy's `ignore-unfixed` flag

**Pros**

- Continues scanning and reporting all vulnerabilities, fixed or not
- Blocks the build only on CRITICAL vulnerabilities that have an available fix
- Directly targets the actual problem: builds blocked with no remediation path
- Native, well-supported Trivy option — no custom logic required
- Unfixed vulnerabilities remain visible in the full JSON report artifact for tracking

**Cons**

- Requires discipline to periodically revisit, since "unfixed" status can change
- A CRITICAL vulnerability with no fix today could still represent real risk left unblocked

---

## Decision

The pipeline enables `ignore-unfixed: true` on the blocking Trivy scan stage.

This changes the enforcement policy to:

- **Block** the build on any CRITICAL vulnerability that has a fix available.
- **Continue reporting** CRITICAL vulnerabilities with no available fix, without blocking the build.

This is not a reduction in scanning scope. Trivy still scans every OS package and application dependency on every run via the separate non-blocking JSON report stage, and the blocking scan still fails on anything the team could actually remediate. The policy only stops failing on vulnerabilities that are, by definition, unpatchable at build time.

---

## Consequences

### Positive

- Software delivery is no longer blocked by vulnerabilities outside the team's control
- Fixable CRITICAL vulnerabilities still fail the build, preserving the pipeline's core security gate
- Full vulnerability visibility is preserved via the uploaded Trivy JSON report, regardless of fix availability
- Policy is explicit and documented, rather than an undocumented workaround

### Negative

- Unfixed CRITICAL vulnerabilities can reach production without blocking, relying on the JSON report being actively reviewed
- The flag must be revisited whenever the base image is updated or patches become available upstream, or stale exceptions could persist unnoticed
- Adds a policy nuance that must be understood by anyone modifying the pipeline in the future

---

## References

- https://aquasecurity.github.io/trivy/latest/docs/configuration/filtering/#by-status
- https://github.com/aquasecurity/trivy-action
- https://www.debian.org/security/
