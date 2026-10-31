extends Node3D
## Frontier environment: streaming terrain, hand-assembled town and bandit camp.
const Kit = preload("res://scripts/geometry_kit.gd")
const CHUNK_SIZE := 64
const CHUNK_RADIUS := 2
const TERRAIN_STEPS := 12

var noise := FastNoiseLite.new()
var chunks: Dictionary = {}
var last_chunk := Vector2i(999, 999)
var terrain_root: Node3D
var town_root: Node3D
var sun: DirectionalLight3D
var sky_environment: Environment
var rain: CPUParticles3D
var weather := "CLEAR"
var clock_minutes := 8.0 * 60.0
var low_detail := true
var camp_center := Vector3(105, 0, -95)

func _ready() -> void:
    noise.seed = 198713
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.0075
    terrain_root = Node3D.new()
    terrain_root.name = "StreamingTerrain"
    add_child(terrain_root)
    town_root = Node3D.new()
    town_root.name = "TownAndLandmarks"
    add_child(town_root)
    _make_sky()
    _build_town()
    _build_bandit_camp()
    _build_landmarks()
    update_streaming(Vector3.ZERO)

func height_at(x: float, z: float) -> float:
    var distance := Vector2(x, z).length()
    var blend: float = smoothstep(48.0, 112.0, distance)
    return noise.get_noise_2d(x, z) * 8.0 * blend

func ground_point(x: float, z: float) -> Vector3:
    return Vector3(x, height_at(x, z), z)

func update_streaming(point: Vector3) -> void:
    var center := Vector2i(floori(point.x / float(CHUNK_SIZE)), floori(point.z / float(CHUNK_SIZE)))
    if center == last_chunk:
        return
    last_chunk = center
    var wanted: Dictionary = {}
    for ix in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
        for iz in range(center.y - CHUNK_RADIUS, center.y + CHUNK_RADIUS + 1):
            var index := Vector2i(ix, iz)
            wanted[index] = true
            if not chunks.has(index):
                chunks[index] = _make_chunk(ix, iz)
    for old in chunks.keys():
        if not wanted.has(old):
            var chunk: Node3D = chunks[old]
            chunk.queue_free()
            chunks.erase(old)

