# 74. Network hacking: a realistic network, a deck and tracers

Status: Accepted (supersedes [ADR 0017](0017-hacking-placeholder.md)); amended by [ADR 0112](0112-hacking-reconciled-with-the-built-game.md)

Date: 2026-11-08

## Context

ADR 0017 parked hacking behind a placeholder (multitools and credentials) until the user supplied a design. The user wants hacking that rewards understanding a believable network, with several ways through, and that fits the systemic principle: rules about properties (components, tags, stimuli), never identities.

## Decision

- **Network**: devices with IP addresses in subnets; one switch per subnet, no VLANs. Links are cable or wireless (access points have a range); autonomous devices have no link but a maintenance port. Gateways (firewalls) sit between subnets with ordered from / to / allow|deny rules, first match wins; from and to are a subnet, a device or "you" (the deck's current address); no ports.
- **Physical layer is systemic**: switches, access points and gateways have `Powered` and `Breakable`. Unpowering or breaking one cuts everything behind it; a device that loses its link falls back to standalone behaviour. Doors carry a fail-safe or fail-secure tag.
- **Access** is per machine (local user and admin accounts, no domain). What a machine can do depends on its subnet, the firewall rules for its address and which devices trust it.
- **Discovery**: from an entry point you see your own subnet and the gateway; a subnet you cannot pass shows as one locked node; access reveals it; seen devices stay on the map, greyed, when access is lost.
- **Entry points**: any computer bare-handed (its own desktop only), a wall jack (tethered), wireless in an access point's range, an autonomous device's maintenance port, or the deck plugged into a computer (it uses the computer's address). Leaving a computer stops nothing already running, but nothing new can be started.
- **The deck** is one inventory item with no upgrades. Discovery and hacking happen only on it; computers have no network app. Tools: Map, Icebreaker, Exploits, Sniffer (wireless only), Firewall (admin of a gateway), Logs (admin erases entries). Hacking is silent; guards can see you doing it.
- **Credentials**: explicit clues are learned automatically and offered with "Fill in"; implicit clues teach nothing, the player types the guess. Correct logins add no trace; failed logins, exploits and the Icebreaker do.
- **Icebreaker**: deterministic brute force. Base time Weak 10 s, Medium 24 s, Strong 50 s (longest real crack 25 s; starting values in [hacking.md](../game/hacking.md#tuning)). Progress is kept on the deck and resumes on the same account, unless the password changed.
- **Exploits**: found items that target a vendor, product and version range; reusable; burned (the subnet's devices patched) when a run is detected.
- **Tracers** are apps on a computer, server or gateway that watch named subnets, tuned by a `.tres` (gain, drain while idle, lockout 30 s). Full trace: an incident to the alarm controller at your entry point and your address blocked. A tracer whose host is down leaves its subnets unwatched; cut off from the alarm controller it still blocks but nothing rings; an admin can stop it ("Tracer offline" on the security console). No subnet tiers: difficulty is what the level designer places.
- **Devices and remote actions**: doors, cameras, turrets, sirens, alarm controllers, computers and keypads expose remote actions ([hacking](../game/hacking.md)). Disabling a camera is loud (dark feed, an operator radios a check); panning it is quiet. No feed loop.
- **Computers** run a simple desktop (Halcyon OS) with Mail, Files and Security. Reading mail and files adds them to the PersonalLog like datapads ([ADR 0060](0060-datapads-read-in-place-personal-log.md)); "Copy to deck" only for objectives.
- **NPCs** log in to devices through a "use device" action at patrol waypoints; devices keep logs.
- **UI**: the computer screen and the deck screen are in the world; a game UI overlay holds known credentials, deck actions, address and access level, toasts, hints, one trace bar per tracer and time estimates. Esc always steps away or lowers the deck; E does not ([ADR 0083](0083-security-terminal-redesign.md): Esc only).
- **Everything is deterministic and saved**: network state, deck contents, crack progress, trace and lockouts.
- **Milestone**: M12. M8 builds the devices and the alarm devices ([ADR 0075](0075-alarms-as-network-devices.md)); the Computer skill and the multitool's removal are [ADR 0076](0076-computer-skill-multitool-removed.md).

## Alternatives considered

- **A hacking minigame** (Deus Ex's timer bar, a pipe or node puzzle): skill expression is a puzzle unrelated to the world; a network model makes power, cables, firewalls and clues the puzzle.
- **Subnet security tiers**: a number that hides why a network is hard. Tracers, firewall rules and software versions are things the player can find and act on.
- **Domain accounts**: one password opens everything; per-machine accounts keep clues local and meaningful.
- **A network app on every computer**: makes the deck pointless and every office PC a full hacking station. Parked ([backlog](../backlog.md)).
- **Random crack times or success rolls**: unreadable and save-scummable. The Icebreaker is deterministic.
- **Clues that weaken passwords**: blurs the two paths. A clue gives the password or a hint to guess it; the Icebreaker cracks it.
- **Ports in firewall rules**: realism without gameplay in v0.
- **A camera feed loop**: removed; quiet vs loud comes from pan vs disable.

## Consequences

- New doc [hacking](../game/hacking.md); the gallery gets a network lab ([hub-and-gallery](../levels/hub-and-gallery.md)) and the warehouse a small network ([mission-warehouse](../levels/mission-warehouse.md)).
- The terminals of M8 keep the credentials placeholder until M12 replaces them with computers ([security](../game/security.md)).
- New inventory item: the deck ([inventory](../game/inventory.md)). New controls for the screens ([controls](../game/controls.md)).
- Guards get a "use device" waypoint action and a security operator role ([perception-and-ai](../game/perception-and-ai.md)).
- Saving grows: network, deck and tracer state ([saving](../game/saving.md)).
- Parked: CLI terminal app, deck upgrades, VLANs, gamepad hacking, remote-hacking augmentation, buying exploits, NPCs noticing changed firewall rules, network app on computers ([backlog](../backlog.md)).
