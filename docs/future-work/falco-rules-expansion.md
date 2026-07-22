# Falco Rules Expansion

## Current State

The platform runs Falco 0.43.1 on the modern eBPF driver with a custom rule set layered on Falco's default rules, covering interactive shell spawns, privilege escalation attempts, unexpected outbound connections, and writes to sensitive paths (`../design-decisions/03-runtime-detection-falco-ebpf.md`). This is a deliberately scoped starting set, not an exhaustive one  `../limitations/known-limitations.md` and `../architecture/threat-model.md` already acknowledge that custom rule coverage is necessarily incomplete.

This document lists the highest-priority rules missing today, how to add a new Falco rule correctly, and what response tier each proposed rule should map to.

## Priority Rules Not Yet Implemented

| Rule | Detects | Priority | Proposed Response Tier |
|---|---|---|---|
| Container escape via `/proc/self/exe` or mount namespace manipulation | Attempts to break out of the container's mount/PID namespace | CRITICAL | Terminate |
| Access to `/var/run/docker.sock` or the container runtime socket from within a container | A container attempting to control the host's container runtime directly  a classic escape/lateral-movement vector | CRITICAL | Terminate |
| Reading the Kubernetes service account token from an unexpected process | A process other than the application itself reading `/var/run/secrets/kubernetes.io/serviceaccount/token`, suggesting credential theft for API access | CRITICAL | Terminate |
| Unexpected process making requests to the Kubernetes API server from within a pod | Lateral movement via stolen or default service account credentials | CRITICAL | Terminate |
| Kernel module load attempt (`init_module`/`finit_module`) from a container | An extremely high-signal, almost-never-legitimate action inside a container workload | CRITICAL | Terminate |
| `ptrace` attach to another process | Process injection or credential/memory scraping from another running process | CRITICAL | Terminate |
| Package manager execution at runtime (`apt`, `apk`, `yum`, `pip install`) inside a running container | Runtime tampering  installing new tooling into an already-deployed container, which should never be a normal application behavior in an immutable-image model | WARNING | Quarantine |
| Cryptomining-indicative syscall/process patterns (e.g., known miner binary names, sustained high CPU tied to a suspicious process tree, connections to known mining pool ports) | Resource-hijacking malware, one of the most common real-world container compromise outcomes | WARNING | Quarantine |
| DNS queries at unusually high frequency or to newly-registered/uncommon domains from a workload | Possible DNS tunneling for data exfiltration or C2 | WARNING | Quarantine |
| Write to a cron directory or systemd unit path from within a container | Persistence mechanism attempt | WARNING | Quarantine |
| Environment variable or secret file read by an unexpected process (not the container's main process) | Credential harvesting from within a compromised container | WARNING | Quarantine |
| Outbound connection on a non-standard port from a workload with no prior baseline of doing so | Possible C2 channel using an unexpected port | INFO | Log only, surface for review |

These are prioritized above the platform's existing custom rules because each one targets a **specific, well-documented, real-world container attack technique** (MITRE ATT&CK Containers matrix techniques such as escape to host, credential access via service accounts, and resource hijacking) rather than a generic behavioral heuristic  closing the highest-value gaps first.

## How to Add a New Rule

1. **Write the rule** in Falco's rule YAML syntax, defining a `condition` (a boolean expression over Falco's syscall/event fields), an `output` (the alert message template), and a `priority` (matching the response tier intended  see the mapping table above and `../design-decisions/04-response-engine-custom-flask.md` for how priority maps to response tier).

```yaml
   - rule: Container Runtime Socket Access
     desc: Detects a process inside a container accessing the container runtime socket
     condition: >
       open_read and container and
       fd.name in (/var/run/docker.sock, /run/containerd/containerd.sock)
     output: >
       Container runtime socket accessed from within a container
       (user=%user.name command=%proc.cmdline container=%container.name
       image=%container.image.repository)
     priority: CRITICAL
     tags: [container, escape, mitre_privilege_escalation]
```

2. **Validate the rule syntax** locally before deploying:
```bash
   falco --validate /path/to/new_rule.yaml
```

3. **Test against a controlled event**, either by deliberately triggering the target behavior in a disposable test pod, or by replaying a captured event trace if Falco's event-capture (`-A`/pcap-style) tooling is being used for regression testing. A rule that has never been shown to actually fire against its intended trigger should not be considered validated.

4. **Check for false-positive risk against normal platform behavior**  specifically, verify the rule doesn't fire against the platform's own components (e.g., a rule targeting API server access must exclude the response engine's own legitimate, scoped calls to the Kubernetes API).

5. **Add the rule to version control** alongside the existing custom rule set, with the same review discipline as any other security-relevant change  a bad Falco rule (overly broad, or targeting the wrong field) is itself a risk to the platform's own reliability, per the false-positive/kill trade-off already documented.

6. **Deploy via the existing Falco rule-loading mechanism** (ConfigMap or Helm values, whichever the current deployment uses), and confirm via Falco's own startup logs that the new rule loaded without syntax errors.

7. **Confirm the response engine's severity-to-action mapping** already covers the new rule's assigned priority tier correctly  no code change should be needed if the rule uses an existing priority tier, but this should be explicitly verified, not assumed.

## Response Mapping Rationale

The CRITICAL-tier rules above (container escape, runtime socket access, service account token theft, API server lateral movement, kernel module loading, `ptrace` injection) share a common property: **each is a technique with essentially no legitimate use case in this platform's workloads.** This is exactly the category the response engine's existing terminate-on-CRITICAL logic was designed for (`../design-decisions/04-response-engine-custom-flask.md`)  high-confidence, low-false-positive-risk matches are the correct candidates for immediate termination.

The WARNING-tier rules (package manager execution, cryptomining indicators, DNS anomalies, persistence attempts, credential file access) are all techniques that **could**, in narrow cases, have a legitimate explanation (a debugging session installing a diagnostic tool, a legitimate batch job with unusual DNS patterns)  exactly the ambiguity the quarantine tier exists to handle, preserving the workload for review rather than assuming malice outright.

## Relationship to Other Documents

- `../design-decisions/03-runtime-detection-falco-ebpf.md`  the existing rule set and the reasoning behind Falco/modern-eBPF as the detection mechanism these rules run on.
- `../design-decisions/04-response-engine-custom-flask.md`  the severity-tier-to-action mapping these new rules are designed to slot directly into.
- `../limitations/known-limitations.md`  the general acknowledgment that rule coverage is incomplete, which this document is the concrete first step in addressing.
- `pod-quarantine-implementation.md`  what "quarantine" as a response actually does, once triggered by a WARNING-tier match from this rule set.
