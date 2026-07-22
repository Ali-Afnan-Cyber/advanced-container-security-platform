# Compliance and Governance

**The compliance evidence half of Layer 5**  automated scoring against a named external standard (CIS, via kube-bench), workload-level configuration governance (Polaris), Kubernetes' own built-in namespace enforcement (Pod Security Standards), and a full crosswalk of every platform control against four external frameworks: **NIST SP 800-190**, **NIST CSF 2.0**, **DORA**, and **HIPAA**.

Where `monitoring/` gives visibility into what's *happening* live, this directory gives evidence of what's *configured correctly* and how that evidence maps to recognized external requirements  a different question, answered by different tooling, and (in the case of the framework mapping) not a piece of tooling at all, but a deliberate documentation exercise.

---

## At a Glance

| Tool / Artifact | Question it answers | Scope | Output |
|---|---|---|---|
| kube-bench | Is the cluster's own configuration CIS-compliant? | Node + control-plane level | Pass/Fail/Warn per CIS control, in a Job's logs |
| Polaris | Is each running workload configured well? | Per-workload | 0–100 score, per-namespace dashboard |
| Pod Security Standards | Is this namespace enforcing a baseline security posture? | Per-namespace | Kubernetes-native admission enforcement |
| Framework mapping | How does every implemented (and every missing) control map to NIST 800-190 / CSF 2.0 / DORA / HIPAA? | Platform-wide | This document's [Framework Mapping](#framework-mapping) section |

These overlap deliberately, not redundantly: kube-bench checks the Kubernetes distribution itself; Polaris checks the workloads running inside it; PSS enforces a baseline continuously regardless of whether a scan ever runs; the framework mapping ties all of it  plus every other layer of the platform  back to language auditors and regulators actually use. See `../docs/design-decisions/06-observability-stack.md` for why kube-bench and Polaris were chosen as a pair.

---

## kube-bench  CIS Kubernetes Benchmark

Runs the CIS Kubernetes Benchmark, version **1.8**, as a one-shot `Job` in `kube-system`, checking well over 100 individual controls spanning control-plane configuration, kubelet configuration, etcd, and file permissions across the node.

**What it mounts, and why.** The Job runs with `hostPID`, `hostIPC`, and `hostNetwork` all set to `true`, and mounts eight host paths read-only: `/var/lib/etcd`, `/var/lib/kubelet`, `/etc/systemd`, `/lib/systemd`, `/etc/kubernetes`, `/usr/local/bin` (mounted at `/usr/local/mount-from-host/bin`), `/etc/cni/net.d`, and `/opt/cni/bin`. This is the maximum host-visibility posture a Kubernetes workload can reasonably request  appropriate here because kube-bench's entire job is to inspect the actual on-disk configuration of the control plane, kubelet, and etcd, which isn't visible through the Kubernetes API at all. This is a deliberate, narrow exception to the platform's otherwise strict "no privileged/host-namespace workloads" posture (`../kyverno/README.md`'s `disallow-privileged-containers` and PSS Restricted), justified by the job's function and its `restartPolicy: Never`, one-shot nature  it isn't a standing privileged workload.

**Run it:**

```bash
kubectl apply -f compliance/kube-bench-job.yaml -n kube-system
kubectl logs job/kube-bench -n kube-system | grep TOTAL
```

**Read the full breakdown**, not just the totals, when investigating a specific control:

```bash
kubectl logs job/kube-bench -n kube-system
```

---

## Polaris  Workload Governance

Deployed via the `fairwinds-stable/polaris` Helm chart, scoring every running workload from 0–100 against configuration best practices: resource limits, root containers, host network usage, and missing health probes.

```yaml
dashboard:
  enable: true
  service:
    type: NodePort
    nodePort: 30500
webhook:
  enable: false
audit:
  enable: false
```

