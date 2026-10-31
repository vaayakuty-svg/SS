# Validation report

## Review and fixes (second pass)

Every GDScript file was read line by line against the Godot 4.3 API, and these bugs were fixed:

| File | Problem | Effect in the game | Fix |
| --- | --- | --- | --- |
| `scripts/world.gd` | Terrain triangles were wound counter-clockwise. Godot treats clockwise triangles as the front face. | The ground was invisible from above, lit from underneath, and its one-sided collision let the player and the horse fall through the world. | Triangles now use clockwise order (`a, c, b, c, d, b`). |
| `scripts/minimap.gd` | Read `player_ref.y`, a property the player does not have. | A script error every frame, and the minimap's direction line was never drawn. | Uses `player_ref.yaw`. |
| `scripts/player.gd` | Called `append()` on `query.exclude`, which returns a copy. | While riding, shots and the camera ray hit your own horse. | Builds the exclusion list first, then assigns it. |
| `scripts/player.gd` | Hid the outlaw model when mounted. | The horse looked riderless. | The rider stays visible in the saddle and turns with the horse. |
| `scripts/horse.gd` | A local variable named `tan` shadowed the built-in `tan()`. | An editor warning. | Renamed to `tan_coat`. |
| `scripts/game.gd` | `closest` was typed `Node3D` but read the NPC script's `display_name`. | An unsafe-access warning. | Left untyped. |
| `project.godot` | No engine version declared. | Godot asks to convert the project when it is imported. | Declares Godot 4.3 with the Compatibility renderer. |
| `blender/build_frontier.py` | Saved next to `__file__`, which is only the text block's name when run from Blender's Text Editor. | The `.blend` and `.glb` were saved to whichever folder Blender was started from. | Uses the text block's file path when there is one. A missing world is also created. |
| `blender/make_preview_glb.py` | No materials, so viewers used glTF's default fully metallic material. Cylinders were built along Z. | The town preview rendered almost black, and posts, lamps, fences, cacti and the water tower lay on their sides. | Adds one matte vertex-colour material and stands cylinders up along Y. `assets/frontier_town_preview.glb` was regenerated. |

## Checks completed

- All `res://` paths referenced by the scripts exist.
- Both Blender scripts compile with Python 3.
- `make_preview_glb.py` was run with trimesh, and the new `frontier_town_preview.glb` (194 meshes, 110 × 145 m) was loaded in a glTF viewer and rendered to `docs/town-preview.png`.

## Checks still not done

- Running the game in Godot. The engine could not be installed in the environment where these fixes were made, so the first run in the Godot editor is still the real test. If the Output or Debugger panel shows an error, note the file and line number for a follow-up fix.
- Running `build_frontier.py` inside Blender, and exporting a Windows `.exe`.
