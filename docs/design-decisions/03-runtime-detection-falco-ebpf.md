# 03. Runtime Detection: Falco (Modern eBPF)

## Context

Admission control closes off a class of risk at deploy time, but it can't see anything about how a container actually behaves once it's running. A perfectly compliant pod  correct security context, signed image, within resource limits  can still be exploited after the fact (a vulnerable application dependency, a supply-chain compromise that slipped past scanning, a credential leak used to spawn a shell). Catching that requires observing live behavior at a level below the application itself: syscalls.

## Decision

Use **Falco 0.43.1**, configured with the **modern eBPF driver**, with a custom rule set layered on top of Falco's default rule library.

The modern eBPF driver attaches to kernel tracepoints and syscall entry/exit points using CO-RE (Compile Once – Run Everywhere) eBPF, rather than requiring a separately built, kernel-version-specific kernel module. Falco correlates observed syscalls back to the originating container using cgroup and namespace metadata, and matches them against loaded rules  both the shipped default rules and a custom set targeting scenarios specific to this platform (unexpected shell spawns, privilege escalation attempts, suspicious outbound connections, writes to sensitive paths).

## Alternatives Considered

**Falco's legacy kernel module driver.** The original Falco driver, and still widely deployed. Rejected in favor of modern eBPF because the kernel module requires a version-specific build against the running kernel, which is a recurring maintenance burden and a potential source of node instability if a build is wrong. The modern eBPF driver's CO-RE approach avoids that per-kernel-version rebuild entirely.

**Falco's legacy (non-CO-RE) eBPF probe.** An intermediate option Falco has offered for longer than the modern probe. Rejected in favor of the modern eBPF driver specifically for its lower operational footprint and more active upstream development focus  the legacy eBPF probe is effectively the predecessor being phased out in favor of the modern one.

**Tetragon (Cilium's eBPF-based runtime security tool).** A credible alternative with a different architecture (in-kernel enforcement hooks, not just observation). Not chosen for this platform's current iteration, though it is the deliberate direction for the *next* project  Ali's follow-on Tetragon-based eBPF enforcement platform builds directly on lessons from this Falco deployment.

**Sysdig (commercial, Falco's original parent project).** Falco itself was originally extracted from Sysdig's open-source core. Rejected on the basis of keeping the platform fully open-source and self-hosted rather than introducing a commercial dependency, since Falco alone provides the detection capability needed here without Sysdig's additional commercial tooling.

## Trade-offs

**Gained:**
- No kernel-module build/version matching required  reduces node-level operational risk.
- In-kernel filtering means only syscalls that could plausibly match a rule are passed up to userspace, keeping overhead manageable on a single-node cluster with limited resources.
- Custom rules target this platform's actual threat scenarios rather than relying solely on generic default rules.

**Given up:**
- **Detection is bounded by syscall/tracepoint visibility, by design.** Activity that never touches a monitored kernel interface (e.g. purely in-process computation) is invisible to this layer  not a bug, but a hard scope limit of syscall-level monitoring as an approach (see `threat-model.md`).
- **Custom rule coverage is necessarily incomplete.** Rules were written against anticipated attack patterns; novel behavior outside that set won't trigger an alert.
- **Single-node co-location risk.** Falco runs on the same node as everything it monitors. A kernel-level compromise beneath the eBPF hook points could blind the detection layer itself, with no second node providing redundant coverage (see `trust-boundaries.md`).
