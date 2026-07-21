# 05. ML Anomaly Detection: Isolation Forest

## Context

Falco's rule-based detection is precise but bounded to what someone thought to write a rule for. Novel or slow-drifting anomalous behavior  the kind that doesn't trip any specific rule but looks statistically unusual against a baseline  needs a different kind of detection. That's a natural fit for unsupervised anomaly detection over metrics and log data. But no attack-labeled dataset exists for this platform, which rules out any supervised approach, and putting an ML model directly in the enforcement path introduces a new kind of risk: an autonomous system making irreversible decisions (terminating a workload) based on a statistical model that can't fully explain itself.

## Decision

Deploy an **Isolation Forest** model as a strictly **intelligence-only, advisory layer**. It consumes already-collected metrics and log data (from Prometheus/Loki) on a periodic basis, scores it for anomalousness, and surfaces flagged anomalies for human review. It has **no enforcement authority**  no path back into the response engine, no ability to trigger termination or quarantine on its own.

## Alternatives Considered

**Supervised classification (e.g. a trained classifier on known-attack examples).** Rejected outright due to the absence of a labeled attack dataset for this platform  building one would require either synthetic attack generation or an unrealistic amount of manually labeled incident data neither of which currently exists.

**Autoencoder-based anomaly detection.** A legitimate alternative unsupervised approach, often used for high-dimensional time-series anomaly detection. Considered, but Isolation Forest was preferred for this scope on the basis of simplicity and interpretability  Isolation Forest's anomaly score has a more direct, tree-partition-based explanation than an autoencoder's reconstruction-error score, which matters when a human is the one reviewing flagged anomalies and needs some basis to trust or dismiss them.

**Giving the ML layer enforcement authority (auto-quarantine on high anomaly score).** Considered and explicitly rejected. An unsupervised model, by definition, has no ground truth to validate against in production  giving it the ability to autonomously act on a workload would mean accepting an unbounded false-positive risk with no tiering or human-in-the-loop check, which is a materially different (and worse) risk profile than the tiered, rule-based response engine in `04-response-engine-custom-flask.md`.

## Trade-offs

**Gained:**
- Anomaly detection coverage that doesn't depend on anyone having anticipated the specific attack pattern in advance  a genuine complement to Falco's rule-based approach.
- No labeled training data required, which was a hard constraint for this platform.
- Zero risk of the ML layer autonomously taking a wrong, irreversible action  false positives here cost a human a few minutes of review, not a killed workload.

**Given up:**
- **No automated response from this layer, ever  by design.** A genuinely novel, fast-moving threat that this layer correctly flags still requires a human to see the flag and act on it; there's no path for this layer to close that gap on its own, unlike Layer 3/4's automated pipeline.
- **Isolation Forest's anomaly score is a signal, not a verdict.** It still requires human judgment to interpret, and a busy or absent operator means flagged anomalies could sit unreviewed  the same dwell-time risk that automated response was built to avoid elsewhere in the platform reappears here, just at lower stakes since no autonomous action is taken.
- **Model quality depends on the baseline data it's trained against.** On a single small cluster with limited traffic diversity, the "normal" baseline the model learns may not generalize well, risking either noisy false positives or under-sensitivity to real anomalies.