**`webhook.enable: false` and `audit.enable: false` are both worth noting precisely.** Polaris supports running as an admission webhook (blocking non-compliant workloads at deploy time, functionally overlapping with what Kyverno already does) and as a scheduled audit job. Both are explicitly off here  Polaris in this platform runs purely as a **passive, dashboard-only scorer**, not an enforcement mechanism and not a scheduled scanner. Its dashboard reflects live cluster state on page load, not a periodic scan history. This is a sound division of labor (Kyverno enforces, Polaris scores) but means Polaris contributes no blocking control of its own  its entire value here is visibility and scoring, not prevention.

```bash
helm install polaris fairwinds-stable/polaris \
  --namespace polaris --create-namespace -f compliance/polaris-values.yaml
# Dashboard: http://<node-ip>:30500
```

---

## Pod Security Standards

Kubernetes' built-in, namespace-level admission enforcement, applied across all four platform namespaces:

| Namespace | Level | Rationale |
|---|---|---|
| `default` | Restricted | Workload namespace  strictest available profile |
| `falco` | Privileged | Falco requires host-level syscall visibility (eBPF probes, kernel access) that the Restricted or Baseline profiles would block outright |
| `monitoring` | Privileged | Prometheus/Loki/Grafana/Promtail's DaemonSet (host-path mounts for the audit log, per `../monitoring/README.md`) requires host-level access incompatible with a stricter profile |
| `falco-talon` | Baseline | An intermediate profile  less permissive than Privileged, but not yet hardened to Restricted |

**Read this table precisely, not optimistically.** Only `default` runs at Restricted  the platform's strictest profile applies to exactly one of four namespaces. `demo-sec`, the namespace referenced throughout `../kyverno/README.md`, `../falco/README.md`, and `../response-engine/README.md` as the platform's actual enforcement scope, does not appear in this table at all  either it inherits `default`'s labeling, is missing a PSS label entirely (falling back to the cluster's baseline default, which may not be Restricted), or this table is incomplete. This should be verified directly (`kubectl get ns demo-sec -o jsonpath='{.metadata.labels}'`) rather than assumed, since it directly affects whether `demo-sec`  the platform's primary target namespace  actually has PSS enforcement at all.

**Three of four namespaces run Privileged or Baseline, not Restricted, and for defensible reasons**  Falco and the monitoring DaemonSet genuinely need host-level access to do their jobs. This is worth stating as a deliberate trade-off rather than a gap: the platform's security tooling itself needs privileges the workloads it protects are correctly denied.

---

## Framework Mapping

This section is the full crosswalk of platform controls against four external frameworks, reproduced from the platform's framework mapping worksheet. **Status** values are used consistently across all four frameworks:

- **Implemented**  the control exists and functions as described, verifiable in this repository.
- **Partial**  a real but incomplete implementation; the gap is named explicitly.
- **Designed**  planned and reasoned about, not yet built.
- **Missing**  not implemented; where a production remediation exists elsewhere in this documentation, it's linked directly.
- **Not Applicable**  outside this platform's technical scope entirely (organizational, physical, or legal controls no Kubernetes platform can satisfy on its own).

### NIST SP 800-190 (Application Container Security Guide)

*A cybersecurity guideline providing best practices for securing containerized applications and container environments.*

