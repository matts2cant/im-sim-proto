# 105. Character model playtest fixes: lit materials, one-handed weapons with a hold turn, the flashlight in the off hand, still dummies, the head hit zone

Status: Accepted (amends [ADR 0103](0103-character-models-and-animation.md) and [ADR 0095](0095-darkness-and-flashlights.md))

Date: 2026-11-10

## Context

Playtest of the character models (ADR 0103): the characters "don't seem shaded, and are overly bright"; guards hold the baton horizontally (it should stand across the fist, like a real baton); the two-handed holds look odd ("hold their weapons in one hand like the pistol"); the flashlight should be a real flashlight in the off hand, not a lens on the face; training dummies should not idle; and the head hit zone should match the model's big blocky head.

## Decision

**Lit materials.** The Kenney GLBs mark their one material `KHR_materials_unlit`, so Godot imported it `SHADING_MODE_UNSHADED`: the texture at full brightness whatever the lights (no emission, no vertex colours; roughness 1, metallic 0, linear filtering without mipmaps). Turning shadow casting off (ADR 0103) only stops the parts casting shadows; it never affected how they are lit. The import now maps each GLB's material to an external `StandardMaterial3D` (`assets/models/kenney_blocky_characters/materials/character_j.tres`, `character_d.tres`: the same texture, per-pixel shading, roughness 0.9, specular 0.3, linear filtering) through the `.import` file's `_subresources` (`use_external`). No code: every character with the model is lit by the scene's lights and receives shadows like the world props.

**One hand for every weapon.** The assault rifle, shotgun and sniper rifle are `WeaponData.grip` `ONE_HAND` now (the default; their `grip = 1` lines are gone), so they use `holding-right` and `holding-right-shoot` like the pistol. The grip field and the two-handed path (`holding-both`, both arms, the mount between the hands) stay: a weapon whose data asks for it still gets it, tested with a stand-in.

**Hold turn per weapon.** `WeaponData` gains `hold_rotation_deg` (Euler degrees, like `view_rest_deg`) and `hold_offset` (metres at the weapon's size, before the 1.3x held scale): the grip pivot's pose in the hand mount, whose -Z runs out of the fist along the forearm and +Y is up when the arm points ahead. `WeaponView` applies it in a hand (`hold_transform()`, recoil on top); the first-person view is unchanged.

| Weapon | hold_rotation_deg | hold_offset | Reads as |
|---|---|---|---|
| Baton | (90, 0, 0) | (0, -0.18, 0.1) | upright across the fist, a short end below it |
| Pistol | 0 | 0 | along the forearm, at the fist's end (as before) |
| Assault rifle, shotgun | 0 | (0, 0, -0.12) | the grip in the fist, the stock along the forearm |
| Sniper rifle | 0 | (0, 0, -0.2) | the same, the longer barrel further out |

**The flashlight in the off hand.** `Flashlight` builds the flashlight itself ("Held": a 0.24 m body and a wider 0.06 m head from cylinders, 0.08 m of it behind the grip) and puts the lens, the halo and the beam on it, at its front. The `Flashlight` node stays on the `Aim` node where ADR 0095 put it: its -Z is still the beam's direction. A `CharacterAnimator` with an off-hand item (`off_hand_path`, the guard's `Aim/Flashlight`) adds an "OffHandMount" to the off-hand part (`arm-left`, at the fist) and a "StowedMount" to the torso (front left of the belt, pointing down) and calls `Flashlight.hang_from(hand, stowed)`:

- **Lit:** the flashlight sits at the hand mount and points exactly along the `Flashlight` node's -Z, whatever the arm does, so the beam's direction never depends on the animation; only its origin moves to the fist. The left arm plays `holding-left` (new off-hand layer, under the hold layer: a two-handed hold, a shot or a swing overrides it), turned by `off_hand_turn_deg` (-14, -48, 0): across the chest, below the chin, so the lens comes close to where it was. It follows the aim's pitch like the held arm. The off-hand pose also drives the torso (`off_hand_parts`), so the upper body stays upright under the light: the sprint's 25-degree forward lean carried the hand 0.35 m further away.
- **Off:** it hangs at the belt and the left arm is free (the walk swing).
- **Down:** the carrier's `off_tags` switch it off (unchanged) and the flashlight stays where it was: a guard knocked out with it lit keeps it in the fist (rigid with the hand, so it lies with the body and comes along when carried); one downed with it off keeps it at the belt. Dropping it on the floor was rejected: a carried body would leave it floating.
- The flashlight runs after the animator each tick (`process_physics_priority` 10), so the light follows the posed hand on the same tick. Without mounts (a carrier without an animator) the lens sits at the node, as before.

**Still dummies.** The training dummy's animator uses its own config, `blocky_mannequin_anim.tres`, whose `idle_clip` is the model's `static` clip (every part at rest, the arms straight down): a stiff mannequin. A per-entity setting through data, no dummy code: any character given that config stands still. `die` on a knockout and `reset()` standing it up are unchanged.

**Head hit zone.** `blocky_hitboxes.tscn` replaces the head sphere (r 0.14) with a box matching the model's head at rest, measured from the mesh (0.8 model units x 0.66): a 0.528 m cube centred at y 1.518 m (1.254-1.782), on the body's axis. The body-part rules are unchanged (head 40, `damage.ballistic` x2). Only weapon rays and the interactor's ray see hitboxes (layer 5); the player's body (mask 13) and props never collide with them, so the bigger head blocks no movement. A lying body's head box is as big as the lying model's head, which the interactor's ray already met. The player keeps its own `hitboxes.tscn` (sphere).