func _make_chunk(cx: int, cz: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Terrain_%d_%d" % [cx, cz]
    terrain_root.add_child(root)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var step: float = float(CHUNK_SIZE) / float(TERRAIN_STEPS)
    for i in range(TERRAIN_STEPS):
        for j in range(TERRAIN_STEPS):
            var x: float = float(cx * CHUNK_SIZE) + float(i) * step
            var z: float = float(cz * CHUNK_SIZE) + float(j) * step
            var a := ground_point(x, z)
            var b := ground_point(x, z + step)
            var c := ground_point(x + step, z)
            var d := ground_point(x + step, z + step)
            for p in [a, c, b, c, d, b]: # clockwise = front face in Godot
                var shade: float = clampf((p.y + 6.0) / 20.0, 0.0, 1.0)
                st.set_color(Color(0.49, 0.38, 0.24).lerp(Color(0.37, 0.43, 0.25), shade))
                st.add_vertex(p)
    st.generate_normals()
    var mesh: ArrayMesh = st.commit()
    var paint := StandardMaterial3D.new()
    paint.vertex_color_use_as_albedo = true
    paint.roughness = 1.0
    var visible_mesh := MeshInstance3D.new()
    visible_mesh.mesh = mesh
    visible_mesh.material_override = paint
    root.add_child(visible_mesh)
    var static_body := StaticBody3D.new()
    root.add_child(static_body)
    var col := CollisionShape3D.new()
    col.shape = mesh.create_trimesh_shape()
    static_body.add_child(col)
    _scatter_props(root, cx, cz)
    return root

func _scatter_props(parent: Node3D, cx: int, cz: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(cx * 73856093 ^ cz * 19349663) + 17
    for k in range(10):
        var x: float = float(cx * CHUNK_SIZE) + rng.randf_range(2.0, float(CHUNK_SIZE) - 2.0)
        var z: float = float(cz * CHUNK_SIZE) + rng.randf_range(2.0, float(CHUNK_SIZE) - 2.0)
        if Vector2(x, z).length() < 66.0 or Vector2(x - 105.0, z + 95.0).length() < 27.0:
            continue
        var p := ground_point(x, z)
        var choice := rng.randi_range(0, 7)
        if choice <= 2:
            _tree(parent, p, rng.randf_range(0.8, 1.5))
        elif choice <= 5:
            _cactus(parent, p, rng.randf_range(0.7, 1.4))
        else:
            var rock := Kit.box(parent, p + Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 1.4), Color(0.42, 0.40, 0.37))
            rock.rotation.y = rng.randf_range(0, TAU)

func _tree(parent: Node3D, p: Vector3, size: float) -> void:
    var trunk := Kit.cylinder(parent, p + Vector3(0, 2.0 * size, 0), 0.27 * size, 4.0 * size, Color(0.28, 0.19, 0.12))
    trunk.rotation.y = 0.0
    var leaves := Kit.sphere(parent, p + Vector3(0, 4.2 * size, 0), 1.55 * size, Color(0.22, 0.31, 0.17))
    leaves.scale = Vector3(1.2, 1.5, 1.1)

func _cactus(parent: Node3D, p: Vector3, size: float) -> void:
    var green := Color(0.22, 0.34, 0.22)
    Kit.cylinder(parent, p + Vector3(0, 1.35 * size, 0), 0.28 * size, 2.7 * size, green)
    Kit.cylinder(parent, p + Vector3(0.55 * size, 1.5 * size, 0), 0.17 * size, 1.05 * size, green)
    Kit.cylinder(parent, p + Vector3(-0.52 * size, 1.85 * size, 0), 0.17 * size, 0.85 * size, green)

func _make_sky() -> void:
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.22, 0.39, 0.58)
    sky_material.sky_horizon_color = Color(0.81, 0.64, 0.44)
    sky_material.ground_horizon_color = Color(0.66, 0.52, 0.33)
    var sky := Sky.new()
    sky.sky_material = sky_material
    sky_environment = Environment.new()
    sky_environment.background_mode = Environment.BG_SKY
    sky_environment.sky = sky
    sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    sky_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    sky_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    sky_environment.fog_enabled = true
    sky_environment.fog_density = 0.004
    sky_environment.fog_light_color = Color(0.80, 0.65, 0.48)
    var env_node := WorldEnvironment.new()
    env_node.environment = sky_environment
    add_child(env_node)
    sun = DirectionalLight3D.new()
    sun.name = "DesertSun"
    sun.rotation_degrees = Vector3(-42, -35, 0)
    sun.light_color = Color(1.0, 0.84, 0.63)
    sun.light_energy = 1.25
    sun.shadow_enabled = false # Toggle on High quality via graphics menu.
    add_child(sun)
    rain = CPUParticles3D.new()
    rain.name = "LightRain"
    rain.emitting = false
    rain.amount = 90
    rain.lifetime = 1.1
    rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain.emission_box_extents = Vector3(20, 1, 20)
    rain.direction = Vector3(0, -1, 0)
    rain.gravity = Vector3(0, -10, 0)
    rain.initial_velocity_min = 12.0
    rain.initial_velocity_max = 18.0
    var drop_mesh := SphereMesh.new()
    drop_mesh.radius = 0.015
    drop_mesh.height = 0.25
    drop_mesh.radial_segments = 4
    drop_mesh.rings = 2
    rain.mesh = drop_mesh
    add_child(rain)

func advance_environment(delta: float, focus: Vector3) -> void:
    clock_minutes = fmod(clock_minutes + delta * 2.0, 1440.0) # 12 min per in-game day.
    var phase: float = clock_minutes / 1440.0 * TAU
    var daylight: float = clampf(sin(phase - PI * 0.5), -0.4, 1.0)
    sun.rotation_degrees.x = -10.0 - daylight * 66.0
    sun.light_energy = 0.1 + maxf(0.0, daylight) * 1.15
    sky_environment.ambient_light_energy = 0.42 + maxf(0.0, daylight) * 0.58
    if is_instance_valid(rain):
        rain.global_position = focus + Vector3(0, 13, 0)

func set_weather(next: String) -> void:
    weather = next
    rain.emitting = weather == "RAIN"
    sky_environment.fog_density = 0.013 if weather == "FOG" else (0.007 if weather == "RAIN" else 0.004)
    if weather == "RAIN":
        sun.light_energy *= 0.6

