#!/bin/bash

kubectl label namespace falco \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged --overwrite

kubectl label namespace kyverno \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged --overwrite

kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=privileged --overwrite

kubectl label namespace default \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite

kubectl create namespace demo-sec --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace demo-sec \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite

kubectl get namespaces \
  -o custom-columns="NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce"
