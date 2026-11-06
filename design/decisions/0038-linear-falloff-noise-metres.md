# 38. Unified linear falloff, noise intensity = audible metres

Status: Accepted

Date: 2026-11-06

## Context

RADIUS stimuli (noise, fire, explosions) need a rule for how strong they are at a receiver. Noise loudness is already measured in audible metres ([ADR 0032](0032-noise-loudness-audible-metres.md)). Receptron intensity windows (a guard ignoring faint noises, a crate igniting only near the flame) need a perceived value that designers can reason about without a table per type.

## Decision

- One falloff for every RADIUS stimulus: `perceived = intensity x (1 - distance / radius)`, delivered only while `distance <= radius`. CONTACT and RAY stimuli arrive at full intensity.
- Noise is emitted with `intensity = radius = loudness`, so its perceived value is `loudness - distance`: the metres of margin left before it becomes inaudible. For noise, distance is the navmesh path distance ([ADR 0039](0039-path-propagation-sound-attenuators.md)).

## Alternatives considered

- **Inverse-square falloff**: physically plausible, but never reaches zero (needs a cutoff anyway) and makes "heard at 6 m" hard to read.
- **Per-type curves (Curve resources)**: flexible, but one more thing to tune per stimulus before anything is known to need it.
- **Binary in/out of radius**: simplest, but loses the "how clearly" signal that awareness levels (M7) use.

## Consequences

- Receptron `min_intensity` for noise reads as "metres inside the audible range": a guard with `min_intensity 2` needs the noise 2 m closer than its loudness.
- Debug overlays draw the radius directly as the reach.
- A different curve later only changes `StimulusPropagation.falloff()`.
