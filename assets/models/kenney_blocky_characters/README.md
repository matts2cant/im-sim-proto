# Kenney Blocky Characters (subset)

Models from the **Blocky Characters 2.0** pack by Kenney (www.kenney.nl), licensed **CC0 1.0** (public domain, see `License.txt`). Credit is not required; we give it anyway.

Only the files the game uses are copied here (GLB format, with the textures at the relative path the GLBs expect, `Textures/texture-x.png`):

| File | Used as |
|---|---|
| `character-j.glb`, `Textures/texture-j.png` | Guards (`actors/guard/guard.tscn` "Model") |
| `character-d.glb`, `Textures/texture-d.png` | Training dummies (`actors/dummy/training_dummy.tscn` "Model") |

Each model has seven rigid parts animated by node transforms (no skin) and the pack's clips (idle, walk, sprint, die, holding-*, holding-*-shoot, attack-*, ...). The scenes scale it to 0.66 and turn it to face -Z, never edit it; `CharacterAnimator` plays the clips. See [ADR 0103](../../../design/decisions/0103-character-models-and-animation.md).
