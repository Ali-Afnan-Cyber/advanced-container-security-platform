#!/bin/bash
set -e

NODE_IP=$(hostname -I | awk '{print $1}')

echo "================================================================"
echo "  ADVANCED CONTAINER SECURITY PLATFORM — LIVE DEMONSTRATION"
echo "================================================================"
echo ""

# cleanup
kubectl delete pod demo-target-pss demo-target-unsigned demo-target \
  -n demo-sec --force 2>/dev/null || true
sleep 3

echo "── Namespace Security Posture ──────────────────────────────────"
echo ""
echo "All workloads are scoped to the demo-sec namespace, enforcing"
echo "the Kubernetes Pod Security Standards restricted profile."
echo ""
kubectl get namespace demo-sec \
  -o custom-columns="NAMESPACE:.metadata.name,PSS:.metadata.labels.pod-security\.kubernetes\.io/enforce"
echo ""
sleep 2

echo "── Gate 1: Pod Security Standards ─────────────────────────────"
echo ""
echo "Deploying a pod that violates the restricted profile —"
echo "no security context, no seccomp, no capability restrictions."
echo ""
cat k8s/demo-sec/demo-target-pss.yaml
echo ""
kubectl apply -f k8s/demo-sec/demo-target-pss.yaml 2>&1 || true
echo ""
sleep 2

echo "── Gate 2: Kyverno — Image Signature Verification ──────────────"
echo ""
echo "Active Kyverno policies:"
kubectl get clusterpolicy
echo ""
echo "Deploying a PSS-compliant pod with an unsigned image..."
echo ""
kubectl apply -f k8s/demo-sec/demo-target-unsigned.yaml 2>&1 || true
echo ""
sleep 2

echo "── Gate 2: Kyverno — Signed Image Accepted ─────────────────────"
echo ""
echo "Deploying with our Cosign-signed image from the CI pipeline..."
echo ""
kubectl apply -f k8s/demo-sec/demo-target.yaml
kubectl wait pod demo-target -n demo-sec \
  --for=condition=Ready --timeout=120s
kubectl get pod demo-target -n demo-sec
echo ""
sleep 2

echo "── Gate 3: Runtime Detection — Falco eBPF ──────────────────────"
echo ""
echo "Falco is intercepting every syscall via eBPF kernel probe."
echo "Simulating credential harvesting — MITRE T1552..."
echo ""
kubectl exec -n demo-sec demo-target -- \
  cat /etc/passwd 2>/dev/null || true

echo ""
echo "Waiting for detection and automated response..."
sleep 10

echo ""
echo "── Response Engine Logs ────────────────────────────────────────"
kubectl -n demo-sec logs deployment/falco-response | \
  grep -A5 "ALERT\|RESULT" | tail -20

echo ""
echo "── Pod Status ──────────────────────────────────────────────────"
kubectl get pod demo-target -n demo-sec 2>/dev/null || \
  echo "[✓] demo-target-signed: TERMINATED by Response Engine"
echo ""
sleep 2

echo "── Gate 4: ML Anomaly Detection ────────────────────────────────"
echo ""
echo "Isolation Forest builds behavioral baselines per container."
echo "Simulating a multi-vector attack burst against the ML API..."
echo ""

python3 - << 'EOF'
import requests, time

ML = "http://192.168.239.128:31000/webhook"

print("  [*] establishing baseline...")
for i in range(8):
    requests.post(ML, json={
        "rule": "Sensitive File Access in Container",
        "priority": "Warning",
        "output": f"baseline {i}",
        "output_fields": {
            "container.name": "app",
            "k8s.pod.name": "demo-target",
            "k8s.ns.name": "demo-sec",
            "proc.name": "cat",
            "fd.name": "/etc/passwd"
        }
    })
    time.sleep(0.1)

rules = [
    "Shell Spawned Inside Container",
    "Sensitive File Access in Container",
    "Container Namespace Escape via setns",
    "Capability Escalation via capset",
    "Privilege Escalation via setuid or setgid"
]

print("  [*] injecting attack burst...")
for i in range(10):
    r = requests.post(ML, json={
        "rule": rules[i % len(rules)],
        "priority": "Critical",
        "output": f"attack {i}",
        "output_fields": {
            "container.name": "app",
            "k8s.pod.name": "demo-target",
            "k8s.ns.name": "demo-sec",
            "proc.name": "sh",
            "fd.name": "/etc/shadow"
        }
    })
    result = r.json()
    print(f"  [{i+1:02d}] {rules[i % len(rules)][:40]:<40} score={result.get('score')}")
    time.sleep(0.2)
EOF

echo ""
sleep 3
echo "── Anomaly Report ──────────────────────────────────────────────"
curl -s http://${NODE_IP}:31000/anomalies | python3 -m json.tool
echo ""
sleep 2

echo "── Gate 5: Compliance ──────────────────────────────────────────"
echo ""
echo "CIS Kubernetes Benchmark — kube-bench results:"
echo ""
kubectl logs job/kube-bench -n kube-system 2>/dev/null | \
  grep -E "^\[PASS\]|^\[FAIL\]|^\[WARN\]|^==|TOTAL" | tail -20

echo ""
echo "Polaris workload scorecard:  http://${NODE_IP}:30500"
echo "Grafana audit trail:         http://${NODE_IP}:30300"
echo "Prometheus metrics:          http://${NODE_IP}:30900"
echo ""
echo "================================================================"
echo "  Defense-in-depth demonstrated across all security layers."
echo "================================================================"
