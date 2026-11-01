extends CanvasLayer
## Native Godot UI: status, objective, crosshair, minimap, pause/actions.
const MapScript = preload("res://scripts/minimap.gd")
var controller = null
var player_ref = null
var mission_ref = null
var world_ref = null
var root: Control
var mission_label: Label
var upper_label: Label
var status_label: Label
var ammo_label: Label
var interaction_label: Label
var popup_label: Label
var tip_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var map: Control
var pause_panel: PanelContainer
var help_visible := true
var notice_timeout := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_hud()
    _build_pause()

func _panel(pos: Vector2, dimensions: Vector2, anchored_right: bool = false, anchored_bottom: bool = false) -> PanelContainer:
    var pane := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.085, 0.075, 0.83)
    style.border_color = Color(0.59, 0.43, 0.23, 0.84)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 11
    style.content_margin_right = 11
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    pane.add_theme_stylebox_override("panel", style)
    root.add_child(pane)
    pane.anchor_left = 1.0 if anchored_right else 0.0
    pane.anchor_right = pane.anchor_left
    pane.anchor_top = 1.0 if anchored_bottom else 0.0
    pane.anchor_bottom = pane.anchor_top
    pane.offset_left = pos.x
    pane.offset_top = pos.y
    pane.offset_right = pos.x + dimensions.x
    pane.offset_bottom = pos.y + dimensions.y
    pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return pane

func _label(parent: Control, text_value: String, font_size: int, tint: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", tint)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _build_hud() -> void:
    var title_panel := _panel(Vector2(16, 16), Vector2(430, 98))
    var mission_stack := VBoxContainer.new()
    title_panel.add_child(mission_stack)
    _label(mission_stack, "DUSTBOUND FRONTIER  •  COYOTE COUNTY", 20, Color(0.98, 0.78, 0.44))
    mission_label = _label(mission_stack, "", 15, Color(0.96, 0.92, 0.80))
    var upper_panel := _panel(Vector2(-255, 16), Vector2(239, 90), true)
    upper_label = _label(upper_panel, "", 15, Color(0.95, 0.89, 0.73))
    var status_panel := _panel(Vector2(16, -126), Vector2(275, 110), false, true)
    var vitals := VBoxContainer.new()
    status_panel.add_child(vitals)
    status_label = _label(vitals, "THE OUTLAW", 15, Color(0.98, 0.78, 0.45))
    health_bar = ProgressBar.new()
    health_bar.max_value = 100
    health_bar.value = 100
    health_bar.custom_minimum_size = Vector2(252, 16)
    health_bar.show_percentage = false
    vitals.add_child(health_bar)
    stamina_bar = ProgressBar.new()
    stamina_bar.max_value = 100
    stamina_bar.value = 100
    stamina_bar.custom_minimum_size = Vector2(252, 15)
    stamina_bar.show_percentage = false
    vitals.add_child(stamina_bar)
    var ammo_panel := _panel(Vector2(-239, -102), Vector2(223, 86), true, true)
    ammo_label = _label(ammo_panel, "", 18, Color(0.98, 0.81, 0.48))
    interaction_label = _label(root, "", 18, Color(1.0, 0.88, 0.62))
    interaction_label.anchor_left = 0.5
    interaction_label.anchor_right = 0.5
    interaction_label.anchor_top = 1.0
    interaction_label.anchor_bottom = 1.0
    interaction_label.offset_left = -260
    interaction_label.offset_right = 260
    interaction_label.offset_top = -154
    interaction_label.offset_bottom = -120
    interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var crosshair := _label(root, "+", 30, Color(1, 0.94, 0.74, 0.8))
    crosshair.anchor_left = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.offset_left = -12
    crosshair.offset_right = 12
    crosshair.offset_top = -22
    crosshair.offset_bottom = 20
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    popup_label = _label(root, "", 20, Color(1.0, 0.76, 0.35))
    popup_label.anchor_left = 0.5
    popup_label.anchor_right = 0.5
    popup_label.offset_left = -310
    popup_label.offset_right = 310
    popup_label.offset_top = 128
    popup_label.offset_bottom = 220
    popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tip_label = _label(root, "WASD move  •  SHIFT sprint  •  SPACE jump  •  E interact/mount\nF call horse  •  Left click fire  •  Right click aim  •  R reload\nF5 save  •  F9 load  •  F3 quality  •  ESC menu  •  F1 hide tips", 13, Color(0.95, 0.91, 0.84, 0.91))
    tip_label.anchor_left = 0.5
    tip_label.anchor_right = 0.5
    tip_label.anchor_top = 1.0
    tip_label.anchor_bottom = 1.0
    tip_label.offset_left = -320
    tip_label.offset_right = 320
    tip_label.offset_top = -69
    tip_label.offset_bottom = -2
    tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map = MapScript.new()
    map.name = "MiniMap"
    map.custom_minimum_size = Vector2(170, 170)
    root.add_child(map)
    map.anchor_top = 1.0
    map.anchor_bottom = 1.0
    map.offset_left = 16
    map.offset_right = 186
    map.offset_top = -310
    map.offset_bottom = -140
    map.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_pause() -> void:
    pause_panel = PanelContainer.new()
    pause_panel.name = "PauseMenu"
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.078, 0.07, 0.97)
    style.border_color = Color(0.84, 0.61, 0.31)
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    style.set_content_margin_all(18)
    pause_panel.add_theme_stylebox_override("panel", style)
    root.add_child(pause_panel)
    pause_panel.anchor_left = 0.5
    pause_panel.anchor_right = 0.5
    pause_panel.anchor_top = 0.5
    pause_panel.anchor_bottom = 0.5
    pause_panel.offset_left = -180
    pause_panel.offset_right = 180
    pause_panel.offset_top = -205
    pause_panel.offset_bottom = 205
    pause_panel.visible = false
    pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    pause_panel.add_child(stack)
    _label(stack, "DUSTBOUND FRONTIER", 26, Color(1, 0.81, 0.44))
    _label(stack, "The road is yours.", 16, Color(0.88, 0.85, 0.73))
    _button(stack, "RESUME THE TRAIL", "resume")
    _button(stack, "SAVE GAME  •  F5", "save")
    _button(stack, "LOAD GAME  •  F9", "load")
    _button(stack, "GRAPHICS QUALITY  •  F3", "quality")
    _button(stack, "CHANGE WEATHER", "weather")
    _button(stack, "EXIT GAME", "quit")
    _label(stack, "An original game prototype  •  Godot 4", 13, Color(0.78, 0.70, 0.59))

