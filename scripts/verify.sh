#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
NODE_IP=$(hostname -I | awk '{print $1}')

echo "================================================"
echo " Platform Verification"
echo "================================================"

echo ""
echo "── Node ──"
kubectl get nodes

echo ""
echo "── All Pods ──"
kubectl get pods -A | grep -v Completed

echo ""
echo "── Falco eBPF ──"
kubectl -n falco logs daemonset/falco \
  | grep -i "modern\|ebpf" | tail -2

echo ""
echo "── Kyverno Policies ──"
kubectl get clusterpolicy

echo ""
echo "── PSS Labels ──"
kubectl get namespaces \
  -o custom-columns="NS:.metadata.name,PSS:.metadata.labels.pod-security\.kubernetes\.io/enforce" \
  | grep -v "<none>"

echo ""
echo "── Network Policies ──"
kubectl get networkpolicy -A | grep -v kube-system

echo ""
echo "── Service Health ──"
curl -s -o /dev/null -w "Grafana:    HTTP %{http_code}\n" \
  http://${NODE_IP}:30300/api/health
curl -s -o /dev/null -w "Prometheus: HTTP %{http_code}\n" \
  http://${NODE_IP}:30900/-/healthy
curl -s -o /dev/null -w "ML Service: HTTP %{http_code}\n" \
  http://${NODE_IP}:31000/health
curl -s -o /dev/null -w "Polaris:    HTTP %{http_code}\n" \
  http://${NODE_IP}:30500

echo ""
echo "── ML Metrics ──"
curl -s http://${NODE_IP}:31000/metrics

echo ""
echo "── Access Points ──"
echo "Grafana    → http://${NODE_IP}:30300  (admin/admin)"
echo "Falco UI   → http://${NODE_IP}:30282  (admin/admin)"
echo "Prometheus → http://${NODE_IP}:30900"
echo "ML Service → http://${NODE_IP}:31000"
echo "Polaris    → http://${NODE_IP}:30500"
