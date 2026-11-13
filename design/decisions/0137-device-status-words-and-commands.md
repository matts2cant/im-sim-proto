# 137. Device status words and commands declared by components

Status: Accepted

Date: 2026-11-13

## Context

The code audit ([audit-2026-11-13.md](../tech/audit-2026-11-13.md), Q12-Q14, Q16, Q18, Q19, Q27, S18) found the device status and command vocabulary spread over four places: `DeviceStatus.applicable()` hardcoded which command to hide for which status word (a string contract with cameras, doors and locks); `DeckStyle` and `HalcyonStyle` each kept an `ALERT_WORDS` list and their own status colour and text rules; the interaction frame's `TargetStatus.Word` was a closed enum with text, colour and blink tables, returned by gameplay code (a mine's `ProximityTrigger`); `Device` held every device kind's command constants and the reach graph's builder, and its `tool_hold()` called `DeckSession`; the deck's port kind and its traffic's kind were two enums mapped by hand (and matched again for the header's label); two screens looked up a device's address with their own loop.

## Decision

- **StatusWord** (`objects/devices/status_word.gd`, a Resource: `text`, `color`, `blink`, `alert`) is the one status vocabulary. Shared words are `.tres` data in `objects/devices/status_words/` (the frame's in `frame/`), preloaded as constants by whoever says them: `DeviceStatus` for the words several devices share (`ONLINE`, `OFFLINE`, `ENABLED`, `DISABLED`, `IDLE`, `RINGING`, `SILENT`), a component for its own (`SecurityCamera.SWEEPING`, `Lockable.LOCKED`, `ProximityTrigger.ARMED_WORD`, ...), `TargetStatus` for the frame's. A word made at run time (a turret's "targets guards") is `StatusWord.make()`.
- **Status**: components' `device_status()` returns `Array[StatusWord]`. Screens keep the words' texts (`NetworkRow.status`, `Computer.DeviceRow.status`) and an `alert` flag (any word flagged `alert`), never a list of alert texts.
- **One colour rule**: `DeviceStatus.tone(texts, disabled, access, alert)` (offline beats disabled beats access beats alert, else online). The deck and the Security app each map the tones to their palette (`DeckStyle.TONES`, `HalcyonStyle.TONES`); `DeviceStatus.text()` / `short_text()` join the words for both.
- **Commands declared by components**: a component offers `device_commands() -> Array[StringName]`, the commands it handles that change something now (Close while open, Unlock while locked, Stop sweep while sweeping; only Enable while switched off). `DeviceStatus.applicable(table_commands, entity)` keeps the table's commands one of the entity's components offers now; while a component is switched off only what the switched-off components offer; an entity whose components declare nothing offers every accepted command. The command constants live with the components that handle them (`Door.OPEN` / `CLOSE`, `Lockable.LOCK` / `UNLOCK`, `Siren.RING` / `SILENCE` / `TEST`, `AlarmController.TRIGGER` / `RESET` / `DISARM`, `DeviceSwitch.ENABLE` / `DISABLE` (the switch-off pair every switchable component handles), `RadioBaseStation.BROADCAST`, `SecurityCamera.STOP_SWEEP` ..., `Turret.TARGET_*`); `Device.INCIDENT` stays with Device. A new command needs no code outside its component; the screens' command tables (`ComputerConfig`, `DeckConfig`: labels and order, data) still list which commands a screen offers.
- **The frame**: `TargetStatus.word_of()` returns a StatusWord (null: no status line); the frame draws its text, colour and blink. A component puts its own word on the frame by joining `StatusWord.FRAME_GROUP` and answering `frame_word() -> StatusWord` (outside `ui/`, so gameplay does not depend on the HUD). The network words keep the status lights' colours (`StatusLight.COLORS`; tests hold them to it).
- **The reach graph's builder** is `DeviceGraphBuilder.build(tree, source, physical)` (`objects/devices/device_graph_builder.gd`); `DeviceGraph` stays pure logic and `Device` keeps the device's own concerns.
- **Tools**: `ToolUse` emits `worked(target, tool)` every tick it works a target; the deck's `DeckSession` reacts (plugs into the Device it works, `Device.of(target)` also resolving a `DevicePanel`). `Device.tool_hold()` knows nothing about the deck.
- **One entry-kind enum**: `NetworkSource.Kind { AUTO, NONE, JACK, PORT, HOST, DEVICE, BARE, WIRELESS }` is both the deck's traffic kind and a device's `deck_port` (AUTO and NONE only there; the first three values are stored in scenes). Labels are data (`NetworkSource.KIND_LABELS`); the `deck.plugged` log names the kind (`PORT` for a maintenance port, was `MAINTENANCE`).
- **One address helper**: `DeviceNetwork.address_of(node)` asks the entity's components for `device_address()`.

## Consequences

- Devices, the deck's Map and menus, the Security app and the frame look and behave as before (review shots before and after match). Commands that would do nothing are no longer offered: a door controller without a lock shows no Lock / Unlock.
- `tests/objects/devices/device_status_test.gd` proves a new toggle command with a stand-in component no shipped code knows (`fixtures/command_stand_in.gd`); `tests/actors/common/tool_use/tool_use_test.gd` the `worked` signal.
