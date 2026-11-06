class_name AwarenessConfig
extends Resource
## Tuning of graded awareness (AwarenessModel, ADR 0068) and of the behaviour it drives
## (AwarenessBehaviour). The guard's: `actors/guard/guard_awareness.tres`. Times in seconds,
## distances in metres.

@export_group("Suspicion meter")
## Meter (0..1) at which an Unaware character becomes Suspicious.
@export var suspicious_threshold: float = 0.3
## The same while wary.
@export var wary_suspicious_threshold: float = 0.2
## Meter at which it becomes Alerted.
@export var alert_threshold: float = 1.0
## Meter lost per second while nothing hostile is seen (not while Alerted).
@export var decay: float = 0.25

@export_group("Suspicious")
## Stop and turn to the point for this long before walking to it.
@export var look_time: float = 2.0
## Look around at the point for this long, then give up.
@export var look_around_time: float = 4.0
## A noise heard at least this loud (perceived) skips the look and runs to the point.
@export var loud_noise: float = 10.0
## New evidence farther than this from the current point sends the character there again.
@export var repoint_distance: float = 1.0

@export_group("Alerted")
## Target unseen for this long: Searching.
@export var lose_time: float = 4.0
## Within this horizontal distance (centre to centre) of a seen target it stops and faces it.
@export var face_distance: float = 1.5

@export_group("Searching")
## Navmesh points visited around the last known position.
@export var search_points: int = 4
@export var search_radius: float = 8.0
## The whole search gives up after this long.
@export var search_duration: float = 30.0
## Look around at each point for this long.
@export var search_look_time: float = 3.0

@export_group("Bodies")
## A downed ally (ADR 0071) is found once this much discovery has built up (the vision gain per
## second while it is seen, as the suspicion meter).
@export var body_discovery_threshold: float = 1.0
## Discovery lost per second while the body is not seen.
@export var body_discovery_decay: float = 0.5
## Finding a body keeps the character wary at least this long.
@export var body_wary_duration: float = 180.0
## Waking an unconscious ally: stand within this horizontal distance of its body (gap from the
## character's centre to the body's bounds)...
@export var wake_distance: float = 1.2
## ...for this long.
@export var wake_time: float = 3.0
## Where it heads to wake it: this far out from the body's bounds, on its own side.
@export var tend_offset: float = 0.5
## Gives up standing by a body after this long (it could not get close enough).
@export var tend_timeout: float = 8.0

@export_group("Wary")
## After any return to Unaware the character stays wary this long (faster suspicion).
@export var wary_duration: float = 60.0

@export_group("Unaware")
## Without a patrol route: glance this many degrees left or right of the post's facing...
@export var glance_angle: float = 45.0
## ...every this many seconds...
@export var glance_interval: float = 6.0
## ...holding each glance this long.
@export var glance_hold: float = 1.5
## Looking around (Suspicious, Searching) sweeps this many degrees either side.
@export var look_around_angle: float = 60.0
## Wait at a patrol point without its own `wait` metadata.
@export var patrol_wait: float = 1.0
