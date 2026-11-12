# Kenney Blaster Kit (subset)

Models from the **Blaster Kit 2.1** by Kenney (www.kenney.nl), licensed **CC0 1.0** (public domain, see `License.txt`). Credit is not required; we give it anyway.

Only the files the game uses are copied here (GLB format, with `Textures/colormap.png` at the relative path the GLBs expect):

| File | Used as |
|---|---|
| `blaster-b.glb` | Pistol (`items/weapons/pistol/pistol_model.tscn`) |
| `blaster-m.glb` | Shotgun (`items/weapons/shotgun/shotgun_model.tscn`) |
| `blaster-f.glb` | Sniper rifle (`items/weapons/sniper_rifle/sniper_rifle_model.tscn`) |
| `blaster-p.glb` | Assault rifle (`items/weapons/assault_rifle/assault_rifle_model.tscn`) |
| `blaster-n.glb` | Submachine gun (`items/weapons/smg/smg_model.tscn`) |
| `silencer-small.glb` | The silencer fitted on a weapon's muzzle (`items/attachments/silencer/silencer.tres`) |
| `crate-small.glb` | The silencer's world pickup (`items/attachments/silencer/silencer_pickup.tscn`) |

The models are scaled in the model scenes, never edited. See [ADR 0085](../../../design/decisions/0085-weapons-and-attachments.md).
