extends CharacterBody3D
## Residents, sheriff and hostile outlaws; lightweight state-based AI.
signal died(character: CharacterBody3D)

const Kit = preload("res://scripts/geometry_kit.gd")
var role := "citizen"
var display_name := "Traveler"
var player_ref = null
var starting_location := Vector3.ZERO
var health := 2
var alive := true
var hostile := false
var ai_timer := 0.0
var attack_timer := 0.0
var flee_time := 0.0
var destination := Vector3.ZERO
var visual: Node3D
var walk_phase := 0.0

func _ready() -> void:
    name = display_name.replace(" ", "")
    collision_layer = 1
    collision_mask = 1
    floor_snap_length = 0.30
    var col := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.height = 1.8
    cap.radius = 0.36
    col.position = Vector3(0, 0.95, 0)
    col.shape = cap
    add_child(col)
    starting_location = global_position
    destination = global_position
    visual = Node3D.new()
    add_child(visual)
    _make_character()

func _make_character() -> void:
    var shirt := Color(0.32, 0.37, 0.35)
    if role == "bandit":
        shirt = Color(0.32, 0.17, 0.13)
    elif role == "sheriff":
        shirt = Color(0.57, 0.43, 0.26)
    var skin := Color(0.68, 0.46, 0.33)
    Kit.box(visual, Vector3(0, 1.17, 0), Vector3(0.66, 0.85, 0.36), shirt)
    Kit.sphere(visual, Vector3(0, 1.83, 0), 0.26, skin)
    Kit.cylinder(visual, Vector3(0, 2.08, 0), 0.40, 0.11, Color(0.16, 0.13, 0.11))
    Kit.cylinder(visual, Vector3(0, 2.18, 0), 0.27, 0.27, Color(0.16, 0.13, 0.11))
    for side in [-1.0, 1.0]:
        Kit.box(visual, Vector3(side * 0.43, 1.14, 0), Vector3(0.24, 0.75, 0.24), shirt)
        Kit.box(visual, Vector3(side * 0.2, 0.37, 0), Vector3(0.24, 0.74, 0.28), Color(0.21, 0.21, 0.19))
    if role == "sheriff":
        Kit.sphere(visual, Vector3(0.20, 1.32, -0.22), 0.08, Color(0.93, 0.74, 0.24))
    Kit.label3d(visual, Vector3(0, 2.73, 0), display_name, 27)

func _physics_process(delta: float) -> void:
    if not alive:
        return
    ai_timer -= delta
    attack_timer -= delta
    flee_time = maxf(0.0, flee_time - delta)
    var intention := Vector3.ZERO
    if is_instance_valid(player_ref):
        var toward: Vector3 = player_ref.global_position - global_position
        toward.y = 0.0
        var distance: float = toward.length()
        if (role == "bandit" or hostile) and distance < 34.0:
            # Early ranged-combat prototype: chase into range, fire periodically.
            if distance > 12.0:
                intention = toward.normalized()
            if distance <= 19.0 and attack_timer <= 0.0:
                attack_timer = 2.6 if role == "bandit" else 3.4
                player_ref.take_damage(7.0 if role == "bandit" else 5.0)
        elif flee_time > 0.0 and distance < 24.0:
            intention = -toward.normalized()
        elif role == "citizen":
            if ai_timer <= 0.0:
                ai_timer = randf_range(3.0, 7.0)
                destination = starting_location + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
            var offset := destination - global_position
            offset.y = 0.0
            if offset.length() > 1.3:
                intention = offset.normalized()
    var speed: float = 6.8 if flee_time > 0.0 else (4.3 if hostile or role == "bandit" else 1.6)
    velocity.x = move_toward(velocity.x, intention.x * speed, delta * 13.0)
    velocity.z = move_toward(velocity.z, intention.z * speed, delta * 13.0)
    if not is_on_floor():
        velocity.y -= 22.0 * delta
    else:
        velocity.y = -0.5
    if intention.length_squared() > 0.05:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-intention.x, -intention.z), delta * 7.0)
    move_and_slide()
    walk_phase += delta * Vector2(velocity.x, velocity.z).length()
    visual.position.y = sin(walk_phase * 6.0) * 0.045

func take_hit(damage: int = 1) -> void:
    if not alive:
        return
    health -= damage
    if role == "citizen":
        flee_time = 10.0
    else:
        hostile = true
    if health <= 0:
        alive = false
        collision_layer = 0
        collision_mask = 0
        visual.rotation.z = 1.25
        visual.position.y = 0.25
        set_physics_process(false)
        died.emit(self)

func speak() -> String:
    if not alive:
        return "No response."
    match role:
        "sheriff":
            return "The trail out east is getting rough, partner."
        "citizen":
            return "Evening. Mind the coyotes past the ridge."
        "bandit":
            return "You picked the wrong camp, stranger!"
        _:
            return "Howdy, traveler."
