# 80. The credentials terminal (M8 placeholder)

Status: Accepted (M12 replaces it with computers and the deck, [ADR 0074](0074-network-hacking.md)); the screen, the device view and the E rule are amended by [ADR 0083](0083-security-terminal-redesign.md)

Date: 2026-11-08

## Context

M8 keeps a placeholder terminal: credentials found in the world log you in, and from it you command the security devices it reaches ([ADR 0077](0077-devices-cables-and-remote-commands.md), [ADR 0079](0079-security-cameras-and-turret.md)). It must not know device types: the doors agent's devices (open, close, lock, unlock) and anything later must appear without terminal changes.

## Decision

- **Terminal** (`objects/terminal/terminal.tscn`, `Terminal`, a `Usable`, "E: use <label>"; tuning `terminal.tres`): a wall-mounted Device with `Powered` and `Breakable` (health 20, electronics). Per instance: `credentials_id`, `username`, `password`, `label`. Unpowered or broken it does nothing when used.
- **Credentials format**: a datapad's `Readable.codes[credentials_id] = "user:password"` (split at the first colon; `TerminalCredentials`, pure). The user name matches without regard to case or surrounding spaces, the password exactly. The terminal asks the user's `PersonalLog.known_code(credentials_id)` and `code_source()` (the entry title), the same path as keypad codes.
- **Screen** (`ui/terminal/terminal_screen.tscn`, `TerminalScreen`, a child of the Player): `Terminal.use(user)` opens the user's screen; a user without one cannot use a terminal. It is **not a pause screen**: the game keeps running; while it is open the player's input is off and the mouse is free. Esc always leaves (handled in `_input`, before text fields and the game menu); E leaves only when no text field has focus (superseded by [ADR 0083](0083-security-terminal-redesign.md): Esc only, E never leaves). It also closes when the user cannot act, is more than 3 m from the terminal, or the terminal goes dead.
- **Login view**: user and password fields; with known credentials, "Known: <user> from '<entry title>'" and a Fill in button (the player still logs in). Wrong: "Wrong password." and a beep (noise 4). The terminal stays logged in until someone logs out (saved).
- **Device view** (superseded by [ADR 0083](0083-security-terminal-redesign.md): Camera and Network tabs over `Terminal.devices()`, the physical network, with statuses from components; offline instead of unpowered / broken): `Terminal.listing()` = every device in `Device.connected_devices()` (new: the reached devices plus dead ones right behind a live link, `DeviceGraph.connected()`) that accepts at least one command of the table, with its state from its tags (online, unpowered, broken; dead devices' buttons are disabled) and one button per accepted command. Buttons call `Device.send_command()`. Refreshed on open, after each press and every second, so devices it no longer reaches disappear.
- **The command table is data** (`TerminalConfig.command_labels`, ordered: `command.open` -> "Open", ...): a device is offered the table's commands it accepts (a receptron for the type, `Device.accepts()`), in table order. Device-to-device traffic (`device.incident`, `command.broadcast`) is left out of the table. Nothing branches on a device's type.
- EventLog: `terminal.opened {terminal, by}`, `terminal.login {terminal, user, ok}`, `terminal.logout {terminal}`; commands as `device.command`.

## Alternatives considered

- **A pause screen** like the reading overlay: safe, but M12's computers keep the world running, and guards walking in on you at a terminal is part of the risk.
- **Listing only reached devices**: reach requires the target to be up, so an unpowered camera would vanish instead of showing "unpowered"; showing dead devices behind a live link tells the player why a command will not work.
- **Commands from a device-type table** ("cameras have pan"): identity code; the receptron list already says what each device takes.

## Consequences

- Doors ([ADR 0078](0078-doors-locks-and-door-navigation.md)) carry `command.open/close/lock/unlock` receptrons and a Device, so a cabled door appears with Open, Close, Lock and Unlock buttons with no door code in the terminal (tested: the showcase door opens from the terminal).
- A new command type needs a label in `terminal.tres` to be offered (a test checks every `command.*` constant on `Device` has one).
- M12 replaces the terminal and its screen; `Device.connected_devices()` and the label table can serve its Security app.
- Tests: `tests/objects/terminal/terminal_rules_test.gd` (credentials, labels), `terminal_test.gd` (login with the datapad's credentials, commands reach devices, walking away); the screen's tests moved to `tests/ui/terminal/` with ADR 0083.
- See [security](../game/security.md), [controls](../game/controls.md).
