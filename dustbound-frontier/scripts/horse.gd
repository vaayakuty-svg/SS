extends CharacterBody3D
## Mountable trail horse, stamina, autonomous follow and basic collision avoidance.
const Kit = preload("res://scripts/geometry_kit.gd")
var rider = null
var follow_target = null
var is_called := false
var stamina := 100.0
var health := 100.0
var base_speed := 9.0
var gallop_speed := 16.0
var leg_nodes: Array[Node3D] = []
var gait := 0.0

func _ready() -> void:
    name = "CopperTheHorse"
    collision_layer = 1
    collision_mask = 1
    floor_snap_length = 0.4
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.65
    capsule.height = 2.6
    collider.shape = capsule
    collider.position = Vector3(0, 1.4, 0)
    add_child(collider)
    _build_model()

func _build_model() -> void:
    var chestnut := Color(0.39, 0.21, 0.12)
    var tan_coat := Color(0.52, 0.30, 0.16)
    var near_black := Color(0.12, 0.09, 0.07)
    Kit.box(self, Vector3(0, 1.5, 0), Vector3(1.05, 1.35, 2.5), chestnut)
    var neck := Kit.box(self, Vector3(0, 2.08, -0.92), Vector3(0.7, 1.3, 0.7), tan_coat)
    neck.rotation.x = -0.35
    Kit.box(self, Vector3(0, 2.72, -1.27), Vector3(0.57, 0.70, 0.85), chestnut)
    Kit.box(self, Vector3(0, 2.50, -1.73), Vector3(0.54, 0.30, 0.5), tan_coat)
    for side in [-1.0, 1.0]:
        Kit.box(self, Vector3(side * 0.22, 3.12, -1.18), Vector3(0.15, 0.43, 0.16), near_black)
        Kit.sphere(self, Vector3(side * 0.296, 2.79, -1.59), 0.055, near_black)
        for back in [-0.78, 0.82]:
            var leg := Kit.box(self, Vector3(side * 0.37, 0.58, back), Vector3(0.29, 1.16, 0.34), chestnut)
            leg_nodes.append(leg)
            Kit.box(leg, Vector3(0, -0.55, -0.05), Vector3(0.35, 0.15, 0.43), near_black)
    var tail := Kit.box(self, Vector3(0, 1.60, 1.46), Vector3(0.2, 1.45, 0.3), near_black)
    tail.rotation.x = 0.2
    Kit.box(self, Vector3(0, 2.18, 0.05), Vector3(1.18, 0.22, 1.15), Color(0.22, 0.15, 0.11))
    Kit.box(self, Vector3(0, 1.77, 0), Vector3(1.25, 0.35, 1.30), Color(0.36, 0.23, 0.17))

func _physics_process(delta: float) -> void:
    var requested := Vector3.ZERO
    var moving_fast := false
    if is_instance_valid(rider):
        var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        requested = Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, rider.yaw)
        moving_fast = Input.is_action_pressed("sprint") and stamina > 0.0
        if moving_fast and requested.length_squared() > 0.05:
            stamina = maxf(0.0, stamina - delta * 10.0)
        else:
            stamina = minf(100.0, stamina + delta * 8.0)
    elif is_called and is_instance_valid(follow_target):
        var to_target: Vector3 = follow_target.global_position - global_position
        to_target.y = 0.0
        if to_target.length() > 4.0:
            requested = to_target.normalized()
        else:
            is_called = false
    var pace := gallop_speed if moving_fast else base_speed
    if not is_instance_valid(rider):
        pace = 7.5
    velocity.x = move_toward(velocity.x, requested.x * pace, 16.0 * delta)
    velocity.z = move_toward(velocity.z, requested.z * pace, 16.0 * delta)
    if is_on_floor():
        velocity.y = -0.5
    else:
        velocity.y -= 22.0 * delta
    if is_instance_valid(rider) and Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = 7.1
    if requested.length_squared() > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(-requested.x, -requested.z), delta * 5.0)
    move_and_slide()
    gait += delta * Vector2(velocity.x, velocity.z).length() * 1.7
    for n in range(leg_nodes.size()):
        leg_nodes[n].rotation.x = sin(gait + float(n) * PI * 0.5) * minf(0.33, Vector2(velocity.x, velocity.z).length() * 0.035)

func mount(player) -> void:
    rider = player
    is_called = false
    player.mount_horse(self)

func dismount() -> Vector3:
    if is_instance_valid(rider):
        rider.dismount_horse(global_position + global_transform.basis.x * 2.4 + Vector3(0, 0.3, 0))
    rider = null
    return global_position

func call_to(player) -> void:
    follow_target = player
    is_called = true
