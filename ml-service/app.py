"""
Falco ML Anomaly Detection — Lightweight Edition
=================================================
- Receives Falco events from Sidekick via HTTP POST
- Extracts 5 numeric features per event
- Scores with Isolation Forest (unsupervised, no labels needed)
- Stores anomalies in memory ring buffer (no external DB needed)
- Exposes /anomalies and /stats for Grafana and exam demo

Why this is lightweight:
- No Redis dependency (removed — saves 64MB RAM)
- No GPU, no model retraining loop
- Ring buffer caps memory at ~50MB max
- Single gunicorn worker
"""

import json
import time
import os
import threading
import logging
from collections import defaultdict, deque
from flask import Flask, request, jsonify
from sklearn.ensemble import IsolationForest
import numpy as np

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)
log = logging.getLogger(__name__)

app = Flask(__name__)

# ── Config ──────────────────────────────────────────
# how many events per container before model is ready
MIN_EVENTS_FOR_MODEL = 10

# ring buffer max size per container — caps memory usage
MAX_EVENTS_PER_CONTAINER = 200

# anomaly ring buffer — keeps last 500 anomalies in memory
MAX_ANOMALIES = 500

# ── State ────────────────────────────────────────────
# per-container event history — deque caps memory automatically
container_events = defaultdict(lambda: deque(maxlen=MAX_EVENTS_PER_CONTAINER))

# detected anomalies ring buffer
anomalies = deque(maxlen=MAX_ANOMALIES)

# total counters for /stats endpoint
total_events = 0
total_anomalies = 0
events_per_rule = defaultdict(int)

lock = threading.Lock()

# ── Feature encoding ─────────────────────────────────
PRIORITY_SCORE = {
    'DEBUG': 0, 'INFORMATIONAL': 1, 'NOTICE': 2,
    'WARNING': 3, 'ERROR': 4, 'CRITICAL': 5,
    'ALERT': 6, 'EMERGENCY': 7
}

# encode rule names as integers for isolation forest
RULE_ID = {
    'Container Namespace Escape via setns': 1,
    'Namespace Manipulation via unshare': 2,
    'Filesystem Escape via mount syscall': 3,
    'Container Breakout via pivot_root': 4,
    'Privilege Escalation via setuid or setgid': 5,
    'Capability Escalation via capset': 6,
    'Shell Spawned Inside Container': 7,
    'Sensitive File Access in Container': 8,
    'Privileged Pod Created': 9,
    'kubectl exec into Pod': 10,
    'ClusterRoleBinding Created': 11,
}

def extract_features(event, container):
    """
    Convert falco event to 5-element numeric vector.
    All features are bounded so isolation forest stays stable.

    [0] priority_score  — alert severity 0-7
    [1] rule_id         — which rule fired (encoded int)
    [2] hour_of_day     — 0-23, detects off-hours activity
    [3] events_last_60s — burst detection for this container
    [4] unique_rules_60s— how many distinct rules fired recently
    """
    priority = event.get('priority', 'WARNING').upper()
    rule = event.get('rule', 'unknown')
    now = time.time()
    cutoff = now - 60

    # count recent events and unique rules from ring buffer
    with lock:
        history = list(container_events[container])

    recent = [e for e in history if e['ts'] > cutoff]
    events_last_60s = min(len(recent), 50)  # cap at 50 to bound feature
    unique_rules_60s = min(len(set(e['rule'] for e in recent)), 11)

    return [
        PRIORITY_SCORE.get(priority, 3),
        RULE_ID.get(rule, 99),
        time.localtime().tm_hour,
        events_last_60s,
        unique_rules_60s
    ]

def score_event(container, features):
    """
    Train isolation forest on container's event history.
    Returns (is_anomaly, raw_score) or (None, None) if not enough data.

    Isolation Forest: -1 = anomaly, 1 = normal
    Raw score: more negative = more anomalous
    """
    with lock:
        history = list(container_events[container])

    if len(history) < MIN_EVENTS_FOR_MODEL:
        return None, None

    X = np.array([e['features'] for e in history])

    model = IsolationForest(
        n_estimators=50,       # reduced from 100 — saves CPU
        contamination=0.1,
        random_state=42,
        n_jobs=1               # single thread — low overhead
    )
    model.fit(X)

    latest = np.array([features])
    prediction = model.predict(latest)[0]
    score = model.score_samples(latest)[0]

    return prediction == -1, round(float(score), 4)

# ── Endpoints ────────────────────────────────────────

@app.route('/health')
def health():
    return jsonify({"status": "ok", "events": total_events}), 200

@app.route('/webhook', methods=['POST'])
def webhook():
    global total_events, total_anomalies

    try:
        event = request.get_json(force=True)
        if not event:
            return jsonify({"error": "empty"}), 400

        rule = event.get('rule', 'unknown')
        priority = event.get('priority', 'WARNING')
        output_fields = event.get('output_fields', {})
        container = output_fields.get('container.name') or 'host'
        output = event.get('output', '')

        features = extract_features(event, container)

        # store event in ring buffer
        record = {
            'ts': time.time(),
            'rule': rule,
            'features': features
        }
        with lock:
            container_events[container].append(record)
            total_events += 1
            events_per_rule[rule] += 1

        # score anomaly
        is_anomaly, score = score_event(container, features)

        if is_anomaly:
            anomaly = {
                "time": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                "container": container,
                "rule": rule,
                "priority": priority,
                "score": score,
                "events_last_60s": features[3],
                "unique_rules_60s": features[4],
                "output": output[:200]  # truncate long outputs
            }
            with lock:
                anomalies.append(anomaly)
                total_anomalies += 1

            log.warning(
                f"ANOMALY container={container} rule={rule} "
                f"score={score} burst={features[3]} rules={features[4]}"
            )

        log.info(f"EVENT rule={rule} container={container} anomaly={is_anomaly}")

        return jsonify({
            "status": "anomaly" if is_anomaly else "normal",
            "score": score,
            "container": container,
            "baseline_events": len(container_events[container])
        }), 200

    except Exception as e:
        log.error(f"error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/anomalies')
def get_anomalies():
    """Returns detected anomalies — used by Grafana JSON datasource"""
    limit = int(request.args.get('limit', 50))
    with lock:
        result = list(anomalies)[-limit:]
    return jsonify({
        "total": total_anomalies,
        "shown": len(result),
        "anomalies": list(reversed(result))
    }), 200

@app.route('/stats')
def get_stats():
    """Per-container stats — used by Grafana for baseline status panel"""
    with lock:
        stats = {
            c: {
                "events": len(evs),
                "model_ready": len(evs) >= MIN_EVENTS_FOR_MODEL
            }
            for c, evs in container_events.items()
        }
        rule_counts = dict(events_per_rule)

    return jsonify({
        "total_events": total_events,
        "total_anomalies": total_anomalies,
        "containers": stats,
        "rules": rule_counts
    }), 200

@app.route('/metrics')
def metrics():
    """
    Prometheus-format metrics endpoint.
    Grafana can scrape this directly without a JSON datasource plugin.
    """
    with lock:
        lines = [
            f'falco_ml_total_events {total_events}',
            f'falco_ml_total_anomalies {total_anomalies}',
            f'falco_ml_containers_tracked {len(container_events)}',
        ]
        for rule, count in events_per_rule.items():
            safe = rule.lower().replace(' ', '_').replace('/', '_')
            lines.append(f'falco_ml_rule_count{{rule="{safe}"}} {count}')

    return '\n'.join(lines) + '\n', 200, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    log.info("Falco ML service starting — lightweight mode")
    app.run(host='0.0.0.0', port=5000)
