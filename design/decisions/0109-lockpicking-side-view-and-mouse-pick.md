# 109. Lockpicking rework: the side view with a rigid pick, a mouse-driven tip with a bottom band, wheel tension, a narrower sweet spot, dwell / bias / overset rules, physical raking

Status: Accepted (amends [ADR 0107](0107-lockpicking-minigame.md))

Date: 2026-11-11

## Context

M10a ([ADR 0107](0107-lockpicking-minigame.md)) ported an earlier version of the lockpicking prototype: a front view of the plug with a separate pins panel, W / S tension, A / D pin changes that drop the pick first, mouse Y lift, and the Master's hold-LMB rake. The user kept iterating on the prototype ([lockpicking_bench.html](../prototypes/lockpicking_bench.html)) and approved a final version: the lock seen from the side with a rigid pick the mouse moves directly, wheel tension, stricter setting rules and physical raking. M10c ports it. The bench's "Controls" select is a bench option only; the game takes its default wheel scheme.

## Decision

- **Controls**: tension is on the **mouse wheel**, 3 % a notch, 1 % with `lockpick_fine` (Shift); it holds where left. `lockpick_tension_up` / `_down` are rebound from W / S to wheel up / down (W / S do nothing while picking). The mouse stays captured: relative motion moves the pick's **aim**, Y the lift (0..1, 300 px for the full lift) and X the tip's target along the keyway (`aim_x`, in pin slots, 60 px a slot, clamped 0.45 of a slot past the front and back pins). Sensitivities are tuning values (`lift_pixels`, `slot_pixels`).
- **The bottom band** (lift <= 0.10): the tip slides along the keyway (eased, 14 / s) only while tip and aim are both in it; above it the tip stays under its pin. Its pin is the nearest slot once the tip is more than 0.55 of a slot from the old one. A / D aim at the previous / next pin slot, only in the band (the bench's A / D move the pin index, which its wheel scheme then overrides; aiming at the slot is the same move made by keys). This replaces ADR 0107's "drop the pick, then move in 0.1 s".
- **The view** (`LockpickSideView`, replacing the front view and the pins panel): the prototype's side cutaway in a real practice lock's proportions (body `n x 0.148 + 0.25` body heights wide, housing and plug of similar height, chambers 45 % of the spacing, the plug's cam end with a screw slot). The **rigid hook pick** (flat handle, two rivets, thin shaft, small upturned hook, fixed lengths) pivots in the keyway mouth and slides in and out so its hook ends at the simulated tip; it bows with force and pales under strain. The wrench blade sits in the keyway mouth, its arm swinging with tension. The **clear lock** (the Master assist, `ASSIST_PINS`, and practice locks) draws the body as acrylic with pins, springs, shear line and labels; otherwise the body is brass with a soft keyway groove and the pick is drawn in three clipped passes: solid outside the lock, faded behind the brass, solid in the groove. The gauge stays at the right edge. The panel is 16:9, 55 % of the screen width, above the HUD belt, the world visible around it. A practice re-layout shows in the same view (pins drop and settle).
- **Sweet spot**: `lo = 0.40 - 0.03 t`, `hi = 0.55 + 0.03 t` (40-55 % untrained, 31-64 % at Master): the `lockpick_window_*` bases and the skill's steps change. Drop thresholds unchanged.
- **Pins**: the key pin always rests on the tip, set or not (a set pin's driver stays caught above the shear line); the M10a margin that held a set key pin below the tip is gone. The binding pin sets only after staying in the set window for the **dwell**, `0.08 - 0.012 t` s (a new attribute, `lockpick_set_dwell`). On a set the tip does not spring up to the aim: the aim's lead becomes a **bias** (`aim_bias += target - tip`; each tick `aim_bias = min(aim_bias, aim)`, `target = max(0, aim - aim_bias)`), worn off by lowering the mouse.
- **Overset** only with tension at the sweet spot's low edge or above: the binding pin past the shear line + tolerance (a fast lift through the window oversets); a set or loose pin past it + tolerance + 0.15 (`set_overset`; a set pin that oversets is no longer set). Caption "clunk, a pin is overset: release the tension to reset". Recovery unchanged (tension to zero drops every set pin).
- **Raking** replaces the hold-LMB rake: a stroke is the tip moving sideways in the bottom band faster than 2.5 slots / s; each reversal counts one (a tick, the scrape, a `rake` noise at the scrape loudness at most every 0.6 s, sharing the scrape's throttle); 0.5 s without one loses the rhythm. Every lock rattles. A picker whose `lockpick_rake` is on (Master), on a **rakeable** lock (a property: at most 5 pins, all standard: `rake_max_pins` 3 -> 5, so Simple and Standard), with tension from the drop threshold to the sweet spot's top and no overset, sets the binding pin every 3 strokes; otherwise a caption says why at most every 1.5 s (add a little tension / too much tension / release an overset pin). The rake timer and lift wave and their tuning are removed.
- **Sound**: scrape and strain go to 0 once the lock opens (and on leaving, as before).

## Alternatives considered

- **Keep W / S tension and the pin-change drop**: the user played both in the bench and chose the wheel and the mouse-driven tip; the bottom band keeps the M10a fix (no jamming the next pin by moving with the pick up) in a form the hand learns.
- **Absolute mouse position for the tip** (as on the bench page): the game keeps the mouse captured (no cursor over a live 3D view), so motion is relative with tuned sensitivities.
- **A / D moving the pin index directly** (the bench code): with the wheel scheme the tip's goal is the mouse aim, which pulls the pin back at once; moving the aim makes the keys work.

## Consequences

- `PinTumbler` takes the aim (`move_aim()`, `step_pin()`, `turn_wrench()`); `step(dt)` has no input arguments. Its events add `rake_stroke` (the tick), `rake` (a noise) and `rake_hint` (a caption).
- `LockpickFrontView` and `LockpickPinsView` are removed; `LockpickSideView.drawn_clear` / `drawn_gauge` tell tests what was drawn.
- Tuning removed: `tension_rate`, `tension_fine_rate`, `set_pin_margin`, `rake_time`, `rake_base`, `rake_amplitude`, `rake_period`, `lift_per_pixel`, `pin_change_drop_time`, `pin_change_move_time`.
