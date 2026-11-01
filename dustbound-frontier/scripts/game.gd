extends Node3D
## Dustbound Frontier - executable vertical slice, original Western sandbox.
const WORLD_SCRIPT = preload("res://scripts/world.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const MISSION_SCRIPT = preload("res://scripts/mission.gd")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const HORSE_SCENE = preload("res://scenes/horse.tscn")
const NPC_SCENE = preload("res://scenes/npc.tscn")
const SAVE_PATH := "user://dustbound_save.json"

var world = null
var player = null
var horse = null
var sheriff = null
var trader = null
var citizens: Array = []
var bandits: Array = []
var mission = null
var hud = null
var wanted_level := 0
var wanted_remaining := 0.0
var is_paused := false
var graphics_quality := "low"
var weather_index := 0
var graphics_levels := ["low", "medium", "high"]
var weather_options := ["CLEAR", "RAIN", "FOG"]
var interaction_timer := 0.0

func _ready() -> void:
    randomize()
    _install_input_actions()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    world = WORLD_SCRIPT.new()
    add_child(world)
    player = PLAYER_SCENE.instantiate()
    add_child(player)
    player.global_position = world.ground_point(0, 16) + Vector3(0, 0.15, 0)
    player.shot_fired.connect(_on_player_shot)
    player.defeated.connect(_on_player_defeated)
    horse = HORSE_SCENE.instantiate()
    add_child(horse)
    horse.global_position = world.ground_point(6.5, 14) + Vector3(0, 0.3, 0)
    sheriff = _spawn_npc("sheriff", "Marshal Reed", Vector3(7.7, 0, -20))
    trader = _spawn_npc("trader", "Eli Mercer  •  Supplies", Vector3(-7.6, 0, 8))
    citizens.append(_spawn_npc("citizen", "Lena", Vector3(-6.8, 0, -6)))
    citizens.append(_spawn_npc("citizen", "Hank", Vector3(6.8, 0, 7)))
    citizens.append(_spawn_npc("citizen", "Otis", Vector3(3.5, 0, 33)))
    for i in range(3):
        var dx: float = [-12.0, 12.0, 3.0][i]
        var dz: float = [-6.0, 6.0, 15.0][i]
        var loc: Vector3 = world.camp_center + Vector3(dx, 0, dz)
        bandits.append(_spawn_npc("bandit", "Ridge Raider %d" % (i + 1), loc))
    mission = MISSION_SCRIPT.new()
    add_child(mission)
    mission.mission_message.connect(_notify)
    hud = HUD_SCRIPT.new()
    add_child(hud)
    hud.controller = self
    hud.player_ref = player
    hud.mission_ref = mission
    hud.world_ref = world
    hud.map.player_ref = player
    hud.map.horse_ref = horse
    hud.map.sheriff_ref = sheriff
    hud.map.camp_pos = world.camp_center
    cycle_quality(false)
    _notify("WELCOME TO DUSTBOUND FRONTIER  •  Meet Marshal Reed by the sheriff's office")

func _spawn_npc(kind: String, character_name: String, desired: Vector3) -> Node3D:
    var npc = NPC_SCENE.instantiate()
    npc.role = kind
    npc.display_name = character_name
    npc.player_ref = player
    add_child(npc)
    npc.global_position = world.ground_point(desired.x, desired.z) + Vector3(0, 0.14, 0)
    npc.starting_location = npc.global_position
    npc.died.connect(_on_npc_died)
    return npc

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    world.advance_environment(delta, player.global_position)
    world.update_streaming(player.global_position)
    if wanted_level > 0:
        wanted_remaining -= delta
        if wanted_remaining <= 0.0:
            wanted_level = maxi(0, wanted_level - 1)
            wanted_remaining = 35.0
            if wanted_level == 0 and is_instance_valid(sheriff) and sheriff.alive:
                sheriff.hostile = false
    mission.check_camp(player.global_position, world.camp_center)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("interact"):
        interact()
    elif event.is_action_pressed("call_horse"):
        if not player.mounted:
            horse.call_to(player)
            _notify("You whistle for Copper. Your horse is coming.")
    elif event.is_action_pressed("save_game"):
        save_game()
    elif event.is_action_pressed("load_game"):
        load_game()
    elif event.is_action_pressed("quality"):
        cycle_quality()
    elif event.is_action_pressed("change_weather"):
        cycle_weather()
    elif event.is_action_pressed("help"):
        hud.help_visible = not hud.help_visible

func interaction_hint() -> String:
    if player.mounted:
        return "E  •  DISMOUNT COPPER"
    var closest = null
    var distance := 4.0
    for candidate in [horse, sheriff, trader] + citizens:
        if not is_instance_valid(candidate):
            continue
        if candidate != horse and not candidate.alive:
            continue
        var d: float = player.global_position.distance_to(candidate.global_position)
        if d < distance:
            distance = d
            closest = candidate
    if closest == horse:
        return "E  •  MOUNT COPPER"
    if closest == sheriff:
        return "E  •  TALK TO MARSHAL REED"
    if closest == trader:
        return "E  •  BUY 12 REVOLVER ROUNDS ($8)"
    if closest != null:
        return "E  •  TALK TO " + closest.display_name.to_upper()
    return "F  •  CALL YOUR HORSE   |   F1  •  HELP"

func interact() -> void:
    if player.mounted:
        horse.dismount()
        _notify("Dismounted Copper.", 2.5)
        return
    if player.global_position.distance_to(horse.global_position) < 3.8:
        horse.mount(player)
        _notify("Mounted Copper. Hold SHIFT to gallop.", 2.5)
        return
    if sheriff.alive and player.global_position.distance_to(sheriff.global_position) < 4.1:
        var result: Dictionary = mission.sheriff_interaction()
        _notify(result["message"], 7.0)
        if int(result["reward"]) > 0:
            player.money += int(result["reward"])
            player.honor += 10
        return
    if trader.alive and player.global_position.distance_to(trader.global_position) < 4.0:
        if player.money >= 8:
            player.money -= 8
            player.reserve_ammo += 12
            _notify("Eli Mercer: 12 rounds for eight dollars. Safe travels!", 5.0)
        else:
            _notify("Eli Mercer: Sorry, you need $8 for ammunition.", 4.0)
        return
    for npc in citizens:
        if npc.alive and player.global_position.distance_to(npc.global_position) < 4.0:
            _notify(npc.speak(), 4.0)
            return

func _on_player_shot(target: Object, _impact: Vector3) -> void:
    if target != null and target.has_method("take_hit"):
        var victim = target
        if victim.role == "citizen" or victim.role == "sheriff" or victim.role == "trader":
            _register_crime(2)
        victim.take_hit(1)

func _on_npc_died(npc) -> void:
    if npc.role == "bandit":
        mission.bandit_killed()
    elif npc.role != "bandit":
        _register_crime(3)
        player.honor -= 15

func _register_crime(severity: int) -> void:
    wanted_level = mini(5, maxi(wanted_level, severity))
    wanted_remaining = 50.0
    if is_instance_valid(sheriff) and sheriff.alive:
        sheriff.hostile = true
    _notify("WANTED!  LAW ENFORCEMENT IS ALERTED", 3.5)

func _on_player_defeated() -> void:
    if player.mounted:
        horse.dismount()
    player.money = maxi(0, player.money - 10)
    player.revive(world.ground_point(0, 18) + Vector3(0, 0.6, 0))
    wanted_level = 0
    wanted_remaining = 0
    if sheriff.alive:
        sheriff.hostile = false
    _notify("YOU COLLAPSED  •  Revived in Dustbound. Lost $10.", 6.0)

func _notify(message: String, seconds: float = 4.5) -> void:
    if is_instance_valid(hud):
        hud.notice(message, seconds)

func toggle_pause() -> void:
    is_paused = not is_paused
    hud.set_paused(is_paused)
    get_tree().paused = is_paused
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED)

