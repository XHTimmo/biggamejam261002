extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player/player.gd")
const LADDER_SCRIPT = preload("res://scripts/level/ladder.gd")
const MARKER_SCRIPT = preload("res://scripts/level/level_marker.gd")
const ELEMENTS = preload("res://scripts/shared/element_catalog.gd")
const MUD_BLOB_SCRIPT = preload("res://scripts/enemies/dirt_mud_blob.gd")
const RUST_CRAWLER_SCRIPT = preload("res://scripts/enemies/rust_crawler.gd")
const OXYGEN_WISP_SCRIPT = preload("res://scripts/enemies/oxygen_wisp.gd")
const IRON_SENTINEL_SCRIPT = preload("res://scripts/enemies/iron_sentinel.gd")
const ALCHEMY_IRON_GOLEM_SCRIPT = preload("res://scripts/enemies/alchemy_iron_golem.gd")
const GATE_SCRIPT = preload("res://scripts/level/mechanisms/gate.gd")
const BOSS_ARENA_SCRIPT = preload("res://scripts/level/boss_arena.gd")
const GEOMETRY_SCRIPT = preload("res://scripts/level/level_geometry.gd")
const AUDIO_SCRIPT = preload("res://scripts/audio/lab_audio.gd")
const ELEMENT_PROJECTILE_SCRIPT = preload("res://scripts/combat/projectiles/element_projectile.gd")
const OXYGEN_PULSE_SCRIPT = preload("res://scripts/combat/projectiles/oxygen_pulse.gd")
const AIR_ENVIRONMENT = preload("res://scripts/combat/ballistics/air_gun_environment.gd")
const AIR_BALLISTICS = preload("res://scripts/combat/ballistics/air_gun_ballistics.gd")
const BACKGROUND_TEXTURE = preload("res://assets/environment/tech_background.png")

const ZONE_WIDTH := 2048
const FINAL_ZONE_WIDTH := 3000
const LEVEL_WIDTH := ZONE_WIDTH * 2 + FINAL_ZONE_WIDTH
const CHECKPOINTS := [Vector2(120, 520), Vector2(2144, 584), Vector2(4192, 584)]
const ZONE_NAMES := ["01  MUD DRAIN", "02  REACTION TRENCH", "03  PURIFICATION CORE"]
const OBJECTIVES := ["Clear the mud blobs and collect samples", "Cross the reaction trench and clear every mud blob", "Defeat the elemental alchemy golem and reach the exit"]
const SAMPLE_COUNT := 8

var player: CharacterBody2D
var camera: Camera2D
var demo_complete := false
var active_checkpoint := 0
var zones: Dictionary = {}
var build_parent: Node2D
var objectives: Array[bool] = [false, false, false]
var samples: Dictionary = {}
var zone_enemy_remaining := [0, 0, 0]
var boss_defeated := false
var elapsed := 0.0
var deaths := 0
var resets := 0
var shot_uses := {"hydrogen": 0, "oxygen": 0, "carbon": 0, "iron": 0}
var stability_bar: ProgressBar
var oxygen_bar: ProgressBar
var charge_bar: ProgressBar
var combat_label: Label
var ammo_label: Label
var status_label: Label
var objective_label: Label
var stage_label: Label
var sample_label: Label
var slots: Array[Panel] = []
var ui_layer: CanvasLayer
var modal: Panel
var modal_title: Label
var modal_body: Label
var modal_primary: Button
var modal_secondary: Button
var menu_mode := ""
var status_time := 0.0
var audio: Node
var world_font: SystemFont
var air_environment: Resource = AIR_ENVIRONMENT.new()
var air_label: Label
var muzzle_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_font = SystemFont.new()
	world_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_ensure_input_actions()
	audio = Node.new()
	audio.set_script(AUDIO_SCRIPT)
	add_child(audio)
	for index in range(3):
		_build_zone(index)
	_build_world_boundaries()
	_create_player()
	_build_ui()
	_message("Experiment offline. Clear the dirt mud blobs and record samples.")
	queue_redraw()

func _ensure_input_actions() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_K], "previous_element": [KEY_Q], "next_element": [KEY_E], "reset_demo": [KEY_R],
		"dash": [KEY_L], "oxygen_normal": [KEY_J], "oxygen_skill": [KEY_U],
		"sprint": [KEY_SHIFT],
		"oxygen_skill2": [KEY_I], "oxygen_ultimate": [KEY_O],
		"pause_demo": [KEY_ESCAPE], "skills": [KEY_TAB]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	# Retire old actions even when a scene has already registered them.
	for action in ["use_acid", "throw_item", "gravity_skill", "next_item", "previous_item", "slot_1", "slot_2", "slot_3"]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)

