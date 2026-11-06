class_name Hud
extends CanvasLayer
## In-game HUD of the player it is a child of: reticle (exact aim cone), the name of the item in
## hand and ammo (magazine / rounds in the inventory), body silhouette, a red flash on every hit,
## the Interactor's prompt under the reticle, short messages, the belt (bottom centre) with the name
## of the item put in hand above it for a moment (ADR 0059) and the death overlay. It only reads
## the player's components. Layer 10: the debug panel (layer 100) draws over it.

## Peak opacity of the damage flash and how long it fades (s).
const FLASH_ALPHA: float = 0.35
const FLASH_TIME: float = 0.4
## Seconds a message stays, the last half fading out.
const MESSAGE_TIME: float = 2.5

var player: Player

var _flash: float = 0.0
var _message_left: float = 0.0
var _item_name_left: float = 0.0

@onready var reticle: Reticle = $Reticle
@onready var weapon_label: Label = $Weapon/Name
@onready var ammo_label: Label = $Weapon/Ammo
@onready var silhouette: BodySilhouette = $Body
@onready var damage_flash: ColorRect = $DamageFlash
@onready var death_overlay: Control = $DeathOverlay
@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message
@onready var item_name_label: Label = $ItemName
@onready var belt_bar: BeltBar = $Belt


func _ready() -> void:
	player = get_parent() as Player
	death_overlay.visible = false
	damage_flash.color.a = 0.0
	message_label.text = ""
	item_name_label.text = ""
	prompt_label.text = ""
	if player == null:
		return
	# The player's _ready runs after ours: wait for it so its components are wired.
	if not player.is_node_ready():
		await player.ready
	silhouette.body = player.body
	player.body.damaged.connect(_on_damaged)
	player.body.died.connect(_on_died)
	player.body.changed.connect(_on_body_changed)
	player.weapons.changed.connect(refresh_weapon)
	belt_bar.bind(player.inventory)
	player.inventory.message.connect(show_message)
	player.inventory.hand_changed.connect(_on_hand_changed)
	refresh_weapon()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		damage_flash.color.a = FLASH_ALPHA * _flash / FLASH_TIME
	if _message_left > 0.0:
		_message_left = maxf(_message_left - delta, 0.0)
		message_label.modulate.a = minf(_message_left / (MESSAGE_TIME * 0.5), 1.0)
	if _item_name_left > 0.0:
		_item_name_left = maxf(_item_name_left - delta, 0.0)
		item_name_label.modulate.a = minf(_item_name_left / (_item_name_time() * 0.5), 1.0)
		if _item_name_left == 0.0:
			item_name_label.text = ""
	if player != null and player.is_node_ready():
		_update_reticle()
		refresh_weapon()
		prompt_label.text = player.interactor.prompt if not player.is_dead() else ""


## Reticle radius in pixels for the player's current spread (0 without a ranged weapon).
func reticle_radius() -> float:
	var data := player.weapons.weapon()
	if data == null or data.is_melee():
		return 0.0
	var camera := player.weapons.camera
	var height := get_viewport().get_visible_rect().size.y
	return AimModel.reticle_radius(player.weapons.aim.spread, camera.fov, height)


func refresh_weapon() -> void:
	var data := player.weapons.weapon()
	var held := player.inventory.held
	if data != null:
		weapon_label.text = data.display_name
	else:
		weapon_label.text = held.item.display_name if held != null else ""
	ammo_label.text = HudRules.ammo_text(player.weapons.state())


## Shows `text` above the belt for a few seconds ("No room in inventory").
func show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_left = MESSAGE_TIME


## Seconds the item name stays above the belt after the hand changed (its last half fading out).
func _item_name_time() -> float:
	return player.inventory.config.item_name_time


func flash_alpha() -> float:
	return damage_flash.color.a


func _update_reticle() -> void:
	var radius := reticle_radius()
	var offset := Vector2.ZERO
	if radius > 0.0:
		var camera := player.weapons.camera
		var height := get_viewport().get_visible_rect().size.y
		var sway := player.weapons.sway()
		offset = Vector2(
			AimModel.reticle_radius(sway.x, camera.fov, height), -AimModel.reticle_radius(sway.y, camera.fov, height)
		)
	reticle.show_cone(radius, offset)
	reticle.visible = not player.is_dead()


# The item put in hand: its name above the belt for a moment; empty hands: no name.
func _on_hand_changed() -> void:
	var stack := player.inventory.in_hand()
	if stack == null:
		item_name_label.text = ""
		_item_name_left = 0.0
		return
	item_name_label.text = stack.item.display_name
	item_name_label.modulate.a = 1.0
	_item_name_left = _item_name_time()


func _on_damaged(_part: StringName, _type: StringName, amount: float) -> void:
	if amount > 0.0:
		_flash = FLASH_TIME
		damage_flash.color.a = FLASH_ALPHA


func _on_died() -> void:
	death_overlay.visible = true


func _on_body_changed() -> void:
	death_overlay.visible = player.is_dead()
	silhouette.queue_redraw()
