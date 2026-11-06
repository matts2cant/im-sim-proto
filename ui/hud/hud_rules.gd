class_name HudRules
extends RefCounted
## Pure HUD helpers: body-part colours and text formats.

const HEALTHY := Color(0.25, 0.85, 0.35)
const HURT := Color(0.95, 0.85, 0.2)
const CRITICAL := Color(0.9, 0.15, 0.1)
const DISABLED := Color(0.04, 0.04, 0.04)

## Share of the yellow-to-green ramp a slightly hurt part may keep: pure green is for full health
## only, so a graze (90 % health) already reads yellow-green instead of looking untouched.
const HURT_GREEN_SHARE: float = 0.6


## Green at full health only, yellow at half, red near 0, black when the part is disabled (0).
static func part_color(ratio: float) -> Color:
	if ratio <= 0.0:
		return DISABLED
	if ratio >= 1.0:
		return HEALTHY
	if ratio >= 0.5:
		return HURT.lerp(HEALTHY, (ratio - 0.5) * 2.0 * HURT_GREEN_SHARE)
	return CRITICAL.lerp(HURT, ratio * 2.0)


## Energy readout above the bar: whole points, rounded up so it reads 0 only when empty.
static func energy_text(current: float) -> String:
	return "%d" % ceili(maxf(current, 0.0) - 0.0001)


## Active augmentation chip: "F1 Cloak", or the name alone for a passive one.
static func chip_text(data: AugmentationData) -> String:
	var key := data.key_label()
	return data.display_name if key.is_empty() else "%s %s" % [key, data.display_name]


## "10 / 30" for weapons with ammo, "" otherwise; "reloading" while reloading.
static func ammo_text(state: WeaponState) -> String:
	if state == null or not state.data.uses_ammo():
		return ""
	if state.is_reloading():
		return "reloading  / %d" % state.reserve
	return "%d / %d" % [state.magazine, state.reserve]