func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = CHECKPOINTS[0]
	player.set_world_bounds(Rect2(0.0, 0.0, LEVEL_WIDTH, 900.0), Vector2(18.0, 26.0))
	var shape := CapsuleShape2D.new()
	shape.radius = 16
	shape.height = 52
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	player.add_child(collider)
	add_child(player)
	player.stability_changed.connect(_on_stability_changed)
	player.player_reset.connect(_on_player_reset)
	player.jumped.connect(func(): audio.play_cue("jump"))
	player.selection_changed.connect(func():
		audio.play_cue("pickup")
		_update_air_readout(1.0)
	)
	player.element_projectile_requested.connect(_spawn_element_projectile)
	player.oxygen_pulse_requested.connect(_spawn_oxygen_pulse)
	player.oxygen_energy_changed.connect(_on_oxygen_energy_changed)
	player.charge_changed.connect(_on_charge_changed)
	player.attack_state_changed.connect(_message)
	player.dash_started.connect(func(): audio.play_cue("dash"))
	player.weapon_fired.connect(audio.play_shot)
	player.reload_finished.connect(audio.play_reload_complete)
	audio.set_weapon_owner(player)
	camera = Camera2D.new()
	camera.position = Vector2(100, -120)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.limit_left = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = 850
	player.add_child(camera)

func _build_world_boundaries() -> void:
	# Keep the player and dash movement inside the authored playfield. The
	# player also has a position clamp as a last line of defense for tunneling.
	_world_boundary("WorldBoundaryLeft", Vector2(-16.0, 450.0), Vector2(32.0, 900.0))
	_world_boundary("WorldBoundaryRight", Vector2(LEVEL_WIDTH + 16.0, 450.0), Vector2(32.0, 900.0))
	_world_boundary("WorldBoundaryTop", Vector2(LEVEL_WIDTH * 0.5, -16.0), Vector2(LEVEL_WIDTH + 64.0, 32.0))

func _world_boundary(node_name: String, pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	_shape(body, size)
	add_child(body)
	return body

func _build_zone(index: int) -> void:
	if index == 2:
		boss_defeated = false
	var zone := Node2D.new()
	zone.name = "Zone%d" % index
	zone.position.x = index * ZONE_WIDTH
	zone.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone)
	zones[index] = zone
	zone_enemy_remaining[index] = 0
	build_parent = zone
	var zone_width := FINAL_ZONE_WIDTH if index == 2 else ZONE_WIDTH
	_platform(Rect2(0, 96, zone_width, 32), Color("#243941"))
	if index == 0:
		_build_intro()
	elif index == 1:
		_build_reactions()
	else:
		_build_finale()
	_marker("Checkpoint%d" % index, Vector2(96, 580), Vector2(58, 80), "checkpoint", str(index))

func _build_intro() -> void:
	_platform(Rect2(0, 610, ZONE_WIDTH, 76))
	_platform(Rect2(220, 475, 220, 24))
	_platform(Rect2(515, 390, 180, 24))
	_platform(Rect2(1440, 485, 144, 24))
	_platform(Rect2(1640, 416, 128, 24))
	_platform(Rect2(-32, 128, 32, 600))
	_ladder("Ladder", Vector2(713, 500), 220)
	_mud_blob("MudBlob_0A", Vector2(760, 550), 0)
	_mud_blob("MudBlob_0B", Vector2(1680, 550), 0)
	_rust_crawler("RustCrawler_0A", Vector2(1160, 550), 0)
	_sample("m1", Vector2(310, 437))
	_sample("m2", Vector2(604, 352))
	_sample("m3", Vector2(1694, 376))

func _build_reactions() -> void:
	_platform(Rect2(0, 610, ZONE_WIDTH, 76))
	_platform(Rect2(424, 128, 112, 342), Color("#34474b"))
	_platform(Rect2(1436, 466, 160, 24))
	_platform(Rect2(1664, 420, 128, 24))
	_platform(Rect2(592, 470, 292, 20))
	_mud_blob("MudBlob_1A", Vector2(720, 550), 1)
	_mud_blob("MudBlob_1B", Vector2(1600, 550), 1)
	_mud_blob("MudBlob_1C", Vector2(760, 430), 1)
	_oxygen_wisp("OxygenWisp_1A", Vector2(1200, 360), 1)
	_ladder("ReactionLadder", Vector2(1812, 515), 190)
	_sample("c1", Vector2(668, 568))
	_sample("c2", Vector2(1150, 480))
	_sample("c3", Vector2(1728, 380))

