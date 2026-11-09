# Controls

Milestone: M0 (input map); movement and look in M1; other actions added as features land (inventory and belt: M5).

## Purpose

Define the input scheme. Bindings are by physical key (QWERTY reference), so other layouts keep the same positions.

## Bindings

| Input | Action |
|---|---|
| W A S D | Move |
| Ctrl | Crouch (hold) |
| Shift | Sprint (hold, forward only) |
| Space | Jump / mantle (press facing a ledge, or hold in the air) |
| E | Interact with the looked-at thing within 2 m, as the HUD prompt says: pick up an item into the inventory, use a usable (a training dummy resets), read a datapad in place (its text opens and goes to the personal log), carry a physics object (up to the carry limit) or a downed (unconscious or dead) character (on its body; counts as 15 kg, slows you to 0.6; [ADR 0071](../decisions/0071-bodies-discovery-waking-carrying.md)); while carrying: put it down gently where there is room (else the prompt reads "No room to put down ..." and nothing happens; Q and LMB likewise). While reading a datapad: close it. Dead: reset the level (or Esc: game menu, Load) |
| R | Reload the equipped weapon |
| Q | Drop what is carried; when nothing is carried: drop the item in hand (weapon or tool) in front of you |
| I | Inventory screen (pauses the game); again or Esc closes |
| L | Personal log screen (pauses the game): what you have read and the codes you know ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)); again or Esc closes |
| 1-0 | Belt slots 1 ... 0: put the slot's item in hand (a weapon is drawn; a tool, medkit, biocell... is held); the same key again: put it away ([ADR 0059](../decisions/0059-belt-selects-lmb-uses.md)). In the inventory screen, while hovering an item: assign it to that slot |
| Mouse wheel | Down: the next non-empty belt slot to the right, up: the previous one; wraps; from empty hands down takes the first item, up the last. One item per notch; nothing is used |
| H | Holster: put away whatever is in hand (empty hands, no belt highlight) |
| F1 / F2 / F3 / F4 / F5 | Toggle Cloak / Run Silent / Speed Enhancement / Regeneration / Combat Strength (press; fails with "Energy depleted" at 0 energy) ([abilities.md](abilities.md)) |
| ` (QuoteLeft) | Debug panel |
| Mouse look | Look (captured mouse) |
| Esc | Close the inventory screen, log screen or reading overlay (only that, never also the menu); otherwise open the game menu (pauses, frees the mouse): Resume, Save, Load, Quit game ([ADR 0064](../decisions/0064-game-menu.md)). In the menu: Esc closes it (on the quit question: No); Up/Down/Tab move between buttons, Enter/Space press. Also on the death and knocked-out screens |
| LMB | Use the item in hand: fire / swing a weapon (an automatic weapon, the assault rifle, keeps firing while LMB is **held** and stops when released; [ADR 0085](../decisions/0085-weapons-and-attachments.md)), use one medkit, a biocell's message (a tool: hold LMB on what you look at; a lockpick on a mechanical lock opens it after pins x 1 s x `lockpick_time_mult`, letting go or looking away loses the progress (M8 placeholder, [ADR 0078](../decisions/0078-doors-locks-and-door-navigation.md)); the lockpick minigame from M10; empty hands: nothing); while carrying: throw along the view. Inventory screen: drag items |
| At a terminal (M8, [ADR 0080](../decisions/0080-credentials-terminal.md), [ADR 0083](../decisions/0083-security-terminal-redesign.md)) | E on a terminal within reach opens its screen; the game keeps running (not a pause screen) and the mouse is free. Click a field and type the user and password, Enter in the user field moves to the password, Enter there logs in; Fill in copies credentials you have read. After login: Camera tab (click a camera or turret in the list: its live view, status and command buttons) or Network tab (click a node: a menu with its status and commands; click the background to close it); Log out. Esc: leave, every time, also while typing (never also opens the game menu). E does not leave. Walking more than 3 m away (pushed, knocked out) closes it |
| At a keypad (M8, [ADR 0078](../decisions/0078-doors-locks-and-door-navigation.md)) | E on a locked door with a keypad opens its entry screen (the game pauses). 0-9 (number row or numpad) or click the buttons: type; Backspace: delete; C: clear; Enter or OK: submit (a wrong code beeps, noise 4, and clears; the right one closes the screen and opens the door). Esc: leave, always, also halfway through typing (never also opens the game menu). E does not leave |
| While lockpicking (M10, [lockpicking.md](lockpicking.md)) | Lockpick on the belt + LMB on a lock within reach starts it; the view locks on the lock. W / S: raise / lower tension (holds, no leak). A / D: move the pick between pins. Mouse Y: lift. S while lifting: ease tension (counter-rotation). E or Esc: leave (releases tension, loses progress; Esc leaves picking first and never also opens the game menu). Tier 3 skill: hold LMB ~2 s to auto-rake a Simple lock |
| At a computer or with the deck (M11, [hacking.md](hacking.md)) | E on a computer within reach: use its screen bare-handed. Deck on the belt + LMB on a wall jack, maintenance port or computer: plug it in (tethered); LMB within an access point's range: raise the deck (wireless). The view locks on the screen; the mouse drives its cursor, the keyboard types into its text fields. Esc: step away or lower the deck, every time, also while typing (never also opens the game menu); E does not ([ADR 0083](../decisions/0083-security-terminal-redesign.md)). Wireless tools keep running with the deck lowered while you stay in range; walking away from a jack, port or computer unplugs the deck and stops its tools. The world keeps running |
| Mission briefing (M9, [ADR 0087](../decisions/0087-mission-systems.md)) | Shown when a mission level starts: its text and objectives; the game pauses and the mouse is free. E, Enter or Esc closes it and play starts (E is not also taken as a use; Esc never also opens the game menu) |
| Mission summary (M9) | Shown at extraction: time, alarms raised, kills, knockouts, optional objectives, badges; the game stays paused, the mouse is free. Click (or Tab and Enter/Space) **Restart mission** (the level from its start) or **Return to hub** (the hub's spawn, empty inventory). Esc does nothing here: there is no way back into the finished mission |
| Mission doorway (hub, M9) | Walking into the west wall's north doorway ("Mission") loads the mission level |
| RMB | `alt_fire`: with a scoped weapon in hand (sniper rifle) **toggles** the scope: press to zoom in (view 15 degrees, scope overlay, slower mouse look), press again to zoom out; it also comes off on reload, switching or putting the weapon away and when you cannot act. Nothing with other items. The game keeps running ([ADR 0085](../decisions/0085-weapons-and-attachments.md)). Inventory screen: item context menu |

## Rules

- Gamepad support and rebinding are parked: [../backlog.md](../backlog.md).
- Lean has no binding in v0.
- Crouch is hold-to-crouch; the player stays crouched while there is no headroom to stand ([movement.md](movement.md)).
- The mouse is captured while the player is active and the debug panel is closed; opening the panel frees it and closing restores the previous mode. Movement input is ignored while the panel is open.
- Carry and throw (M3): see [objects-and-fire.md](objects-and-fire.md). Interact, carry, weapon and belt actions (E, Q, LMB, R, H, 1-0) trigger on the press edge in the physics tick, like jump; they are ignored while the debug panel is open. Wheel notches (`belt_next` / `belt_prev`) are counted as input events and applied in the same physics tick with the same gating (dead or incapacitated, debug panel, pause screens).
- Weapons (M4): see [weapons-and-aiming.md](weapons-and-aiming.md).
- Inventory, belt, pickup prompts and drop (M5): see [inventory.md](inventory.md). The inventory screen, the log screen and the reading overlay pause the game and free the mouse; only one is open at a time ([ADR 0052](../decisions/0052-inventory-pauses-the-game.md)); a key still held when they close does not count as a new press in game.
- The terminal screen (M8) and computer and deck screens (M11) do not pause the game: while one is open the player's input is off.
- Dead (M4): every input is ignored except E, which reloads the level ([damage.md](damage.md)).
- Mouse sensitivity (0.0025 rad per pixel) and the ±89° pitch clamp are in `actors/player/player_config.tres`. Through a scope the sensitivity (and the look bloom of the aim cone) is multiplied by the camera's FOV / 80 (15 / 80 fully zoomed), so the crosshair moves as far on screen per pixel as at the hip.
- Inventory screen: dragging a silencer onto a weapon fits it ([inventory.md](inventory.md#attachments)).

## Interactions

- [movement.md](movement.md), [inventory.md](inventory.md), [hacking.md](hacking.md), [abilities.md](abilities.md), [weapons-and-aiming.md](weapons-and-aiming.md), [saving.md](saving.md), [debug-panel.md](debug-panel.md)

## Open questions

- RMB with items other than a scoped weapon: still unbound.
