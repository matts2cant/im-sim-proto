# 120. Weapon feel: skill-to-aim blend, recoil patterns, feedback (M13a and M13b)

Status: Accepted (extends [ADR 0048](0048-aim-model.md) and [ADR 0085](0085-weapons-and-attachments.md))

Date: 2026-11-11

## Context

The roadmap asks for weapon feel "closer to Counter-Strike". Today accuracy is a Deus Ex style cone (ADR 0048): shots land uniformly inside the reticle circle, which grows with movement, firing and turning and shrinks as the player settles; Weapons skills shrink the cone and the settle time. Recoil is only the weapon model tilting for 0.12 s. There are no hit markers, impact effects, tracers, hit reactions, weapon motion or per-weapon sounds (one shared gunshot). The user and the chief engineer settled M13 in a design review (grilling, three rounds).

## Decision

**Split**: M13a Feel loop (recoil, spread, skill scaling, the submachine gun, the shooting range, the settings menu), then the user's playtest, then M13b Feedback.

**M13a, the feel loop**

- **Accuracy blends character skill and the player's aim.** An Untrained character misses often even with a good aim (the Deus Ex cone stays large); each tier moves closer to Counter-Strike, where the player's own aim and recoil control decide. Only Master's first shot is exact when standing still; lower tiers keep a smaller still cone per step.
- **Targets, measured by tests** (first guesses, tuned by the user on the range). A still player at 10 m from a standing guard's torso:

  | | Untrained | Trained | Advanced | Master |
  |---|---|---|---|---|
  | Pistol, shots after a short pause, hit share | ~55 % | ~75 % | ~90 % | ~100 % |
  | Assault rifle, 10-shot spray, recoil pulled well, hit share | ~30 % | ~50 % | ~70 % | ~85 % |

  Today's measured outcomes stay targets: the shotgun kills in one shot at 5 m (the user kept its strength), the scoped sniper kills with one torso shot at 40 m, the assault rifle kills in about 0.6 s at 10 m at Master with good recoil control.
- **Recoil**:
  - automatic weapons (assault rifle, submachine gun) follow a fixed pattern per weapon plus a little random noise;
  - the camera climbs with the whole pattern and returns by itself once firing stops; during a spray the player pulls down to compensate;
  - semi-automatic weapons kick once per shot (up, a little sideways) and recover in about 0.2 s, so tapping needs no correction; the shotgun and the sniper kick hard, the sniper's scope blacks out briefly.
- **Skill scales recoil**: the pattern's size and noise (Untrained ×1.5 size and ×2 noise, Master ×1 and ×0.5), and recovery speed (the current settle times stay). Every tier learns the same shape.
- **Spread while firing** grows per shot and recovers when the player pauses (the current per-shot bloom, retuned).
- **Moving penalty, moderate**: running hurts, walking and crouching are near-accurate, airborne is bad (the current walk/sprint/air/crouch terms, retuned).
- **No aiming down the sights**; the sniper keeps its scope.
- **A submachine gun** (Kenney `blaster-a` model): damage 9, 0.07 s between shots, 30 rounds, 1.8 s reload, 40 m range, a pattern drifting more sideways than up, takes a silencer, noise 22 m; pistol ammo and the Pistols skill. Target: kills a standing guard in 0.6–0.7 s at 5 m with recoil controlled, clearly worse than the assault rifle past 15 m. On the hub's weapons rack and carried by one or two warehouse guards (who drop it). Guards keep their current aim model until M13b.
- **The shooting range** (a new hub gallery room): dummies at 5, 10, 20 and 40 m and one walking side to side; a spray wall that keeps every hole; a stats panel (hit share, group size); live tuning sliders per weapon (pattern size, noise, recovery, spread, kick, shake) that save into the weapon's tuning file; a Weapons skill tier switch; a button resetting every downed dummy. M13's tests measure the targets above there.
- **A settings menu nested in the Esc menu** (the game stays paused; Back or Esc returns to the Esc menu), stored in the player's profile (`user://`), not in save games: mouse sensitivity, invert Y; field of view (70–100°, default 80); camera motion (0–100 %, scaling shake, bob and the camera's recoil climb, never the bullets' pattern); master, effects and music volume; fullscreen or windowed, vsync. No key rebinding.
- No mockup: the settings menu follows the Esc menu's style; the range's panel and sliders are a plain debug tool.

**M13b, feedback** (after the M13a playtest)

- Hit markers on the crosshair, subtle, with distinct ones for a headshot and a kill; no damage numbers.
- Impacts: holes and puffs per material group (metal sparks, concrete dust, wood splinters, glass), capped in number and fading; a small dark-red puff on body hits (no decals on bodies, no pools); a blue-white spark for baton stun hits.
- Tracers on the assault rifle, the submachine gun and guards' shots, every few rounds.
- Getting hit (the player is not special): a hit kicks the view slightly and adds spread for about 0.3 s; a guard hit flinches, delaying its next shot by about 0.3 s, and a limb hit staggers it.
- Guards obey the weapon's spread and recoil, compensating about 70 %, and keep firing short bursts; their accuracy is retuned so the ADR 0070 survival targets hold (the player survives at least 3 s under fire at 10 m, about 2 s at 4 m).
- Weapon motion driven by code (no arms or hands): kick, sway, bob, reload and draw; a slight camera shake on firing, scaled by the camera motion setting.
- Sounds per weapon built from the sound packs already in the project (layers, pitch, a bass layer), with an echo tail by indoor or outdoor area; if the packs are too thin, the chief engineer asks the user before adding any.
- No mockup required: feedback is game feel, judged in the game (the user, 2026-11-12). A reference sketch exists in [hit_feedback.html](../prototypes/hit_feedback.html).

## Alternatives considered

- **Accuracy decided by the player alone (Counter-Strike) or by the character alone (Deus Ex)**: the first empties the Weapons skills, the second is the feel the roadmap wants to leave.
- **A camera that stays still while bullets climb, or the Counter-Strike 2 half split**: the user chose the full camera climb.
- **Patterns on every weapon**: only automatic fire makes a pattern learnable.
- **Aiming down the sights**: a new aiming animation per weapon, not in the reference.
- **No new weapon in M13**: the user asked for the submachine gun now, so patterns differ between two automatic weapons.
- **Arms and hands in the first-person view**: no models in the Kenney packs; real art comes later.
- **One milestone**: the user needs to feel the recoil before the feedback layers go on top of it.
- **Blood decals on walls and floors**: changes the game's tone for little gain.

## Consequences

- [weapons-and-aiming.md](../game/weapons-and-aiming.md) gains the M13 design section; the roadmap splits M13a and M13b.
- The weapon outcome tests (`tests/items/weapons/weapon_outcomes_test.gd`) and the guard accuracy table of ADR 0070 are re-measured; Weapons skill tiers change meaning (they now also scale recoil).
- The Esc menu gains a Settings entry; settings live in `user://`, not in save games.
