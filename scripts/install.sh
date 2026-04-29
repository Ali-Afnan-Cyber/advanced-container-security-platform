#!/bin/bash
set -e
echo "================================================"
echo " Container Security Platform — Full Install"
echo "================================================"

# pre-flight
echo "[*] checking prerequisites..."
uname -r
ls /sys/kernel/btf/vmlinux && echo "[+] BTF present" || exit 1
sudo apt-get update -qq
sudo apt-get install -y curl wget apt-transport-https gnupg2

# audit policy
sudo mkdir -p /etc/kubernetes /var/log/kubernetes
sudo cp k8s/audit-policy.yaml /etc/kubernetes/audit-policy.yaml

# k3s
echo "[*] installing k3s..."
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --kube-apiserver-arg=audit-policy-file=/etc/kubernetes/audit-policy.yaml \
  --kube-apiserver-arg=audit-log-path=/var/log/kubernetes/audit.log \
  --kube-apiserver-arg=audit-log-maxage=7 \
  --kube-apiserver-arg=audit-log-maxbackup=3 \
  --kube-apiserver-arg=audit-log-maxsize=100

sleep 20
sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo tee /etc/systemd/system/k3s.service.d/kubeconfig-permissions.conf << 'EOF'
[Service]
ExecStartPost=/bin/chmod 644 /etc/rancher/k3s/k3s.yaml
EOF
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo systemctl daemon-reload
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -q 'KUBECONFIG' ~/.bashrc || \
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
kubectl get nodes

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# namespaces
for ns in falco falco-talon monitoring kyverno polaris; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
done
bash k8s/namespaces/pss-labels.sh

# falco custom rules configmap
kubectl create configmap falco-custom-rules \
  --from-file=custom-rules.yaml=falco/custom-rules.yaml \
  -n falco --dry-run=client -o yaml | kubectl apply -f -

# falco
helm install falco falcosecurity/falco \
  --namespace falco \
  -f falco/falco-values.yaml \
  --timeout 5m
kubectl -n falco rollout status daemonset/falco --timeout=180s

# kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --set replicaCount=1 \
  --timeout 5m
kubectl -n kyverno rollout status deployment/kyverno --timeout=120s
kubectl apply -f kyverno/

# falco talon
helm install falco-talon \
  oci://ghcr.io/falcosecurity/charts/falco-talon \
  --namespace falco-talon \
  --set image.registry=falco.docker.scarf.sh \
  --set image.repository=issif/falco-talon \
  --set image.tag=0.1.1 \
  --set image.pullPolicy=IfNotPresent \
  --set listenAddress=0.0.0.0 \
  --set listenPort=2803 \
  -f falco-talon/talon-rules.yaml \
  --timeout 3m

# ml service
cd ml-service
docker build -t falco-ml:latest .
docker save falco-ml:latest | sudo k3s ctr images import -
cd ..
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: falco-ml
  namespace: falco
spec:
  replicas: 1
  selector:
    matchLabels:
      app: falco-ml
  template:
    metadata:
      labels:
        app: falco-ml
    spec:
      containers:
      - name: falco-ml
        image: falco-ml:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        resources:
          requests:
            memory: 80Mi
            cpu: 50m
          limits:
            memory: 200Mi
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: falco-ml
  namespace: falco
spec:
  selector:
    app: falco-ml
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 31000
EOF

# monitoring
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=baseline --overwrite
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  -f monitoring/prometheus-values.yaml \
  --timeout 5m
helm install loki grafana/loki \
  --namespace monitoring \
  -f monitoring/loki-values.yaml \
  --timeout 5m
helm install promtail grafana/promtail \
  --namespace monitoring \
  -f monitoring/promtail-values.yaml \
  --timeout 3m
helm install grafana grafana/grafana \
  --namespace monitoring \
  -f monitoring/grafana-values.yaml \
  --timeout 5m

# polaris
kubectl create namespace polaris --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace polaris \
  pod-security.kubernetes.io/enforce=baseline --overwrite
helm install polaris fairwinds-stable/polaris \
  --namespace polaris \
  -f compliance/polaris-values.yaml \
  --timeout 3m

# network policies
kubectl apply -f network-policies/

# audit webhook
sudo cp k8s/audit-webhook.yaml /etc/kubernetes/audit-webhook.yaml
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/k3s server \
  --kube-apiserver-arg=audit-policy-file=/etc/kubernetes/audit-policy.yaml \
  --kube-apiserver-arg=audit-log-path=/var/log/kubernetes/audit.log \
  --kube-apiserver-arg=audit-log-maxage=7 \
  --kube-apiserver-arg=audit-log-maxbackup=3 \
  --kube-apiserver-arg=audit-log-maxsize=100 \
  --kube-apiserver-arg=audit-webhook-config-file=/etc/kubernetes/audit-webhook.yaml \
  --kube-apiserver-arg=audit-webhook-batch-max-wait=5s|' \
  /etc/systemd/system/k3s.service
sudo systemctl daemon-reload
sudo systemctl restart k3s
sleep 20

echo ""
echo "================================================"
echo " Installation Complete"
echo "================================================"
bash scripts/verify.sh
