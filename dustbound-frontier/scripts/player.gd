extends CharacterBody3D
## Controllable third-person outlaw. Player/camera/weapon are fully procedural.
signal shot_fired(target: Object, impact: Vector3)
signal defeated

const Kit = preload("res://scripts/geometry_kit.gd")
const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_SPEED := 8.0
const GRAVITY := 22.0

var health := 100.0
var stamina := 100.0
var money := 25
var honor := 0
var ammo := 6
var reserve_ammo := 42
var reload_timer := 0.0
var fire_timer := 0.0
var roll_timer := 0.0
var mounted := false
var horse_ref: CharacterBody3D
var yaw := 0.0
var pitch := -0.13
var camera_distance := 5.6
var body_visual: Node3D
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var camera: Camera3D
var aim_active := false
var reload_duration := 1.6
var camera_collision_distance := 5.6

func _ready() -> void:
    name = "OutlawPlayer"
    collision_layer = 1
    collision_mask = 1
    floor_snap_length = 0.35
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.40
    shape.height = 1.85
    col.shape = shape
    col.position = Vector3(0, 0.97, 0)
    add_child(col)
    body_visual = Node3D.new()
    body_visual.name = "OutlawVisual"
    add_child(body_visual)
    _create_outlaw_model()
    yaw_pivot = Node3D.new()
    yaw_pivot.position = Vector3(0, 1.72, 0)
    add_child(yaw_pivot)
    pitch_pivot = Node3D.new()
    yaw_pivot.add_child(pitch_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.0, camera_distance)
    camera.fov = 73.0
    camera.current = true
    camera.near = 0.10
    pitch_pivot.add_child(camera)

func _create_outlaw_model() -> void:
    Kit.box(body_visual, Vector3(0, 1.15, 0), Vector3(0.73, 0.90, 0.38), Color(0.25, 0.19, 0.15))
    Kit.box(body_visual, Vector3(0, 0.82, -0.02), Vector3(0.79, 0.16, 0.44), Color(0.13, 0.10, 0.08))
    Kit.sphere(body_visual, Vector3(0, 1.85, 0), 0.27, Color(0.68, 0.48, 0.32))
    Kit.cylinder(body_visual, Vector3(0, 2.11, 0), 0.36, 0.3, Color(0.19, 0.14, 0.11))
    Kit.cylinder(body_visual, Vector3(0, 2.0, 0), 0.54, 0.08, Color(0.19, 0.14, 0.11))
    for side in [-1.0, 1.0]:
        Kit.box(body_visual, Vector3(side * 0.22, 0.38, 0), Vector3(0.28, 0.74, 0.32), Color(0.29, 0.25, 0.22))
        Kit.box(body_visual, Vector3(side * 0.22, 0.11, -0.09), Vector3(0.32, 0.23, 0.54), Color(0.19, 0.15, 0.12))
        Kit.box(body_visual, Vector3(side * 0.49, 1.20, 0), Vector3(0.25, 0.82, 0.27), Color(0.24, 0.18, 0.15))
    var revolver := Kit.box(body_visual, Vector3(0.54, 0.98, -0.28), Vector3(0.11, 0.16, 0.48), Color(0.20, 0.21, 0.22))
    revolver.rotation.x = 0.18
    Kit.box(body_visual, Vector3(0, 1.39, -0.225), Vector3(0.71, 0.17, 0.10), Color(0.54, 0.24, 0.15))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.0026
        pitch = clampf(pitch - event.relative.y * 0.0026, -1.05, 0.68)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(2.0, camera_distance - 0.35)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(8.0, camera_distance + 0.35)

