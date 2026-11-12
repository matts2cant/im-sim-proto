# 85. Shotgun, sniper rifle, assault rifle and weapon attachments

Status: Accepted (amends [ADR 0048](0048-aim-model.md), [ADR 0050](0050-inventory-model-and-belt-references.md) and [ADR 0070](0070-guard-combat-and-loadouts.md)); shotgun at 15 m amended by [ADR 0105](0105-character-model-playtest-fixes.md): 1-3 shots with the model-sized head, kept by the user

Date: 2026-11-09

## Context

The player had one lethal weapon, a pistol that was always silenced (fire noise 6 m). The brief asked for three new weapons with distinct roles (a close-range shotgun, a scoped sniper rifle, a full-auto assault rifle), real models from the Kenney Blaster Kit (CC0), and a silencer the player fits in the inventory, so that "quiet" becomes a choice the player makes instead of a property of the starting gun. Pellets, automatic fire, a scope and attachments must be data any weapon and any holder (guards included) can use, never branches on weapon ids (AGENTS.md "Systemic design").

## Decision

**Weapons are data on `WeaponData`** (`items/weapons/weapon_data.gd`):

- `pellets` and `pellet_spread_deg`: a shot fires `pellets` projectiles, each its own damage and force ray, spread evenly-random inside a cone around the aimed direction (`PelletPattern`, pure: pellet i in the i-th angular sector, radius uniform over the disk's area). One impact noise per shot, at the first projectile's hit.
- `automatic`: while the holder's `trigger_held` is true it fires again every `cycle_time` (checked before the cooldown ticks, so exactly one shot per cycle); an empty magazine ends the burst without dry clicks. The player sets `trigger_held` from LMB every tick (hold, not toggle); any AI can set it the same way.
- `aim_config` (the cone while drawn: the holder's own config when null, so the skill-scaled pistol keeps `aim_untrained.tres`), and `AimConfig.shot_bloom_cap_deg`: shots bloom the cone up to the cap, stance floors may still be wider (sustained-fire bloom that recovers through the normal settle).
- `scope_fov`, `scope_time`, `scope_aim_config`: a weapon with a scope. `ScopeState` (pure) is a toggle with a zoom amount; the holder steps it with "can scope" (a scope, arms usable, not reloading), so it **scopes out by itself** on reload, when the user cannot act or loses its arms; switching or putting the weapon away drops it at once. While scoped the holder uses the scope's cone and hides the view model. Whoever owns the camera reads `scope.view_fov(weapon, hip_fov)`: the player blends 80 to 15 degrees over 0.15 s, scales mouse sensitivity (and look bloom) by the FOV ratio, and the HUD draws the scope overlay (black outside a round lens, thin crosshair, the scoped cone as a thin ring; since 2026-11-12 the HUD crosshair centred on the lens, see the amendment) instead of the reticle. The game keeps running.
- `attachment_slots` (`muzzle`), `suppressed_fire_sound`, `view_scene` (a `WeaponModel` scene: the model pointing -Z, a muzzle marker, `AttachmentMount`s). Weapons without a model keep the placeholder box (`view_size`...; the guards' pistol).

**Attachments are items whose effect is Modifiers on weapon stats.** An attachment item carries an `AttachmentData` (`items/attachments/`): its slot, `Modifier`s, a label ("silenced"), a model and its length. `WeaponState` holds the fitted attachments in an `AttributeSet`; `stat(name)` is the WeaponData property `name` (any numeric field, plus `suppressed`) through those modifiers, and the holder reads `fire_noise`, `impact_noise`, `fire_volume_db`, `muzzle_flash_size` and `suppressed` through it. The silencer: `fire_noise` x0.25, `muzzle_flash_size` x0, `fire_volume_db` -2, `suppressed` = 1 (the weapon's suppressed sound). The pistol goes from 25 m to 6.25 m, the old silenced pistol's 6.

- Compatibility is data: the weapon lists the slots it accepts, the attachment names its slot, one attachment per slot (`Attachments.can_attach`, pure). Pistol, sniper rifle and assault rifle accept `muzzle`; the shotgun accepts nothing.
- What is fitted lives in the weapon stack's instance state, `attachments: {slot: item id}` (JSON-safe), so it is saved with the inventory and kept by the world pickup when dropped; `PlayerInventory.weapon_state()` applies it when it builds the stack's WeaponState.
- **Fitting is in the inventory screen** (it pauses): dragging an attachment highlights every stack it fits (grid and belt); dropping it on one fits it (`PlayerInventory.attach`: the attachment stack is used up, `item.attached` is logged); anywhere else it moves or drops as before. **A fitted attachment cannot come off** (user decision).
- The model shows the attachment: `WeaponModel.fit()` instances the attachment's model at its mount, and a muzzle attachment moves the muzzle (flash, shot noise) to its end. The view model is rebuilt when an attachment is fitted to the drawn weapon (`WeaponState.attached` signal). World pickups with a `WeaponModel` fit what their state records (`ItemPickup.refresh_model`).

**The view model is its own component.** `WeaponView` (the holder's child "ViewPivot") owns the model or box, recoil and swing animation, the muzzle flash and the cloak fade; the holder keeps shots, timings and state.

**Baselines changed on purpose**: the player's pistol is now loud by default ("Pistol", fire noise 25, a flash, a gunshot sound); the hub's loadout table has a silencer beside it. Guards' loadouts are unchanged (`pistol_unsilenced.tres`, no model).

## Tuning (measured, `tests/items/weapons/weapon_outcomes_test.gd`, guard body, 8 fixed seeds)

| Weapon | Starting numbers | Target | Measured | Changed |
|---|---|---|---|---|
| Shotgun | 8 x 12 ballistic, 5 degree cone | one torso shot at 5 m downs a guard; 15 m takes 3+ | 5 degrees: 2 seeds of 8 killed in one shot at 5 m (most pellets miss the 0.44 m torso) | pellet cone **2.5 degrees**: 5 m one shot on 8/8; 15 m 3 to 6+ shots |
| Sniper rifle | 90 ballistic, hip 6 degrees, scoped 0.2 | scoped and still one torso shot kills at 40 m; first shot hits the range's 40 m dummy | 8/8 one shot; the scoped cone settles from 6 to 0.25 degrees in 1.4 s | none |
| Assault rifle | 14 ballistic, 0.1 s, 1.5 degrees + 0.4 per shot, cap 6 | held on the torso at 10 m kills in under 1.2 s | 3 seeds of 8 over 1.2 s (up to 2.0 s) | floor **1.0 degree**, **+0.25 per shot** (cap 6, settle 0.5 s): 0.53 to 0.63 s |

## Alternatives considered

- **A separate silenced weapon resource per weapon** (the old `pistol.tres` / `pistol_unsilenced.tres` pair): doubles every weapon and cannot express "fitted later"; modifiers on the existing stats compose with any future attachment (a scope that adds range, a heavy barrel).
- **Attachments as their own grid stacks linked to the weapon** (detachable): the user decided attachments stay on; recording them in the weapon's state keeps drop, pickup and save working with no new links.
- **Branching on `kind == SHOTGUN` / weapon ids** for pellets, auto fire or the scope: rejected by the systemic rule; every behaviour is a field any weapon can set.
- **Scope as a hold (RMB held)**: the user asked for a toggle.

## Consequences

- Any weapon can become automatic, scoped or a shotgun by data; a guard handed one would fire it through the same holder.
- New weapon stats that attachments should affect only need the holder to read them through `WeaponState.stat()`.
- The player starts loud: stealth now needs the silencer from the loadout table (or the range's second one) fitted first.
- Tests: `tests/items/weapons/pellet_pattern_test.gd`, `scope_state_test.gd`, `spread_bloom_test.gd`, `tests/items/attachments/attachments_test.gd` (pure); `new_weapons_test.gd`, `scope_test.gd`, `generic_holder_test.gd` (a minimal character, no player), `weapon_outcomes_test.gd` (measured targets), `weapon_view_test.gd`; `tests/ui/inventory/attachment_screen_test.gd` (drag, highlight, refuse, save/load, drop/pick-up); `tests/levels/gallery/shooting_range/shooting_range_rack_test.gd`.

## Amendment (2026-11-12, playtest)

The scope overlay no longer draws the scoped cone as a red ring: it draws the HUD crosshair at the centre of the lens, and the aim offset moves the lens and the crosshair together; the thin lines stop short of the arms ([ADR 0123 amendment](0123-recoil-and-skill-aim.md#amendment-2026-11-12-playtest)).
