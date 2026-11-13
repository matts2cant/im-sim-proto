class_name FallImpactConfig
extends Resource
## Tuning of FallImpact (ADR 0056, ADR 0138): `actors/common/movement/fall_impact.tres`.

## Landings slower than this (m/s) are not reported (stepping off a kerb, every small hop).
@export var min_speed: float = 3.0