| Category | Control | Our Implementation | Status |
|---|---|---|---|
| Image Security | Vulnerability scanning before deployment | Trivy gate (CRITICAL severity, exit-code 1) in the GitHub Actions pipeline | **Implemented** |
| Image Security | Multi-scanner strategy | Trivy implemented; Grype and Clair designed but not implemented | **Partial** |
| Image Security | Image signing and integrity verification | Cosign keyless signing → Fulcio → Rekor; signature verified at the end of the pipeline | **Implemented** |
| Image Security | SBOM generation and tracking | Syft generates an SPDX-JSON SBOM, attested via Cosign, stored in Rekor | **Implemented** |
| Image Security | Minimal base images / non-root | Multi-stage Dockerfile, non-root `appuser` | **Implemented** |
| Image Security | Image tag immutability | Images signed and referenced by digest (`sha256:...`), not by mutable tag | **Implemented** |
| Registry Security | Continuous vulnerability monitoring on running images | No Trivy Operator scanning already-running workloads | **Missing** → [`../docs/future-work/gitops-integration.md`](../docs/future-work/gitops-integration.md) |
| Registry Security | Trusted registry enforcement | Kyverno string-match allows only `ali20052025/secure-app` | **Partial**  not cryptographic |
| Orchestrator Security | Cryptographic admission verification | `verifyImages` rule not implemented; current check is string-match only against an image reference, not a signature | **Missing** → [`../kyverno/README.md`](../kyverno/README.md#known-gaps--hardening-notes) |
| Container Runtime | Runtime threat detection | Falco, modern eBPF, 11 custom rules across syscall and audit layers | **Implemented** |
| Container Runtime | Container escape detection | `setns`, `unshare`, `mount`, `pivot_root` rules  all CRITICAL | **Implemented** |
| Container Runtime | Privilege escalation detection | `setuid`/`setgid`/`capset` rules  WARNING priority | **Implemented** |
| Container Runtime | Anomaly detection / behavioral analysis | Isolation Forest ML service, 5-feature vector, per-container baseline | **Implemented** |
| Container Runtime | Automated threat response | Python response engine  terminate (syscall-tier rules) or label-based quarantine (audit-tier rules) | **Implemented** |
| Orchestrator Security | Container isolation / resource limits | PSS Restricted + Kyverno `require-resource-limits` (Enforce) | **Implemented** |
| Orchestrator Security | RBAC least privilege | Service accounts scoped per namespace; response engine RBAC limited to `demo-sec` | **Implemented** |

### NIST CSF 2.0 (Cybersecurity Framework)

*A cybersecurity framework that helps organizations manage, reduce, and improve cybersecurity risk through a structured, risk-based approach  organized around six functions.*

**GOVERN**

| Control | Our Implementation | Status |
|---|---|---|
| Security policy documentation | Five platform security policies defined (image acceptance, runtime, network, audit, least privilege) | **Implemented** |
| Roles and responsibilities | Service accounts, RBAC roles, and namespace boundaries defined | **Implemented** |
| Supply chain risk management | Cosign signing, Trivy scanning, SLSA Level 2 provenance, SBOM | **Implemented** |
| Risk assessment process | No formal, documented risk assessment process | **Missing** → [`../docs/future-work/slsa-level-3.md`](../docs/future-work/slsa-level-3.md) (supply-chain risk); broader risk register not yet scoped |

**IDENTIFY**

| Control | Our Implementation | Status |
|---|---|---|
| Asset inventory | SBOM provides a software component inventory per image | **Implemented** |
| Vulnerability identification | Trivy pipeline scanning, Polaris workload scoring, kube-bench CIS | **Implemented** |
| Configuration assessment | Polaris (workload scoring), kube-bench (cluster configuration) | **Implemented** |
| Continuous asset monitoring | No Trivy Operator for continuous runtime CVE discovery | **Missing** → [`../docs/future-work/gitops-integration.md`](../docs/future-work/gitops-integration.md) |

**PROTECT**

| Control | Our Implementation | Status |
|---|---|---|
| Access control / least privilege | PSS Restricted, Kyverno policies, RBAC-scoped service accounts | **Implemented** |
| Supply chain integrity | Cosign keyless, SBOM attestation, provenance attestation, Rekor | **Implemented** |
| Network segmentation | Default-deny NetworkPolicy across all four namespaces, explicit allow rules per service path | **Implemented** |
| Secure configuration enforcement | Kyverno Enforce policies, PSS Restricted, CIS Benchmark hardening | **Implemented** |
| Encryption in transit | NetworkPolicy controls which paths are allowed, but traffic on those allowed paths is unencrypted  no mTLS | **Partial** → [`../docs/design-decisions/06-observability-stack.md`](../docs/design-decisions/06-observability-stack.md) references Linkerd as forward design, not yet implemented |
| Encryption at rest | Not implemented | **Missing** → etcd encryption provider not configured |
| Vulnerability remediation | Manual
