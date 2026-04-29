#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

helm uninstall falco -n falco 2>/dev/null || true
helm uninstall falco-talon -n falco-talon 2>/dev/null || true
helm uninstall grafana -n monitoring 2>/dev/null || true
helm uninstall prometheus -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall promtail -n monitoring 2>/dev/null || true
helm uninstall polaris -n polaris 2>/dev/null || true
helm uninstall kyverno -n kyverno 2>/dev/null || true

kubectl delete namespace falco falco-talon monitoring kyverno polaris \
  --force 2>/dev/null || true

/usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

sudo rm -f /etc/kubernetes/audit-policy.yaml
sudo rm -f /etc/kubernetes/audit-webhook.yaml
sudo rm -f /usr/local/bin/helm
sudo rm -rf /var/log/kubernetes/
sed -i '/KUBECONFIG/d' ~/.bashrc

echo "[+] cleanup complete"
