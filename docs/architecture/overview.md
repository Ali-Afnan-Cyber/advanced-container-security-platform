# Architecture Overview

## 1. Problem Statement

Most container security implementations stop at image scanning in CI. In practice, the attack surface spans the full container lifecycle: what gets built, whether it can be trusted, what is allowed to run, what happens once it's running, and what happens when something goes wrong. Treating any single control (a scanner, a network policy, an IDS) as sufficient leaves the other stages unprotected.

This platform implements defense-in-depth across five independent layers on a single-node K3s cluster, with each layer designed to hold even if an earlier layer fails or is bypassed. It is built as a lab-grade platform — the constraints of a single node are treated honestly rather than hidden, and every design decision is defensible on its own trade-offs.

## 2. Goals

- Defense-in-depth across five independently operating layers, from build to runtime.
- Verifiable image provenance using keyless signing (Cosign) and a public transparency log (Rekor).
- Policy-enforced admission control that rejects non-compliant workloads before they run.
- Real-time runtime threat detection at the kernel level using eBPF (Falco).
- Automated, auditable incident response rather than alert-only monitoring.
- Full observability and compliance evidence (metrics, logs, CIS benchmarking, config validation).
- Honest documentation of every architectural gap, rather than overclaiming coverage.

## 3. Non-Goals

- **High availability / disaster recovery** — this is a single-node cluster with no node failover and no persistent volume backing for Loki/Prometheus.
- **Cryptographic signature verification at admission** — Kyverno's `verifyImages` check is currently string-match against an expected signer annotation, not a live cryptographic check against the Fulcio/Rekor chain. Documented in `threat-model.md`.
- **SLSA Level 3 provenance** — the pipeline currently achieves SLSA Level 2 (signed provenance, hosted build), not Level 3 (isolated/hermetic builds).
- **SIEM-grade correlation** — Loki/Grafana provide log aggregation and dashboards, not multi-source correlation or long-term retention.
- **Autonomous ML enforcement** — the Isolation Forest service is intelligence-only. It has no authority to terminate, quarantine, or otherwise act on a workload.
- **Multi-tenant isolation** — this is a single-tenant platform; no namespace-level tenant boundary hardening is in scope.

## 4. High-Level Architecture

    SUPPLY CHAIN (CI)
    GitHub Actions → Syft (SBOM) → Trivy (scan) → Cosign (sign, keyless/OIDC) → Registry push → Rekor (transparency log entry) 

 ↓ image reference + attestations

    ADMISSION CONTROL (K3s API)
    Kyverno ClusterPolicies + Pod Security Standards
    (Restricted profile, verifyImages check)

 ↓ pod scheduled

    RUNTIME DETECTION (Node)
    Falco 0.43.1 — modern eBPF probe, custom rules

 ↓ security event

    AUTOMATED RESPONSE ENGINE
    Custom Python/Flask service — terminate / quarantine

 ↓ actions + events

    OBSERVABILITY & COMPLIANCE LAYER
    Prometheus (metrics) · Grafana (dashboards) · Loki (logs)
    kube-bench (CIS) · Polaris (config posture)
  
 ↓ metrics + logs (read-only)

    INTELLIGENCE LAYER (advisory only, no enforcement)
    Isolation Forest anomaly detection service

## 5. Five-Layer Defense-in-Depth Summary

| Layer | Function | Primary Tooling |
|---|---|---|
| 1. Supply Chain Security | Ensures every image is scanned, has an SBOM, and is signed with verifiable provenance before it can be deployed | GitHub Actions, Syft, Trivy, Cosign (keyless), Rekor, SLSA L2 |
| 2. Admission Control | Blocks non-compliant workloads at the Kubernetes API before a pod is ever scheduled | Kyverno ClusterPolicies, Pod Security Standards (Restricted) |
| 3. Runtime Detection | Observes live container behavior at the kernel level and flags anomalous activity | Falco 0.43.1 (modern eBPF), custom rule set |
| 4. Automated Response | Converts detection events into action — termination or quarantine — without waiting on a human | Custom Python/Flask response engine |
| 5. Observability & Compliance | Provides metrics, logs, and compliance evidence across all other layers | Prometheus, Grafana, Loki, kube-bench, Polaris |

A sixth, non-enforcing layer — an Isolation Forest ML service — sits alongside these five as an advisory intelligence source, surfacing anomalies for human review without enforcement authority of its own.
