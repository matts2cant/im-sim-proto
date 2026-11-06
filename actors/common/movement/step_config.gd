class_name StepConfig
extends Resource
## Tuning for StepClimber (ADR 0058). The values live in a .tres (the player's:
## actors/player/player_step.tres); the script only declares them. Distances in metres.

## Highest obstacle the character walks up onto without jumping, measured from the feet (bottom of
## the collision shape) to the obstacle's top surface; also the deepest drop it walks down without
## leaving the floor (stairs, kerbs).
@export var step_height: float
## A step up moves the body at least this far along its motion (more when it moves faster), so a
## rounded capsule bottom lands on the step's edge within the max floor angle: about
## radius x (1 - sin 45 deg) = 0.10 m for a 0.35 m capsule, plus margin.
@export var step_reach: float
## Seconds a view (the player's camera) takes to ease over a step's height change; 0 = no easing.
@export var smooth_time: float
