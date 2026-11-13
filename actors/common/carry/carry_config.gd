class_name CarryConfig
extends Resource
## Tuning of a Carrier (ADR 0053, ADR 0139; the default, the player's: `carry.tres`). The
## mass limit is the carrier's `carry_mass_limit` attribute. Distances in metres, speeds in m/s.

## Reach of the pick-up look ray from the eyes.
@export var carry_reach: float = 2.0
## Hold point (ADR 0053): the centre sits (base + largest half-extent) along the view from the eyes
## and (drop + half-extent) lower on the screen. A release aims at least the carrier's body radius +
## half-extent + clearance out from its axis.
@export var hold_base_distance: float = 0.45
@export var hold_drop: float = 0.1
@export var hold_clearance: float = 0.1
## Seconds the object takes to move to the hold point and turn upright after pick-up.
@export var hold_turn_time: float = 0.15
## See-through amount of the held object's meshes (0 opaque, 1 invisible).
@export var held_transparency: float = 0.5
## Release: the shape is cast from the chest (this far below the eyes, on the carrier's axis) to the
## hold point and placed this many metres short of the first contact.
@export var release_start_drop: float = 0.35
@export var release_margin: float = 0.01
## Throw: impulse along the view (N s); speed = min(max speed, impulse / mass).
@export var throw_impulse: float = 40.0
@export var throw_max_speed: float = 12.0
## Carrying at least this mass (kg) multiplies the move speed by `heavy_carry_speed_factor`.
@export var heavy_carry_mass: float = 10.0
@export var heavy_carry_speed_factor: float = 0.8
