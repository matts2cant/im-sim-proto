# 103. Character models and animation (Kenney Blocky Characters, CharacterAnimator)

Status: Accepted (amends [ADR 0047](0047-hitboxes-layer-5-part-aware-ray.md), [ADR 0070](0070-guard-combat-and-loadouts.md), [ADR 0071](0071-bodies-discovery-waking-carrying.md) and [ADR 0085](0085-weapons-and-attachments.md))

Date: 2026-11-09

## Context

Guards and training dummies were graybox boxes and a sphere that tipped over when downed. The user asked for the Kenney Blocky Characters (CC0): `character-j` for guards, `character-d` for training dummies, animated with the pack's clips (idle, walk, sprint, holding a gun, shooting, melee, death). The animation must follow the systems, not the guard: any character with the model gets it from its properties (speed, tags, the weapon it holds), never from its identity (AGENTS.md "Systemic design"), and the gameplay (aim, shots, flashlight beam, hit zones, downed collision, carrying, saving) must not change.

The model (probed): no skin; seven rigid parts (`root`, `torso`, `head`, `arm-left`, `arm-right`, `leg-left`, `leg-right`) animated by node transforms (rotation tracks on every part, a position track on `root`). 2.7 units tall, 1.6 wide (arms out), facing +Z. All 26 clips are imported without a loop flag: idle 1.33 s, walk 0.67 s, sprint 0.5 s, die 0.33 s (falls backwards, held lying with the arms over the head), holding-right / holding-both 0.17 s (a static pose: the arm(s) raised to point ahead), holding-*-shoot 0.2 s (arms kick up 11 degrees, the torso leans back), attack-melee-right 0.42 s (the arm up overhead, then a chop).

## Decision

**Assets.** `assets/models/kenney_blocky_characters/` holds only `character-j.glb`, `character-d.glb`, their `Textures/texture-j.png` / `texture-d.png` (the relative path the GLBs reference) and `License.txt`, imported with the blaster kit's settings. The scenes instance the GLB as "Model" scaled **0.66** and turned 180 degrees (it faces -Z): 1.78 m tall (the old head top; the capsule is 1.8 m), 1.07 m across the arms, 0.53 m head. It fits the levels' 1.2 x 2.2 m doorways with about 6 cm a side.

**One component, `CharacterAnimator`** (`actors/common/animation/`): a pure `CharacterAnimModel` picks the clips, a pure `CharacterAnimLayer` cross-fades them, the node adapter samples the model's clips (`Animation.rotation_track_interpolate`) into its part nodes every physics tick. Its inputs are properties only:

