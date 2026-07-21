# Monitoring & Alerting

This document describes the current Prometheus/Grafana/Loki setup and, specifically, what's missing between "data is collected and visible on a dashboard" and "the right person is notified when something needs attention."

## Current Setup

As described in `../design-decisions/06-observability-stack.md`, the platform runs:
- **Prometheus** for metrics collection across cluster and platform components.
- **Grafana** for dashboarding over both Prometheus (metrics) and Loki (logs), giving a single visualization pane.
- **Loki** for log aggregation, including Falco alerts and response engine action records.

This setup answers "what happened, and what does the platform's current state look like" reasonably well for someone actively looking at a dashboard. It does not, on its own, answer "who gets told, and how, when something needs immediate attention."

## The Missing Piece: Alert Routing

The platform currently has no configured **Alertmanager** (or equivalent) sitting between "a metric crossed a threshold" and "a human is notified." Concretely, this means:

- **No push notifications.** Grafana can display that something is wrong, but only to someone who is already looking at it. There is no mechanism currently routing a critical event (e.g. a spike in CRITICAL-tier Falco alerts, the response engine pod going down, Loki ingestion stopping) to a phone, Slack channel, or email inbox.
- **No severity-based routing.** Even if alerting rules exist in Prometheus, without Alertmanager there's no routing tree distinguishing "wake someone up now" from "note it, review tomorrow." Every signal is effectively the same priority: visible on a dashboard, and nothing more, until someone looks.
- **No deduplication or grouping.** A single underlying incident (e.g. a node under memory pressure) can generate many individual metric breaches. Without Alertmanager's grouping/inhibition rules, each would be a separate, ungrouped signal rather than one correlated incident.
- **No on-call integration.** There is no connection today to a paging system (e.g. PagerDuty, Opsgenie) or even a simple Slack/webhook notification channel  the loop from "Prometheus detects an anomaly" to "someone is actually told" is currently open.
- **No SLO-based alerting.** Current metrics are collected and visualized, but there's no defined service-level objective (e.g. "response engine action latency under N seconds," "Falco alert-to-Loki latency under N seconds") with burn-rate alerting against it  alerting today would be threshold-based at best, once configured, rather than tied to a meaningful reliability target.

## What Closing This Gap Would Require

1. **Deploy Alertmanager** alongside the existing Prometheus instance, with:
   - **Routing trees** mapping alert labels (e.g. `severity=critical`, `component=response-engine`) to specific receivers.
   - **Receivers** configured for at least one real notification channel  a Slack webhook is the lowest-effort starting point; PagerDuty/Opsgenie for anything resembling real on-call rotation.
   - **Grouping and inhibition rules** so a single root cause doesn't generate a flood of individually-paged alerts.
2. **Define concrete alerting rules**, at minimum for:
   - Any core platform component being down (Kyverno webhook, response engine, Falco, Prometheus/Loki/Grafana themselves).
   - A sustained spike in CRITICAL-tier Falco alerts (potential active incident).
   - Response engine action failures (e.g. a termination/quarantine call to the Kubernetes API failing)  this is arguably the highest-priority alert missing today, since a silent failure here means the automated response layer described in `../design-decisions/04-response-engine-custom-flask.md` could be failing without anyone knowing.
   - Loki/Prometheus disk or memory pressure, given the retention concerns in `backup-recovery.md`.
3. **Decide on a real notification destination** before building out routing rules  the rules are only as useful as what they're wired to.
4. **Revisit this document once Alertmanager exists**, to record the actual routing tree and receivers chosen, rather than leaving this as a standing gap description indefinitely.

## Relationship to Other Documents

- `../design-decisions/06-observability-stack.md`  the reasoning behind the current Prometheus/Grafana/Loki tooling choices.
- `high-availability.md`  an Alertmanager instance would itself need HA consideration once deployed, for the same reasons as every other single-instance component in the stack.
- `backup-recovery.md`  several of the alerting priorities above (disk pressure, data loss risk) are direct consequences of the persistence gap described there.
