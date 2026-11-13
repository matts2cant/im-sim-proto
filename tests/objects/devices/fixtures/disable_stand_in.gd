extends Node
## Test stand-in (not a suite, ADR 0099 amendment, ADR 0137): a behaviour component that can be
## switched off by a command, the way any device component may say so (DeviceStatus.is_disabled()),
## offering Enable while off and Disable while on (DeviceStatus.applicable()).

var disabled: bool = false


func device_status() -> Array[StatusWord]:
	return [DeviceStatus.DISABLED if disabled else DeviceStatus.ENABLED] as Array[StatusWord]


func device_commands() -> Array[StringName]:
	return [DeviceSwitch.ENABLE if disabled else DeviceSwitch.DISABLE] as Array[StringName]


func device_disabled() -> bool:
	return disabled
