class_name TracerConfig
extends Resource
## Tuning of a Tracer (ADR 0113, hacking.md "Tuning"): `objects/network/tracer.tres`, the sensitive
## variant `tracer_sensitive.tres`. Trace is a percentage (0-100); every gain is multiplied by the
## user's `deck_trace_gain_mult` (the Computer skill).

## % per second while a tool runs against a watched device (the Icebreaker).
@export var gain_per_second: float = 4.0
## % added by a failed login (a wrong guess) on a watched device.
@export var failed_login: float = 15.0
## % added by a map scan of a watched subnet.
@export var scan: float = 10.0
## % per second drained while nothing adds to it ...
@export var drain_per_second: float = 10.0
## ... starting this long after the last gain (s).
@export var drain_delay: float = 2.0
## How long a full trace blocks the user's address (s).
@export var lockout: float = 30.0
