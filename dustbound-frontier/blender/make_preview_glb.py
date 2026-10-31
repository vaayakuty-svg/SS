"""Make a self-contained original Blender-importable .glb preview using trimesh.
Run with Python 3 and trimesh, no installed Blender needed.
"""
from pathlib import Path
import math
import numpy as np
import trimesh

out = Path(__file__).resolve().parents[1] / 'assets' / 'frontier_town_preview.glb'
scene = trimesh.Scene()
counts = {}

def cube(label, center, size, color):
    obj = trimesh.creation.box(extents=size)
    obj.apply_translation(center)
    obj.visual.face_colors = list(color) + [255]
    counts[label] = counts.get(label,0)+1
    scene.add_geometry(obj, geom_name=f'{label}_{counts[label]}', node_name=f'{label}_{counts[label]}')

def cyl(label, center, radius, height, color, sections=10):
    obj = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    # trimesh builds cylinders along Z; stand them up along glTF's Y (up) axis.
    obj.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, (1, 0, 0)))
    obj.apply_translation(center)
    obj.visual.face_colors = list(color) + [255]
    counts[label] = counts.get(label,0)+1
    scene.add_geometry(obj, geom_name=f'{label}_{counts[label]}', node_name=f'{label}_{counts[label]}')

soil=(132,96,64)
plank=(105,61,37)
wood=(135,92,55)
roof=(65,52,42)
glass=(40,89,93)
stone=(91,85,75)
metal=(42,40,36)
gold=(218,157,70)

cube('Desert Ground', (0,-0.2,0), (110,.4,145), soil)
cube('Main Street', (0,0.04,0), (11,.06,109), (152,109,70))

def building(title, x, z, height, width=12, depth=11, tint=wood):
    side=1 if x<0 else -1
    cube(f'{title} Walls',(x,height/2,z),(width,height,depth),tint)
    cube(f'{title} Roof',(x,height+.32,z),(width+1,.64,depth+1),roof)
    porch_x=x+side*(width/2+1.75)
    cube(f'{title} Porch',(porch_x,.23,z),(3.5,.45,depth+1),plank)
    cube(f'{title} Awning',(porch_x,4.35,z),(3.5,.28,depth+1),roof)
    for zp in [-depth*.35,depth*.35]:
        cyl(f'{title} Awning Post',(porch_x+side*1.25,2.18,z+zp),.14,4.35,plank)
        cube(f'{title} Window',(x+side*(width/2+.09),3.25,z+zp),(.16,1.9,1.6),glass)
    cube(f'{title} Door',(x+side*(width/2+.12),1.4,z),(.20,2.8,1.7),metal)
    cube(f'{title} Sign Board',(porch_x,height+.9,z),(0.45,1.2,depth*.8),plank)
    for y in range(4):
        cube(f'{title} Wall Planking',(x,(y+1)*height/5,z+depth/2+.03),(width,.09,.09),plank)

for name,x,z,h,w,d,color in [
    ('Saloon',-17,-20,9,14,12,(116,69,45)),
    ('Sheriff',17,-20,8,12,11,(137,110,72)),
    ('General Store',-17,6,7,14,11,(123,78,50)),
    ('Bank',17,6,8,11,11,(133,114,100)),
    ('Hotel',-17,32,10,14,12,(119,82,66)),
    ('Livery',17,32,7,15,12,(102,82,59)),
]:
    building(name,x,z,h,w,d,color)

for x in [-33,33]:
    for z in range(-51,52,6):
        cyl('Ranch Fence Post',(x,1,z),.13,2,plank)
    for height in [.8,1.4]:
        cube('Ranch Fence Rails',(x,height,0),(.15,.12,105),plank)

for x in [-7,7]:
    for z in [-42,-12,18,48]:
        cyl('Street Lamp Iron Pole',(x,2.1,z),.09,4.2,metal)
        cube('Street Lamp Glass',(x,4.5,z),(.55,.8,.55),gold)

for x in [28,32]:
    for z in [22,26]:
        cyl('Water Tower Support',(x,4,z),.19,8,plank)
cyl('Water Tower Tank',(30,9.2,24),2.85,3.5,wood,14)
cyl('Water Tower Cap',(30,11.1,24),3.1,.3,roof,14)

# Wagon, 4 wheels (cylinders axes: along z; rotate to axle x)
cube('Wagon Wooden Frame',(-4,1.4,23),(2.8,.42,4.7),plank)
for x in [-5.5,-2.5]:
    for z in [21.6,24.6]:
        wheel=trimesh.creation.annulus(r_min=.35,r_max=.7,height=.23,sections=20)
        wheel.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,(0,1,0)))
        wheel.apply_translation((x,.75,z))
        wheel.visual.face_colors=list(metal)+[255]
        counts['Wagon Wheel']=counts.get('Wagon Wheel',0)+1
        scene.add_geometry(wheel,geom_name=f'Wagon Wheel {counts["Wagon Wheel"]}')

# Wells, cacti, loose rocks around the scene.
cyl('Town Well Stone',(0,.6,26),1.25,1.2,stone)
for i in range(42):
    xx=((i*37)%102)-51
    zz=((i*61)%136)-68
    if abs(xx)<35 and abs(zz)<53:
        continue
    if i%3==0:
        cyl('Cactus Stem',(xx,1.1,zz),.27,2.2,(47,84,53),8)
        cyl('Cactus Arm',(xx+.48,1.45,zz),.14,.7,(47,84,53),8)
    else:
        cube('Sandstone Boulder',(xx,.3,zz),(1.5,.6,1.2),stone)

# Simple horse in the center foreground.
cube('Copper Horse Torso',(5,1.6,14),(1.0,1.3,2.4),(100,56,32))
cube('Copper Horse Neck',(5,2.25,12.94),(.7,1.3,.65),(116,65,35))
cube('Copper Horse Head',(5,2.78,12.52),(.58,.65,.86),(100,56,32))
for x in [4.63,5.37]:
    for z in [13.2,14.8]:
        cube('Copper Horse Leg',(x,.6,z),(.25,1.2,.3),(100,56,32))
cube('Copper Saddle',(5,2.36,14), (1.18,.19,1.3),(45,32,25))

def add_matte_material(glb: bytes) -> bytes:
    """Give every primitive one non-metallic material. Without it, glTF's default
    material is fully metallic and the town renders almost black in most viewers."""
    import json, struct
    length = struct.unpack('<I', glb[12:16])[0]
    doc = json.loads(glb[20:20 + length])
    doc['materials'] = [{'name': 'Frontier vertex colour', 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.0, 'roughnessFactor': 0.9}}]
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            prim['material'] = 0
    text = json.dumps(doc, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    rest = glb[20 + length:]
    body = struct.pack('<I', len(text)) + b'JSON' + text + rest
    return b'glTF' + struct.pack('<II', 2, 12 + len(body)) + body


out.write_bytes(add_matte_material(scene.export(file_type='glb')))
print('Wrote:',out,'size KB:',out.stat().st_size/1024,'unique named parts',len(scene.geometry))
