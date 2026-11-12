class_name ShotFeedback
extends Node
## Component of every WeaponHolder (its child "ShotFeedback", ADR 0126): turns the holder's resolved
## shots and swings into world effects through the viewport's ShotFx. Any shooter gets the same
## (the player is not special):
## - each projectile that hits leaves the impact of the material it hit (ShotFxConfig.group_for());
## - a tracer from the muzzle to the first projectile's hit (or its reach) on every `every`-th round:
##   the holder's `tracer_every` when set (guards: every shot), else the weapon's
##   WeaponData.tracer_every (0: never);
## - a melee hit on a body: a blue-white spark when the weapon deals `damage.stun`, else the body puff.

const STUN_TYPE: StringName = &"damage.stun"

## Ranged rounds fired since the holder was set up (the tracer count).
var rounds: int = 0


func _ready() -> void:
	# The world's pool is built once, before the first shot needs it (no hitch on that shot).
	_warm_up.call_deferred()


func _warm_up() -> void:
	if is_inside_tree():
		ShotFx.in_world(self)


## True when round number `round_number` (1-based) carries a tracer, one every `every` rounds.
static func wants_tracer(round_number: int, every: int) -> bool:
	return every > 0 and round_number > 0 and round_number % every == 0


## A ranged shot of `data`: `muzzle` where it left, `ends` each projectile's end (its hit or its
## reach) and `hits` the intersect_ray results of the projectiles that hit. `every`: the holder's
## tracer setting (0: the weapon's).
func shot(data: WeaponData, muzzle: Vector3, ends: Array[Vector3], hits: Array[Dictionary], every: int) -> void:
	var fx := ShotFx.in_world(self)
	if fx == null:
		return
	for hit in hits:
		var collider := hit.get("collider") as Node
		fx.impact(collider, hit["position"] as Vector3, hit.get("normal", Vector3.ZERO) as Vector3)
	rounds += 1
	var interval := every if every > 0 else data.tracer_every
	if wants_tracer(rounds, interval) and not ends.is_empty():
		fx.tracer(muzzle, ends[0])


## A melee swing of `data` hit `collider` at `point`: a spark or puff on a body, nothing on a surface.
func swing_hit(data: WeaponData, collider: Node, point: Vector3, normal: Vector3) -> void:
	if not ShotFxConfig.is_body(collider):
		return
	var fx := ShotFx.in_world(self)
	if fx == null:
		return
	fx.impact(collider, point, normal, ShotFxConfig.STUN if deals_stun(data) else ShotFxConfig.BODY)


## The weapon deals stun (any `damage.stun` entry).
static func deals_stun(data: WeaponData) -> bool:
	for type: StringName in data.damage:
		if TagContainer.matches(type, STUN_TYPE):
			return true
	return false
