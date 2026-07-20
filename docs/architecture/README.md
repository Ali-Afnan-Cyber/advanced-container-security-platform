# Architecture Documentation

This directory contains the architecture documentation for the **Advanced Container Security Platform** — a defense-in-depth container security system running on a single-node K3s cluster (Ubuntu 24, VMware).

The platform implements five independent security layers spanning the full container lifecycle: supply chain integrity, admission control, runtime detection, automated response, and observability/compliance. A sixth, advisory-only intelligence layer (Isolation Forest) sits alongside these without enforcement authority.

## How to Read This Directory

The documents are ordered to build understanding progressively — start at the top for context, move down for implementation detail, and finish with the two documents that state the system's limits explicitly.

| # | Document | Answers |
|---|---|---|
| 1 | [`overview.md`](./overview.md) | What problem does this solve, what's in scope, what isn't, and what does the system look like end to end? |
| 2 | [`components.md`](./components.md) | What is each piece of the system, and why was that specific technology chosen? |
| 3 | [`data-flow.md`](./data-flow.md) | How does a single container image move from commit to running, monitored workload? |
| 4 | [`runtime.md`](./runtime.md) | What actually happens on the live cluster — eBPF hooking, event pipeline, response triggering? |
| 5 | [`threat-model.md`](./threat-model.md) | What does each layer defend against, and what does it explicitly *not* defend against? |
| 6 | [`trust-boundaries.md`](./trust-boundaries.md) | Where are the trust zones, what crosses each boundary, and what's implicitly trusted within one? |

**Suggested reading order:** `overview.md` → `components.md` → `data-flow.md` → `runtime.md` → `threat-model.md` → `trust-boundaries.md`.

If you only have time for two documents, read `overview.md` for context and `threat-model.md` for an honest account of what the platform does and doesn't cover.

## Document Scope and Relationships

```text
overview.md          — the map (what and why, at a glance)
│
├── components.md      — the parts (what each piece is, tech choice)
│
├── data-flow.md        — the sequence (build → sign → admit → detect → respond → observe)
│
├── runtime.md           — the live behavior (zoomed into detection + response, in motion)
│
├── threat-model.md       — the coverage (per-layer: defends against / known gap)
│
└── trust-boundaries.md    — the zones (where trust is established vs. assumed)
```
`components.md` and `data-flow.md` describe the system as designed. `runtime.md` describes the system in motion. `threat-model.md` and `trust-boundaries.md` describe the system's limits — every gap named there is a deliberate, documented trade-off for a single-node, lab-grade platform, not an oversight.

## Conventions Used Across These Documents

- **Known gaps are stated explicitly, not implied.** Where a design decision trades coverage for simplicity (e.g. single-scanner CI, no persistent volumes, SLSA L2 instead of L3), that trade-off is named in `threat-model.md` and cross-referenced from wherever it's relevant.
- **Diagrams are plain-text/ASCII**, kept in-file rather than as external image assets, so they stay versioned and diffable alongside the prose that explains them.
- **Cross-references between documents** are relative markdown links (e.g. `see threat-model.md`) rather than duplicated explanations — each fact has one home.
- **Layer numbering is consistent** across all six documents: Layer 1 (Supply Chain) through Layer 5 (Observability & Compliance), with the Isolation Forest intelligence layer always referenced separately and never numbered alongside the five enforcing layers, since it holds no enforcement authority.

## Source of Truth

Implementation details here reflect the platform as defended in the EduQual Level 6 oral examination (Topic 98: Advanced Container Security Platform). Where the live implementation diverges from an earlier design intent (e.g. Grype/Clair referenced in design materials but not implemented; Kyverno's `verifyImages` as string-match rather than cryptographic verification), the documentation reflects the **implementation as built**, with the divergence noted rather than smoothed over.

Repository: `Ali-Afnan-Cyber/container-security-platform`

## Related Documentation

- Project root `README.md` — setup, deployment, and usage instructions (not covered here; this directory is architecture only).
- `docs/architecture/threat-model.md` and `trust-boundaries.md` — read together for a complete security posture review.
