# Demo Script — 4 Minutes

Complete end-to-end demonstration of all security controls.

## Pre-Demo Setup
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
NODE_IP=$(hostname -I | awk '{print $1}')
# Open browser tabs: Grafana · Falco UI · Polaris · ML /anomalies
```

## Timeline
| Time | Action | Shows |
|------|--------|-------|
| 0:00-0:25 | kubectl get pods -A | Full stack running |
| 0:25-0:55 | Kyverno block demo | Supply chain enforcement |
| 0:55-1:35 | Falco detection | Layer 1 syscall rules |
| 1:35-2:00 | Talon termination | Automated response |
| 2:00-2:30 | RBAC escalation | Layer 2 audit rules |
| 2:30-3:00 | ML anomaly burst | Behavioral detection |
| 3:00-3:30 | Compliance proof | kube-bench · Polaris |
| 3:30-4:00 | Grafana dashboard | Unified observability |

See scripts/demo.sh for exact commands.