func _build_finale() -> void:
	_platform(Rect2(0, 610, FINAL_ZONE_WIDTH, 76))
	_platform(Rect2(480, 742, 160, 60))
	_platform(Rect2(1120, 742, 256, 60))
	_platform(Rect2(1376, 642, 152, 28))
	_platform(Rect2(560, 360, 760, 24))
	_platform(Rect2(1360, 438, 176, 24))
	_platform(Rect2(1584, 512, 120, 24))
	_platform(Rect2(1216, 480, 88, 156), Color("#34474b"))
	_mud_blob("MudBlob_2A", Vector2(720, 550), 2)
	_mud_blob("MudBlob_2B", Vector2(1120, 550), 2)
	_mud_blob("MudBlob_2C", Vector2(1320, 550), 2)
	_mud_blob("MudBlob_2D", Vector2(1480, 400), 2)
	_iron_sentinel("IronSentinel_2A", Vector2(1600, 550), 2)
	# The final arena begins after the regular enemy route. Its ceiling, visual
	# barrier and floating platforms give the boss a dedicated combat space.
	_platform(Rect2(2010, 420, 760, 24), Color("#294b55"))
	_platform(Rect2(2050, 500, 160, 20), Color("#294b55"))
	_platform(Rect2(2270, 350, 190, 20), Color("#294b55"))
	_platform(Rect2(2530, 455, 170, 20), Color("#294b55"))
	_boss_arena(Vector2(2390, 430))
	_boss_arena_wall("BossArenaCeiling", Vector2(2390, 176), Vector2(820, 18))
	_boss_arena_wall("BossArenaRightWall", Vector2(2800, 420), Vector2(18, 420))
	# All regular enemies are placed before the final arena. The golem is the
	# last enemy on the route, directly before ExitGate.
	_alchemy_iron_golem("AlchemyIronGolem_2A", Vector2(2390, 550), 2)
	_ladder("FinalLadder", Vector2(1500, 500), 190)
	_exit_gate("ExitGate", Vector2(2850, 554))
	_marker("Exit", Vector2(2910, 554), Vector2(76, 108), "exit", "exit")
	_sample("f1", Vector2(1000, 320))
	_sample("f3", Vector2(1450, 400))

func _boss_arena(pos: Vector2) -> Node2D:
	var arena := Node2D.new()
	arena.name = "BossArenaField"
	arena.set_script(BOSS_ARENA_SCRIPT)
	arena.position = pos
	arena.set("arena_size", Vector2(820, 500))
	build_parent.add_child(arena)
	return arena

