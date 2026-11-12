class_name AlarmControllerConfig
extends Resource
## Tuning of an AlarmController (ADR 0077). Default: `objects/alarm/alarm_controller.tres`.

## Seconds it rings after an incident (or a trigger); another one restarts the time (ADR 0072; 45 s
## since ADR 0100).
@export var duration: float = 45.0
## While ringing it sends `command.ring` again this often to every siren it reaches, so a siren
## cut off from it falls silent (Siren `ring_hold`) and one reconnected rings again.
@export var ring_refresh: float = 1.0

@export_group("Loss of signal (M12c)")
## This many supervised devices dropping within `fault_window` seconds raise one network fault
## (ADR 0115); 0: no supervision (no trouble notes, no fault).
@export var fault_drops: int = 3
@export var fault_window: float = 10.0
## Seconds between two checks of who still reaches it.
@export var supervision_interval: float = 0.5
## Trouble notes kept for the security console (newest last).
@export var trouble_notes: int = 8
