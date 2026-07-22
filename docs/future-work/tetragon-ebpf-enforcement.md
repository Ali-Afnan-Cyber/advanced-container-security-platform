# Tetragon eBPF Kernel Enforcement Platform

## Status

This is the actual next project  not a modification to the current platform, but a deliberately separate, narrower build. This document explains why it's being built as its own thing and what it's targeting; it is a pointer to that project's rationale, not a substitute for that project's own documentation once it exists.

## Why This Is a New Project, Not a Layer Bolted onto the Current Platform

The current platform's runtime detection layer (`../design-decisions/03-runtime-detection-falco-ebpf.md`) is built on Falco, which observes syscalls via eBPF and generates alerts *after* a syscall has already occurred. Response is necessarily reactive: an event happens, Falco matches a rule, an alert is emitted, the Flask response engine receives it over HTTP, and only then is an action (terminate/quarantine) taken. Every step in that chain  rule matching, HTTP delivery, response engine decision logic  introduces latency between "the bad thing happened" and "the platform reacted to it."

Tetragon, built on eBPF like Falco, takes a structurally different approach: it can enforce policy **in-kernel, at the point of the syscall itself**, blocking or killing a process before the action completes, not after. That's not an incremental improvement to the existing detection layer  it's a different point in the control flow entirely, and trying to retrofit it into the existing five-layer platform (which was deliberately scoped and defended as a complete, closed system in its own oral examination) would mean either diluting the clarity of that platform's own story or building something that's neither a clean Falco-based system nor a clean Tetragon-based one.

The decision, consistent with the reasoning in `../design-decisions/07-single-node-k3s-tradeoffs.md` about scope discipline, is to build the Tetragon enforcement platform as its **own narrowly scoped, deeply implemented, fully explainable system**, on the same single-node K3s cluster (Ubuntu 24, VMware), deliberately scrapping the previous platform's infrastructure rather than layering on top of it. Depth over breadth, applied at the project level this time rather than the component level.

## What This Project Targets

At a high level, the Tetragon project is expected to cover:

- **TracingPolicy-based enforcement**, defining specific syscall/kprobe conditions that Tetragon can act on directly in-kernel  not just observe and report, the way Falco's userspace rule engine does.
- **Process lineage tracking**, using Tetragon's process credential and execution tree visibility to make enforcement decisions that account for a process's ancestry, not just the syscall in isolation.
- **In-kernel blocking of specific dangerous actions** (e.g., a `sigkill` action tied to a TracingPolicy match) as a first-class Tetragon capability, rather than an out-of-band response engine reacting after the fact.
- **A narrower, more deeply defensible rule set** than the current platform's Falco custom rules  fewer rules, each one fully understood and explainable end-to-end, consistent with the stated goal of a "narrowly scoped, deeply implemented, and fully explainable system."

## Relationship to the Current Platform

This project is a **successor in lineage, not a replacement in place**. The current platform (`../architecture/overview.md`) remains a complete, documented, defended system in its own right. The Tetragon project exists because the oral defense of the current platform, and the process of building it, surfaced a clear next question  "what would it take to enforce in-kernel instead of reacting after the fact?"  that deserved its own focused answer rather than an asterisk on this platform's documentation.

Where relevant lessons carry over directly:
- The same single-node K3s cluster is reused as the deployment target  see `../design-decisions/07-single-node-k3s-tradeoffs.md` for the trade-offs that decision already carries, which apply here too.
- The same discipline of stating known gaps plainly (`../limitations/known-limitations.md`) is expected to carry into this project's own documentation once it exists.
- The false-positive/kill trade-off analysis in `../design-decisions/04-response-engine-custom-flask.md` is directly relevant background  in-kernel enforcement makes this trade-off sharper, not softer, since there's even less room for a human-in-the-loop check between detection and action than there was with the Flask response engine's HTTP round-trip.

## What This Document Is Not

This is not an implementation plan, an architecture document, or a threat model for the Tetragon platform  those belong to that project once it's underway, in its own repository and its own documentation structure, following the same pattern established across `../architecture/`, `../design-decisions/`, `../production/`, and `../limitations/` in this repository. This document exists solely to record, from the current platform's side, why that project is the deliberate next step and how it relates to what's already been built here.
