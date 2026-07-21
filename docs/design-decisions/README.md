# Design Decisions

This directory documents **why each major component looks the way it does** — the current-state rationale behind each design choice, the alternatives that were considered and rejected, and the trade-offs accepted as a result.

This is distinct from an Architecture Decision Record (ADR) log. ADRs are chronological — "at time X, given what we knew then, we decided Y." These documents are not time-stamped decision history; they are living, current-state explanations of *why the platform is built the way it is today*, each one revisable if the underlying decision is ever revisited.

For **what** the platform is and **how** it fits together, see `../architecture/`. This directory answers **why** each piece was built the way it was.

## Documents

| # | Document | Component |
|---|---|---|
| 01 | [`01-image-signing-cosign-keyless.md`](./01-image-signing-cosign-keyless.md) | Cosign keyless signing, Fulcio, Rekor |
| 02 | [`02-admission-control-kyverno.md`](./02-admission-control-kyverno.md) | Kyverno ClusterPolicies + Pod Security Standards |
| 03 | [`03-runtime-detection-falco-ebpf.md`](./03-runtime-detection-falco-ebpf.md) | Falco 0.43.1, modern eBPF driver |
| 04 | [`04-response-engine-custom-flask.md`](./04-response-engine-custom-flask.md) | Custom Python/Flask automated response engine |
| 05 | [`05-ml-anomaly-detection-isolation-forest.md`](./05-ml-anomaly-detection-isolation-forest.md) | Isolation Forest (advisory-only intelligence layer) |
| 06 | [`06-observability-stack.md`](./06-observability-stack.md) | Prometheus, Grafana, Loki, kube-bench, Polaris |
| 07 | [`07-single-node-k3s-tradeoffs.md`](./07-single-node-k3s-tradeoffs.md) | The single-node K3s foundation everything else runs on |

## Structure of Each Document

Every document follows the same four-part structure, in the same order:

1. **Context** — what problem this component needs to solve, and why that problem exists in the first place.
2. **Decision** — what was actually built, stated precisely.
3. **Alternatives Considered** — the other real options, and the specific reason each was set aside (not a strawman list).
4. **Trade-offs** — what was gained, and — just as deliberately documented — what was given up.

The **Trade-offs** section in each document is not a caveat appended as an afterthought. Every accepted trade-off here is also named in `../architecture/threat-model.md`, so the reasoning behind a gap and the gap itself are never more than one document apart.

## How This Directory Relates to `../architecture/`

- `../architecture/components.md` states *what* each component is and its purpose in the system, in brief.
- This directory expands on the *why* behind each of those same components, at the depth of alternatives seriously considered and rejected.
- `../architecture/threat-model.md` and `../architecture/trust-boundaries.md` describe the *consequences* of the decisions recorded here. Read together, the three directories form a complete line of reasoning: what was built → why it was built that way → what that choice defends against and what it doesn't.

## A Note on Document 07

`07-single-node-k3s-tradeoffs.md` is placed last deliberately, not because it's least important, but because it's foundational — nearly every trade-off in documents 01 through 06 traces back, in some way, to the single-node constraint this document addresses directly. It's meant to be read as the lens the other six are viewed through, which is easier to appreciate after seeing the specific trade-offs it produces downstream.

## Source of Truth

These rationale documents reflect design reasoning defended in the EduQual Level 6 oral examination (Topic 98: Advanced Container Security Platform) and correspond to the implementation in `Ali-Afnan-Cyber/container-security-platform`. Where a document notes a gap or an unimplemented alternative (e.g. Grype/Clair considered but not integrated), that reflects the platform as actually built, not an aspirational future state.
