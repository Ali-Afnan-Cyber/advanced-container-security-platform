# ML Anomaly Detection Service

Behavioral anomaly detection using Isolation Forest.
Receives Falco events via http_output, scores against per-container baseline.

## Algorithm
Isolation Forest — unsupervised, no labeled data required.
Builds behavioral baseline per container from live event stream.

## Features (5 per event)
1. Alert priority score (0-7)
2. Rule ID (encoded integer)
3. Hour of day (off-hours detection)
4. Events in last 60 seconds (burst detection)
5. Unique rules in last 60 seconds (combination detection)

## Endpoints
- POST /webhook — receive Falco events
- GET  /anomalies — query detected anomalies
- GET  /stats — per-container baseline status
- GET  /metrics — Prometheus metrics
- GET  /health — health check

## Resource Footprint
- RAM: ~200MB (Python + sklearn + gunicorn)
- CPU: 50m request · 200m limit

## Build
```bash
docker build -t falco-ml:latest .
docker save falco-ml:latest | sudo k3s ctr images import -
```
