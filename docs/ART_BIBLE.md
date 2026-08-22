# Art Bible — Demo 0.2.0

## Direction

`Mage Prototype` uses a readable stylized low-poly look: large silhouettes,
faceted surfaces, matte stone and concentrated emissive magic. The third-person
camera must keep silhouettes readable at exploration distance while supporting
closer views of characters, structures and concentrated spell effects.

## Palette

- Player: violet robes, warm skin, gold focus, bright arcane purple.
- Shadow Chaser: near-black plum body with a crimson core.
- Ember Cultist: dark red robes, bone mask and orange-red magic.
- Arena: desaturated blue stone, muted violet edges and purple runes.
- Friendly effects: violet/blue. Hostile effects: red/orange.

## Asset contract

- Blender and Godot use metric scale; character feet sit at local ground level.
- Blender is Z-up; glTF/GLB is the only runtime 3D interchange format.
- Gameplay collisions remain authored as primitive Godot shapes.
- Imported models contain visuals only and never own gameplay scripts.
- Source: `assets/source/mage_prototype_p0.blend`.
- Rebuild: `tools/assets/build_p0_asset_kit.ps1`.
- `.blend` and `.glb` files are stored through Git LFS.

## Performance limits

- One material palette per role; no runtime material duplication for normal state.
- No skeletal modifiers or transparent layered surfaces in the P0 kit.
- Character motion is applied to one `ModelRoot`, keeping imported meshes static.
- Lighting uses one shadowed directional light; small magic lights cast no shadows.