func _boss_arena_wall(node_name: String, pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = node_name
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 1
	_shape(wall, size)
	build_parent.add_child(wall)
	return wall

func _platform(rect: Rect2, tint := Color("#2e4953")) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.set_script(GEOMETRY_SCRIPT)
	body.size = rect.size
	body.tint = tint
	body.position = rect.get_center()
	_shape(body, rect.size)
	if rect.size.y <= 28:
		body.get_node("CollisionShape2D").one_way_collision = true
	build_parent.add_child(body)
	return body

func _shape(body: Node, size: Vector2) -> void:
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

func _sensor(node_name: String, script: Script, pos: Vector2, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.set_script(script)
	area.position = pos
	_shape(area, size)
	build_parent.add_child(area)
	return area

func _ladder(node_name: String, pos: Vector2, height: float) -> void:
	var ladder := _sensor(node_name, LADDER_SCRIPT, pos, Vector2(42, height))
	ladder.ladder_height = height

func _mud_blob(node_name: String, pos: Vector2, zone_index: int) -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.name = node_name
	enemy.set_script(MUD_BLOB_SCRIPT)
	enemy.position = pos
	enemy.collision_layer = 1
	enemy.collision_mask = 1
	_shape(enemy, Vector2(34, 24))
	build_parent.add_child(enemy)
	zone_enemy_remaining[zone_index] += 1
	enemy.connect("defeated", _on_mud_blob_defeated.bind(zone_index))
	return enemy

func _rust_crawler(node_name: String, pos: Vector2, zone_index: int) -> CharacterBody2D:
	return _spawn_enemy(node_name, pos, zone_index, RUST_CRAWLER_SCRIPT, Vector2(42, 32))

func _oxygen_wisp(node_name: String, pos: Vector2, zone_index: int) -> CharacterBody2D:
	return _spawn_enemy(node_name, pos, zone_index, OXYGEN_WISP_SCRIPT, Vector2(40, 40))

func _iron_sentinel(node_name: String, pos: Vector2, zone_index: int) -> CharacterBody2D:
	return _spawn_enemy(node_name, pos, zone_index, IRON_SENTINEL_SCRIPT, Vector2(48, 52))

func _alchemy_iron_golem(node_name: String, pos: Vector2, zone_index: int) -> CharacterBody2D:
	var boss := _spawn_enemy(node_name, pos, zone_index, ALCHEMY_IRON_GOLEM_SCRIPT, Vector2(56, 96), false)
	boss.connect("defeated", _on_boss_defeated.bind(zone_index))
	boss.connect("phase_warning", _on_boss_phase_warning)
	boss.connect("phase_changed", _on_boss_phase_changed)
	boss.connect("attack_started", _on_boss_attack_started)
	boss.connect("health_changed", _on_boss_health_changed)
	return boss

func _exit_gate(node_name: String, pos: Vector2) -> StaticBody2D:
	var gate := StaticBody2D.new()
	var gate_size := Vector2(24, 144)
	gate.name = node_name
	gate.set_script(GATE_SCRIPT)
	gate.set("gate_size", gate_size)
	gate.position = pos
	gate.collision_layer = 1
	gate.collision_mask = 1
	_shape(gate, gate_size)
	build_parent.add_child(gate)
	return gate

func _spawn_enemy(node_name: String, pos: Vector2, zone_index: int, script: Script, body_size: Vector2, connect_defeated := true) -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.name = node_name
	enemy.set_script(script)
	enemy.position = pos
	enemy.collision_layer = 1
	enemy.collision_mask = 1
	_shape(enemy, body_size)
	build_parent.add_child(enemy)
	zone_enemy_remaining[zone_index] += 1
	if connect_defeated:
		enemy.connect("defeated", _on_mud_blob_defeated.bind(zone_index))
	return enemy

func _sample(id: String, pos: Vector2) -> void:
	if samples.has(id):
		return
	_marker("Sample_" + id, pos, Vector2(28, 32), "sample", id)

func _marker(node_name: String, pos: Vector2, size: Vector2, kind: String, id: String) -> void:
	var marker := Area2D.new()
	marker.name = node_name
	marker.set_script(MARKER_SCRIPT)
	marker.kind = kind
	marker.marker_id = id
	marker.position = pos
	_shape(marker, size)
	build_parent.add_child(marker)
	marker.activated.connect(_marker_activated)

func _marker_activated(marker: Area2D) -> void:
	if marker.kind == "sample":
		if not samples.has(marker.marker_id):
			samples[marker.marker_id] = true
			player.restore_stability(12)
			audio.play_cue("pickup")
			_message("记录实验样本  %d / %d  ·  稳态 +12" % [samples.size(), SAMPLE_COUNT])
	elif marker.kind == "checkpoint":
		var index := int(marker.marker_id)
		if index > active_checkpoint + 1 or (index > 0 and not objectives[index - 1]):
			marker.used = false
			return
		if index >= active_checkpoint:
			active_checkpoint = index
			player.spawn_position = CHECKPOINTS[index]
			player.restore_stability(100)
			audio.play_cue("checkpoint")
			_message("检查点已同步 · 四元素始终可用。")
	elif marker.kind == "exit":
		_try_complete()

func _on_mud_blob_defeated(zone_index: int) -> void:
	zone_enemy_remaining[zone_index] = maxi(0, zone_enemy_remaining[zone_index] - 1)
	if zone_enemy_remaining[zone_index] > 0 or objectives[zone_index]:
		_try_unlock_final_exit()
		return
	objectives[zone_index] = true
	audio.play_cue("reaction")
	_message("AREA CLEAR - EXIT ROUTE OPEN")
	_try_unlock_final_exit()

func _on_boss_defeated(zone_index: int) -> void:
	boss_defeated = true
	audio.set_boss_music(false)
	_message("ELEMENTAL ALCHEMY GOLEM DEFEATED")
	_on_mud_blob_defeated(zone_index)
	_try_unlock_final_exit()

func _on_boss_phase_changed(element: String) -> void:
	_message("GOLEM CORE STATE: " + element.to_upper())
	audio.play_cue("reaction")

func _on_boss_phase_warning(element: String, hint: String) -> void:
	_message("GOLEM PHASE WARNING: %s  |  %s" % [element.to_upper(), hint])
	audio.play_cue("reaction")

func _on_boss_attack_started(attack_name: String) -> void:
	if not boss_defeated and not player.resetting:
		audio.set_boss_music(true)
	_message("GOLEM WARNING: " + attack_name.to_upper())

func _on_boss_health_changed(value: float, maximum: float) -> void:
	if value > 0.0 and value < maximum and not boss_defeated and not player.resetting:
		audio.set_boss_music(true)

func _try_unlock_final_exit() -> void:
	if not boss_defeated or not objectives[2] or not zones.has(2):
		return
	var gate := zones[2].get_node_or_null("ExitGate") as StaticBody2D
	if gate and gate.has_method("set_open"):
		gate.set_open(true)

func _spawn_element_projectile(origin: Vector2, direction: Vector2, damage: float, kind: String, element: String) -> void:
	if demo_complete or player.resetting or get_tree().paused:
		return
	var projectile := Area2D.new()
	projectile.set_script(ELEMENT_PROJECTILE_SCRIPT)
	projectile.element = element
	shot_uses[element] += 1
	projectile.position = origin
	projectile.direction = direction
	projectile.damage = damage
	projectile.attack_kind = kind
	projectile.compression_strength = player.last_compression_strength if kind == "charged" else 1.0
	projectile.environment = air_environment
	projectile.impact_landed.connect(_on_projectile_impact)
	projectile.collision_layer = 0
	projectile.collision_mask = 3
	var shape := CircleShape2D.new()
	shape.radius = 22 if kind == "charged" else 11
	var collider := CollisionShape2D.new()
	collider.shape = shape
	projectile.add_child(collider)
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectile)
	projectile.add_to_group("projectiles")

func _on_projectile_impact(_element: String, _kind: String) -> void:
	audio.play_cue("damage")

func _spawn_oxygen_pulse(origin: Vector2, radius: float, damage: float, kind: String) -> void:
	if demo_complete or player.resetting or get_tree().paused:
		return
	var pulse := Area2D.new()
	pulse.set_script(OXYGEN_PULSE_SCRIPT)
	pulse.position = origin
	pulse.radius = radius
	pulse.damage = damage
	pulse.attack_kind = kind
	pulse.collision_layer = 0
	# Pulse attacks must see both enemy bodies (layer 1) and legacy oxygen
	# targets (layer 2). Previously layer 2 alone made pulses pass through all
	# CharacterBody2D enemies.
	pulse.collision_mask = 3
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	pulse.add_child(collider)
	pulse.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pulse)
	pulse.add_to_group("projectiles")

