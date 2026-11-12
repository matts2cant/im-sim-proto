class_name ImpactPuff
extends Resource
## One impact look (ADR 0126): the short burst of particles a hit throws off a surface of one
## material group (metal sparks, concrete dust, wood splinters, glass shards, a body's dark-red
## puff, a stun hit's blue-white spark) and the hole it leaves, if any. Tuning in
## `items/weapons/fx/shot_fx.tres` (ShotFxConfig.puffs); visual only.

@export_group("Puff")
@export var color: Color = Color(0.66, 0.64, 0.6)
## Particles per hit.
@export_range(1, 64) var amount: int = 12
## Seconds a particle lives.
@export_range(0.05, 3.0, 0.01) var lifetime: float = 0.6
## Launch speed range (m/s), along the surface normal within `spread_deg`.
@export_range(0.0, 20.0, 0.1) var speed_min: float = 0.8
@export_range(0.0, 20.0, 0.1) var speed_max: float = 2.5
## Half-angle (degrees) of the cone particles leave in around the normal.
@export_range(0.0, 180.0, 1.0) var spread_deg: float = 40.0
## Downward pull (m/s²): sparks and splinters fall, dust drifts.
@export_range(0.0, 20.0, 0.1) var gravity: float = 2.0
## Edge of a particle (m).
@export_range(0.002, 0.2, 0.001) var particle_size: float = 0.025
## Particles shrink to nothing over their life (sparks); off: they keep their size and fade.
@export var shrink: bool = false
## Unshaded and bright (sparks); off: lit like the surface (dust, splinters).
@export var glow: bool = false

@export_group("Hole")
## A hit leaves a hole on a static surface (never on bodies).
@export var hole: bool = true
@export var hole_color: Color = Color(0.06, 0.06, 0.06, 0.95)
## Edge of the hole mark (m).
@export_range(0.01, 0.5, 0.005) var hole_size: float = 0.05
## The hole is a crack star (glass) instead of a round hole.
@export var cracks: bool = false