func _build_town() -> void:
    # Flat walkable dirt street, railway, buildings, porches and town props.
    Kit.box(town_root, Vector3(0, 0.025, 0), Vector3(11, 0.045, 115), Color(0.62, 0.48, 0.31))
    for z in range(-52, 56, 8):
        Kit.box(town_root, Vector3(0, 0.055, float(z)), Vector3(7.5, 0.05, 0.17), Color(0.52, 0.39, 0.27))
    _building(Vector3(-16, 0, -19), "THE DUSTY SPUR", Color(0.44, 0.25, 0.16), 14.0, 12.0, 9.0)
    _building(Vector3(16, 0, -19), "SHERIFF", Color(0.57, 0.45, 0.27), 12.0, 11.0, 8.0)
    _building(Vector3(-16, 0, 7), "GENERAL STORE", Color(0.53, 0.34, 0.20), 14.0, 11.0, 7.0)
    _building(Vector3(16, 0, 7), "BANK", Color(0.51, 0.44, 0.37), 11.5, 11.0, 8.0)
    _building(Vector3(-17, 0, 34), "HOTEL", Color(0.47, 0.30, 0.24), 13.5, 12.0, 10.0)
    _building(Vector3(17, 0, 34), "LIVERY", Color(0.38, 0.32, 0.24), 15.0, 12.0, 6.5)
    _well(Vector3(2.5, 0, 23))
    _water_tower(Vector3(31, 0, 27))
    for i in range(4):
        _fence_line(Vector3(-33, 0, -40 + i * 3), 6)
    for z in [-43.0, -7.0, 19.0, 45.0]:
        _lamp(Vector3(6, 0, z))
        _lamp(Vector3(-6, 0, z))
    Kit.label3d(town_root, Vector3(0, 6.4, 54), "DUSTBOUND FRONTIER", 54)

func _building(pos: Vector3, title: String, wall: Color, width: float, depth: float, height: float) -> void:
    var b := Node3D.new()
    b.name = title
    b.position = pos
    town_root.add_child(b)
    Kit.box(b, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), wall, true)
    var dark := Color(0.18, 0.13, 0.11)
    Kit.box(b, Vector3(0, height + 0.35, 0), Vector3(width + 1.5, 0.7, depth + 1.0), dark)
    var road_sign: float = 1.0 if pos.x < 0 else -1.0
    var frontage_x: float = road_sign * (width / 2.0 + 2.0)
    Kit.box(b, Vector3(frontage_x, 0.25, 0), Vector3(3.0, 0.5, depth + 2.0), Color(0.40, 0.26, 0.16))
    Kit.box(b, Vector3(frontage_x, 4.4, 0), Vector3(3.5, 0.3, depth + 2.0), Color(0.31, 0.20, 0.13))
    for z in [-depth * 0.35, depth * 0.35]:
        Kit.cylinder(b, Vector3(frontage_x + road_sign * 1.2, 2.25, z), 0.16, 4.5, Color(0.28, 0.18, 0.12))
    # Doors and windows appear on the facade facing the street.
    var facade_x: float = road_sign * (width / 2.0 + 0.06)
    Kit.box(b, Vector3(facade_x, 1.5, 0), Vector3(0.17, 3.0, 1.7), dark)
    for z in [-depth * 0.3, depth * 0.3]:
        Kit.box(b, Vector3(facade_x, 3.5, z), Vector3(0.18, 2.0, 1.5), Color(0.19, 0.32, 0.35))
        Kit.box(b, Vector3(facade_x + road_sign * 0.15, 3.5, z), Vector3(0.15, 0.12, 1.8), Color(0.18, 0.12, 0.08))
    Kit.label3d(b, Vector3(frontage_x, height + 1.4, 0), title, 43)
    for row in range(4):
        Kit.box(b, Vector3(0, height * 0.25 * float(row), depth * 0.5 + 0.02), Vector3(width, 0.12, 0.1), Color(0.35, 0.23, 0.16))

