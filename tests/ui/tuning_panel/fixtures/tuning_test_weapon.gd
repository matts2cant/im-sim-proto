extends WeaponData
## Test fixture: a weapon with tuning values the panel knows nothing about: two range values, a plain
## one (no range: not listed) and a referenced part with its own range value.

const Part := preload("res://tests/ui/tuning_panel/fixtures/tuning_test_part.gd")

@export_range(0.0, 5.0, 0.1) var kick: float = 1.0
@export_range(1, 10) var burst: int = 3
@export var plain: float = 2.0
@export var part: Part
