#!/bin/bash
# Apply Pod Security Standards to all namespaces

kubectl label namespace falco \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged --overwrite

kubectl label namespace kyverno \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged --overwrite

kubectl label namespace falco-talon \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/audit=baseline --overwrite

kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=privileged \
  --overwrite

kubectl label namespace default \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite

echo "[+] PSS labels applied to all namespaces"
kubectl get namespaces -o custom-columns=\
"NAME:.metadata.name,\
ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce"
