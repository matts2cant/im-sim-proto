# 128. Weapon motion, camera shake, layered shot sounds and echo by place (M13b build)

Status: Accepted (builds part of the M13b feedback of [ADR 0120](0120-weapon-feel.md); extends [ADR 0085](0085-weapons-and-attachments.md), [ADR 0123](0123-recoil-and-skill-aim.md), [ADR 0124](0124-settings-profile.md))

Date: 2026-11-12

## Context

ADR 0120 asks M13b for weapon motion driven by code (kick, sway, bob, reload, draw; no arms or hands), a slight camera shake on firing scaled by the camera motion setting, per-weapon sounds built from the packs in the project (layers, pitch, a bass layer) and an echo tail that depends on indoor or outdoor. Until now the view model only tilted for 0.12 s per shot, every gun played one shared gunshot (Titan Handgun) at a different volume, and nothing reverberated. Game feel is judged in the game, so every value must be tuning data the range's tuning panel can reach (ADR 0125).

## Decision

- **Weapon motion is a view feature driven by data**: `WeaponData.motion` (a `WeaponMotionConfig`, `<weapon>_motion.tres`, every number an `@export_range`) feeds a pure `WeaponMotion` that `WeaponView` adds on top of the grip pivot's pose (offset in the camera frame, Euler turn about the grip). It is on only where the holder's new `view_motion` export is (the player's holder); guards' guns hang from their animated hands and keep the short fixed recoil tilt.
  - **Kick**: a critically damped spring per shot (peak after `kick_time`, back in about five of them), stacking under automatic fire up to `kick_stack_max`; back, nose up, rolled to a random side. The pistol is back in about 0.18 s like its camera recoil, the shotgun and sniper kick hard and slow, the SMG and rifle shudder. Melee keeps its chop.
  - **Sway**: the model lags mouse turns (`sway_per_deg`, capped, returning with a time constant). The player hands its mouse turns to the view (`WeaponView.add_turn()`).
  - **Bob**: the holder measures its user's ground speed from how far the user moved since the last step (any character; a teleport counts as standing), so nothing is player-specific; none airborne (the aim stance), smaller crouched (the `stance.crouch` tag); one side swing and two footstep dips per 4 m (the footsteps' 2 m stride).
  - **Reload**: dips down and out of view over the first quarter of the reload and comes back over the last (`WeaponState.reload_total`, `reload_progress()`).
  - **Draw and holster**: a weapon not already shown rises from lowered over `draw_time` when drawn or switched to; a holster lowers it over `holster_time`, then hides it. Visual only: firing, cycle and switch timings are unchanged (a shot during the draw leaves from the eye as always).
- **Camera shake** (`ViewShake`, pure, in the player): a shot of a weapon with `motion.shake_deg` starts a short decaying wobble (mostly up, a little sideways and rolled, 12 Hz, gone after `shake_time`); a stronger running shake is kept. The camera turns by it times the camera motion setting, so at 0 nothing but the player moves the camera. The holder takes the shake back out of the shots and the crosshair (`WeaponHolder.eye_shake`, subtracted in `aim_offset()`), like the recoil share the camera follows: shaking never moves where bullets go. The player has no camera view bob, so there is none to scale.
- **Layered shot sounds**: `WeaponData.shot_sound` and `suppressed_shot_sound` (a `ShotSound`: `body`, `bass`, `mechanism`, each a `ShotSoundLayer` of a few recorded variants, base volume and pitch, random pitch and volume jitter per shot, a delay) replace the single `fire_sound` for guns; `fire_sound` stays for the baton's swing and weapons without layers (the turret). Fixed slots, not a list, so the tuning panel lists every layer's numbers. `ShotSound.pick()` chooses each layer's variant (never the same one twice in a row) and its variation; the holder's `ShotAudio` plays each voice on its own 3D player from a round-robin pool of nine (so tails ring on at their own pitch), delayed layers (a pump, a bolt) later. A fitted attachment's volume change (`fire_volume_db` through `stat()`) shifts every layer. Silenced shots keep a muffled thud body and the mechanism, no bass.
- **Echo by place**: two buses send to `Effects` (so the effects volume applies): `ReverbIndoor` (wet only; short predelay, little feedback, small room: a short dense tail) and `ReverbOutdoor` (dry plus wet; 140 ms predelay with feedback, large room: a longer, sparser tail). Indoors is an acoustic zone: an `Area3D` on a new physics layer 9 `acoustics` (`PhysicsLayers.ACOUSTICS`) using Godot's reverb bus settings (`reverb_bus_enabled`, `ReverbIndoor`, amount 0.45; `Acoustics.make_zone()`). Every kit `Room` makes one over its interior (`Room.indoor_acoustics`, on by default: a closed room is indoors), so the hub, its gallery rooms and the warehouse's hall, annex, offices, gate booth and basement are indoors with no level edits; the yards, the roof, the road, ducts and the culvert are outdoors, the default. Shot voices let zones reach them (`area_mask`): inside a zone they play on `Effects` and the engine sends the zone's share to `ReverbIndoor`; elsewhere they play on `ReverbOutdoor` (`Acoustics.player_bus_at()`). The place is the shooter's (the voices sit at the holder), so a guard's shot in the yard echoes outdoors whoever hears it.

