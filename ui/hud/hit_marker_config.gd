class_name HitMarkerConfig
extends Resource
## Tuning of the crosshair's hit markers (ADR 0126, `ui/hud/hit_marker.tres`): how long each kind
## shows, its colour, the ticks' size and the placeholder tick sounds.

@export_group("Times (s)")
@export_range(0.02, 2.0, 0.01) var body_time: float = 0.15
@export_range(0.02, 2.0, 0.01) var head_time: float = 0.22
@export_range(0.02, 2.0, 0.01) var stun_time: float = 0.15
@export_range(0.02, 2.0, 0.01) var kill_time: float = 0.35
@export_range(0.02, 2.0, 0.01) var knockout_time: float = 0.35

@export_group("Colours")
@export var body_color: Color = Color(0.95, 0.96, 0.96, 0.95)
@export var head_color: Color = Color(1.0, 0.82, 0.3, 1.0)
@export var stun_color: Color = Color(0.62, 0.85, 1.0, 1.0)
@export var kill_color: Color = Color(0.9, 0.33, 0.29, 1.0)
## A knockout: the kill's X in the stun colour.
@export var knockout_color: Color = Color(0.62, 0.85, 1.0, 1.0)

@export_group("Shape (px at 1080 px tall)")
## Diagonal ticks from `tick_inner` to `tick_outer` from the aim point.
@export_range(1.0, 60.0, 0.5) var tick_inner: float = 9.0
@export_range(1.0, 80.0, 0.5) var tick_outer: float = 16.0
@export_range(0.5, 8.0, 0.5) var tick_width: float = 2.0
## The kill's X.
@export_range(1.0, 60.0, 0.5) var cross_inner: float = 6.0
@export_range(1.0, 80.0, 0.5) var cross_outer: float = 18.0
@export_range(0.5, 8.0, 0.5) var cross_width: float = 3.0

@export_group("Sound")
## A soft placeholder tick (PlaceholderBeep) per marker; the kill's is lower, longer and louder.
@export_range(100.0, 8000.0, 10.0) var tick_hz: float = 2400.0
@export_range(0.01, 0.3, 0.005) var tick_length: float = 0.03
@export_range(-40.0, 6.0, 0.5) var tick_db: float = -16.0
@export_range(100.0, 8000.0, 10.0) var kill_hz: float = 1500.0
@export_range(0.01, 0.3, 0.005) var kill_length: float = 0.07
@export_range(-40.0, 6.0, 0.5) var kill_db: float = -9.0
## Markers within this many seconds of the last sound stay silent (eight shotgun pellets: one tick).
@export_range(0.0, 0.5, 0.01) var sound_gap: float = 0.05


func time_of(kind: HitMarkerRules.Kind) -> float:
	match kind:
		HitMarkerRules.Kind.BODY:
			return body_time
		HitMarkerRules.Kind.HEAD:
			return head_time
		HitMarkerRules.Kind.STUN:
			return stun_time
		HitMarkerRules.Kind.KNOCKOUT:
			return knockout_time
		HitMarkerRules.Kind.KILL:
			return kill_time
	return 0.0


func color_of(kind: HitMarkerRules.Kind) -> Color:
	match kind:
		HitMarkerRules.Kind.HEAD:
			return head_color
		HitMarkerRules.Kind.STUN:
			return stun_color
		HitMarkerRules.Kind.KNOCKOUT:
			return knockout_color
		HitMarkerRules.Kind.KILL:
			return kill_color
	return body_color


## The kill and the knockout draw an X; the others four short ticks.
static func is_cross(kind: HitMarkerRules.Kind) -> bool:
	return kind == HitMarkerRules.Kind.KILL or kind == HitMarkerRules.Kind.KNOCKOUT
