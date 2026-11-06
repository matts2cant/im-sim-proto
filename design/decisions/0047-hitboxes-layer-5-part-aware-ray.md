# 47. Hitboxes on layer 5 and part-aware RAY delivery

Status: Accepted

Date: 2026-11-06

## Context

M4 body-part damage ([ADR 0018](0018-damage-body-parts.md)) needs to know which part a shot or a baton hit landed on. Until now a RAY stimulus hit the first collider on any layer and receivers only got the entity, the perceived intensity and the distance. Characters' movement capsules (player layer 2, actors layer 3, [ADR 0045](0045-collision-layers.md)) are far coarser than a head; a shot would always hit the capsule first. The shooter's own body must not be hit either (the camera sits inside its head).

## Decision

- **Hitboxes**: characters carry `actors/common/body/hitboxes.tscn`, six `AnimatableBody3D` shapes on collision layer 5 (hitboxes) with collision mask 0 and metadata `body_part` (`head`, `torso`, `arm_l`, `arm_r`, `leg_l`, `leg_r`). Nothing masks layer 5, so they never push or block anything; they only answer queries. They move with the character (the player's are lowered when crouching; a knocked-out dummy's tip over with it).
- **Weapon queries** (pistol rays, baton sweeps) use `PhysicsLayers.WEAPON_MASK` = world | objects | hitboxes: never the character bodies (2/3), and exclude the shooter's body and its own hitboxes.
- **Stimulus RAY** gains `collision_mask` (default all layers, so existing rays are unchanged) and `exclude: Array[RID]` (on top of the source body).
- **Delivery data reaches effects**: `StimulusReceiver.receive()` passes its `data` on to `EffectContext.data`. RAY delivery adds `collider` (the node hit), `position` and `normal`; CONTACT adds `collider` (the target node, e.g. a hitbox the baton touched). Delivery still walks up to the nearest ancestor with receivers, so a hitbox delivers to its entity. The EventLog records nodes in this data by name.
- `BodyDamageEffect` reads the part from the collider's metadata; no part means the damage is shared out by type ([damage.md](../game/damage.md)).

## Alternatives considered

- **One receiver per hitbox**: six receivers per character, six registrations, and RADIUS stimuli (explosions, fire) would be delivered six times.
- **Hit position mapped to a part by height**: no shapes needed, but arms and torso overlap in height, crouching and lying poses break it, and tests could not aim at a part.
- **Hitboxes as Area3D**: rays and shape casts would need `collide_with_areas`, and the default RAY query would also start hitting triggers (layer 6).
- **Hitboxes on the character layers**: the movement capsule and the hitboxes would block each other and the player would collide with its own head.

## Consequences

- Any new RAY or CONTACT effect can be part-aware through `ctx.collider()`.
- New characters (M7 guards) instance the same hitbox scene and add the `body_damage` receptron.
- Hitbox shapes are sized for a standing 1.8 m humanoid; poses other than standing, crouched and lying need their own layout.
