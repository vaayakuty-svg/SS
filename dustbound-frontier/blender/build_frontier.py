"""Dustbound Frontier — ORIGINAL Blender scene and props builder.

How to use:
    1. Launch Blender 4.0+ > Scripting workspace.
    2. Open this file, then press Run Script.
    3. It creates the Western town and saves an editable Dustbound_Frontier.blend,
       as well as a Godot-compatible glTF/GLB in this folder.

Or from a terminal (with Blender installed):
    blender --background --python blender/build_frontier.py

The Godot starter uses separate procedural geometry and does not require these assets.
"""
import bpy
import math
import random
from pathlib import Path

random.seed(2506)
def _script_dir():
    space = getattr(bpy.context, 'space_data', None)
    text = getattr(space, 'text', None)
    if text is not None and text.filepath:
        return Path(bpy.path.abspath(text.filepath)).resolve().parent
    return Path(__file__).resolve().parent


OUT = _script_dir()

# Clean the scene, while keeping the user's other Blender files unaffected.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    principled = m.node_tree.nodes.get('Principled BSDF')
    if principled:
        principled.inputs['Base Color'].default_value = (*color, 1)
        principled.inputs['Roughness'].default_value = 0.85
        principled.inputs['Metallic'].default_value = metallic
    return m


WOOD = mat('Sun-weathered Cedar', (0.36, 0.20, 0.11))
WOOD_LIGHT = mat('Weathered Timber', (0.55, 0.35, 0.18))
WOOD_DARK = mat('Aged Railroad Ties', (0.17, 0.11, 0.08))
DUST = mat('Terracotta Desert Dirt', (0.53, 0.35, 0.23))
STONE = mat('Canyon Stone', (0.36, 0.34, 0.31))
ROOF = mat('Rusted Tin', (0.21, 0.19, 0.18), 0.4)
GLASS = mat('Blue Leaded Glass', (0.11, 0.29, 0.31), 0.1)
LEATHER = mat('Saddle Leather', (0.18, 0.10, 0.07))
CLOTH = mat('Tan Canvas', (0.54, 0.45, 0.32))
HORSE = mat('Chestnut Coat', (0.36, 0.20, 0.12))
IRON = mat('Blacksmith Forged Iron', (0.12, 0.12, 0.12), 0.45)
GOLD = mat('Lettered Sign Gold', (0.93, 0.67, 0.27), 0.05)


