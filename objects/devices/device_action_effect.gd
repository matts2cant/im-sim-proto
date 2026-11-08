class_name DeviceActionEffect
extends Effect
## Runs the device action the stimulus names (its type: `command.ring`, `device.incident`, ...) on
## the entity's Device (ADR 0077): Device.receive_action() tells the entity's behaviour components
## through `action_received`. The receptron holding it decides which types the device accepts and
## blocks on `state.unpowered` and `state.broken`. Nothing happens on an entity without a Device.


func apply(ctx: EffectContext) -> void:
	var device := Device.of(ctx.entity)
	if device != null:
		device.receive_action(ctx.stimulus.type, ctx.stimulus)


func can_apply(ctx: EffectContext) -> bool:
	return Device.of(ctx.entity) != null
