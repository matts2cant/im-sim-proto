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
| Esc | Close the inventory screen, log screen or reading overlay (only that, never also the menu); otherwise open the game menu (pauses, frees the mouse): Resume, Save, Load, Quit game ([ADR 0064](../decisions/0064-game-menu.md)). In the menu: Esc closes it (on the quit question: No); Up/Down/Tab move between buttons, Enter/Space press. Also on the death screen |
| LMB | Use the item in hand: fire / swing a weapon, use one medkit, a biocell's message (a tool: nothing until M8; empty hands: nothing); while carrying: throw along the view. Inventory screen: drag items |
| RMB | Alt. Inventory screen: item context menu |

## Rules

- Gamepad support and rebinding are parked: [../backlog.md](../backlog.md).
- Lean has no binding in v0.
- Crouch is hold-to-crouch; the player stays crouched while there is no headroom to stand ([movement.md](movement.md)).
- The mouse is captured while the player is active and the debug panel is closed; opening the panel frees it and closing restores the previous mode. Movement input is ignored while the panel is open.
- Carry and throw (M3): see [objects-and-fire.md](objects-and-fire.md). Interact, carry, weapon and belt actions (E, Q, LMB, R, H, 1-0) trigger on the press edge in the physics tick, like jump; they are ignored while the debug panel is open. Wheel notches (`belt_next` / `belt_prev`) are counted as input events and applied in the same physics tick with the same gating (dead or incapacitated, debug panel, pause screens).
- Weapons (M4): see [weapons-and-aiming.md](weapons-and-aiming.md).
- Inventory, belt, pickup prompts and drop (M5): see [inventory.md](inventory.md). The inventory screen, the log screen and the reading overlay pause the game and free the mouse; only one is open at a time ([ADR 0052](../decisions/0052-inventory-pauses-the-game.md)); a key still held when they close does not count as a new press in game.
- Dead (M4): every input is ignored except E, which reloads the level ([damage.md](damage.md)).
- Mouse sensitivity (0.0025 rad per pixel) and the ±89° pitch clamp are in `actors/player/player_config.tres`.

## Interactions

- [movement.md](movement.md), [inventory.md](inventory.md), [abilities.md](abilities.md), [weapons-and-aiming.md](weapons-and-aiming.md), [saving.md](saving.md), [debug-panel.md](debug-panel.md)

## Open questions

- Behaviour of RMB per item in game: still unbound (M6 may use it for augmentation targets).
