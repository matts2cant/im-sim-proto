class_name AlarmControllerConfig
extends Resource
## Tuning of an AlarmController (ADR 0077). Default: `objects/alarm/alarm_controller.tres`.

## Seconds it rings after an incident (or a trigger); another one restarts the time (ADR 0072; 45 s
## since ADR 0100).
@export var duration: float = 45.0
## While ringing it sends `command.ring` again this often to every siren it reaches, so a siren
## cut off from it falls silent (Siren `ring_hold`) and one reconnected rings again.
@export var ring_refresh: float = 1.0
