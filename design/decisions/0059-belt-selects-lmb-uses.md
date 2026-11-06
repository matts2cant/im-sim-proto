# 59. Belt selects, LMB uses; mouse wheel and H

Status: Accepted

Date: 2026-11-06

## Context

Until now a belt key *used* its slot's item: weapons and tools toggled in hand, but a medkit was consumed at once, a datapad opened for reading and a biocell showed its message. Playtesting asked for cycling through the belt with the mouse wheel, a highlight on the current slot and H to holster. With "key = use", scrolling past a medkit would heal (and spend it), so the wheel cannot sit on top of the old rule.

## Decision

- Selecting a belt slot (keys 1-0 or the wheel) puts its item **in hand**, whatever it is: a weapon is drawn, any other item (tool, medkit, keycard, biocell) is held (`PlayerInventory.held`). Nothing is used by selecting. The same key again puts it away (unchanged toggle).
- Exception: a datapad's (`READ`) belt key still opens the reading overlay at once, as before. Datapads stop being inventory items in a follow-up change (read in place, stored in a personal log), so no datapad-in-hand behaviour is designed here; the rule stays generic for weapons, tools and consumables.
- **LMB** (`fire`) uses the item in hand: fires / swings a weapon (unchanged), consumes one medkit (it stays in hand while any are left; the last one empties the slot and the hands), shows a biocell's or keycard's message. A tool still does nothing until M8. While carrying an object LMB still throws it; with empty hands LMB does nothing.
- **Mouse wheel** (`belt_next` = wheel down, `belt_prev` = wheel up): the next / previous non-empty slot, wrapping; from empty hands wheel down takes the first non-empty slot from the left, wheel up the last. One step per notch. Wheel buttons press and release within one event pair, so the Player counts notches in `_unhandled_input` and applies them in its physics tick with the other belt actions (pure rule: `Belt.next_filled`).
- **H** (`holster`): empty hands (`PlayerInventory.put_away()`); `Belt.selected` = -1, the HUD highlight goes.
- The wheel and H follow the number keys' gating: ignored while dead or incapacitated, while the debug panel is open and while a pause screen (inventory, reading overlay) is open; they work while carrying, like the number keys. Switching during a reload cancels it, as switching by number key does.
- HUD: the highlight follows `Belt.selected`; the item's name shows above the belt for `InventoryConfig.item_name_time` (1.5 s, fading over its last half) after the hand changes, hidden when holstered. The bottom-right name label shows any held item.
- The inventory screen's Use is unchanged: it uses at once (a medkit heals, a datapad reads, weapons and tools toggle in hand), since there the player picks the action explicitly.
- A saved `in_hand` is restored by putting it back in hand (before, a saved consumable would have been used on load).

## Alternatives considered

- **Wheel skips consumables** (keep "key = use"): the wheel and the keys would disagree about what a slot does, and a medkit could only be reached by its key.
- **Wheel only highlights, a confirm key draws**: one more key for the common case; Deus Ex draws on scroll.
- **Polling the wheel as a held action**: a wheel press is released in the same event pair, so `is_action_pressed` in the physics tick misses it.

## Consequences

- Using a medkit from the belt takes two inputs (key, then LMB); a medkit can be kept in hand for repeated heals.
- Every selection logs `item.used {action: equip}`; LMB use logs `consume`, `read` or `nothing` as before.
- Tests that pressed a belt key to heal now press the key and then `fire`.
