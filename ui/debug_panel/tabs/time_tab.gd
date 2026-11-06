class_name TimeTab
extends VBoxContainer
## Debug panel tab: game speed (Engine.time_scale, 0.1-2.0) with a reset to 1.0.

@onready var _slider: HSlider = $Row/Scale
@onready var _value: Label = $Row/Value
@onready var _reset: Button = $Row/Reset


func _ready() -> void:
	_slider.value_changed.connect(set_time_scale)
	_reset.pressed.connect(set_time_scale.bind(1.0))
	set_time_scale(Engine.time_scale)


func set_time_scale(value: float) -> void:
	var scale := clampf(value, _slider.min_value, _slider.max_value)
	Engine.time_scale = scale
	_slider.set_value_no_signal(scale)
	_value.text = "x%.2f" % scale
