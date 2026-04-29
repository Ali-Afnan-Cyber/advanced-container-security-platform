# Falco Runtime Detection

Custom rules replacing Falco default ruleset entirely.
11 rules across 2 detection layers.

## Driver
- modern eBPF (no kernel module, BTF-based, kernel 5.8+)

## Layer 1 — Syscall Rules (8 rules)
Target: setns · unshare · mount · pivot_root · setuid · setgid · capset · execve · open/openat

## Layer 2 — K8s Audit Rules (3 rules)
Target: privileged pod creation · kubectl exec · ClusterRoleBinding creation

## Deploy
```bash
kubectl create configmap falco-custom-rules \
  --from-file=custom-rules.yaml=falco/custom-rules.yaml \
  -n falco
helm install falco falcosecurity/falco \
  --namespace falco -f falco/falco-values.yaml
```
