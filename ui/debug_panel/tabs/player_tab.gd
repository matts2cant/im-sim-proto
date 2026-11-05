extends VBoxContainer
## Debug panel tab: live player movement readouts. Registered by the Player it shows.

var player: Player

@onready var _readout: Label = $Readout


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	if not is_instance_valid(player):
		_readout.text = "No player"
		return
	var lines: PackedStringArray = [
		"Speed: %.2f m/s" % player.horizontal_speed(),
		"Mode: %s" % PlayerMotion.mode_name(player.mode),
		"Grounded: %s" % ("yes" if player.is_on_floor() else "no"),
		"Crouched: %s" % ("yes" if player.crouched else "no"),
		"Surface: %s" % player.surface,
		"Last footstep loudness: %.1f m" % player.noise.last_footstep_loudness,
		"Last landing loudness: %.1f m" % player.noise.last_landing_loudness,
	]
	_readout.text = "\n".join(lines)
