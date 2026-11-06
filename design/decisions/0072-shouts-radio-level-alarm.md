# 72. Shouts, radio and the level alarm

Status: Accepted (extends [ADR 0068](0068-awareness-states-and-guard-behaviour.md))

Date: 2026-11-06

## Context

Guards must pass alerts on: a shout that carries through the space like noise, a radio that reaches farther and through walls, and a level-wide alarm that M8's panels and cameras will raise. Exactly three autoloads exist (AGENTS.md); a new one is not allowed. Systems talk through stimuli.

## Decision

- **`AlertComms`** component (sibling of GradedAwareness; tuning **`CommsConfig`**, the guard's `guard_comms.tres`; pure decisions in **`CommsRules`**):
  - **Shout**: on entering Alerted (`CommsRules.should_shout`) and on finding a body (BodyDiscovery's `body_found`, ADR 0071) it emits `alert.shout`, a RADIUS stimulus of loudness 18 (intensity = radius) propagated along the navmesh like noise (PATH, doors attenuate). Logged `actor.shout {actor, reason, point}` (reason `alerted` or `body`).
  - **Radio**: on entering Alerted, if the character has the tag `equipment.radio` (guard.tscn does; the loadout variants inherit it), it emits `alert.radio`, a STRAIGHT RADIUS stimulus of 30 m: walls do not matter. Logged `actor.radio {actor, point}`.
- **Hearing calls**: the guard's `Ears` get the **`heard_shout`** receptron (`alert.shout`, min perceived 1.0: up to 17 m of path), its main receiver the **`heard_radio`** receptron (`alert.radio`, requires `equipment.radio`); both blocked while downed and run an `AwarenessEffect` of the new kind **CALL** (reason `shout` / `radio`): `Awareness.notice_call(origin, source, why)`. GradedAwareness heeds it only from a source with an ally tag (logged `actor.heard_call {actor, from, kind, point}`) and calls `AwarenessModel.search_at(origin, why)`: Searching with the caller's position as the first destination at run pace, then 3 random points (search_index starts at 1). Alerted characters keep chasing; a character tending a body keeps tending. Searchers neither shout nor radio, so calls do not cascade; a shout is not `noise`, so guards still ignore allies' footsteps.
- **Level alarm**: a **`LevelAlarm`** node per level (`levels/kit/level_alarm.tscn`; the hub has one), in the group `level_alarm` (`LevelAlarm.current(tree)`); no autoload.
  - Raised by an **`alarm.raise`** stimulus from any emitter: its own StimulusReceiver has the `alarm_raise` receptron (`levels/kit/alarm_raise.tres`) with **`RaiseAlarmEffect`**. `LevelAlarm.make_raise(origin, source)` builds one with a 10 km radius so it reaches the alarm anywhere in a level (M8 panels and cameras use it).
  - Pure **`AlarmTimer`**: on for `duration` 90 s, raising again restarts it, `clear()` ends it. Logged `alarm.raised {by, point, duration, again}`, `alarm.ended {reason: timeout | cleared}`. Saved (time left, point).
  - While raised, every character's AlertComms keeps it wary (at least 60 s more) and, when Unaware or Suspicious (`CommsRules.alarm_searches`), starts a search around where it stands (reason `alarm`); a finished search starts again while the alarm lasts. Alerted and Searching characters carry on. Guards do not run to alarm panels yet (M8).
  - HUD: a red "ALARM" label at the top while raised. Debug panel, Overlays tab: "Raise alarm" (an `alarm.raise` stimulus from the player's position) and "Clear alarm", with the time left.
- **Barks**: `BarkLines` picks lines by the change's reason too: `body_found` ("Man down!"), `called` (shout, radio, alarm: "On my way!") and `woken`.

## Alternatives considered

- **Calls as `alert_at()`** (Alerted at once): every guard in earshot would run in with the meter full and engage on the first glimpse; Searching keeps the escalation graded and gives the player a chance to hide.
- **Shouts as `noise`**: guards ignore allies' noise (ADR 0069), and a shout means more than "something made a sound": a separate type keeps both rules simple.
- **Radio as a direct call to every guard in range**: bypasses the stimulus log and the receptron tag rule (`equipment.radio`), which lets a jammer or a stolen radio work later by tags.
- **An alarm autoload**: forbidden (exactly three); a level node in a group is found the same way and is saved with the level.
- **The alarm sending guards to its origin**: with no panels yet, every guard in the level would converge on one spot; searching where they stand reads as "on alert" and M8 can add panel-running.

## Consequences

- Any character with GradedAwareness and AlertComms shouts and radios; any with the receptrons hears; a camera (M8) can emit `alarm.raise` without knowing about guards.
- A level without a LevelAlarm simply has no alarm (make_raise reaches nothing).
- Tests: `tests/actors/common/awareness/comms_rules_test.gd`, `awareness_model_calls_test.gd`, `tests/levels/kit/alarm_timer_test.gd`, `tests/scenarios/guard_comms_test.gd` (fixture `tests/scenarios/fixtures/comms_yard.tscn`: a shout reaches an ally 5 m of path away and not one 21 m around a wall; radio reaches 25 m through the wall and not 35 m; no radio tag, no call; a non-ally's shout is not heeded; the alarm sends all five guards searching and ends after 90 s; save and clear).
- See [perception and AI](../game/perception-and-ai.md), [debug panel](../game/debug-panel.md).