## Sounds per weapon (from the packs in the project)

Only one real gunshot recording exists in the packs (SFX starter pack `Hollywood/Titan Handgun`); the guns are told apart by its pitch and volume and by their bass and mechanism layers. The user decides whether to add a gun sound pack.

| | Body | Bass thump | Mechanism |
|---|---|---|---|
| Pistol | Titan Handgun x1.05, -4 dB | Kenney `impactPunch_heavy_000-002` x0.75, -12 dB | Kenney `impactMetal_light_000-002` x1.6, -18 dB, +0.03 s |
| SMG | Titan Handgun x1.32, -9 dB | `impactPunch_medium_000-002` x0.8, -14 dB | `impactMetal_light_000-004` x2.0, -20 dB, +0.015 s |
| Assault rifle | Titan Handgun x0.9, -6 dB | Kenney sci-fi `explosionCrunch_000-002` x0.85, -13 dB | `impactMetal_light_002-004` x1.25, -17 dB, +0.025 s |
| Shotgun | Titan Handgun x0.72, +1 dB | sci-fi `lowFrequency_explosion_001`, -4 dB | `Hollywood/Heavy Gun Reload` x1.15, -9 dB, +0.4 s (the pump) |
| Sniper rifle | Titan Handgun x0.8, +3 dB | sci-fi `lowFrequency_explosion_000` x0.9, -3 dB | `impactMetal_medium_000-001` x1.1, -13 dB, +0.6 s (the bolt) |
| Silenced (pistol, SMG, rifle, sniper) | `impactPunch_medium` thud at the weapon's pitch | none | as unsilenced |

Pitch and volume vary per shot by 2-5 % and 0.5-2 dB per layer. The guards' pistol uses the pistol's sound.

## Alternatives considered

- **Motion on every holder, guards included**: a guard's gun hangs from its animated hand, whose animation already moves it; bobbing it again would double the motion.
- **Bob from the player's velocity or input**: the holder would need the player; the user's change of position works for any character.
- **Camera shake that the bullets follow**: then the camera motion setting would change where shots go (ADR 0124 says it never does).
- **`AudioStreamRandomizer` per layer and one player per layer**: the engine would vary pitch per playback, but a test could not see the choice, and one player per layer re-pitches the tails still ringing.
- **An outdoor zone covering the level, indoor zones inside it**: the audio engine takes the first zone a point query returns, with no priority, so nested zones of different buses are not reliable; outdoors is simply "no zone".
- **Zones placed by hand in each level**: every Room is already level data that says "enclosed"; a separate zone would drift from the room it belongs to.

## Consequences

- `WeaponData` gains `motion`, `shot_sound`, `suppressed_shot_sound`; `WeaponHolder` gains `view_motion`, `eye_shake`, `shot_audio`; `WeaponView` gains the motion, `add_turn()`, `settle_motion()` (tests) and `is_holstering()`; `WeaponState` gains `reload_total` and `reload_progress()`.
- `default_bus_layout.tres` has `ReverbIndoor` and `ReverbOutdoor`; `project.godot` names physics layer 9 `acoustics`.
- A Room generates one more internal child (the zone); a room meant to sound outdoors sets `indoor_acoustics` off.
- Tests that fire right after drawing settle the view (`settle_motion()`), since the model is still rising.
- Other sounds (footsteps, impacts, alarms) can opt into the echo by setting `area_mask` and the bus from `Acoustics`.
