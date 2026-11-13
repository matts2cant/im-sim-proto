class_name ThrowConfig
extends Resource
## Tuning of a Thrower (ADR 0131): how far a surface may be to stick a thrown weapon on it, the
## fixed arc of a throw and its distance (the user's `throw_distance` attribute; base here).

## A surface (not a character) this close to the eye along the view, metres: the weapon is stuck there
## (a ghost shows where); further: it is thrown.
@export var stick_reach: float = 1.2
## Throw distance (m) on flat ground from eye height, looking level, before the user's
## `throw_distance` modifiers (the Demolition skill: +2 / +4 / +6).
@export var base_distance: float = 12.0
## The throw leaves this many degrees above the view direction (a fixed arc: looking up throws
## higher and shorter, looking level throws `base_distance`).
@export var lift_deg: float = 20.0
## The entity starts this far ahead of the eye along the view (m).
@export var spawn_forward: float = 0.35
## Seconds the thrown entity ignores its thrower's body (it starts inside the reach of its arm).
@export var ignore_thrower_time: float = 0.3
## Opacity of the ghost (0 hidden, 1 solid).
@export_range(0.0, 1.0) var ghost_alpha: float = 0.6
