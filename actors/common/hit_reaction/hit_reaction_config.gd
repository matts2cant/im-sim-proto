class_name HitReactionConfig
extends Resource
## Tuning of a HitReaction (ADR 0127): how a character reacts to a hit it takes. Angles in degrees,
## times in seconds. The player's: `actors/player/player_hit_reaction.tres`; the guards':
## `actors/guard/guard_hit_reaction.tres`. A zero time turns that part of the reaction off.

const HITS: Array[StringName] = [&"damage.ballistic", &"damage.blunt", &"damage.stun", &"damage.explosive"]

## Damage types that cause a reaction (hierarchical: `damage.ballistic` matches its subtypes); a
## burn or a fall does not.
@export var damage_types: Array[StringName] = HITS
## Perceived damage below this causes no reaction.
@export var min_damage: float = 1.0

@export_group("Aim punch")
## The aim kicks up by this, and sideways by up to `punch_side_deg` away from the side the hit came
## from; the eye's owner turns the eye by its share (the player's camera: the camera motion setting).
@export_range(0.0, 10.0, 0.05) var punch_up_deg: float = 1.0
@export_range(0.0, 10.0, 0.05) var punch_side_deg: float = 0.5
## Time constant of the punch's return (95 % back after three of them).
@export_range(0.01, 1.0, 0.01) var punch_recover_time: float = 0.1

@export_group("Spread")
## The aim cone's floor grows by this (`aim_spread_add`) for `spread_time` after a hit, then settles
## back at the weapon's settle time.
@export_range(0.0, 10.0, 0.05) var spread_add_deg: float = 1.5
@export_range(0.0, 2.0, 0.01) var spread_time: float = 0.3

@export_group("Flinch")
## A flinch holds an AI shooter's fire (CombatBehaviour): its next shot comes this much later; a
## new hit restarts it.
@export_range(0.0, 2.0, 0.01) var flinch_time: float = 0.0

@export_group("Stagger")
## A hit on one of these hitbox parts staggers the character: `move_speed_mult` x
## `stagger_speed_mult` for `stagger_time`, and its model leans away from the shot by up to
## `stagger_lean_deg` (CharacterAnimator), easing in over `lean_in_time`.
@export var stagger_parts: Array[StringName] = [&"arm_l", &"arm_r", &"leg_l", &"leg_r"]
@export_range(0.0, 2.0, 0.01) var stagger_time: float = 0.0
@export_range(0.0, 1.0, 0.05) var stagger_speed_mult: float = 0.4
@export_range(0.0, 45.0, 0.5) var stagger_lean_deg: float = 12.0
@export_range(0.01, 0.5, 0.01) var lean_in_time: float = 0.08
