# Monitoring Stack

Three-component observability platform.

## Components

| Component | Purpose | Port |
|-----------|---------|------|
| Prometheus | Metrics collection + storage | 30900 |
| Grafana | Unified dashboard | 30300 |
| Loki | Log aggregation | internal |
| Promtail | Log shipping (pods + audit log) | daemonset |

## Dashboards

**Container Security Platform**
- Total events · ML anomalies · containers tracked
- Events over time · rule breakdown
- Data: Prometheus ← falco-ml /metrics

**Audit Trail and Compliance**
- Live Kubernetes audit event stream
- Filtered views: exec · privileged · RBAC · secrets
- Data: Loki ← Promtail ← /var/log/kubernetes/audit.log

## Deploy
```bash
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring -f monitoring/prometheus-values.yaml
helm install loki grafana/loki \
  --namespace monitoring -f monitoring/loki-values.yaml
helm install promtail grafana/promtail \
  --namespace monitoring -f monitoring/promtail-values.yaml
helm install grafana grafana/grafana \
  --namespace monitoring -f monitoring/grafana-values.yaml
```
