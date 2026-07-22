# GitOps Integration and Trivy Operator Automated Remediation

## Current State

Today, Trivy runs only in the CI pipeline, scanning an image once, at build time, before it's signed and pushed (`../design-decisions/01-image-signing-cosign-keyless.md`). Once a workload is deployed, there is no ongoing check for whether that same image has since become vulnerable  a CVE disclosed the day after deployment goes completely unnoticed by the platform until someone manually re-scans or redeploys. Separately, deployment itself is not GitOps-managed: manifests are applied directly (via `kubectl` or the CI pipeline pushing changes), meaning there's no single reconciliation loop guaranteeing the cluster's actual state matches what's declared in version control, and no built-in drift detection between the two.

This document covers both gaps together because the fix for one enables the fix for the other: continuous in-cluster vulnerability scanning (Trivy Operator) only becomes *actionable*  not just visible  once there's a GitOps reconciliation loop (ArgoCD or Flux) that can pick up a remediation change and apply it automatically.

## Part 1: Trivy Operator for Continuous In-Cluster Scanning

### What It Adds

The Trivy Operator runs inside the cluster itself, continuously scanning running workloads (not just images at build time) and producing Kubernetes-native custom resources  `VulnerabilityReport`, `ConfigAuditReport`, and related CRDs  for every scanned resource. This closes the gap between "scanned once, before deployment" and "continuously monitored for newly disclosed vulnerabilities in an already-running image."

This complements, rather than replaces, the CI-time Trivy scan (`../design-decisions/01-image-signing-cosign-keyless.md`): the CI scan is a gate before deployment; the Operator is ongoing surveillance after deployment.

### Automated Remediation Flow
