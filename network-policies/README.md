# Network Policies — Zero Trust Segmentation

Default deny all traffic. Explicit allow only where required.

## Per-Namespace Policy

| Namespace | Default | Allowed Ingress | Allowed Egress |
|-----------|---------|-----------------|----------------|
| default | deny all | none | DNS only |
| falco | deny all | prometheus (5000) · NodePort (2802) | talon (2803) · ml (5000) |
| falco-talon | deny all | falco ns (2803) | k8s API (6443) · DNS |
| monitoring | deny all | NodePorts | falco metrics (5000·8765) |

## Apply
```bash
kubectl apply -f network-policies/
```
