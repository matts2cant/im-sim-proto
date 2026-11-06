class_name AimConfig
extends Resource
## Tuning for the AimModel (softened Deus Ex 1 reticle, ADR 0048). Angles in degrees.
## Values live in `aim_untrained.tres`; M6 skill tiers swap or modify them.

## Spread floor standing still.
@export var base_min_deg: float = 1.5
## Floor additions while moving.
@export var walk_add_deg: float = 3.0
@export var sprint_add_deg: float = 6.0
@export var air_add_deg: float = 6.0
## Crouched and still: the base floor times this.
@export var crouch_still_factor: float = 0.8
## Time constant (s) of the exponential settle toward the floor (Untrained 0.8, Master 0.2).
@export var settle_time: float = 0.8
## Mouse look bloom per screen pixel moved, capped per physics frame.
@export var look_bloom_per_px: float = 0.02
@export var look_bloom_max_per_frame: float = 2.0
## Bloom per shot.
@export var shot_bloom_deg: float = 2.5
@export var max_spread_deg: float = 10.0
## Aim sway: amplitude (degrees) of a slow figure-of-eight drift of the aim point, x `aim_sway_mult`.
@export var sway_deg: float = 0.15
## Sway cycles per second.
@export var sway_frequency: float = 0.35
