class_name AlarmHearingConfig
extends Resource
## Tuning of AlarmHearing (ADR 0077, ADR 0138): `actors/common/awareness/alarm_hearing.tres`.

## Seconds it keeps hearing after the last siren pulse (longer than the siren's 1 s interval).
@export var hold: float = 1.5
