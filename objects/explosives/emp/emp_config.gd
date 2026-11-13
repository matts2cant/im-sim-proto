class_name EmpConfig
extends Resource
## Tuning of an EmpPulse (ADR 0131): `emp.tres`.

## Everything electronic within this many metres of the blast (straight line, walls do not matter).
@export var radius: float = 6.0
## Seconds it stays off (the `emp` stimulus's intensity).
@export var seconds: float = 20.0