func _on_oxygen_energy_changed(value: float, _maximum: float) -> void:
	if oxygen_bar:
		oxygen_bar.value = value

func _on_charge_changed(value: float, maximum: float) -> void:
	if charge_bar:
		charge_bar.max_value = maximum
		charge_bar.value = value
	_update_air_readout(1.0 + 3.0 * clampf(value / maxf(0.01, maximum), 0.0, 1.0))

func _on_atmosphere_selected(index: int) -> void:
	air_environment.apply_preset(index)
	_update_air_readout(1.0)

func _update_air_readout(strength: float) -> void:
	if not air_label or not muzzle_label:
		return
	air_label.text = "空气 %.2f kg/m³ · %.0f°C · 风 %.0f m/s" % [air_environment.air_density(), air_environment.temperature_k - 273.15, air_environment.wind_mps.x]
	var element: String = ELEMENTS.IDS[player.selected_element]
	var shot: RefCounted = AIR_BALLISTICS.new() if ELEMENTS.is_gas(element) else load("res://scripts/combat/ballistics/solid_ballistics.gd").new()
	if element == "hydrogen":
		shot.molar_mass_ratio = 2.016 / 28.965
		shot.mixing_per_second = 1.0
	elif not ELEMENTS.is_gas(element):
		shot.element = element
	shot.launch(Vector2.RIGHT, strength, air_environment)
	muzzle_label.text = "%s · %.1fx · %.1f m/s" % [ELEMENTS.WEAPONS[player.selected_element], strength, shot.initial_speed_mps]

func _on_stability_changed(value: float, _maximum: float) -> void:
	if stability_bar:
		stability_bar.value = value
	if value < 30:
		_message("稳态偏低 · 远离腐蚀区，收集样本或返回检查点。")

func _on_player_reset() -> void:
	if player.reset_reason == "manual":
		resets += 1
	else:
		deaths += 1
	call_deferred("_restore_checkpoint")

