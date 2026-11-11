# 111. Character tabs (Health, Augmentations, Skills) and the per-part medkit

Status: Accepted

Date: 2026-11-11

## Context

M11 replaces the scattered character screens with one Tab interface (the approved mockup: [tab_interface.html](../prototypes/tab_interface.html)); the world keeps running while it is open. Three of its pages show the character: Health, Augmentations and Skills. The mockup adds one new rule: a medkit can be used on a chosen body part instead of being spread over the hurt parts. Until now a medkit sent a `heal` CONTACT to its user and `HealEffect` split it over the damaged parts ([ADR 0057](0057-forces-item-use-and-heat-as-generic-systems.md)). The Skills page needs to say what every tier of a skill gives, and skills are only data (`SkillEffect`: an attribute, an op and a magnitude per tier, [ADR 0061](0061-abilities-model.md)) with no wording or units.

## Decision

- **Pages.** Each page is a `TabPage` scene (`ui/tab_interface/tabs/health_tab.tscn`, `augmentations_tab.tscn`, `skills_tab.tscn`) bound once to the player and refreshing itself every frame while visible. They read and act only through components (`BodyParts`, `Tags`, `PlayerInventory`, `Augmentations`, `Energy`, `Skills`), so they work for any character that has them; the Health page has no treatment without a `PlayerInventory`.
- **Per-part medkit = the medkit touching that part.** `PlayerInventory.use_stack(stack, part)` sends the item's use stimuli to the part's hitbox instead of the user. StimulusSystem already delivers a CONTACT on a hitbox to the entity's receivers with the hitbox as `collider` (that is how a shot finds its part, [ADR 0047](0047-hitboxes-layer-5-part-aware-ray.md)); `HealEffect` now reads the part from the collider (`Hitboxes.part_of`) and heals only that part (`BodyParts.heal(amount, source, part)` -> `BodyDamageModel.heal_part`, capped at the part's max), and its `can_apply` (the dry run behind the refusal) checks that part. So the amount is the same `heal` 30 x the user's `medical_heal_mult`, the refusal is the same "You are not hurt" (item kept), and any character with hitboxes and the `heal` receptron can be treated per part. A `heal` on the entity itself (the belt's medkit, "Heal all", Regeneration) still spreads.
- **Healing items are found by property**: consumables whose `use_stimuli` include `heal`; the amount shown is that intensity x the user's `use_scale_attribute`, and the skill named next to it is the one whose effects change that attribute.
- **What a disabled part does is worded from the body profile** (`leg_speed_mult`, `arm_spread_add`, `arm_sway_mult`; head and torso: death); current effects come from the body (one disabled limb) and the state tags (both legs / arms disabled whatever added the tag, plus a data list of tags with their text: burning, unconscious, cloaked).
- **Skill tier tables are data.** `SkillEffect` gains a Display group: `label`, and either the modifier itself (`x0.8`, `+1.2 %`), the value it gives a stated `display_base` with `display_scale`, `display_unit` and `display_decimals` (settle `0.6 s`, medkit `45`, sweet spot `37 %`), or `tier_texts` (Lockpicking's assists). `SkillData.tier_rows()` builds the table; the page adds no per-skill code.
- **Augmentation switches use the F-keys' path** (`Augmentations.toggle_slot()`); the TESTING tier buttons use the debug Stats tab's (`Skills.set_tier()`), until M18 replaces them with experience.

## Alternatives considered

- **A `part` field on `Stimulus`**: explicit, but it adds body vocabulary to the core framework for one effect, and hitboxes already are how a stimulus names a part.
- **A direct `BodyParts.heal_part()` call from the UI**: a player-only shortcut that skips the item, the Medicine scale, the refusal dry run and the EventLog chain.
- **Reading the tier-table base values from the consumers' tuning** (the weapon's damage, the lockpick tuning's window): every consumer has its own resource, and a skill does not know which weapon or tool reads its attribute. The base values shown are display data that repeat the tuning; a test pins the shipped table, so a tuning change that forgets the display shows up there only if the numbers are asserted, which they are for Pistols, Medicine and Lockpicking.

## Consequences

- A medkit can be aimed at a part by anything that can touch a hitbox: a future medic NPC healing an ally's leg needs no new code.
- Characters without hitboxes can only be healed spread; the Health page then still shows their body but its per-part button is refused.
- `actor.healed` and `item.used` log the part.
- The `display_base` numbers in `skill_table.tres` must follow tuning changes by hand (pistol damage 25, rifle 14, sniper 90, baton swing 0.6 s, medkit 30, the lockpick tuning's bases).
