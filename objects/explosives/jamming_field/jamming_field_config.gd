class_name JammingFieldConfig
extends Resource
## Tuning of a JammingField (ADR 0131, ADR 0112): `jamming_field.tres`.

## Wireless links with an end within this many metres of its centre (straight line, walls do not
## matter) drop.
@export var radius: float = 10.0
## Seconds it lasts.
@export var duration: float = 20.0
## The beacon's blink period (s).
@export var blink_period: float = 0.8
