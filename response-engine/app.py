import logging
import time
import requests
from flask import Flask, request, jsonify
from kubernetes import client, config

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

app = Flask(__name__)

try:
    config.load_incluster_config()
    log.info("Loaded in-cluster Kubernetes config")
except Exception:
    config.load_kube_config()
    log.info("Loaded local kubeconfig")

v1 = client.CoreV1Api()

ML_WEBHOOK = "http://falco-ml.falco.svc.cluster.local:5000/webhook"

SYSCALL_RULES = {
    "Shell Spawned Inside Container",
    "Sensitive File Access in Container",
    "Filesystem Escape via mount syscall",
    "Container Breakout via pivot_root",
    "Container Namespace Escape via setns",
    "Namespace Manipulation via unshare",
    "Privilege Escalation via setuid or setgid",
    "Capability Escalation via capset",
    "Terminal shell in container",
    "Read sensitive file untrusted",
    "Read sensitive file trusted after startup",
    "Run shell untrusted",
}

AUDIT_RULES = {
    "Privileged Pod Created",
    "kubectl exec into Pod",
    "ClusterRoleBinding Created",
}


def terminate_pod(namespace, pod_name, rule):
    log.info("=" * 60)
    log.info(f"ALERT  → {rule}")
    log.info(f"CONTEXT→ pod={pod_name} namespace={namespace}")
    log.info(f"REASON → Syscall-level threat detected in container")
    log.info(f"ACTION → Force deleting pod (grace_period=0)")
    start = time.time()
    try:
        v1.delete_namespaced_pod(
            name=pod_name,
            namespace=namespace,
            body=client.V1DeleteOptions(grace_period_seconds=0)
        )
        elapsed = round(time.time() - start, 3)
        log.info(f"RESULT → SUCCESS pod={pod_name} deleted in {elapsed}s")
        log.info("=" * 60)
        return True, f"deleted in {elapsed}s"
    except client.exceptions.ApiException as e:
        if e.status == 404:
            log.info(f"RESULT → pod={pod_name} already gone (404)")
            log.info("=" * 60)
            return True, "already deleted"
        elapsed = round(time.time() - start, 3)
        log.error(f"RESULT → FAILED error={e.reason} after {elapsed}s")
        log.info("=" * 60)
        return False, str(e.reason)


def label_pod(namespace, pod_name, rule):
    log.info("=" * 60)
    log.info(f"ALERT  → {rule}")
    log.info(f"CONTEXT→ pod={pod_name} namespace={namespace}")
    log.info(f"REASON → Kubernetes audit-level threat detected")
    log.info(f"ACTION → Labeling pod compromised=true quarantine=true")
    start = time.time()
    try:
        v1.patch_namespaced_pod(
            name=pod_name,
            namespace=namespace,
            body={"metadata": {"labels": {
                "compromised": "true",
                "quarantine": "true",
                "falco-rule": rule[:50].replace(" ", "-").lower()
            }}}
        )
        elapsed = round(time.time() - start, 3)
        log.info(f"RESULT → SUCCESS pod={pod_name} labeled in {elapsed}s")
        log.info("=" * 60)
        return True, f"labeled in {elapsed}s"
    except client.exceptions.ApiException as e:
        if e.status == 404:
            log.info(f"RESULT → pod={pod_name} not found (404)")
            log.info("=" * 60)
            return True, "pod not found"
        elapsed = round(time.time() - start, 3)
        log.error(f"RESULT → FAILED error={e.reason} after {elapsed}s")
        log.info("=" * 60)
        return False, str(e.reason)


def log_only(namespace, pod_name, rule, priority):
    log.info("=" * 60)
    log.info(f"ALERT  → {rule}")
    log.info(f"CONTEXT→ pod={pod_name} namespace={namespace}")
    log.info(f"PRIORITY→ {priority}")
    log.info(f"ACTION → LOG ONLY (rule not in response mapping)")
    log.info("=" * 60)


@app.route('/falco', methods=['POST'])
def falco_webhook():
    try:
        event = request.get_json(force=True)
        if not event:
            return jsonify({"error": "empty body"}), 400

        rule = event.get('rule', 'unknown')
        priority = event.get('priority', 'unknown')
        output_fields = event.get('output_fields', {})
        pod_name = output_fields.get('k8s.pod.name')
        namespace = output_fields.get('k8s.ns.name')

        try:
            requests.post(ML_WEBHOOK, json=event, timeout=2)
        except Exception as e:
            log.warning(f"ML forward failed: {e}")

        if namespace != 'demo-sec':
            return jsonify({"status": "ignored", "reason": f"namespace={namespace}"}), 200

        if not pod_name:
            log.info(f"AUDIT EVENT → rule={rule} ns={namespace}")
            return jsonify({"status": "audit_logged", "rule": rule}), 200

        if rule in SYSCALL_RULES:
            success, result = terminate_pod(namespace, pod_name, rule)
            return jsonify({"status": "terminated" if success else "error",
                           "rule": rule, "pod": pod_name, "result": result}), 200
        elif rule in AUDIT_RULES:
            success, result = label_pod(namespace, pod_name, rule)
            return jsonify({"status": "labeled" if success else "error",
                           "rule": rule, "pod": pod_name, "result": result}), 200
        else:
            log_only(namespace, pod_name, rule, priority)
            return jsonify({"status": "logged", "rule": rule, "pod": pod_name}), 200

    except Exception as e:
        log.error(f"webhook error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "service": "falco-response-engine"}), 200


@app.route('/status', methods=['GET'])
def status():
    return jsonify({
        "syscall_rules": list(SYSCALL_RULES),
        "audit_rules": list(AUDIT_RULES),
        "scope": "demo-sec namespace only",
        "ml_forwarding": "all events → falco-ml"
    }), 200


if __name__ == '__main__':
    log.info("Falco Response Engine starting...")
    log.info(f"Syscall rules (terminate): {len(SYSCALL_RULES)}")
    log.info(f"Audit rules (label): {len(AUDIT_RULES)}")
    log.info("Listening on 0.0.0.0:5000/falco")
    app.run(host='0.0.0.0', port=5000)
