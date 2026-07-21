# Limitations

This directory is the platform's honest accounting of where it stops — organized into three distinct kinds of "not covered," which are easy to blur together but mean different things:

| Document | Answers | In one line |
|---|---|---|
| [`known-limitations.md`](./known-limitations.md) | What did we try to do, and where does it fall short? | Gaps *within* implemented scope |
| [`scope-exclusions.md`](./scope-exclusions.md) | What did we never attempt at all? | Capabilities deliberately *outside* scope |
| [`assumptions.md`](./assumptions.md) | What do we take as given, and not verify? | Preconditions the platform's guarantees depend on |

## Why the Distinction Matters

It's tempting to file all three under one vague "limitations" heading, but they carry different implications for anyone evaluating or extending this platform:

- A **known limitation** (e.g. `verifyImages` being string-match rather than cryptographic) is a solvable engineering problem within the platform's existing scope — the fix is more work on something already being built.
- A **scope exclusion** (e.g. multi-tenancy) isn't a partial solution waiting to be finished — it's a boundary drawn on purpose, and extending past it means taking on a meaningfully different problem, not just doing more of the current one.
- An **assumption** (e.g. trusting the container registry) isn't something the platform failed to check — it's a precondition the whole design leans on. If the assumption doesn't hold in a given deployment, the surrounding controls may not mean what they appear to mean, regardless of how well-implemented they are.

Conflating these three understates some risks and overstates others. Treating an assumption as if it were merely a known limitation, for instance, makes it sound like a matter of degree rather than a foundation the rest of the design depends on.

## How to Use This Directory

If you're evaluating this platform for a use case beyond its original scope, read these in order:

1. **`assumptions.md` first** — check whether your environment actually matches what the platform assumes (registry trust, single-tenancy, threat model boundary). If an assumption doesn't hold, everything built on top of it needs re-evaluation before anything else here is relevant.
2. **`scope-exclusions.md` second** — check whether your use case needs a capability that was never attempted (multi-cluster, multi-tenancy, formal compliance certification). If so, that's new engineering work, not a bug fix.
3. **`known-limitations.md` last** — the specific, itemized gaps within what was actually built, each with a pointer to the fuller discussion elsewhere in the documentation.

## Relationship to the Rest of the Documentation

- `../architecture/threat-model.md` first introduced most of the items in `known-limitations.md`, in the context of what each layer defends against.
- `../design-decisions/` explains *why* each trade-off behind a known limitation was accepted.
- `../production/` describes the concrete path to closing the limitations and exclusions that are addressable (scaling, HA, secrets, monitoring, backup/recovery) — treat this directory as the honest map of what's not yet covered, and `../production/` as the corresponding map of how to get there.

## Source of Truth

The gaps, exclusions, and assumptions catalogued here were directly defended in the EduQual Level 6 oral examination (Topic 98: Advanced Container Security Platform) and reflect the platform as implemented in `Ali-Afnan-Cyber/container-security-platform`. Nothing in this directory is a newly surfaced concern — each item was a known, deliberate part of the platform's design posture at the time it was built.
