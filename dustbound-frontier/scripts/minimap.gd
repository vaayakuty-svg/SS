extends Control
## Lightweight 2D map (north-up): white player, yellow sheriff, red bandit camp.
var player_ref = null
var sheriff_ref: Node3D
var horse_ref: Node3D
var camp_pos := Vector3(105, 0, -95)
var map_radius := 180.0

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var boundary := Rect2(0, 0, size.x, size.y)
    draw_rect(boundary, Color(0.09, 0.12, 0.10, 0.89), true)
    draw_rect(boundary, Color(0.78, 0.59, 0.31), false, 2.0)
    if not is_instance_valid(player_ref):
        return
    var center := size * 0.5
    # A few pale lines indicate the town's center street.
    var road_a := _point_to_map(Vector3(0, 0, -75))
    var road_b := _point_to_map(Vector3(0, 0, 75))
    draw_line(road_a, road_b, Color(0.65, 0.54, 0.36, 0.8), 6.0)
    draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), Color(0.28, 0.27, 0.24, 0.5), 1.0)
    if is_instance_valid(sheriff_ref):
        _dot(sheriff_ref.global_position, Color(1, 0.78, 0.27), 4.0)
    if is_instance_valid(horse_ref):
        _dot(horse_ref.global_position, Color(0.46, 0.76, 0.99), 3.5)
    _dot(camp_pos, Color(0.96, 0.30, 0.23), 5.0)
    draw_circle(center, 4.8, Color.WHITE)
    var direction := Vector2(-sin(player_ref.yaw), -cos(player_ref.yaw))
    draw_line(center, center + direction * 12.0, Color.WHITE, 2.5)

func _point_to_map(point: Vector3) -> Vector2:
    var offset: Vector3 = point - player_ref.global_position
    var factor: float = minf(size.x, size.y) / (map_radius * 2.0)
    return size * 0.5 + Vector2(offset.x, offset.z) * factor

func _dot(where: Vector3, tint: Color, radius: float) -> void:
    var xy := _point_to_map(where)
    if Rect2(Vector2.ZERO, size).has_point(xy):
        draw_circle(xy, radius, tint)
