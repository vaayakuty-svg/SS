extends RefCounted
## Primitive geometry building blocks, no proprietary or downloaded assets.

static var material_cache: Dictionary = {}

static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var key: String = color.to_html() + "_" + str(metallic)
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.88
    mat.metallic = metallic
    mat.cull_mode = BaseMaterial3D.CULL_BACK
    material_cache[key] = mat
    return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> Node3D:
    var holder := Node3D.new()
    holder.position = pos
    parent.add_child(holder)
    var mesh := BoxMesh.new()
    mesh.size = size
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material(color)
    holder.add_child(visual)
    if solid:
        var body := StaticBody3D.new()
        holder.add_child(body)
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        body.add_child(col)
    return holder

static func cylinder(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color, solid: bool = false) -> Node3D:
    var holder := Node3D.new()
    holder.position = pos
    parent.add_child(holder)
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 8
    var vis := MeshInstance3D.new()
    vis.mesh = mesh
    vis.material_override = material(color)
    holder.add_child(vis)
    if solid:
        var body := StaticBody3D.new()
        holder.add_child(body)
        var col := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = length
        col.shape = shape
        body.add_child(col)
    return holder

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> Node3D:
    var holder := Node3D.new()
    holder.position = pos
    parent.add_child(holder)
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 10
    mesh.rings = 5
    var vis := MeshInstance3D.new()
    vis.mesh = mesh
    vis.material_override = material(color)
    holder.add_child(vis)
    return holder

static func label3d(parent: Node3D, pos: Vector3, words: String, font_size: int = 44) -> Label3D:
    var label := Label3D.new()
    label.text = words
    label.font_size = font_size
    label.pixel_size = 0.008
    label.modulate = Color(1.0, 0.89, 0.66)
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = pos
    parent.add_child(label)
    return label