| Input | Read from |
|---|---|
| Ground speed | the body's horizontal `get_real_velocity()` (a CharacterBody3D; 0 otherwise) |
| Sprinting | `stance.sprint` (or 3.0 m/s and faster) |
| Down | `state.dead`, `state.unconscious` |
| Grip | the WeaponHolder's drawn weapon: `WeaponData.grip` (new: `ONE_HAND` pistol and baton, `TWO_HAND` assault rifle, shotgun, sniper rifle) |
| Shot, swing | the new `WeaponHolder.fired(weapon)` signal (melee or not from the weapon's kind) |

State to clip (`actors/common/animation/blocky_character_anim.tres`, every name and number is data):

| Layer (parts) | State | Clip |
|---|---|---|
| Base (all) | below 0.25 m/s | `idle` |
| | walking | `walk` at speed / 2.6 m/s (patrol 1.5 m/s: x0.58; investigate 2.5: x0.96), clamped 0.4-2 |
| | `stance.sprint` or 3.0 m/s+ | `sprint` at speed / 5.0 m/s (run 4.0: x0.8); walk and sprint swap at the same stride share |
| Hold (grip's arms) | one-handed weapon drawn | `holding-right` on `arm-right` |
| | two-handed weapon drawn | `holding-both` on both arms |
| Action (grip's arms + torso, head) | a shot | `holding-right-shoot` / `holding-both-shoot`, once (overrides the hold pose) |
| (torso, head, both arms) | a melee swing | `attack-melee-right`, once |
| Down (all) | dead (beats unconscious) / unconscious | `die`, once, held on its last frame |

- Cross-fades take 0.18 s (a shot fades in over 0.05 s); standing up from the down pose takes 0.45 s, so a woken guard eases back to idle.
- **Upper and lower body**: the hold and action layers drive only their parts (node names in the config), so the legs keep the base clip's walk or sprint under a held gun or a swing: a per-part filtered blend, no extra clips. The held arms also follow the aim's pitch (the `Aim` node looking up or down at a target), weighted by the hold layer.
- **Down pose on the floor**: the `die` clip leaves the figure 0.23 m below the floor (the head, the deepest part, lies on its back); the adapter measures this once from the clip's last frame (the model's meshes' boxes) and lifts the model by it as the clip plays, so the lowest part rests on the floor and nothing rises above 0.53 m (the downed capsule is 0.7 m). Bodies stay walkable, findable and carryable as before: collision, layers and hitboxes are still `DownedPose`'s (ADR 0082); the animator only draws.
- **Save/load**: nothing is saved; the pose follows the restored tags. The animator shows the state at once (no fade, the down clip at its end) on its first tick and after a quickload (`QuickSave.LOADED_GROUP`, `on_quickloaded()`), so a loaded body is already lying.
- A body lying still in its held pose is not re-posed until something changes.

**The held weapon hangs from the hand.** The animator adds a "HandMount" under the hand part and calls `WeaponView.hang_from(mount)`: the view's grip pivot sits there (at the fist's end for one-handed weapons, between the fists for two-handed ones), the model's scale undone and the weapon drawn at **1.3x** its size (`held_scale`: the blocky fists are 0.26 m wide and hid the pistol). In a hand the view keeps the recoil but not the first-person melee chop (the arm swings). **Visual only**: shots and sweeps still leave the `Aim` node along its -Z, unchanged; the muzzle flash and the shot noise start at the muzzle, now in the hand (about 0.2 m further right and lower than the old view model). The flashlight stays on the `Aim` node exactly as before (beam, lens and halo): the lens sits at the face's right edge and reads as a head lamp; moving the lens to the left hand was rejected (the hand swings while walking, the beam does not).

**Shadows.** The animated parts and the held weapon cast no shadow (`model_casts_shadows` off): a moving shadow caster makes every shadowed light around it render its shadow map again each tick, and ten idle guards took the warehouse from about 550 to 160-240 frames per second. A static shadow-only proxy (`blocky_shadow_proxy.tscn`, five boxes of the model's rest shape, node "Pose") casts the character's shadow; `DownedPose` (guards) and `TrainingDummy` tip it like the old figure.

**Hit zones** (`actors/common/body/blocky_hitboxes.tscn`, inherits `hitboxes.tscn`; the player keeps the original): the same six shapes and sizes, moved to the model's parts at rest:

| Part | Shape | Old centre | New centre | Model part at rest |
|---|---|---|---|---|
| Head | sphere r 0.14 | y 1.64 | y 1.52 | cube 0.53, y 1.25-1.78 |
| Torso | box 0.44 x 0.62 x 0.26 | y 1.21 | y 0.96 | 0.53 x 0.59 x 0.40, y 0.66-1.25 |
| Arms | box 0.13 x 0.66 x 0.16 | x ±0.3, y 1.18 | x ±0.4, y 0.89, z +0.07 | 0.26 x 0.73 x 0.26, x ±0.26-0.53 |
| Legs | box 0.17 x 0.9 x 0.2 | x ±0.11, y 0.45 | x ±0.13, y 0.45 | 0.26 x 0.66 x 0.26 each, y 0-0.66 |

The hitboxes do not animate (they tip with `DownedPose` as before). Shapes keep their sizes, so a shot at the outer part of the big head (above 1.66 m or below 1.38 m, or its corners) misses it; the torso box covers up to 1.27 m. Damage numbers and tests are unchanged.

**Training dummy**: `character-d` on its base (raised 0.04 m), idle; knocked out or dead it plays `die` (its tags come from BodyParts like a guard's), and `reset()` stands it up through the wake fade. Its physics (layers 3 and 7, ADR 0070) and its tipping hitboxes and capsule are unchanged.

**Every guard scene** gets the model through `actors/guard/guard.tscn` (the pistol, baton and rifle variants inherit it); the graybox meshes and materials are gone. No level changed.

## Measured

- Warehouse (`warehouse_shots.tscn -- perf=1`, 10 guards, 1152 x 648): before about 420-650 fps and 4.5-9 ms physics process per tick (noisy); after 340-560 fps and 5.8-8.1 ms. The animator costs about 76 us per character per tick (0.8 ms for ten). Distance-based throttling was not needed.
- New suites: `character_anim_model_test.gd` (11 tests, pure) and `character_animator_test.gd` (5 tests) run in well under 3 s each.

## Alternatives considered

- **AnimationTree** (BlendTree with filtered Blend2, OneShot and Transition nodes): the standard tool, but the per-grip part filters, holding the last frame of `die`, snapping a loaded pose and lifting the lying model are each one line in a hand-written layer and need workarounds in a tree; sampling seven rigid parts is cheap in script and testable without the scene tree.
- **Animated hitboxes** (each box following its part): more accurate hits on a walking or swinging guard, but shots would depend on animation timing and the downed rules (tipped boxes) would need redoing; rejected for now.
- **Resizing the hitboxes to the model's parts** (a 0.53 m head box): headshots would become about four times easier, a balance change for the user to decide.
- **Keeping the model's shadows**: the shadow-map cost above.

## Consequences

- Any character can carry a rigid-part model with a `CharacterAnimator` and a config; a new clip mapping is a `.tres`.
- A weapon's grip is data; new weapons set it.
- Open: whether to enlarge the head hit zone to the model's head; whether carried bodies should hang limp over the shoulder (they keep the rigid lying pose, translucent, as before); a crouch clip if characters ever crouch (the pack has none).
- Tests: `tests/actors/common/animation/character_anim_model_test.gd`, `character_animator_test.gd`; review shots `tests/actors/common/animation/fixtures/character_shots.tscn` (`-- shots=all`) and `warehouse_shots` `characters_patrol_light`.
