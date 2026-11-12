class_name GameSettingsDisplay
extends RefCounted
## Applies GameSettings' display settings to the main window through the DisplayServer, only when
## the window differs (so loading the profile at every level start does not touch the window).
## Tests swap GameSettings.display for a subclass that records the calls.


func set_fullscreen(on: bool) -> void:
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if on and not full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not on and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func set_vsync(on: bool) -> void:
	var wanted := DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != wanted:
		DisplayServer.window_set_vsync_mode(wanted)
