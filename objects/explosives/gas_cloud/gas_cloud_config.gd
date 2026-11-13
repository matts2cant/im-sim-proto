class_name GasCloudConfig
extends Resource
## Tuning of a GasCloud (ADR 0131): `gas_cloud.tres`. The dose: `stun_per_pulse` every
## `pulse_interval` s against a knockout threshold of 60 (player and guards) knocks out after
## ceil(60 / stun_per_pulse) pulses.

## Radius of the cloud (m): the dose reaches receivers this far from its centre.
@export var radius: float = 2.5
## Seconds it lasts.
@export var duration: float = 12.0
## `damage.stun.gas` dealt each pulse to everyone inside (uniform, line of sight to the centre).
@export var stun_per_pulse: float = 10.0
## Seconds between pulses; the first comes one interval after the release (the first breath).
@export var pulse_interval: float = 0.5
## Its centre rises this far above where it was released (less under a low ceiling).
@export var lift: float = 1.0
## Drift speed (m/s), horizontal, in a random direction; it stops short of walls.
@export var drift_speed: float = 0.1
## It stops drifting when a wall is this close ahead of its centre (m).
@export var wall_margin: float = 1.0
## Seconds it takes to swell to full size, and to fade out at the end.
@export var swell_time: float = 0.8
@export var fade_time: float = 2.0
## The look: colour and opacity of each puff where it faces the view (its edges fade).
@export var color: Color = Color(0.62, 0.78, 0.36, 0.26)
