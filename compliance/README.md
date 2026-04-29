# Compliance and Governance

Automated compliance across three tools.

## kube-bench — CIS Kubernetes Benchmark
Runs 100+ CIS controls against k3s configuration.

```bash
kubectl apply -f compliance/kube-bench-job.yaml -n kube-system
kubectl logs job/kube-bench -n kube-system | grep TOTAL
```

## Polaris — Workload Governance
Audits every running workload. Scores 0-100.
Checks: resource limits · root containers · host network · missing probes

```bash
helm install polaris fairwinds-stable/polaris \
  --namespace polaris -f compliance/polaris-values.yaml
# Dashboard: http://NODE_IP:30500
```

## Pod Security Standards
Built-in Kubernetes namespace-level enforcement.

| Namespace | Level |
|-----------|-------|
| default | restricted |
| falco | privileged |
| monitoring | privilege |
| falco-talon | baseline |