func cycle_quality(announce: bool = true) -> void:
    var idx: int = graphics_levels.find(graphics_quality)
    graphics_quality = graphics_levels[(idx + 1) % graphics_levels.size()] if announce else "low"
    world.low_detail = graphics_quality == "low"
    world.sun.shadow_enabled = graphics_quality == "high"
    if graphics_quality == "low":
        Engine.max_fps = 60
    else:
        Engine.max_fps = 90
    if announce:
        _notify("GRAPHICS QUALITY: %s" % graphics_quality.to_upper())

func cycle_weather() -> void:
    weather_index = (weather_index + 1) % weather_options.size()
    world.set_weather(weather_options[weather_index])
    _notify("WEATHER: " + world.weather)

func quit_game() -> void:
    get_tree().paused = false
    get_tree().quit()

func save_game() -> void:
    var fallen: Array = []
    for b in bandits:
        fallen.append(not b.alive)
    var snapshot := {
        "version": 1,
        "player_pos": _vec(player.global_position),
        "horse_pos": _vec(horse.global_position),
        "health": player.health,
        "stamina": player.stamina,
        "money": player.money,
        "honor": player.honor,
        "ammo": player.ammo,
        "reserve_ammo": player.reserve_ammo,
        "horse_health": horse.health,
        "horse_stamina": horse.stamina,
        "mission_stage": mission.stage,
        "mission_defeated": mission.bandits_defeated,
        "mission_visited": mission.visited_camp,
        "bandits_dead": fallen,
        "wanted": wanted_level,
        "clock": world.clock_minutes,
        "weather": world.weather,
        "mounted": player.mounted
    }
    var handle := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if handle == null:
        _notify("ERROR: Could not write save file.")
        return
    handle.store_string(JSON.stringify(snapshot, "  "))
    handle.close()
    _notify("GAME SAVED  •  " + SAVE_PATH)

