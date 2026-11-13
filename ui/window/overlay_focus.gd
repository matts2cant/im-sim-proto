class_name OverlayFocus
extends RefCounted
## The focus a screen takes while the world keeps running (ADR 0110, 0133): the Tab interface, the
## computer, deck, keypad, lockpicking, reading and tuning screens, the debug panel and, for the
## mouse, PauseScreens. A holder acquire()s it for a user with the mouse mode it wants and whether
## the user's HUD hides, or acquire_all()s every user's input (the debug panel, a pause); release()
## gives it back.
## - Input: a held user does not accept input (Player.accepts_input(), blocks_input()). Any node can
##   be held (is_held()): systems ask that, not the screens.
## - Holds are counted: the user's held keys are resynced (Player.resync_actions()), its HUD shows
##   again and the mouse returns to its mode from before the first hold once, when the last hold that
##   needs it goes, whatever order the screens close in.
## - While anything is held the mouse is in the newest hold's mode (the lockpick captures it; the
##   debug panel opened over it frees it until it closes).
## Holds of freed holders are dropped (as if released) on the next call.


class Hold:
	extends RefCounted
	var holder: Object
	## The user held, or null with `everyone`.
	var user: Node
	var everyone: bool = false
	var mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
	## The HUD it hides (null: none) and that HUD's instance id.
	var hud: Hud
	var hud_id: int = 0


static var _holds: Array[Hold] = []
static var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
# HUD instance id -> its visibility before the first hold that hid it.
static var _hud_before: Dictionary[int, bool] = {}


## Takes the focus for `holder` (a screen) over `user` (null: the mouse only), with the mouse in
## `mouse` mode and, when `hide_hud`, the user's HUD hidden. Acquiring again replaces its hold.
static func acquire(
	holder: Object, user: Node, mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE, hide_hud: bool = false
) -> void:
	_add(holder, user, false, mouse, hide_hud)


## Takes the focus for `holder` over every user's input (the debug panel, a pause), the mouse in
## `mouse` mode.
static func acquire_all(holder: Object, mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE) -> void:
	_add(holder, null, true, mouse, false)


static func _add(holder: Object, user: Node, everyone: bool, mouse: Input.MouseMode, hide_hud: bool) -> void:
	_prune()
	var index := _index_of(holder)
	if index >= 0:
		_drop(index)
	if _holds.is_empty():
		_mouse_before = Input.mouse_mode
	var hold := Hold.new()
	hold.holder = holder
	hold.user = user
	hold.everyone = everyone
	hold.mouse = mouse
	hold.hud = Hud.of(user) if hide_hud else null
	if hold.hud != null:
		hold.hud_id = hold.hud.get_instance_id()
		if not _hides(hold.hud_id):
			_hud_before[hold.hud_id] = hold.hud.visible
	_holds.append(hold)
	if hold.hud != null:
		hold.hud.visible = false
	Input.mouse_mode = mouse


## Gives `holder`'s focus back; the last hold on a user (on the mouse, on a HUD) restores it.
static func release(holder: Object) -> void:
	var index := _index_of(holder)
	if index >= 0:
		_drop(index)
	_prune()


## True while `holder` has the focus.
static func holds(holder: Object) -> bool:
	return _index_of(holder) >= 0


## True while a screen holds `user` (a hold for no one does not count).
static func is_held(user: Node) -> bool:
	_prune()
	return _holds_user(user)


## True while `user`'s input is off: a screen holds it, or something holds every user's.
static func blocks_input(user: Node) -> bool:
	_prune()
	for hold in _holds:
		if hold.everyone:
			return true
	return _holds_user(user)


## The mouse mode the holds want now (the newest's), or the current one when nothing holds.
static func mouse_mode() -> Input.MouseMode:
	_prune()
	return _holds[-1].mouse if not _holds.is_empty() else Input.mouse_mode


## Number of holds now.
static func count() -> int:
	_prune()
	return _holds.size()


static func _drop(index: int) -> void:
	var hold := _holds[index]
	_holds.remove_at(index)
	if hold.hud_id != 0 and not _hides(hold.hud_id):
		if is_instance_valid(hold.hud):
			hold.hud.visible = _hud_before.get(hold.hud_id, true)
		_hud_before.erase(hold.hud_id)
	if is_instance_valid(hold.user) and not _holds_user(hold.user):
		var player := hold.user as Player
		if player != null:
			player.resync_actions()
	Input.mouse_mode = _holds[-1].mouse if not _holds.is_empty() else _mouse_before


static func _prune() -> void:
	var i := _holds.size() - 1
	while i >= 0:
		if i < _holds.size() and not is_instance_valid(_holds[i].holder):
			_drop(i)
		i -= 1


static func _holds_user(user: Node) -> bool:
	if user == null:
		return false
	for hold in _holds:
		if not hold.everyone and is_instance_valid(hold.user) and hold.user == user:
			return true
	return false


static func _index_of(holder: Object) -> int:
	for i in _holds.size():
		if is_instance_valid(_holds[i].holder) and _holds[i].holder == holder:
			return i
	return -1


static func _hides(hud_id: int) -> bool:
	for hold in _holds:
		if hold.hud_id == hud_id:
			return true
	return false