def box(name, center, dimensions, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(material)
    if bevel:
        mod = ob.modifiers.new('Subtle edge rounding', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        ob.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
    return ob


def cylinder(name, center, radius, depth, material, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def text_obj(title, location, facing=0.0, size=0.85):
    font = bpy.data.curves.new(title + ' Font', type='FONT')
    font.body = title
    font.size = size
    font.align_x = 'CENTER'
    font.extrude = 0.014
    ob = bpy.data.objects.new(title + ' Sign', font)
    bpy.context.collection.objects.link(ob)
    ob.location = location
    ob.rotation_euler = (math.pi / 2, 0, facing)
    ob.data.materials.append(GOLD)
    return ob


def building(name, x, z, side, width=11.5, height=7.5, depth=11):
    sign = -1 if side < 0 else 1
    box(name + ' walls', (x, 0, height * 0.5), (width, depth, height), WOOD_LIGHT, 0.05)
    box(name + ' tin roof', (x, 0, height + 0.35), (width + 1, depth + 1, 0.7), ROOF)
    facade = x + sign * (width / 2 + 0.12)
    box(name + ' dark door', (facade, 0, 1.55), (0.16, 1.7, 3.1), WOOD_DARK)
    for sidez in [-depth * 0.27, depth * 0.27]:
        box(name + ' shop window', (facade, sidez, 3.3), (0.18, 1.65, 1.8), GLASS)
    porch = x + sign * (width / 2 + 1.75)
    box(name + ' porch', (porch, 0, 0.19), (3.3, depth + 1, 0.36), WOOD)
    box(name + ' porch roof', (porch, 0, 4.60), (3.5, depth + 1, 0.23), WOOD_DARK)
    for zz in [-depth * 0.37, depth * 0.37]:
        cylinder(name + ' porch support', (porch + sign * 1.3, zz, 2.3), 0.14, 4.6, WOOD)
    text_obj(name.upper(), (facade + sign * 0.25, 0, height + 1.12), math.pi / 2 if side < 0 else -math.pi / 2, 0.84)


# Blender Z-up geometry. Godot preview from Blender would use exporter axis conversion.
box('Main street — ground', (0, 0, -0.2), (120, 160, 0.4), DUST)
box('Town road', (0, 0, -0.01), (12, 125, 0.05), WOOD_LIGHT)
for name, xpos, zpos, side, h in [
    ('Dusty Spur Saloon', -18, -22, -1, 9),
    ('Sheriffs Office', 18, -22, 1, 8),
    ('General Store', -18, 5, -1, 7),
    ('First Frontier Bank', 18, 5, 1, 8),
    ('Frontier Hotel', -18, 32, -1, 10),
    ('Livery Stable', 18, 32, 1, 6.2),
]:
    # Swap Y/Z from the logical Godot plan.
    building(name, xpos, zpos, side, 11.6, h, 10.8)

for x in (-35, 35):
    for y in range(-50, 56, 6):
        cylinder('Fence post', (x, y, 1), 0.13, 2, WOOD)
    for z in (0.75, 1.5):
        box('Fence rail', (x, 2, z), (0.2, 110, 0.14), WOOD)

# Tower, wagon, hitching posts, lanterns.
for x in (-2.0, 2.0):
    for y in (-2.0, 2.0):
        cylinder('Water tower support', (33 + x, 24 + y, 4), 0.19, 8, WOOD)
cylinder('Water storage tank', (33, 24, 9.2), 2.9, 3.1, WOOD)
cylinder('Water tank lid', (33, 24, 10.9), 3.2, 0.3, ROOF)

box('Wagon bed', (-4, 25, 1.45), (2.7, 4.5, 0.45), WOOD)
for x in (-5.4, -2.6):
    for y in (23.4, 26.6):
        wheel = cylinder('Iron-rimmed wagon wheel', (x, y, 0.85), 0.7, 0.17, WOOD_DARK, 16)
        wheel.rotation_euler[1] = math.pi / 2
for x in (-7, 7):
    for z in (-35, 7, 39):
        cylinder('Street lantern stand', (x, z, 2.2), 0.1, 4.4, IRON)
        box('Street lantern', (x, z, 4.45), (0.52, 0.52, 0.7), GOLD)

# A stylized, editable horse model with individual meshes.
box('Copper • body', (5, 15, 1.7), (1.0, 2.5, 1.25), HORSE, 0.12)
neck = box('Copper • neck', (5, 13.9, 2.25), (0.65, 0.72, 1.15), HORSE)
neck.rotation_euler[0] = -0.25
box('Copper • muzzle', (5, 13.43, 2.85), (0.58, 0.95, 0.50), HORSE)
for x in (4.65, 5.35):
    for y in (14.2, 15.9):
        box('Copper • leg', (x, y, 0.58), (0.25, 0.30, 1.16), HORSE)
box('Copper • saddle', (5, 15.1, 2.42), (1.2, 1.38, 0.25), LEATHER)

# Camera and light for an attractive immediately viewable scene.
bpy.ops.object.camera_add(location=(77, -79, 70), rotation=(math.radians(62), 0, math.radians(42)))
camera = bpy.context.object
camera.name = 'Frontier cinematic camera'
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type='SUN', location=(0, 0, 50))
sun = bpy.context.object
sun.name = 'Late afternoon sun'
sun.rotation_euler = (math.radians(32), math.radians(-14), math.radians(-18))
sun.data.energy = 2.3
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.samples = 16
bpy.context.scene.render.resolution_x = 1600
bpy.context.scene.render.resolution_y = 900
bpy.context.scene.render.resolution_percentage = 100
if bpy.context.scene.world is None:
    bpy.context.scene.world = bpy.data.worlds.new('Frontier sky')
bpy.context.scene.world.color = (0.35, 0.42, 0.53)

# Save the actual editable Blender scene.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'Dustbound_Frontier.blend'))
# Export only visible mesh/text parts; exclude camera/light from GLB.
try:
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'frontier_blender_assets.glb'), export_format='GLB', export_cameras=False, export_lights=False)
except Exception as exc:
    print('GLB export skipped:', exc)
print('Created original Dustbound Frontier Blender assets:', OUT)
