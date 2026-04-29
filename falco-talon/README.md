# Falco Talon — Automated Response

Response rules mapped 1-to-1 with Falco detection rules.

## Response Strategy

**Container Runtime Threats → Terminate (grace=0)**
Immediate pod termination. No data exfiltration window.

**K8s Audit Threats → Quarantine (label)**
Pod preserved for forensic investigation.
Label: quarantine=true · threat=<category>

## Deploy
```bash
helm install falco-talon \
  oci://ghcr.io/falcosecurity/charts/falco-talon \
  --namespace falco-talon \
  -f falco-talon/talon-rules.yaml
```