func _vec(v: Vector3) -> Array:
    return [v.x, v.y, v.z]

func _unvec(a: Array) -> Vector3:
    if a.size() != 3:
        return Vector3.ZERO
    return Vector3(float(a[0]), float(a[1]), float(a[2]))

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        _notify("NO SAVED GAME FOUND. Press F5 to save.")
        return
    var handle := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if handle == null:
        _notify("ERROR: Could not read save file.")
        return
    var parsed = JSON.parse_string(handle.get_as_text())
    handle.close()
    if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
        _notify("SAVE FILE IS INVALID OR UNSUPPORTED.")
        return
    if player.mounted:
        horse.dismount()
    player.global_position = _unvec(parsed.get("player_pos", [0, 1, 16]))
    horse.global_position = _unvec(parsed.get("horse_pos", [6, 1, 14]))
    player.velocity = Vector3.ZERO
    horse.velocity = Vector3.ZERO
    player.health = clampf(float(parsed.get("health", 100)), 1, 100)
    player.stamina = clampf(float(parsed.get("stamina", 100)), 0, 100)
    player.money = int(parsed.get("money", 25))
    player.honor = int(parsed.get("honor", 0))
    player.ammo = int(parsed.get("ammo", 6))
    player.reserve_ammo = int(parsed.get("reserve_ammo", 42))
    player.reload_timer = 0.0
    horse.health = float(parsed.get("horse_health", 100))
    horse.stamina = float(parsed.get("horse_stamina", 100))
    mission.stage = int(parsed.get("mission_stage", 0))
    mission.bandits_defeated = int(parsed.get("mission_defeated", 0))
    mission.visited_camp = bool(parsed.get("mission_visited", false))
    var flags: Array = parsed.get("bandits_dead", [])
    for i in range(mini(flags.size(), bandits.size())):
        if bool(flags[i]) and bandits[i].alive:
            bandits[i].alive = false
            bandits[i].set_physics_process(false)
            bandits[i].collision_layer = 0
            bandits[i].collision_mask = 0
            bandits[i].visual.rotation.z = 1.25
    wanted_level = int(parsed.get("wanted", 0))
    wanted_remaining = 40.0
    if sheriff.alive:
        sheriff.hostile = wanted_level > 0
    world.clock_minutes = float(parsed.get("clock", 480))
    world.set_weather(str(parsed.get("weather", "CLEAR")))
    weather_index = maxi(0, weather_options.find(world.weather))
    if bool(parsed.get("mounted", false)):
        horse.mount(player)
    _notify("SAVED GAME LOADED.")

func _install_input_actions() -> void:
    var binds := {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "sprint": KEY_SHIFT,
        "jump": KEY_SPACE,
        "crouch": KEY_CTRL,
        "roll": KEY_C,
        "interact": KEY_E,
        "call_horse": KEY_F,
        "reload": KEY_R,
        "pause": KEY_ESCAPE,
        "help": KEY_F1,
        "quality": KEY_F3,
        "save_game": KEY_F5,
        "load_game": KEY_F9,
        "change_weather": KEY_F6
    }
    for action in binds.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var event := InputEventKey.new()
        event.physical_keycode = binds[action]
        InputMap.action_add_event(action, event)
    for config in [{"action": "fire", "index": MOUSE_BUTTON_LEFT}, {"action": "aim", "index": MOUSE_BUTTON_RIGHT}]:
        var act: String = config["action"]
        if not InputMap.has_action(act):
            InputMap.add_action(act)
        var event := InputEventMouseButton.new()
        event.button_index = config["index"]
        InputMap.action_add_event(act, event)
