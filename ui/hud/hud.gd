class_name Hud
extends CanvasLayer
## In-game HUD of the player it is a child of: reticle (exact aim cone), weapon name and ammo, body
## silhouette, a red flash on every hit, and the death overlay. It only reads the player's
## BodyParts and WeaponHolder. Layer 10: the debug panel (layer 100) draws over it.

## Peak opacity of the damage flash and how long it fades (s).
const FLASH_ALPHA: float = 0.35
const FLASH_TIME: float = 0.4

var player: Player

var _flash: float = 0.0

@onready var reticle: Reticle = $Reticle
@onready var weapon_label: Label = $Weapon/Name
@onready var ammo_label: Label = $Weapon/Ammo
@onready var silhouette: BodySilhouette = $Body
@onready var damage_flash: ColorRect = $DamageFlash
@onready var death_overlay: Control = $DeathOverlay


func _ready() -> void:
	player = get_parent() as Player
	death_overlay.visible = false
	damage_flash.color.a = 0.0
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
	refresh_weapon()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		damage_flash.color.a = FLASH_ALPHA * _flash / FLASH_TIME
	if player != null and player.is_node_ready():
		_update_reticle()
		refresh_weapon()


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
	weapon_label.text = data.display_name if data != null else ""
	ammo_label.text = HudRules.ammo_text(player.weapons.state())


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


func _on_damaged(_part: StringName, _type: StringName, amount: float) -> void:
	if amount > 0.0:
		_flash = FLASH_TIME
		damage_flash.color.a = FLASH_ALPHA


func _on_died() -> void:
	death_overlay.visible = true


func _on_body_changed() -> void:
	death_overlay.visible = player.is_dead()
	silhouette.queue_redraw()
