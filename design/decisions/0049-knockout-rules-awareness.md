# 49. Knockout rules and Awareness interface

Status: Accepted

Date: 2026-11-06

## Context

[ADR 0024](0024-baton-knockout.md) decided that one baton hit from behind on an unaware guard is a knockout, otherwise several hits. M4 needs exact rules, and the training dummy needs them before M7 guard perception exists to say whether a guard is aware.

## Decision

- `damage.stun` adds **stun points** (x the profile's stun multiplier) instead of lowering health. At `knockout_threshold` 60 the character is knocked out: tag `state.unconscious`, `actor.knocked_out`. Stun points do not decay in v0.
- **From behind**: the attacker (the stimulus source) is inside the 120 degree arc centred on the target's back (its -Z facing reversed), measured in the horizontal plane (`StunRules.is_behind`, pure).
- From behind **and** the target is not aware: stun x10 (baton 20 becomes 200, an instant knockout). Otherwise the baton's 20 per hit needs three hits.
- **Awareness interface**: a tiny `Awareness` component with `is_aware() -> bool`; in M4 it returns an exported flag (dummies default to false). M7 replaces the body with guard perception state (Unaware = false; Suspicious and up = true). A character without the component counts as aware (no sneak bonus against the player).
- All numbers (threshold, arc, multiplier) are in the `BodyProfile` .tres.

## Alternatives considered

- **Instant knockout from behind regardless of awareness**: makes alerted guards trivial to circle-strafe.
- **Knockout from any direction on unaware targets**: removes the positioning skill the rule is meant to reward.
- **Stun as a separate health pool per part**: more bookkeeping, no gameplay difference for one baton.
- **Waiting for M7 for awareness**: the rule could not be tested until then.

## Consequences

- The Low-Tech skill (M6) scales the stun amount or the threshold through data.
- M7 must implement `Awareness.is_aware()` and decide how unconscious guards wake up (another guard finds them).
