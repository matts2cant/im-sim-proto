extends Node3D
## Screenshot helper for reviews (not a test, ADR 0099): the terminal's network map of the synthetic
## 60-device network (synthetic_network.gd) at the terminal screen's graph size, centred in the
## review window. Run the scene in a window with `-- out=<png> [zoom=<factor>] [select=<name>]`:
## it fits the map, then zooms around the map's centre and / or opens a node's menu, saves the
## window image and quits.

const Synthetic := preload("res://tests/ui/deck/fixtures/synthetic_network.gd")
const SHOT_SIZE := Vector2i(1152, 648)
## The Network tab's graph size on the terminal screen.
const GRAPH_SIZE := Vector2(1054, 440)

var _args: Dictionary = {}
var _network := Synthetic.new()
var _graph: NetworkGraph
var _time: float = 0.0
var _viewed: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			_args[parts[0]] = parts[1]
	get_window().size = SHOT_SIZE
	_network.build(self)
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = TerminalStyle.PANEL_COLOR
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	_graph = NetworkGraph.new()
	_graph.position = (Vector2(SHOT_SIZE) - GRAPH_SIZE) * 0.5
	_graph.size = GRAPH_SIZE
	layer.add_child(_graph)
	_graph.request_fit()
	_graph.show_network(_network.rows, _network.cables, null)


func _process(delta: float) -> void:
	_time += delta
	if _time > 0.3 and not _viewed:
		_viewed = true
		if _args.has("zoom"):
			_graph.zoom_at(_graph.size * 0.5, float(_args["zoom"]))
		if _args.has("select"):
			_graph.select(String(_args["select"]))
	if _time < 1.0:
		return
	var out := String(_args.get("out", "res://reports/screenshots/network_map.png"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("Saved ", out)
	_network.release()
	get_tree().quit()