func _restore_checkpoint() -> void:
	audio.set_boss_music(false)
	var index := active_checkpoint
	var old_zone: Node = zones[index]
	old_zone.free()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	objectives[index] = false
	if index == 2:
		boss_defeated = false
	_build_zone(index)
	player.global_position = CHECKPOINTS[index]
	player.spawn_position = CHECKPOINTS[index]
	player.velocity = Vector2.ZERO
	player.resetting = false
	camera.reset_smoothing()
	_message("Current chamber restored - mud blobs respawned; collected samples retained.")

func _try_complete() -> void:
	if demo_complete or not objectives[0] or not objectives[1] or not objectives[2] or not boss_defeated:
		return
	demo_complete = true
	audio.play_cue("checkpoint")
	_save_run()
	_show_modal("complete")

func _save_run() -> void:
	if "--test-mode" in OS.get_cmdline_user_args():
		return
	var file := FileAccess.open("user://playtest_runs.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists("user://playtest_runs.jsonl") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify({"version": "level-2", "seconds": elapsed, "deaths": deaths, "resets": resets, "samples": samples.size(), "route": "mud_clear", "shot_uses": shot_uses}))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_demo") and menu_mode != "complete":
		if menu_mode == "":
			_show_modal("pause")
		else:
			_close_modal()
	if Input.is_action_just_pressed("skills") and menu_mode != "complete":
		if menu_mode == "":
			_show_modal("skills")
		else:
			_close_modal()
	if get_tree().paused:
		return
	elapsed += delta
	status_time = maxf(0, status_time - delta)
	if status_label:
		status_label.visible = status_time > 0
		stage_label.text = "%d / 3  舱段  ·  %02d:%02d" % [active_checkpoint + 1, int(elapsed) / 60, int(elapsed) % 60]
		sample_label.text = "◇  %d / %d" % [samples.size(), SAMPLE_COUNT]
		objective_label.text = OBJECTIVES[active_checkpoint]
		combat_label.text = "U %.1fs" % player.skill_cooldown if player.skill_cooldown > 0 else "U / O %d" % player.oxygen_energy
		ammo_label.text = "换弹 %.1fs" % player.reload_remaining[player.selected_element] if player.is_reloading() else "弹 %d / %d" % [player.magazine_ammo[player.selected_element], player.magazine_capacity()]
		ammo_label.modulate = Color("#dfbd7d") if player.is_reloading() else Color.WHITE
		for index in range(4):
			var style := slots[index].get_theme_stylebox("panel") as StyleBoxFlat
			style.border_color = ELEMENTS.TINTS[index] if index == player.selected_element else Color("#35545d")
			style.set_border_width_all(2 if index == player.selected_element else 1)
			slots[index].modulate = Color.WHITE if index == player.selected_element else Color(0.65, 0.65, 0.65)
	if not demo_complete:
		var exit_node := zones[2].get_node("Exit") as Area2D
		if exit_node.overlaps_body(player):
			_try_complete()

func _message(text: String) -> void:
	if status_label:
		status_label.text = text
		status_time = 5

func _panel(rect: Rect2, parent: Node) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10262ee8")
	style.border_color = Color("#386068")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(text: String, pos: Vector2, font_size: int, tint: Color, parent: Node) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_override("font", world_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(200, 38)
	button.text = text
	button.add_theme_font_override("font", world_font)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	modal.add_child(button)
	return button

func _style_meter(bar: ProgressBar, tint: Color, meter_size: Vector2) -> void:
	# The default theme has a minimum height that exceeds our compact HUD.
	bar.add_theme_font_size_override("font_size", 1)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#152a32")
	background.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.size = meter_size
	# Joining the CanvasLayer refreshes the inherited theme asynchronously.
	bar.set_deferred("size", meter_size)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_panel(Rect2(20, 18, 1112, 88), ui_layer)
	_label("稳态  /  反应舱", Vector2(40, 28), 25, Color("#e3eee3"), ui_layer)
	_label("STABILITY", Vector2(42, 70), 12, Color("#7ea69e"), ui_layer)
	stability_bar = ProgressBar.new()
	stability_bar.position = Vector2(140, 73)
	stability_bar.max_value = 100
	stability_bar.value = 100
	stability_bar.show_percentage = false
	_style_meter(stability_bar, Color("#83d5ac"), Vector2(218, 12))
	ui_layer.add_child(stability_bar)
	_label("ENERGY", Vector2(42, 88), 11, Color("#8aceda"), ui_layer)
	oxygen_bar = ProgressBar.new()
	oxygen_bar.position = Vector2(140, 91)
	oxygen_bar.max_value = player.MAX_OXYGEN
	oxygen_bar.value = player.oxygen_energy
	oxygen_bar.show_percentage = false
	_style_meter(oxygen_bar, Color("#8aceda"), Vector2(218, 8))
	ui_layer.add_child(oxygen_bar)
	ammo_label = _label("弹 12 / 12", Vector2(365, 29), 12, Color("#d7e9df"), ui_layer)
	_label("I 蓄力", Vector2(366, 52), 12, Color("#dfbd7d"), ui_layer)
	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(365, 73)
	charge_bar.max_value = player.MAX_CHARGE_TIME
	charge_bar.show_percentage = false
	_style_meter(charge_bar, Color("#dfbd7d"), Vector2(68, 12))
	ui_layer.add_child(charge_bar)
	combat_label = _label("", Vector2(365, 89), 11, Color("#8aceda"), ui_layer)
	var atmosphere := OptionButton.new()
	atmosphere.position = Vector2(720, 28)
	atmosphere.size = Vector2(150, 28)
	for preset in AIR_ENVIRONMENT.PRESETS:
		atmosphere.add_item(preset.name)
	atmosphere.item_selected.connect(_on_atmosphere_selected)
	ui_layer.add_child(atmosphere)
	air_label = _label("", Vector2(720, 59), 10, Color("#9bd8d5"), ui_layer)
	muzzle_label = _label("", Vector2(720, 78), 10, Color("#dfbd7d"), ui_layer)
	_update_air_readout(1.0)
	for index in range(4):
		var slot := _panel(Rect2(452 + index * 63, 32, 59, 55), ui_layer)
		slots.append(slot)
		_label(ELEMENTS.NAMES[index], Vector2(10, 6), 18, ELEMENTS.TINTS[index], slot)
		_label("气枪" if index < 2 else "固体", Vector2(8, 32), 11, Color("#86b3ad"), slot)
	stage_label = _label("", Vector2(900, 31), 14, Color("#ead1a1"), ui_layer)
	sample_label = _label("", Vector2(1020, 61), 12, Color("#aadadd"), ui_layer)
	_panel(Rect2(20, 112, 1112, 53), ui_layer)
	objective_label = _label("", Vector2(40, 114), 16, Color("#d3bc8a"), ui_layer)
	status_label = _label("", Vector2(40, 139), 15, Color("#9cddc2"), ui_layer)
	_panel(Rect2(20, 621, 1112, 26), ui_layer)
	_label("A/D 移动  W 开始攀爬，S 在梯子上向下  S 趴下爬行  Q/E 切元素  J 普攻  K 跳跃  L 冲刺  U 技能  I 蓄力  O 大招  R 恢复  Tab 能力  Esc 暂停", Vector2(32, 624), 12, Color("#9db9b8"), ui_layer)
	modal = _panel(Rect2(186, 165, 780, 418), ui_layer)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_title = _label("", Vector2(32, 24), 28, Color("#e6eddd"), modal)
	modal_body = _label("", Vector2(32, 78), 16, Color("#acd0c9"), modal)
	modal_body.size = Vector2(716, 250)
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_primary = _button("继续实验", Vector2(32, 352), _close_modal)
	modal_secondary = _button("重新开始整关", Vector2(268, 352), _restart_demo)
	modal.visible = false

func _show_modal(mode: String) -> void:
	menu_mode = mode
	get_tree().paused = true
	modal.visible = true
	if mode == "complete":
		modal_title.text = "实验舱已恢复供能"
		modal_body.text = "MUD CLEAR    TIME: %02d:%02d    SAMPLES: %d / %d\nFAILURES: %d    RESETS: %d    SHOTS: %d" % [int(elapsed) / 60, int(elapsed) % 60, samples.size(), SAMPLE_COUNT, deaths, resets, shot_uses.hydrogen + shot_uses.oxygen + shot_uses.carbon + shot_uses.iron]
		modal_primary.text = "TRY AGAIN"
	else:
		modal_title.text = "基础能力" if mode == "skills" else "实验暂停"
		modal_body.text = "Q/E 上一个/下一个元素：氢 → 氧 → 碳 → 铁。\n氢/氧各 12 发，碳/铁各 6 发；打空自动换弹。\n气体换弹 1.2 秒，固体 0.8 秒；机械咔哒声提示换弹中。\n切换保留弹量，收起武器暂停换弹；换弹期间仍可移动。\n\nJ 普攻；K 跳跃/空中喷气；L 冲刺。I 按住蓄力，松开释放。\nJ/I 各耗 1 发；氧 U/O 各 1 发，其他元素 U/O 各 3/5 发。\nU 消耗 25 能量、冷却 4 秒；O 消耗 100 能量。\n弹量不足先换弹，不扣技能能量；命中与蓄力补充能量。\n\nA/D 移动，W/S 梯子，S 趴下。R 恢复，Tab 能力，Esc 暂停。"
		modal_primary.text = "继续实验"

func _close_modal() -> void:
	if menu_mode == "complete":
		_restart_demo()
		return
	menu_mode = ""
	modal.visible = false
	get_tree().paused = false

func _restart_demo() -> void:
	audio.set_boss_music(false)
	get_tree().paused = false
	menu_mode = ""
	modal.visible = false
	active_checkpoint = 0
	objectives = [false, false, false]
	samples.clear()
	elapsed = 0
	deaths = 0
	resets = 0
	shot_uses = {"hydrogen": 0, "oxygen": 0, "carbon": 0, "iron": 0}
	player.select_element(1)
	demo_complete = false
	boss_defeated = false
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	for zone in zones.values():
		zone.free()
	zones.clear()
	for index in range(3):
		_build_zone(index)
	player.spawn_position = CHECKPOINTS[0]
	player.global_position = CHECKPOINTS[0]
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	# Rebuild the zone from static terrain and mud blobs.
	player.jump_buffer = 0
	player.coyote_remaining = 0
	player.resetting = false
	player.reset_combat()
	player._update_crouch(false)
	player._update_visuals()
	player.restore_stability(100)
	camera.reset_smoothing()
	_message("New experiment started - clear the dirt mud blobs in all three chambers.")

func _draw() -> void:
	draw_texture_rect(BACKGROUND_TEXTURE, Rect2(-64, -64, LEVEL_WIDTH + 128, 1024), true)
	var playfield_tint := Color("#10272f")
	playfield_tint.a = 0.28
	draw_rect(Rect2(0, 192, LEVEL_WIDTH, 650), playfield_tint)
	for zone_index in range(3):
		var base := zone_index * ZONE_WIDTH
		var tint: Color = [Color("#526955"), Color("#355e65"), Color("#625442")][zone_index]
		for x in range(base + 64, base + ZONE_WIDTH, 256):
			draw_rect(Rect2(x, 210, 160, 320), Color("#18313b"))
			draw_rect(Rect2(x + 6, 216, 148, 300), Color("#122a33"))
			draw_rect(Rect2(x + 26, 252, 104, 16), tint.darkened(0.4))
			draw_line(Vector2(x + 38, 322), Vector2(x + 38, 480), tint, 4)
			draw_circle(Vector2(x + 116, 337), 15, Color("#294551"))
			draw_arc(Vector2(x + 116, 337), 11, PI, TAU, 12, Color("#82a4a1"), 2)
			draw_rect(Rect2(x + 64, 480, 76, 8), Color("#2c4650"))
		draw_line(Vector2(base + 16, 204), Vector2(base + ZONE_WIDTH - 16, 204), tint, 7)
		draw_line(Vector2(base + 16, 211), Vector2(base + ZONE_WIDTH - 16, 211), Color("#193c43"), 2)
		for x in range(base + 112, base + ZONE_WIDTH, 384):
			draw_rect(Rect2(x, 177, 88, 8), Color("#d7b571"))
			draw_rect(Rect2(x + 8, 185, 72, 3), Color("#765f3b"))
		draw_string(world_font, Vector2(base + 180, 258), ZONE_NAMES[zone_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#afc4b8"))
		draw_string(world_font, Vector2(base + 182, 282), ["MUD / SAMPLE", "REACTION / CLEANUP", "PURIFICATION / EXIT"][zone_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#638c88"))
	# Mark contamination zones and samples without drawing any machine wiring.
	for zone_index in range(3):
		var base := zone_index * ZONE_WIDTH
		var mud_tint := Color("#8f6b58") if zone_index == 0 else Color("#6f8b70") if zone_index == 1 else Color("#8d725e")
		for mark in [Vector2(760, 579), Vector2(1320, 579), Vector2(1660, 579)]:
			if zone_index == 0 and mark.x == 1320:
				continue
			draw_circle(Vector2(base, 0) + mark, 24, Color(mud_tint, 0.16))
			draw_arc(Vector2(base, 0) + mark, 24, 0.2, TAU - 0.2, 12, Color(mud_tint, 0.7), 2)
		draw_string(world_font, Vector2(base + 190, 300), "MUD CONTAINMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#789a88"))
		draw_string(world_font, Vector2(base + 1800, 585), "->", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#a8ddc1"))
