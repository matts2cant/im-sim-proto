class_name CombatConfig
extends Resource
## Tuning of CombatBehaviour and CombatModel (ADR 0070): reaction, rate of fire, preferred range,
## melee approach and the accuracy of an AI shooter. The guard's: `actors/guard/guard_combat.tres`.
## Times in seconds, distances in metres (horizontal, centre to centre between the feet), angles in
## degrees. The weapon itself (damage, magazine, reload, reach, swing time) is its WeaponData.

@export_group("Timing")
## Seconds of sight of the target before the first shot or swing of an engagement.
@export var reaction_time: float = 0.5
## A random pause in this range between two shots (on top of the weapon's own cycle).
@export var shot_interval_min: float = 0.6
@export var shot_interval_max: float = 0.9
## Out of sight for this long ends the engagement (the walker goes back to the awareness behaviour,
## which runs to the last known position); a shorter loss keeps the reaction already spent.
@export var lose_grace: float = 0.5

@export_group("Ranged")
## Preferred distance band to the target: closer than min, it backs away; farther than max, it
## advances. Either way it walks back into the band by `distance_margin` before stopping again.
@export var min_distance: float = 6.0
@export var max_distance: float = 12.0
@export var distance_margin: float = 1.0
## Fires only while its own horizontal speed is below this (it stops to shoot).
@export var fire_max_speed: float = 0.3
## Above this horizontal speed (m/s) it aims with the walking stance's spread, below with the still one.
@export var still_speed: float = 0.5
## Fires (and swings) only while its facing is within this angle of the target.
@export var fire_max_angle: float = 15.0
## With no clear line of fire for this long, it steps `sidestep_distance` sideways (alternating).
@export var sidestep_time: float = 1.0
@export var sidestep_distance: float = 1.5
## Automatic weapons (WeaponData.automatic) fire bursts: the trigger stays held for a random number
## of shots in this range (at the weapon's cycle), then the usual shot interval follows (ADR 0087).
@export var burst_shots_min: int = 3
@export var burst_shots_max: int = 4

@export_group("Melee")
## Runs in until this close (plus its braking distance).
@export var melee_stop_distance: float = 1.2
## Swings while within the weapon's reach (WeaponData.max_range, from the eye) minus this.
@export var melee_swing_margin: float = 0.3

@export_group("Accuracy")
## The shooter's own error on top of its weapon's cone (WeaponData.aim_config, ADR 0127), degrees:
## this much at `spread_near_distance` and closer, at a target that is not settled.
@export var spread_base_deg: float = 0.0
@export var spread_near_distance: float = 4.0
## Added per metre beyond `spread_near_distance`.
@export var spread_per_metre: float = 0.05
## A target faster than this (m/s) adds `fast_target_add_deg`.
@export var fast_target_speed: float = 3.0
@export var fast_target_add_deg: float = 2.0
## A target slower than this counts as still: the aim settles on it.
@export var still_target_speed: float = 0.5
## Seconds of sight of a still target to settle fully; settled, the cone is x `settled_factor`.
@export var settle_time: float = 2.0
@export var settled_factor: float = 0.75
## Time constant (s) of the smoothing of the target's measured speed.
@export var target_speed_smoothing: float = 0.15
## Share (0-1) of its weapon's recoil climb (and of a hit's aim punch) the shooter pulls back by
## re-aiming at the target (RecoilState.view_share, ADR 0127): 0 leaves its shots the whole
## pattern, 1 none of it.
@export_range(0.0, 1.0, 0.05) var recoil_compensation: float = 0.7