func _button(parent: Node, title: String, action: String) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(310, 39)
    parent.add_child(button)
    button.pressed.connect(_choose.bind(action))

func _choose(action: String) -> void:
    match action:
        "resume":
            controller.toggle_pause()
        "save":
            controller.save_game()
        "load":
            controller.load_game()
        "quality":
            controller.cycle_quality()
        "weather":
            controller.cycle_weather()
        "quit":
            controller.quit_game()

func _unhandled_input(event: InputEvent) -> void:
    if pause_panel.visible and event.is_action_pressed("pause"):
        controller.toggle_pause()
        get_viewport().set_input_as_handled()

func set_paused(paused: bool) -> void:
    pause_panel.visible = paused

func notice(message: String, seconds: float = 4.5) -> void:
    popup_label.text = message
    notice_timeout = seconds

func _process(delta: float) -> void:
    if notice_timeout > 0.0:
        notice_timeout -= delta
        if notice_timeout <= 0:
            popup_label.text = ""
    if not is_instance_valid(player_ref) or mission_ref == null or world_ref == null or controller == null:
        return
    mission_label.text = "MISSION  /  " + mission_ref.objective()
    var hours: int = int(world_ref.clock_minutes / 60.0)
    var minutes: int = int(world_ref.clock_minutes) % 60
    upper_label.text = "$%d    •    HONOR %d\nWANTED %d / 5\n%02d:%02d  •  %s  •  %s" % [player_ref.money, player_ref.honor, controller.wanted_level, hours, minutes, world_ref.weather, controller.graphics_quality.to_upper()]
    status_label.text = "COPPER TRAIL  •  ON HORSE" if player_ref.mounted else "THE WANDERING OUTLAW"
    health_bar.value = player_ref.health
    stamina_bar.value = controller.horse.stamina if player_ref.mounted else player_ref.stamina
    ammo_label.text = "REVOLVER  %d / %d\n%s" % [player_ref.ammo, player_ref.reserve_ammo, "RELOADING..." if player_ref.reload_timer > 0 else "6-SHOT CYLINDER"]
    interaction_label.text = controller.interaction_hint()
    tip_label.visible = help_visible and not pause_panel.visible
