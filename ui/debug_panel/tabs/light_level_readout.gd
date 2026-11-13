class_name LightLevelReadout
extends Label
## Debug panel Overlays tab: the player's numeric light level (LightExposure, ADR 0065) and how many
## lights reach it. Finds the player through the panel (DebugPanel.player()).


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	text = readout(DebugPanel.player())


## The text shown for `player` (any node; a LightExposure child is read).
static func readout(player: Node) -> String:
	var exposure := LightExposure.of(player)
	if exposure == null:
		return "Light: no player"
	return "Light: %.2f (%d lights in reach)" % [exposure.level, exposure.lights_in_reach]
