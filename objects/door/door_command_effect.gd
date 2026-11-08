class_name DoorCommandEffect
extends Effect
## Runs a remote command on the entity (ADR 0078): `open`, `close`, `lock` or `unlock` on its Door;
## `lock` / `unlock` reach a Lockable without a Door too (a locker). The `command.<name>` receptrons
## use it; they are blocked by `state.unpowered` and `state.broken`, so this never checks power.

@export var command: StringName = &"open"


func apply(ctx: EffectContext) -> void:
	var by: Node = ctx.stimulus.source if is_instance_valid(ctx.stimulus.source) else null
	var door := Door.of(ctx.entity)
	if door != null:
		door.command(command, by)
		return
	var lockable := Lockable.of(ctx.entity)
	if lockable == null:
		return
	if command == &"lock":
		lockable.lock(by, &"command")
	elif command == &"unlock":
		lockable.unlock(by, &"command")


func can_apply(ctx: EffectContext) -> bool:
	return Door.of(ctx.entity) != null or Lockable.of(ctx.entity) != null