## Measured

**Flashlight alignment** (`held_flashlight_test.gd`, guard_pistol with its AI off, lit): the beam's direction is exactly the `Flashlight` node's (0.0 degrees in every state; that node is 10 degrees below the eye's line, as in ADR 0095). Its origin, from where the lens was (the node on the eye):

| State | Origin offset |
|---|---|
| Standing, patrol walk 1.5 m/s, search walk 2.5 m/s, sprint 4 m/s | 0.46 m |
| Aiming the pistol 8.5 degrees down / up | 0.52 / 0.40 m |
| Shooting (aimed up) | 0.40 m |

The brief asked for about 0.4 m. A rigid 0.66 m blocky arm cannot bring a visible flashlight closer without crossing the face: with the lens just past the fist (the flashlight hidden in it) and the arm raised across the head it reached 0.29-0.34 m, but the arm went through the head. Aiming down moves it further because the arm pitches about the shoulder, 0.4 m below the eye. The ADR 0095 tests pass unchanged: a walking player in the beam at 8 m is Alerted in 2.38 s (target 2-3 s), a lit body is found.

**Head hit zone** (`weapon_outcomes_test.gd`, the player against a target with the guards' body, 8 seeds):

| | Old sphere | New box |
|---|---|---|
| Pistol at the head, 10 m, settled | 1 shot | 1 shot |
| Pistol snapped onto the head (3-degree cone, a shot every cycle) | 5 of 8 alive after 4 s; others 1.8-2.5 s | 0.4-2.5 s, 6 of 8 within 2 s |
| Shotgun aimed at the torso, 15 m, shots to kill | 3-6 (median 3) | 1-3 (median 2); 3 of 8 die to one shot |

The upper pellets of a shotgun torso shot now land on the head: the 15 m target of ADR 0085 ("3 or more") no longer holds. The test now checks that fewer than half the seeds die to one shot at 15 m; whether the shotgun needs retuning (spread, falloff) is open.

**Frame cost** (`warehouse_shots.tscn -- perf=1`, 10 guards, 1152 x 648, three runs each; frames per second, physics process per tick; outliers of 10-17 ms physics on a first shot left out):

| Shot | Before (ADR 0103) | After | After, every flashlight on (`flashlights=1`), before / after |
|---|---|---|---|
| `yard_from_gate` | 571-616 fps, 5.7-6.5 ms | 570-600 fps, 6.2-6.4 ms | 598-639 / 566-588 fps |
| `characters_patrol_light` (a lit patrol 4 m away) | 1451-1557 fps, 6.1-6.5 ms | 1325-1392 fps, 6.4-6.7 ms | 1467-1491 / 1354-1380 fps |
| `m9g_patrol_light_15m` | 574-626 fps, 7.0-7.5 ms | 550-566 fps, 7.2-7.4 ms | 574-576 / 488-530 fps |
| `hall_dock` | 315-345 fps, 6.7-6.8 ms | 302-310 fps, 7.2-7.4 ms | 305-313 / 286-295 fps |

About 5 % fewer frames per second (shaded materials, and a lit beam's shadow map now redrawn every frame as it moves with the hand; up to 11 % with every flashlight on in the yard) and about 0.3-0.5 ms more physics per tick (the off-hand layer and placing the flashlights). No throttling needed.

## Alternatives considered

- **Unlit look with darker textures**, or a light-reading shader: unlit can never be darker in the dark than the walls next to it; the external material is the standard path.
- **The beam's basis from the hand** (the flashlight rigid in the fist): its direction would follow the walk, the sprint lean and the turn of the arm. Copying the eye's direction keeps the gameplay of ADR 0095 exactly.
- **A hand-held pose straight ahead** (`holding-left` without a turn): the lens 0.6-1.0 m from where it was; the turn across the chest halves that.
- **Removing the grip field**: no simpler (the config, model and tests already branch on it) and a two-handed weapon may come back.
- **A smaller head box** (between the sphere and the model's head): the brief asked for the head the player sees.

## Consequences

- Shooting a guard in the head is much easier, and the shotgun at range much stronger (above): a balance question for the user.
- Any new character model with an unlit GLB material needs the same import mapping.
- A weapon's in-hand pose is data (`hold_rotation_deg`, `hold_offset`); a new weapon sets it.
- The off hand can hold any `Flashlight`; another kind of off-hand item would need the same small API (`hang_from()`, in use while `lit`).
- Tests: `held_flashlight_test.gd` (alignment across states, belt, downed), `blocky_hitboxes_test.gd` (head box from the mesh), `character_animator_test.gd` (every weapon one-handed at its hold turn, a static idle stands still), `character_anim_model_test.gd` (stand-in two-handed grip, off-hand pose), `training_dummy_test.gd` (a standing dummy holds still), `weapon_outcomes_test.gd` (pistol at the head; shotgun at 15 m). Shading: `character_shading_test.gd` (every model mesh of a guard and a dummy draws per-pixel shaded, no emission, no override; a headless run cannot render, so it checks the material).
