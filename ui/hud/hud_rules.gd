class_name HudRules
extends RefCounted
## Pure HUD helpers: body-part colours and text formats.

const HEALTHY := Color(0.25, 0.85, 0.35)
const HURT := Color(0.95, 0.85, 0.2)
const CRITICAL := Color(0.9, 0.15, 0.1)
const DISABLED := Color(0.04, 0.04, 0.04)


## Green at full health, yellow at half, red near 0, black when the part is disabled (0).
static func part_color(ratio: float) -> Color:
	if ratio <= 0.0:
		return DISABLED
	if ratio >= 0.5:
		return HURT.lerp(HEALTHY, (minf(ratio, 1.0) - 0.5) * 2.0)
	return CRITICAL.lerp(HURT, ratio * 2.0)


## "10 / 30" for weapons with ammo, "" otherwise; "reloading" while reloading.
static func ammo_text(state: WeaponState) -> String:
	if state == null or not state.data.uses_ammo():
		return ""
	if state.is_reloading():
		return "reloading  / %d" % state.reserve
	return "%d / %d" % [state.magazine, state.reserve]
