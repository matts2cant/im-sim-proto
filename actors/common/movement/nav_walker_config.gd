class_name NavWalkerConfig
extends Resource
## Tuning of NavWalker, the generic non-player movement controller. The guard's:
## `actors/guard/guard_walker.tres`. Speeds in m/s.

## Patrol and routine moves.
@export var walk_speed: float = 1.8
## Walking to something suspicious.
@export var investigate_speed: float = 2.5
## Running (alerted, a loud noise, the first search point).
@export var run_speed: float = 5.0
## A requested speed of at least this sets `stance.sprint` (MovementNoise: the louder footsteps).
@export var sprint_tag_speed: float = 4.0
## How fast the horizontal velocity reaches the requested one (m/s^2).
@export var acceleration: float = 14.0
## Turn rate towards the walking direction or the requested facing (degrees per second).
@export var turn_rate: float = 240.0
## Multiplier on the engine gravity.
@export var gravity_scale: float = 1.0
## A move counts as arrived within this horizontal distance (m) of its target (or of the closest
## point the navmesh reaches).
@export var arrive_distance: float = 0.4
## ...and within this height (m) of it: a target a storey above or below (a noise on a cabinet over
## the room it stands in) is reached by walking the navmesh path, not by standing under it.
@export var arrive_height: float = 1.0
## Moving slower than `stuck_speed_ratio` x the requested speed for this long (s) also counts as
## arrived: the way is blocked (a prop, another character).
@export var stuck_time: float = 1.5
@export var stuck_speed_ratio: float = 0.2
## After arriving short of the target, asking for the same target again re-plans after this long (s).
@export var retry_time: float = 0.5
