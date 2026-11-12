class_name AimConfig
extends Resource
## Tuning for the AimModel (softened Deus Ex 1 reticle, ADR 0048; skill and aim blend, ADR 0123).
## Angles in degrees. One per weapon (`<weapon>_aim.tres`; `aim_untrained.tres` for weapons without
## their own); skills change them through the shooter's attributes (ADR 0061). Every value is an
## @export_range so the shooting range's sliders can list them generically.

## Spread floor standing still, x the shooter's `<class>_still_mult` (Master: 0, the first still
## shot is exact).
@export_range(0.0, 10.0, 0.05) var base_min_deg: float = 1.5
## Floor additions while moving, x the shooter's `<class>_spread_mult`.
@export_range(0.0, 10.0, 0.05) var walk_add_deg: float = 3.0
@export_range(0.0, 10.0, 0.05) var sprint_add_deg: float = 6.0
@export_range(0.0, 10.0, 0.05) var air_add_deg: float = 6.0
## Crouched and still: the still floor times this.
@export_range(0.0, 1.0, 0.05) var crouch_still_factor: float = 0.8
## Time constant (s) of the exponential settle toward the floor. The shooter's `<class>_settle_time`
## attribute changes it (Pistols: Untrained 0.8 ... Master 0.2 s; ADR 0061; Sniper x1.0 ... x0.4,
## ADR 0101).
@export_range(0.01, 3.0, 0.01) var settle_time: float = 0.8
## While the shooter is crouched (still or moving: the `stance.crouch` tag) the settle time is
## multiplied by this (0.8 s -> 0.48 s; Master 0.2 s -> 0.12 s).
@export_range(0.0, 1.0, 0.05) var crouch_settle_factor: float = 0.6
## Mouse look bloom per screen pixel moved, capped per physics frame.
@export_range(0.0, 0.1, 0.001) var look_bloom_per_px: float = 0.02
@export_range(0.0, 5.0, 0.05) var look_bloom_max_per_frame: float = 2.0
## Bloom per shot, x the shooter's `<class>_spread_mult`.
@export_range(0.0, 5.0, 0.05) var shot_bloom_deg: float = 2.5
## Shots bloom the cone up to this (degrees; an automatic weapon's sustained-fire cap); stance floors
## may still be wider. 0: up to `max_spread_deg`.
@export_range(0.0, 10.0, 0.05) var shot_bloom_cap_deg: float = 0.0
@export_range(0.0, 20.0, 0.1) var max_spread_deg: float = 10.0
## Aim sway: amplitude (degrees) of a slow figure-of-eight drift of the aim point, x `aim_sway_mult`
## (injuries) x `<class>_sway_mult` (Sniper skill, ADR 0101).
@export_range(0.0, 2.0, 0.01) var sway_deg: float = 0.15
## Sway cycles per second.
@export_range(0.0, 2.0, 0.01) var sway_frequency: float = 0.35
