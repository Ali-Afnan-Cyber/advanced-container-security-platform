<div align="center">

# 🛡️ Advanced Container Security Platform

### Runtime Protection · Supply Chain Security · Kubernetes Threat Detection

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s-326CE5?logo=kubernetes)](https://k3s.io)
[![Falco](https://img.shields.io/badge/Falco-eBPF-00AEC7?logo=falco)](https://falco.org)
[![Supply Chain](https://img.shields.io/badge/Supply%20Chain-Cosign%20%2B%20SLSA%20L2-4A90D9)](https://sigstore.dev)
[![Compliance](https://img.shields.io/badge/Compliance-CIS%20Benchmark-green)](https://cisecurity.org)

</div>

---

## Overview

A comprehensive, production-inspired container security platform built on open-source tools. Implements defense-in-depth across the full software lifecycle — from code commit to runtime threat response.

**Built for:** EduQual Level 6 — Advanced Container Security Platform (Topic 98)

---

## Architecture

![Implementation Architecture](docs/architecture (1).png)

---

## Security Pillars

| Pillar | Tools | Status |
|--------|-------|--------|
| Supply Chain Security | Trivy · Cosign · SLSA L2 · SBOM | ✅ Implemented |
| Admission Control | Kyverno · Pod Security Standards | ✅ Implemented |
| Runtime Detection | Falco eBPF · Custom Rules | ✅ Implemented |
| Automated Response | Falco Talon | ✅ Implemented |
| ML Anomaly Detection | Isolation Forest · Flask | ✅ Implemented |
| K8s Audit Detection | k3s Audit Webhook · Falco | ✅ Implemented |
| Compliance Automation | kube-bench · Polaris · PSS | ✅ Implemented |
| Network Segmentation | Kubernetes NetworkPolicy | ✅ Implemented |
| Observability | Prometheus · Grafana · Loki | ✅ Implemented |

---

## Detection Layers

### Layer 1 — Syscall Detection (Falco eBPF)

| Rule | Syscall | Severity | MITRE |
|------|---------|----------|-------|
| Namespace Escape | setns() | CRITICAL | T1611 |
| Namespace Manipulation | unshare() | CRITICAL | T1611 |
| Filesystem Escape | mount() | CRITICAL | T1611 |
| Container Breakout | pivot_root() | CRITICAL | T1611 |
| Privilege Escalation | setuid/setgid | WARNING | T1548 |
| Capability Escalation | capset() | WARNING | T1548 |
| Shell Spawn | execve(sh/bash) | WARNING | T1059 |
| Sensitive File Access | open/openat | WARNING | T1552 |

### Layer 2 — Kubernetes Audit Detection

| Rule | Event | Severity | MITRE |
|------|-------|----------|-------|
| Privileged Pod Created | Pod spec privileged:true | CRITICAL | T1610 |
| kubectl exec Detected | pods/exec · pods/attach | WARNING | T1609 |
| RBAC Escalation | ClusterRoleBinding created | CRITICAL | T1078 |

### Layer 3 — ML Anomaly Detection

- **Algorithm:** Isolation Forest (unsupervised)
- **Features:** priority score · rule ID · hour of day · burst rate · unique rules/60s
- **Baseline:** 5+ events per container
- **Overhead:** ~200MB RAM · 50m CPU

---

## Automated Response

| Threat Category | Talon Action | Grace Period |
|-----------------|--------------|--------------|
| Container breakout attempts | Kubernetes:Terminate | 0s |
| Privilege escalation | Kubernetes:Terminate | 0s |
| Shell spawn in container | Kubernetes:Terminate | 0s |
| Sensitive file access | Kubernetes:Terminate | 0s |
| Privileged pod (audit) | Kubernetes:Label quarantine=true | — |
| kubectl exec (audit) | Kubernetes:Label quarantine=true | — |
| RBAC escalation (audit) | Kubernetes:Label quarantine=true | — |

---

## Quick Start

### Prerequisites

```bash
# Ubuntu 22.04 · 2+ vCPU · 10GB+ RAM
# kernel 5.8+ with BTF support
ls /sys/kernel/btf/vmlinux && echo "BTF present"
```

### Deploy Full Platform

```bash
git clone https://github.com/Ali-Afnan-Cyber/container-security-platform.git
cd container-security-platform
chmod +x scripts/install.sh
./scripts/install.sh
```

### Verify Everything Running

```bash
chmod +x scripts/verify.sh
./scripts/verify.sh
```

---

## Repository Structure

.
├── app/                    # Demo Flask application (hardened Dockerfile)
├── .github/workflows/      # Supply chain CI/CD pipeline
├── falco/                  # Falco custom rules + helm values
├── falco-talon/            # Automated response rules
├── ml-service/             # ML anomaly detection service
├── monitoring/             # Prometheus · Grafana · Loki helm values
├── kyverno/                # Admission control policies
├── compliance/             # kube-bench · Polaris configs
├── network-policies/       # Namespace isolation policies
├── k8s/                    # Audit policy · webhook config
├── docs/                   # Architecture diagrams · demo script
└── scripts/                # Install · verify · demo · cleanup

---

## Access Points (after deployment)

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana Dashboard | http://NODE_IP:30300 | admin/admin |
| Falco Sidekick UI | http://NODE_IP:30282 | admin/admin |
| Prometheus | http://NODE_IP:30900 | — |
| ML Anomalies API | http://NODE_IP:31000 | — |
| Polaris Dashboard | http://NODE_IP:30500 | — |

---

## Tech Stack

Runtime:        k3s · containerd · Ubuntu 22.04
Detection:      Falco 0.43.0 · modern eBPF driver
Response:       Falco Talon 0.1.1
ML:             scikit-learn · Flask · Gunicorn
Supply Chain:   Cosign · Sigstore · Rekor · Syft · SLSA
Admission:      Kyverno · Pod Security Standards
Compliance:     kube-bench · Polaris · NetworkPolicy
Observability:  Prometheus · Grafana · Loki · Promtail

---

## Author

**Ali Afnan**
EduQual Level 6 — Diploma in AI Operations

---

<div align="center">
Built with open-source tools. Designed for real-world threat models.
</div>

