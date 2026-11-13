class_name GameMenu
extends CanvasLayer
## Game menu (child of the Player, ADR 0064): Esc opens it when no other pause screen is open
## (PauseScreens: it pauses the game and frees the mouse), Esc or Resume closes it. Save writes the
## one save slot (QuickSave; refused while dead or knocked out), Load loads it (disabled, with the reason, when
## there is nothing loadable; the line under it names the save's time and level), Quit game asks
## for confirmation first. Not openable while the debug panel is open, the player's input is
## disabled or a load is running; it opens on the losing screen, dead or knocked out (Load works
## there).
## After a load the new player's menu shows "Loaded" on the HUD (QuickSave.LOADED_GROUP).
## Settings opens the nested SettingsMenu (ADR 0124) in place of the buttons: still paused; Back or
## Esc returns to the buttons (not to the game); closing the menu also leaves it (the profile is
## saved on leaving).

## Yes on the quit confirmation, before the game quits (tests turn the quit off).
signal quit_requested

const SAVED := "Saved"
const LOADED := "Loaded"
const DEAD := "Cannot save while dead"
const KNOCKED_OUT := "Cannot save while knocked out"
const QUIT_QUESTION := "Quit? Unsaved progress is lost."
const HINT := "Esc: resume"
const CONFIRM_HINT := "Esc: back"

var player: Player
## False in tests: Yes only emits quit_requested.
var quit_on_confirm: bool = true

@onready var panel: PanelContainer = %Panel
@onready var buttons: VBoxContainer = %Buttons
@onready var resume_button: Button = %Resume
@onready var save_button: Button = %Save
@onready var load_button: Button = %Load
@onready var settings_button: Button = %SettingsButton
@onready var settings_menu: SettingsMenu = %Settings
@onready var quit_button: Button = %Quit
@onready var slot_label: Label = %SlotInfo
@onready var status_label: Label = %Status
@onready var confirm_box: VBoxContainer = %Confirm
@onready var yes_button: Button = %Yes
@onready var no_button: Button = %No
@onready var hint_label: Label = %Hint


func _ready() -> void:
	visible = false
	add_to_group(PauseScreens.GROUP)
	add_to_group(QuickSave.LOADED_GROUP)
	player = Entities.of_component(self) as Player
	resume_button.pressed.connect(close)
	save_button.pressed.connect(save_game)
	load_button.pressed.connect(load_game)
	settings_button.pressed.connect(open_settings)
	settings_menu.back_requested.connect(close_settings)
	quit_button.pressed.connect(ask_quit)
	yes_button.pressed.connect(confirm_quit)
	no_button.pressed.connect(cancel_quit)
	(%Question as Label).text = QUIT_QUESTION


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


func is_confirming_quit() -> bool:
	return visible and confirm_box.visible


func is_in_settings() -> bool:
	return visible and settings_menu.visible


func can_open() -> bool:
	return (
		player != null
		and player.accepts_input()
		and not QuickSave.is_loading()
		and not PauseScreens.any_open(get_tree())
	)


func open() -> void:
	if visible or not can_open():
		return
	status_label.text = ""
	_show_confirm(false)
	_show_settings(false)
	refresh_slot()
	visible = true
	PauseScreens.update(get_tree())
	resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	_show_settings(false)
	# A button keeping focus would take Space / Enter (jump) as a press while playing.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	PauseScreens.update(get_tree())
	player.resync_actions()


## Load is enabled only for a loadable save; the line under it names the save or says why not.
func refresh_slot() -> void:
	var status := QuickSave.check()
	load_button.disabled = status != SaveFile.Status.OK
	if status != SaveFile.Status.OK:
		slot_label.text = GameMenuRules.message(status)
		return
	var header := SaveFile.read(QuickSave.path).data
	slot_label.text = GameMenuRules.slot_line(header, GameMenuRules.system_utc_offset())


## Save: writes the slot now and says "Saved" (the menu stays open); false when refused (dead or
## knocked out: the save could only be loaded onto the losing screen; a load running) or the write
## failed.
func save_game() -> bool:
	if player == null or QuickSave.is_loading():
		return false
	if not ActorState.can_act(player):
		status_label.text = DEAD if player.is_dead() else KNOCKED_OUT
		return false
	var status := QuickSave.save_game(get_tree())
	status_label.text = SAVED if status == SaveFile.Status.OK else GameMenuRules.message(status)
	refresh_slot()
	return status == SaveFile.Status.OK


## Load: starts loading the slot. The menu goes with the old level (it closes and unpauses as it
## leaves the tree); the new player's menu shows "Loaded". False, with the reason, when there is
## nothing loadable.
func load_game() -> bool:
	if QuickSave.is_loading():
		return false
	var status := QuickSave.check()
	if status != SaveFile.Status.OK:
		status_label.text = GameMenuRules.message(status)
		refresh_slot()
		return false
	QuickSave.load_game(get_tree())
	return true


## Settings: the Settings screen replaces the panel (the game stays paused).
func open_settings() -> void:
	if not visible:
		return
	_show_settings(true)


## Back (or Esc) from Settings: the profile is saved and the buttons come back.
func close_settings() -> void:
	if not settings_menu.visible:
		return
	_show_settings(false)
	settings_button.grab_focus()


func ask_quit() -> void:
	_show_confirm(true)
	no_button.grab_focus()


func cancel_quit() -> void:
	_show_confirm(false)
	quit_button.grab_focus()


func confirm_quit() -> void:
	quit_requested.emit()
	if quit_on_confirm:
		get_tree().quit()


## QuickSave.LOADED_GROUP: the load this player came from has finished.
func on_quickloaded() -> void:
	Notices.send(player, LOADED)


func _show_settings(shown: bool) -> void:
	if shown:
		panel.visible = false
		settings_menu.open()
	else:
		settings_menu.close()
		panel.visible = true


func _show_confirm(confirming: bool) -> void:
	buttons.visible = not confirming
	confirm_box.visible = confirming
	hint_label.text = CONFIRM_HINT if confirming else HINT


# Esc: back out of Settings or the quit confirmation, else close; opens the menu only when no other pause screen
# is open (that screen closes on this Esc instead, never both).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if visible:
		if settings_menu.visible:
			close_settings()
		elif confirm_box.visible:
			cancel_quit()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()
