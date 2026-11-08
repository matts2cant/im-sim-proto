# Backlog

Parked items, out of scope for v0.

| Item | Note | Why parked |
|---|---|---|
| Terminal (CLI) app | A command-line app on computers or the deck | The desktop apps and the deck's tools cover v0 ([hacking](game/hacking.md)) |
| Deck upgrades | Better scanners, faster Icebreaker, more tools | One deck model in v0 ([ADR 0074](decisions/0074-network-hacking.md)) |
| VLANs | Several subnets on one switch | One switch carries one subnet ([ADR 0074](decisions/0074-network-hacking.md)) |
| Gamepad hacking | Cursor and typing on a gamepad | Part of the gamepad milestone |
| Remote-hacking augmentation | Hack a device in view without a link | Not in the v0 augmentation list ([ADR 0020](decisions/0020-skills-augmentations.md)) |
| Buying exploits | Exploits from vendors or contacts | No economy in v0; exploits are found ([hacking](game/hacking.md)) |
| NPCs reading device logs | Operators find exploit runs and logins in logs and react | v0: only the player reads logs ([hacking](game/hacking.md)) |
| NPCs noticing changed firewall rules | Operators or admins review rules and react | v0 operators react to dark camera feeds and offline tracers only ([hacking](game/hacking.md)) |
| Network app on computers | Discovery and hacking from any computer | Only the deck hacks in v0 ([ADR 0074](decisions/0074-network-hacking.md)) |
| Security robot | Needs EMP/electricity to be interesting | Electricity not in v0 |
| Water and electricity elements | Extra systemic pillars | v0 pillars are stealth, physics, security, fire ([ADR 0006](decisions/0006-pillars.md)) |
| Progression | XP, skill points, augmentation canisters/slots, body-location conflicts; attributes/modifiers are built for it | No progression in v0 ([ADR 0008](decisions/0008-progression-none.md)) |
| Forge (C#-only GAS addon) | Reconsider only if moving to C# | v0 uses GDScript and an own framework ([ADR 0003](decisions/0003-systemic-framework.md)) |
| Lean, ladders | Extra movement | Scope ([ADR 0014](decisions/0014-movement-scope.md)) |
| Gamepad and rebinding | Input options | Keyboard and mouse only for v0 ([ADR 0028](decisions/0028-input-physical-keys.md)) |
| Gamepad lockpicking mapping | L2 tension (analog: tension follows trigger depth), R2 lift (same spring/lag model), right stick changes pins; built-in rumble for clicks and strain (Godot 4.7 has rumble, light bar and motion sensors) | Part of the gamepad milestone ([ADR 0073](decisions/0073-realistic-lockpicking.md)) |
| DualSense adaptive triggers (stretch) | Trigger resistance for tension and strain; Godot has no adaptive-trigger API, so it needs a GDExtension | Needs the user's approval before adding any dependency |
| Lockpicking training course | A Deus Ex-style training level for the final game; v0 has acrylic practice locks | Needs a real level ([lockpicking](game/lockpicking.md)) |
| Other lock types | Safe dials, disc detainers, etc. | Pin-tumbler only for now |
| Terrain3D | Outdoor levels; addon removed | No outdoor terrain in v0 |
| Difficulty settings | Tuning via `.tres` and debug panel instead | Not needed for a prototype ([ADR 0029](decisions/0029-docs-english-no-difficulty.md)) |
| Real art, marketplace assets | Replace graybox | Abstract graybox fiction ([ADR 0010](decisions/0010-fiction-graybox.md)) |
| Git LFS, GitHub remote, CI | Remote workflow | Local git only for now ([ADR 0019](decisions/0019-version-control.md)) |
| Voiced barks | Replace text barks | Text and placeholder sound suffice ([ADR 0022](decisions/0022-guard-feedback.md)) |
| Inventory rotation | Rotate items on the grid | Fixed footprints keep it simple ([ADR 0015](decisions/0015-inventory-grid.md)) |
