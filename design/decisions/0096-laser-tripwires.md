# 96. Laser tripwires

Status: Accepted

Date: 2026-11-09

## Context

M9g asks for laser detectors that can raise the alarm, as devices on the security network of [ADR 0077](0077-devices-cables-and-remote-commands.md), built the way the security camera is ([ADR 0079](0079-security-cameras-and-turret.md)): a Device plus a behaviour component, remote commands as stimuli, status words for the screens ([ADR 0083](0083-security-terminal-redesign.md)). The systemic rules (AGENTS.md) ask that anything with a body breaks the beam the same way, the player included, and that what it ignores is a tag rule, not an identity.

## Decision

- **Component** `LaserTripwire` (`objects/laser/laser_tripwire.gd`) beside the entity's `Device`; tuning `LaserTripwireConfig` (`objects/laser/laser_tripwire.tres`). The beam runs from the entity's origin along its local +Z for `beam_length` metres (per instance); the instance's height is the beam's height.
- **Beam check**: each physics tick a thin box (`beam_width` 0.03 m, inset `end_inset` 0.08 m from both ends) is checked with `intersect_shape` against the config's `detect_mask`: player, actors, objects, static actors and downed bodies (never the world layer, so walls and the device's own boxes never trip it). A held body is a ghost (layer 0) no query finds: `Carryable` puts itself in group `carried` while held (`Carryable.CARRIED_GROUP`), and the laser tests those bodies' shape bounds against the beam segment. So a body walking, a prop thrown or held out, and a body lying in the beam all trip it.
- **Ignored tags**: a body whose entity (the collider, or its nearest ancestor with `Tags`) has one of `ignored_tags` (default `actor.guard`: patrols do not ring it) passes unseen, unless it also has one of `trip_anyway_tags` (`state.unconscious`, `state.dead`): a downed guard falling into the beam trips it.
- **Trip** (`TripwireModel`, pure): the first break trips it once: `Device.report_incident(point)` (the point of the beam nearest the body) to every alarm controller it reaches, a beep (noise 8 at the emitter, placeholder tone) and EventLog `laser.tripped {laser, by, point, controllers}`. It stays tripped until the beam has been clear for `rearm_delay` (1 s), so one crossing, however slow, or a body left in the beam is one incident.
- **Commands**: the shared `command.disable` / `command.enable` receptrons (`laser.toggled {laser, enabled}`). Disabled, unpowered or broken (its Device down) it neither checks nor shows its beam; coming back it starts armed and clear.
- **Status**: `device_status()` gives `enabled` / `disabled` and `clear` / `tripped`; no view, so it is on the terminal's Network tab and the debug network overlay but not the Camera tab. Screens show `offline` when they cannot reach it.
- **Scene** `objects/laser/laser_tripwire.tscn`: a `StaticBody3D` (world layer) whose origin sits on the emitter's wall face at beam height, +Z across the gap. Two 0.12 x 0.12 x 0.08 m metal boxes (emitter with a red lens, receiver moved to `beam_length` at load) are its collision shapes, so a shot at either end hits the device. Health 20 of `material.electronics` (the camera's values): one pistol round (25) breaks it. Saveable (disabled, trip state); `Device` saves `broken`.
- **Heights** (metrics: jump apex 1.0 m, crouched height 0.95 m): low beam 0.4 m (jumped: walking, the feet are above 0.4 m from 0.07 to 0.57 s of the 0.64 s airtime, so a take-off 0.64 to 1.92 m before the beam clears it), high beam 1.3 m (crouched under with 0.35 m to spare), and a pair 0.4 m + 1.3 m that neither a jump nor a crouch gets past: it must be disabled, unpowered or broken.
- **Gallery**: the security wing's laser hall, behind closet D1 (see [hub-and-gallery](../levels/hub-and-gallery.md#5-security-wing)).

## Alternatives considered

- **A ray along the beam**: returns only the first hit, so an ignored guard in front would hide an intruder behind; a shape query returns every body in the beam at once.
- **An Area3D for the beam**: areas see bodies by layer like queries do, so it still misses held ghosts, and it adds monitoring state to save and restore.
- **Ignoring guards unconditionally**: a knocked-out guard dropped into the beam is a body breaking it; keeping the exception for able staff is the readable rule.
- **A cooldown after each trip** (like the camera's report cooldown) rather than re-arming on a clear beam: a slow crouch through the beam would report twice.

## Consequences

- Any entity with a `Device`, the receptrons and a `LaserTripwire` is a tripwire: tested on a minimal entity built in code (`tests/objects/laser/laser_tripwire_test.gd`), with the shipped scene and the real player (`laser_tripwire_player_test.gd`: walk, jump, crouch, pair, a thrown crate, a pistol round), its beep on a baked navmesh (`laser_beep_hearing_test.gd`), the alarm chain and terminal (`tests/scenarios/laser_alarm_test.gd`) and the gallery (`tests/levels/gallery/security_wing/security_wing_lasers_test.gd`). Pure model: `tripwire_model_test.gd`.
- Throwing a prop through a beam is a way to ring the alarm on purpose (a distraction).
- Level builders set `beam_length` to the gap between the two wall faces (the receiver is placed at load, not in the editor) and keep world geometry out of the beam; the gallery test checks the first world hit along each beam is the far wall.
- See [security](../game/security.md#laser-tripwires).
