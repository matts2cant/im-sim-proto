extends VBoxContainer
## Debug panel tab: live player movement, body and aim readouts, and the step height (StepClimber,
## ADR 0058) to tune in play. Registered by the Player it shows. The step height edits the loaded
## StepConfig resource (player_step.tres) in memory only: copy a value you like into the .tres.

var player: Player

@onready var _readout: Label = $Readout
@onready var _step_height: SpinBox = $StepRow/StepHeight


func _ready() -> void:
	_step_height.value_changed.connect(set_step_height)


## Sets the player's step height (m); clamped to the field's range.
func set_step_height(value: float) -> void:
	if not is_instance_valid(player):
		return
	player.step.config.step_height = clampf(value, _step_height.min_value, _step_height.max_value)


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
		"Height: %.2f m" % player.global_position.y,
		"Crouched: %s" % ("yes" if player.crouched else "no"),
		"Surface: %s" % player.noise.surface,
		"Last footstep loudness: %.1f m" % player.noise.last_footstep_loudness,
		"Last landing loudness: %.1f m" % player.noise.last_landing_loudness,
		"Carrying: %s" % _carried(),
		"Body: %s" % player.body.debug_text(),
		"Move speed x%.2f" % player.attributes.value(&"move_speed_mult"),
		"Aim: %s  spread %.2f deg  stance %s" % [_weapon(), player.weapons.aim.spread, _stance()],
	]
	_readout.text = "\n".join(lines)


func _weapon() -> String:
	var data := player.weapons.weapon()
	return String(data.id) if data != null else "holstered"


func _stance() -> String:
	return String(AimModel.Stance.find_key(player.aim_stance())).to_lower()


func _carried() -> String:
	if not player.carry.is_carrying():
		return "nothing (limit %.0f kg)" % player.carry.mass_limit()
	return "%s (%.1f kg)" % [player.carry.held.name, player.carry.held_mass()]