func _well(pos: Vector3) -> void:
    var w := Node3D.new()
    w.position = pos
    town_root.add_child(w)
    Kit.cylinder(w, Vector3(0, 0.55, 0), 1.25, 1.1, Color(0.39, 0.37, 0.33), true)
    Kit.cylinder(w, Vector3(-1.0, 1.7, 0), 0.12, 3.4, Color(0.38, 0.22, 0.15))
    Kit.cylinder(w, Vector3(1.0, 1.7, 0), 0.12, 3.4, Color(0.38, 0.22, 0.15))
    Kit.box(w, Vector3(0, 3.3, 0), Vector3(2.7, 0.35, 2.5), Color(0.28, 0.19, 0.12))

func _water_tower(pos: Vector3) -> void:
    var tower := Node3D.new()
    tower.position = pos
    town_root.add_child(tower)
    for x in [-2.0, 2.0]:
        for z in [-2.0, 2.0]:
            Kit.cylinder(tower, Vector3(x, 4.1, z), 0.2, 8.2, Color(0.39, 0.24, 0.14))
    Kit.cylinder(tower, Vector3(0, 9.2, 0), 3.0, 3.4, Color(0.41, 0.28, 0.18))
    Kit.cylinder(tower, Vector3(0, 11.0, 0), 3.4, 0.32, Color(0.21, 0.16, 0.14))

func _fence_line(pos: Vector3, count: int) -> void:
    for i in range(count):
        var x: float = pos.x + float(i) * 2.4
        Kit.box(town_root, Vector3(x, 1.0, pos.z), Vector3(0.17, 2.0, 0.18), Color(0.36, 0.24, 0.13))
    Kit.box(town_root, pos + Vector3(float(count - 1) * 1.2, 1.45, 0), Vector3(float(count - 1) * 2.4, 0.15, 0.16), Color(0.36, 0.24, 0.13))

func _lamp(pos: Vector3) -> void:
    Kit.cylinder(town_root, pos + Vector3(0, 2.1, 0), 0.13, 4.2, Color(0.17, 0.17, 0.16))
    Kit.box(town_root, pos + Vector3(0, 4.4, 0), Vector3(0.6, 0.8, 0.6), Color(0.93, 0.67, 0.25))

func _build_bandit_camp() -> void:
    camp_center.y = height_at(camp_center.x, camp_center.z)
    var b := Node3D.new()
    b.name = "CoyoteRidgeBanditCamp"
    b.position = camp_center
    town_root.add_child(b)
    Kit.cylinder(b, Vector3(0, 0.4, 0), 1.1, 0.8, Color(0.20, 0.19, 0.16))
    Kit.sphere(b, Vector3(0, 1.0, 0), 0.45, Color(1.0, 0.37, 0.07))
    for k in range(3):
        var theta: float = float(k) * TAU / 3.0
        var t := Vector3(cos(theta) * 8.0, 0, sin(theta) * 8.0)
        Kit.box(b, t + Vector3(0, 0.9, 0), Vector3(3.8, 1.8, 4.3), Color(0.42, 0.35, 0.22))
        Kit.box(b, t + Vector3(0, 1.9, 0), Vector3(4.5, 0.23, 5.0), Color(0.33, 0.27, 0.19))
    Kit.label3d(b, Vector3(0, 5.4, 0), "COYOTE RIDGE  /  OUTLAW CAMP", 42)
    for k in range(4):
        Kit.cylinder(b, Vector3(float(k) * 3.0 - 6.0, 0.65, -14), 0.48, 1.3, Color(0.34, 0.22, 0.14))

func _build_landmarks() -> void:
    # Frontier rail line and the old mine mark exploratory locations.
    for z in range(-180, 181, 3):
        var p := ground_point(-57.0, float(z))
        Kit.box(town_root, p + Vector3(0, 0.11, 0), Vector3(5.0, 0.2, 0.25), Color(0.25, 0.18, 0.13))
    for x in [-58.1, -55.9]:
        Kit.box(town_root, Vector3(x, 0.17, 0), Vector3(0.17, 0.13, 105), Color(0.33, 0.33, 0.33))
    var mine := ground_point(68.0, 61.0)
    Kit.box(town_root, mine + Vector3(0, 3.0, 0), Vector3(8, 6, 3), Color(0.26, 0.22, 0.19))
    Kit.box(town_root, mine + Vector3(0, 2.0, 1.57), Vector3(3, 4.0, 0.1), Color(0.06, 0.06, 0.06))
    Kit.label3d(town_root, mine + Vector3(0, 8, 0), "ABANDONED MINE", 36)
