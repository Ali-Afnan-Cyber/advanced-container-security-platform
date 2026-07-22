# AI Anomaly Detection: From Advisory Signal to Enforcement-Adjacent Layer

## Current State

As established in `../design-decisions/05-ml-anomaly-detection-isolation-forest.md`, the Isolation Forest service is strictly **intelligence-only** today: it consumes metrics and log data from Prometheus/Loki periodically, produces an anomaly score, and surfaces it for human review. It has no path back into the Flask response engine and no enforcement authority whatsoever  a flagged anomaly, however high its score, results in nothing more than a dashboard entry until a person reviews it.

This was a deliberate, correctly-reasoned scope boundary at the time: no labeled attack dataset exists to validate the model against, and giving an unsupervised model direct enforcement authority would mean accepting an unbounded false-positive risk with no tiering and no human-in-the-loop check.

## Why Revisit This Now

Leaving the ML layer permanently advisory-only means it never actually closes the dwell-time gap it was partly justified by  a genuinely novel anomaly it correctly flags still depends entirely on a human noticing the flag in time. The goal of this future work is **not** to remove the human-in-the-loop principle that motivated the original design, but to build a properly engineered path from "anomaly detected" to "appropriate, bounded, auditable action taken," without ever letting the ML layer make an irreversible decision unilaterally.

## Target Design

### Principle: Asymmetric Trust, Preserved

The core safety property from the current design is kept, not loosened: **Falco's rule-based detection can trigger termination; the ML layer never can.** The ML layer's maximum possible enforcement authority, even in the target design, is triggering the same quarantine mechanism described in `pod-quarantine-implementation.md`  a reversible, auditable, easily-undone action  never a destructive one. This asymmetry reflects the fundamental difference between a human-authored rule (explainable, deterministic, reviewed once at write-time) and a statistical model's output (probabilistic, harder to fully explain, subject to drift).

### Proposed Architecture

```text
Prometheus/Loki (metrics + logs)
│
▼
Isolation Forest scoring service
│
▼
Anomaly score + confidence band + contributing features
│
├─▶ LOW confidence → logged only (current behavior, unchanged)
│
├─▶ MEDIUM confidence → surfaced to human review queue
│ (Slack/dashboard, per monitoring-alerting.md)
│ + auto-quarantine ONLY on explicit human approval
│
└─▶ HIGH confidence + corroboration → auto-quarantine (not termination)
(see "Corroboration Requirement" below)
```

### Corroboration Requirement for Any Automated Action

A HIGH-confidence anomaly score alone is not sufficient to trigger automated quarantine. The proposed design requires **corroboration**  the anomaly must align with at least one independent signal, for example:
- A Falco alert (even a lower-tier one) involving the same pod within a defined time window, or
- A Kyverno policy violation logged against the same workload, or
- A Polaris/kube-bench finding flagging the same workload's configuration.

This mirrors how the response engine already treats confidence tiers (`../design-decisions/04-response-engine-custom-flask.md`)  a single, uncorroborated statistical signal is treated the same way a single uncorroborated Falco WARNING-tier rule is: worth surfacing, not worth acting on alone.

### Explainability Requirement

Before any anomaly score can feed into an automated action (even the corroborated, quarantine-only path above), the scoring service must also emit the **contributing features** behind that score  for example, using a feature-attribution method appropriate to Isolation Forest's tree-partition structure (e.g., per-feature path-length contribution) rather than only a bare numeric score. This is what makes the flagged anomaly reviewable by a human at all, and what makes an eventual audit of "why did the platform quarantine this pod" answerable in more than "the model said so."

### Human Review Workflow

For the MEDIUM-confidence path, a lightweight approval mechanism is required  at minimum, a Slack message (via the Alertmanager routing work in `../production/monitoring-alerting.md`) with an approve/dismiss action, or a dashboard queue in Grafana. This is intentionally low-tech: the goal is a fast, low-friction human checkpoint, not a full workflow engine.

### Drift Detection and Retraining

Because the model's notion of "normal" is learned from this specific cluster's baseline traffic (a limitation already noted in `../design-decisions/05-ml-anomaly-detection-isolation-forest.md`), the target design includes:
- A scheduled retraining job against a rolling window of recent baseline data, so the model doesn't calcify around a baseline that no longer reflects normal operation.
- A drift metric (e.g., tracking the distribution of anomaly scores over time) exposed to Prometheus, so a sudden shift in the model's own scoring behavior is itself observable  model drift becoming a monitored signal, not a silent failure mode.

## Implementation Plan

1. **Instrument feature attribution** in the existing Isolation Forest service before anything else changes  this is a prerequisite for every downstream step, since no automated action should be built on top of an unexplainable score.
2. **Define the confidence bands** (LOW/MEDIUM/HIGH) and corroboration logic as a discrete decision function, testable independently of the response engine integration.
3. **Build the human-approval path first** (MEDIUM confidence) before the fully-automated corroborated path (HIGH confidence)  get the review workflow proven out with a human in the loop on every action before removing that requirement for the narrower, corroborated case.
4. **Integrate with the existing quarantine mechanism** (`pod-quarantine-implementation.md`) rather than building a second action pathway  the ML layer should call the same quarantine primitive the Falco-triggered path uses.
5. **Add the drift-detection metric and retraining job last**, once the enforcement path itself is stable and there's real operational data to validate retraining cadence against.

## Open Questions

- What corroboration window (time delta between the anomaly and a corroborating signal) is appropriate  too short risks missing genuinely correlated events; too long risks false corroboration between unrelated events.
- Whether feature attribution for Isolation Forest specifically needs a dedicated library/approach, or whether a simpler heuristic (e.g., per-feature deviation from baseline) is sufficient for this platform's scale.
- Whether the human-approval path should have a timeout/escalation (e.g., auto-quarantine if unreviewed after N minutes)  this reopens the dwell-time-vs-false-positive trade-off from `../design-decisions/04-response-engine-custom-flask.md` in a new form and needs its own explicit decision, not a default.

## Relationship to Other Documents

- `../design-decisions/05-ml-anomaly-detection-isolation-forest.md`  the original advisory-only decision and its rationale, which this document extends rather than reverses.
- `pod-quarantine-implementation.md`  the quarantine mechanism this layer would call into.
- `../production/monitoring-alerting.md`  the alert-routing infrastructure the human-review path depends on.
- `../design-decisions/04-response-engine-custom-flask.md`  the existing false-positive/kill trade-off reasoning this design deliberately mirrors for the ML case.
