# ADR-001: Use k3s as the Kubernetes Distribution

**Status:** Accepted

## Context

The project required a Kubernetes environment capable of supporting runtime security, admission control, software supply chain security, observability, and CI/CD integration while remaining practical to deploy on limited development hardware.

The implementation was developed inside a virtual machine with approximately **6 GB of available memory** and limited CPU resources. A full upstream Kubernetes installation using kubeadm would have introduced unnecessary operational overhead and resource consumption for a single-node development environment.

The chosen platform needed to:

- Support standard Kubernetes APIs
- Be compatible with CNCF ecosystem tools
- Minimize resource usage
- Deploy quickly
- Be suitable for iterative testing and experimentation

---

## Options Considered

### Option 1 — kubeadm

**Pros**

- Upstream Kubernetes
- Maximum flexibility
- Closest to production deployments

**Cons**

- Higher memory and CPU requirements
- More complex installation and maintenance
- Greater operational overhead for a single-node lab

---

### Option 2 — Minikube

**Pros**

- Easy local development
- Well documented
- Supports multiple drivers

**Cons**

- Primarily intended for local application development
- Less representative of a persistent Kubernetes server
- Additional abstraction depending on deployment driver

---

### Option 3 — kind (Kubernetes in Docker)

**Pros**

- Extremely fast cluster creation
- Excellent for CI testing
- Lightweight

**Cons**

- Designed primarily for ephemeral testing
- Docker dependency adds another layer
- Less suitable for long-running security experiments

---

### Option 4 — MicroK8s

**Pros**

- CNCF-certified
- Rich built-in add-ons
- Simple installation

**Cons**

- Higher baseline resource consumption than k3s
- Larger installation footprint
- Additional services unnecessary for this project

---

### Option 5 — k3s

**Pros**

- Lightweight Kubernetes distribution
- Minimal memory and CPU requirements
- Fully compatible with standard Kubernetes APIs
- Simple installation and maintenance
- Widely used for edge, IoT, homelab, and resource-constrained environments

**Cons**

- Bundled components differ from some production kubeadm deployments
- Some enterprise features require additional configuration

---

## Decision

The project will use **k3s** as the Kubernetes distribution.

Although the project implements production-inspired security controls, its primary objective is to provide a reproducible research and demonstration environment within the available hardware constraints.

k3s provides full Kubernetes API compatibility while significantly reducing operational complexity and resource consumption. This allows more system resources to be allocated to security tooling such as Falco, Kyverno, Trivy, Prometheus, Grafana, and Loki rather than the orchestration platform itself.

The decision represents an engineering trade-off between infrastructure fidelity and efficient resource utilization.

---

## Consequences

### Positive

- Lower memory footprint
- Faster cluster provisioning
- Simpler maintenance
- More resources available for security tooling
- Fully compatible with Kubernetes-native tooling used throughout the project

### Negative

- Environment differs slightly from a production kubeadm deployment
- Certain production-specific configurations are outside the scope of this implementation
- Performance characteristics may not exactly match larger multi-node clusters

---

## References

- https://k3s.io/
- https://kind.sigs.k8s.io/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- https://minikube.sigs.k8s.io/
- https://microk8s.io/
