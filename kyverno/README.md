# Kyverno Admission Control Policies

Seven policies enforcing security at pod admission.

## Policies

| Policy | Mode | Description |
|--------|------|-------------|
| verify-image-signature | Enforce | Only Cosign-signed images from approved registry |
| disallow-privileged | Enforce | Blocks privileged:true containers |
| require-resource-limits | Enforce | CPU and memory limits mandatory |
| require-non-root | Enforce | runAsNonRoot:true mandatory |
| disallow-hostpath | Enforce | Host filesystem mounts blocked |
| disallow-latest-tag | Audit | Warns on :latest image tags |
| require-probes | Audit | Warns on missing health probes |

## Apply All Policies

```bash
kubectl apply -f kyverno/
```

## Test Blocking

```bash
# This should be BLOCKED
kubectl run test --image=nginx --restart=Never

# This should be ALLOWED (signed pipeline image)
kubectl run test --image=YOUR_USERNAME/secure-app:latest --restart=Never
```
