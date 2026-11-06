class_name PushConfig
extends Resource
## Tuning of BodyPusher: how a character moves the physics props it walks into and stands on
## (ADR 0054). The player's: `actors/player/player_push.tres`; the guard's: `actors/guard/guard_push.tres`.

## Mass (kg) whose weight (x engine gravity) presses on the rigid bodies the character stands on
## (props do not collide with kinematic characters in the solver).
@export var body_mass: float = 80.0
## The weight on one body is at most this many times that body's own weight (a small crate gets
## 4 x 98 = 392 N, a 0.5 kg bottle 20 N): large mass ratios destabilise the solver.
@export var weight_max_ratio: float = 4.0
## Most force (N) the character pushes rigid bodies with by walking into them, shared between them.
## A prop on the floor needs more than 0.5 x mass x 9.8 N to slide (prop friction 0.5): 250 N
## moves a small (10 kg, 49 N) or metal (25 kg, 123 N) crate, not a large one (60 kg, 294 N).
@export var push_force: float = 250.0
## Pushed bodies are not sped up past this (m/s): pushing slows the character down, and a pushed
## crate stays under ImpactSettings.min_speed (2.5), so shoving one into a wall makes no impact.
@export var push_max_speed: float = 2.0
## A rigid body counts as walked into within this distance (m) ahead of the capsule, and as stood
## on within this distance below the feet.
@export var push_probe: float = 0.05
