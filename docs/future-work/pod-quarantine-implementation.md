# Proper Pod Quarantine Implementation

## Current State

The response engine's quarantine action is currently described, in `../design-decisions/04-response-engine-custom-flask.md`, at the level of intent rather than mechanism: "network isolation or a label change removing the pod from service." In its current form this is closer to a marker than an enforced isolation boundary  a label change alone does not, by itself, stop a pod from making outbound connections, receiving traffic, or continuing to run exactly as before. This document specifies what quarantine needs to actually *do* to be a real containment control, and the full sequence of steps required to get there.

## Why the Current Approach Is Insufficient

A label change alone accomplishes, at most, two things: it can remove a pod from a Service's endpoint list (if the Service selector includes that label as a match condition) and it can make the pod identifiable for later review. It does **not**:
- Stop the pod from initiating outbound connections (e.g., to a C2 server, or to exfiltrate data).
- Stop other pods from continuing to send traffic to it directly by pod IP (bypassing the Service entirely).
- Prevent the pod from continuing whatever malicious process triggered the quarantine in the first place  the process inside the container keeps running unless explicitly paused or the container is otherwise contained.

For quarantine to mean what the name implies, it needs to combine **network isolation**, **service removal**, and **a defined forensic hold period**, applied together as one atomic action, not as a single label change assumed to imply all three.

## Target Design

### Step 1: Apply the Quarantine Label

```bash
kubectl label pod <pod-name> -n <namespace> security.platform/quarantine=true --overwrite
```

This label is the trigger condition for every other step below  nothing else should depend on inferring quarantine state any other way.

### Step 2: Enforce Network Isolation via NetworkPolicy

A cluster-wide default-deny NetworkPolicy baseline should already exist for quarantine to layer on top of correctly (if it doesn't yet, this is a prerequisite, not an optional add-on). On top of that baseline, a dedicated NetworkPolicy targets exactly the quarantine label:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-deny-all
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      security.platform/quarantine: "true"
  policyTypes:
    - Ingress
    - Egress
  ingress: []   # no ingress allowed
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: platform-forensics   # allow only egress to a forensics/logging endpoint, if needed
```

This is the step that actually stops the pod from communicating  with everything except, optionally, a narrowly scoped forensics collection endpoint if live inspection of the running process is part of the investigation workflow.

### Step 3: Remove the Pod from Service Endpoints

If the pod's labels currently make it a member of a Service's endpoint set, the quarantine label alone won't remove it unless the Service's selector explicitly excludes quarantined pods. The response engine should verify (or the platform's Service definitions should be authored in advance) that quarantine removes the pod from load-balanced traffic  either by the Service selector excluding the quarantine label directly, or by the response engine patching the pod's other labels so it no longer matches the Service selector at all.

### Step 4: Do Not Delete or Restart the Pod

A quarantined pod should be explicitly excluded from any process that might otherwise terminate, evict, or restart it  deleting it destroys the forensic evidence quarantine exists to preserve. If a Deployment/ReplicaSet manages the pod, the quarantine step should also prevent the controller from replacing it (for example, by scaling down the owning ReplicaSet's replica count by one *without* deleting the quarantined pod itself, so a fresh replacement pod is created to maintain service capacity while the quarantined one is left untouched for review).

### Step 5: Log and Notify

The quarantine action, once applied, is recorded to Loki (consistent with the rest of the response engine's action logging per `../design-decisions/04-response-engine-custom-flask.md`) and routed to a human reviewer through the alert-routing mechanism described in `../production/monitoring-alerting.md`  quarantine should never be a silent action.

### Step 6: Define a Forensic Hold Period and Manual Release Procedure

A quarantined pod should be held for a defined period (e.g., 24–72 hours, tunable) rather than indefinitely, to avoid quarantine becoming an unbounded resource drain, but release should require **explicit human action**, not an automatic timeout:

```bash
kubectl label pod <pod-name> -n <namespace> security.platform/quarantine-
```

Removing the label should be treated as a deliberate, logged action in its own right  ideally requiring a brief documented reason (e.g., a required annotation explaining the investigation outcome) rather than a bare label removal with no accompanying record of why.

## Implementation Plan

1. **Establish the default-deny NetworkPolicy baseline cluster-wide**, if not already in place  quarantine's network isolation step depends on this existing first.
2. **Author the quarantine-specific NetworkPolicy** and test it in isolation against a disposable pod before wiring it into the response engine.
3. **Update Service definitions** (or the response engine's patch logic) to guarantee quarantined pods are excluded from load-balanced traffic.
4. **Update the response engine's quarantine action** to perform label application, verify NetworkPolicy coverage, and handle the owning controller's replica count, as one coordinated sequence rather than a single API call.
5. **Add the release procedure** as a documented, auditable operation  not just the reverse of step 1, but a step that itself gets logged.
6. **Test the full quarantine-to-release cycle** end to end against a real triggered alert before considering this complete.

## Open Questions

- Whether quarantined pods should retain any live inspection access (e.g., `kubectl exec` for a responder) or be fully sealed off  a trade-off between forensic value and containment completeness.
- What the right default hold period is before requiring a decision, and whether that should vary by the severity of the triggering event.
- Whether quarantine state should be tracked in a dedicated CRD instead of a plain label, for stronger structure around metadata like quarantine timestamp, triggering alert reference, and reviewer notes.

## Relationship to Other Documents

- `../design-decisions/04-response-engine-custom-flask.md`  the original quarantine concept this document makes concrete.
- `falco-rules-expansion.md`  the WARNING-tier rules that are the primary trigger for this quarantine path.
- `ai-anomaly-enforcement-layer.md`  the proposed ML-triggered enforcement path, which is designed to call into this same quarantine mechanism rather than a separate one.
- `../architecture/trust-boundaries.md`  the response engine's scoped Kubernetes permissions, which need to include NetworkPolicy and Service patch permissions for this design to be implementable.
