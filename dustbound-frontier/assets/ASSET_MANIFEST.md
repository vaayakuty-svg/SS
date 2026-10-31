# Asset manifest — original procedural art

This starter project is self-contained. **No proprietary models, sounds, textures, or Rockstar assets are included.**

- Player outlaw, horse Copper, NPCs, sheriff and outlaws: primitive Godot meshes, assembled in GDScript.
- Town buildings, fences, lighting posts, water tower, well, railroad, mine and bandit camp: built by `scripts/world.gd`.
- Wilderness: terrain chunks generated using FastNoiseLite, with rocks, trees, cacti and trimesh collisions.
- Sky/fog, sunlight and rain: built using Godot environment and particle nodes.
- HUD/minimap: vector controls generated inside Godot.
- Audio: not included in this prototype. Add original/appropriately licensed sound effects in a later milestone.
- Animations: simple procedural walking bob and horse leg motion; realistic rigged animation is future work.
- Optional `blender/build_frontier.py`: run from Blender to create original editable town props and save `.blend`, plus an exported `.glb` collection for a future asset swap. Not required to run the game.