func _physics_process(delta: float) -> void:
    fire_timer = maxf(0.0, fire_timer - delta)
    if reload_timer > 0.0:
        reload_timer -= delta
        if reload_timer <= 0.0:
            var to_load: int = mini(6 - ammo, reserve_ammo)
            ammo += to_load
            reserve_ammo -= to_load
    aim_active = Input.is_action_pressed("aim")
    yaw_pivot.rotation.y = yaw
    pitch_pivot.rotation.x = pitch
    camera.fov = lerpf(camera.fov, 52.0 if aim_active else 73.0, minf(delta * 9.0, 1.0))
    camera.position.x = lerpf(camera.position.x, 0.62 if aim_active else 0.0, minf(delta * 8.0, 1.0))
    if mounted and is_instance_valid(horse_ref):
        global_position = horse_ref.global_position + Vector3(0, 1.12, 0)
        velocity = Vector3.ZERO
        body_visual.rotation.y = horse_ref.rotation.y
    else:
        _walking(delta)
    if Input.is_action_just_pressed("reload"):
        reload_weapon()
    if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _shoot()
    _update_camera_collision(delta)

func _walking(delta: float) -> void:
    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, yaw)
    var sprinting: bool = Input.is_action_pressed("sprint") and stamina > 1.0 and not Input.is_action_pressed("crouch")
    var speed: float = 2.5 if Input.is_action_pressed("crouch") else (SPRINT_SPEED if sprinting else WALK_SPEED)
    if roll_timer > 0.0:
        roll_timer -= delta
        speed = 13.0
    elif Input.is_action_just_pressed("roll") and direction.length_squared() > 0.01 and is_on_floor():
        roll_timer = 0.38
        speed = 13.0
    if sprinting and direction.length_squared() > 0.01:
        stamina = maxf(0.0, stamina - delta * 13.0)
    else:
        stamina = minf(100.0, stamina + delta * 9.0)
    velocity.x = move_toward(velocity.x, direction.x * speed, delta * 32.0)
    velocity.z = move_toward(velocity.z, direction.z * speed, delta * 32.0)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_SPEED
    else:
        velocity.y = -0.5
    if direction.length_squared() > 0.05:
        body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(-direction.x, -direction.z), delta * 11.0)
    move_and_slide()

func _update_camera_collision(delta: float) -> void:
    var origin: Vector3 = pitch_pivot.global_position
    var desired: Vector3 = pitch_pivot.to_global(Vector3(camera.position.x, 0, camera_distance))
    var query := PhysicsRayQueryParameters3D.create(origin, desired)
    query.exclude = _ray_exclusions()
    var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    var allowed: float = camera_distance
    if not obstruction.is_empty():
        allowed = maxf(1.0, origin.distance_to(obstruction["position"]) - 0.2)
    camera_collision_distance = lerpf(camera_collision_distance, allowed, minf(1.0, delta * 15.0))
    camera.position.z = camera_collision_distance

func _shoot() -> void:
    if fire_timer > 0.0 or reload_timer > 0.0:
        return
    if ammo <= 0:
        reload_weapon()
        return
    ammo -= 1
    fire_timer = 0.35
    var from: Vector3 = camera.global_position
    var center: Vector3 = -camera.global_transform.basis.z
    var scatter: float = 0.006 if aim_active else 0.024
    var direction := (center + camera.global_transform.basis.x * randf_range(-scatter, scatter) + camera.global_transform.basis.y * randf_range(-scatter, scatter)).normalized()
    var query := PhysicsRayQueryParameters3D.create(from, from + direction * 135.0)
    query.exclude = _ray_exclusions()
    var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    var target: Object = null
    var impact: Vector3 = from + direction * 135.0
    if not result.is_empty():
        target = result["collider"]
        impact = result["position"]
    shot_fired.emit(target, impact)

func _ray_exclusions() -> Array[RID]:
    var skip: Array[RID] = [get_rid()]
    if mounted and is_instance_valid(horse_ref):
        skip.append(horse_ref.get_rid())
    return skip

func reload_weapon() -> void:
    if ammo < 6 and reserve_ammo > 0 and reload_timer <= 0.0:
        reload_timer = reload_duration

func mount_horse(horse: CharacterBody3D) -> void:
    mounted = true
    horse_ref = horse
    collision_layer = 0
    collision_mask = 0

func dismount_horse(where: Vector3) -> void:
    mounted = false
    horse_ref = null
    global_position = where
    velocity = Vector3.ZERO
    collision_layer = 1
    collision_mask = 1

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    if health <= 0.0:
        defeated.emit()

func revive(at: Vector3) -> void:
    health = 100.0
    stamina = 100.0
    global_position = at
    velocity = Vector3.ZERO
