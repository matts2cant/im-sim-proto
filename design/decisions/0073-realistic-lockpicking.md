# 73. Realistic pin-tumbler lockpicking minigame

Status: Accepted

Date: 2026-11-07

## Context

Locks in M8 need a way to be picked. Deus Ex used a hold-to-pick timer. The user wants a minigame true to real pin-tumbler locks, with real vocabulary, where understanding the mechanic is the skill. Mouse and keyboard come first.

## Decision

- Model a pin-tumbler lock: under tension one pin binds at a time, setting it clicks, spool and serrated pins give false sets, overset jams, too little tension drops set pins, too much makes pins stiff and risks breaking the pick. Details and numbers: [lockpicking](../game/lockpicking.md).
- Controls: W/S set tension (it holds, no leak), A/D change pin, mouse Y lifts through a spring whose lag is the applied force. Start with LMB on a lock with the lockpick selected; leave with E, Esc or damage.
- Feedback is outside-only (sound, wrench and pick motion, camera nudges), no HUD meters and no X-ray. Clear acrylic practice locks in the Security wing are the tutorial.
- Four tiers (Simple, Standard, Secure, High-security) with seeded random pin data per lock.
- The Lockpicking skill widens tolerances and clears feedback (tier 2 hints the binding pin, tier 3 auto-rakes Simple locks); it never hard-gates a lock.
- Picks break only on failure.
- Any entity with a `Lock` component and pin data uses it (systemic, [ADR 0003](0003-systemic-framework.md)).
- Staging: M8 builds locks as data plus a hold-to-pick placeholder; M10 adds the minigame.

## Alternatives considered

- **Deus Ex-style hold-to-pick timer**: no skill expression, not true to real locks. Kept only as the M8 placeholder.
- **X-ray cutaway view**: makes the mechanic easy to read but is not how picking works; reading by sound and feel is the goal. Used only for the acrylic practice locks.
- **Tension that leaks away unless W is held (auto-leaking)**: hides the meaning of the tension window and punishes holding still. The level holds where it is left.
- **Gamepad first**: mouse and keyboard are the target; gamepad follows in its own milestone ([backlog](../backlog.md)).
- **Consume a pick per lock**: punishes success. Picks break on failure only.

## Consequences

- M8 locks carry pin data and a pick hook; the `lockpick_time_mult` attribute serves the placeholder and is replaced in M10 by tolerance attributes ([abilities](../game/abilities.md)).
- New milestone M10 and practice locks in the Security wing ([README](../README.md), [hub-and-gallery](../levels/hub-and-gallery.md)).
- The loadout economy (2 picks) needs retuning ([inventory](../game/inventory.md)).
- Sound design, tolerances and break thresholds are open ([lockpicking](../game/lockpicking.md)).
- Amends the mechanical-lock line in [security](../game/security.md).
