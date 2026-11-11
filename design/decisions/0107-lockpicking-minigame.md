# 107. Lockpicking minigame: the prototype's model, an assist ladder by skill, pin changes that reset the lift, practice locks that re-lay their pins

Status: Accepted, amended by [ADR 0109](0109-lockpicking-side-view-and-mouse-pick.md) (side view and rigid pick, mouse-driven tip with a bottom band instead of pin changes that reset the lift, wheel tension, sweet spot, dwell / bias / overset rules, physical raking)

Date: 2026-11-11

## Context

[ADR 0073](0073-realistic-lockpicking.md) set the rules of a realistic pin-tumbler minigame and M8 ([ADR 0078](0078-doors-locks-and-door-navigation.md)) built the lock data and a hold-to-pick placeholder (pins x 1 s x `lockpick_time_mult`). The user approved an HTML prototype ([lockpicking_bench.html](../prototypes/lockpicking_bench.html)) and settled what M10 builds: its mechanics and drawing in game, in real time, with assists that grow with skill (ADR 0073 had "no HUD meters, no X-ray"), the prototype's pin-change bug fixed, and practice locks as the tutorial. Sounds are ADR 0108.

## Decision

- **The model is the prototype's**: `PinTumbler` (pure RefCounted) ports `step()` faithfully: binding order, the spring tip whose lag is the force, sets, oversets (cleared by releasing tension), spool false sets and counter-rotation, serrated ticks, strain and pick break, pin drops below the drop threshold (all at 0 %), the Master's auto-rake, the plug angle. Every number lives in `LockpickTuning` (`lockpick_tuning.tres`), unchanged. A lock builds its model (`MechanicalLock.new_model()`) from its data: `pins` in order, `pin_seed` (same lock every retry), `tolerance_mult`.
- **The screen is a thin adapter**: `MechanicalLock.tool_hold()` (still driven by `ToolUse`, doors unchanged) opens the user's `LockpickScreen`, a CanvasLayer child of the player. It does not pause: the player's input is off (no walking or looking; the stance stays), the camera turns to the lock (`Player.face_towards()`), W / S / A / D / Shift are `lockpick_*` actions, relative mouse Y moves the lift target, LMB rakes. It leaves on E or Esc (taking the event first, so the game menu never opens), damage, the user unable to act, the lock unlocked by other means, out of reach or the last pick broken. Model events play their `LockpickAudio` cue, show their caption and make their noise at the lock (`pick_noise()`, the usual noise path, ADR 0073's loudness table); the open event calls `complete_pick()` (unlocks it for the user, who wants it open). A broken pick uses up one tool of the lock's kind (`PlayerInventory.use_up_tool()`). Front view, gauge and pins view are Control `_draw` ports of `drawFront()`, `drawGauge()` and `drawSide()`.
- **Skill as attributes**: `lockpick_time_mult` is removed. The Lockpicking skill adds ADD modifiers to `lockpick_window_low` / `_high`, `lockpick_drop_threshold`, `lockpick_drop_delay`, `lockpick_lift_tolerance`, `lockpick_rake` and `lockpick_assist`, whose bases are in the tuning, so every tier equals the prototype's `skillParams(t)`. `LockpickParams` reads them from the picker every tick. The prototype's binding-pin `hint` (louder scrape, pick tremor at tier 2+) is dropped.
- **Assist ladder**: cumulative from `lockpick_assist`: 0 sound only, 1 + the tension gauge, 2 + captions, 3 + the pins view. It is an attribute so an augmentation can raise it. A practice lock always shows all three.
- **Changing pins resets the lift**: A / D set the lift target to the bottom; the tip falls below the pins (0.05 s from full lift), then the pick moves across one pin per 0.05 s; mouse lift is ignored until it arrives and further presses queue. In the prototype the pick moved with the tip up, so the next pin was lifted at once and often jammed.
- **Practice locks** are a property of the lock data (`practice`, `practice_tier` choosing one of the tuning's four tiers: Simple, Standard, Secure, High-security with the prototype's pins and tolerances). Once opened, `PracticeRelock` re-locks the Lockable 3 s later with a new random seed and the layout counter + 1 (saved), whether or not the picker stayed; an open screen re-lays its model (the plug turns back, the old pins drop, the new shear lines ease in over 0.5 s), plays `relock`, captions "new pin layout" and shows "Layout N". Real locks keep their seed. Picks break on practice locks like on any lock.
- Rakeable is a property too: at most `rake_max_pins` (3) pins, all standard.

## Alternatives considered

- **Keep ADR 0073's "no meters"**: the prototype showed the lock is hard to read by sound alone for a new player; the user chose meters that come with skill, so mastery still shows.
- **Pause the game while picking**: rejected by ADR 0073; picking under a guard's patrol is the tension of the mechanic.
- **A minigame node on the lock** instead of a screen on the picker: the UI and input belong to the player; the lock stays data plus a small API any entity can carry (doors, lockers, the practice lock).
- **Practice locks as their own component**: a flag in the lock data needs no new node and keeps every lock on one path.

## Consequences

- Any entity with a `Lockable` and a `MechanicalLock` is picked the same way (tested on a bare box).
- Old tests that held LMB for the placeholder's time now call `complete_pick()` for the minigame's success; the minigame itself has unit tests (model, params, re-lock) and integration tests with the real player (`tests/ui/lockpick/`).
- The door prompt's "Picking N%" is no longer shown (`tool_progress()` stays -1).
- Captions follow skill only; an accessibility option is a later pass.
