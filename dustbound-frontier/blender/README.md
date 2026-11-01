# Open the 3D models in Blender

The archive includes a ready-made **`assets/frontier_town_preview.glb`**, which you can immediately inspect in Blender: **File → Import → glTF 2.0 (.glb/.gltf)**.

For a fully editable **.blend project**, open `blender/build_frontier.py` inside Blender's **Scripting** workspace and choose **Run Script**. It will create:

- `blender/Dustbound_Frontier.blend` — original town, props, horse preview, camera and lighting;
- `blender/frontier_blender_assets.glb` — GLB export of that scene.

You can also run `blender --background --python blender/build_frontier.py` from the project root with Blender installed and available on PATH.

These Blender models are an *optional visual asset workflow*. The Godot prototype already renders a similar Western environment using original generated meshes and starts without external files.
