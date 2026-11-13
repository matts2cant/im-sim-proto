extends Node
## Test stand-in (not a suite, ADR 0137): a minimal component with a toggle command pair of its own
## that no shipped code knows (`command.fixture_on` / `command.fixture_off`). It declares the one that
## changes something now (DeviceStatus.applicable()) next to its status word: proof that a new toggle
## command needs no edit outside its component.

const ON: StringName = &"command.fixture_on"
const OFF: StringName = &"command.fixture_off"

var on: bool = false


func device_status() -> Array[StatusWord]:
	return [StatusWord.make("on" if on else "off")] as Array[StatusWord]


func device_commands() -> Array[StringName]:
	return [OFF if on else ON] as Array[StringName]
