extends Node2D

const PLAYER_SCRIPT = preload("res://player.gd")
const SPRING_SCRIPT = preload("res://spring_platform.gd")
const ROCK_SCRIPT = preload("res://rock.gd")
const HAZARD_SCRIPT = preload("res://hazard.gd")
const WEIGHT_SCRIPT = preload("res://weight.gd")
const SWITCH_SCRIPT = preload("res://switch.gd")
const GATE_SCRIPT = preload("res://gate.gd")
const LADDER_SCRIPT = preload("res://ladder.gd")
const PLATFORM_SCRIPT = preload("res://moving_platform.gd")
const MARKER_SCRIPT = preload("res://level_marker.gd")
const WATER_SCRIPT = preload("res://water_trough.gd")
const ELEMENTS = preload("res://element_catalog.gd")
const MAGNET_SCRIPT = preload("res://magnet_receiver.gd")
const GEOMETRY_SCRIPT = preload("res://level_geometry.gd")
const AUDIO_SCRIPT = preload("res://lab_audio.gd")
const ELEMENT_PROJECTILE_SCRIPT = preload("res://element_projectile.gd")
const OXYGEN_PULSE_SCRIPT = preload("res://oxygen_pulse.gd")
const TARGET_SCRIPT = preload("res://target_dummy.gd")
const AIR_ENVIRONMENT = preload("res://air_gun_environment.gd")
const AIR_BALLISTICS = preload("res://air_gun_ballistics.gd")
const BACKGROUND_TEXTURE = preload("res://assets/environment/tech_background.png")

const ZONE_WIDTH := 2048
const LEVEL_WIDTH := ZONE_WIDTH * 3
const CHECKPOINTS := [Vector2(120, 520), Vector2(2144, 584), Vector2(4192, 584)]
const ZONE_NAMES := ["01  力学检修舱", "02  反应与相变舱", "03  平衡控制舱"]
const OBJECTIVES := ["推配重到圆形压板，为吊台和隔离门供能", "酸蚀碳酸钙，冷却水槽，选择安全路线", "选择上层配重路线或下层酸蚀路线，解除出口锁"]
const SAMPLE_COUNT := 9

var player: CharacterBody2D
var camera: Camera2D
var gate: StaticBody2D
var pressure_switch: Area2D
var rock: StaticBody2D
var demo_complete := false
var active_checkpoint := 0
var zones: Dictionary = {}
var build_parent: Node2D
var objectives: Array[bool] = [false, false, false]
var final_route := ""
var samples: Dictionary = {}
var elapsed := 0.0
var deaths := 0
var resets := 0
var shot_uses := {"hydrogen": 0, "oxygen": 0, "carbon": 0, "iron": 0}
var stability_bar: ProgressBar
var oxygen_bar: ProgressBar
var charge_bar: ProgressBar
var combat_label: Label
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
	_create_player()
	_build_ui()
	_message("实验舱离线。先让橙色配重压住绿色圆形压板。")
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
	camera = Camera2D.new()
	camera.position = Vector2(100, -120)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.limit_left = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = 850
	player.add_child(camera)

func _build_zone(index: int) -> void:
	var zone := Node2D.new()
	zone.name = "Zone%d" % index
	zone.position.x = index * ZONE_WIDTH
	zone.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone)
	zones[index] = zone
	build_parent = zone
	_platform(Rect2(0, 96, ZONE_WIDTH, 32), Color("#243941"))
	if index == 0:
		_build_mechanics()
	elif index == 1:
		_build_reactions()
	else:
		_build_finale()
	_marker("Checkpoint%d" % index, Vector2(96, 580), Vector2(58, 80), "checkpoint", str(index))

func _build_mechanics() -> void:
	_platform(Rect2(0, 610, 960, 76))
	_platform(Rect2(1440, 610, 608, 76))
	_platform(Rect2(220, 475, 220, 24))
	_platform(Rect2(515, 390, 180, 24))
	_platform(Rect2(1440, 485, 144, 24))
	_platform(Rect2(1640, 416, 128, 24))
	_platform(Rect2(-32, 128, 32, 600))
	_ladder("Ladder", Vector2(713, 500), 220)
	_spring("SpringPlatform", Vector2(330, 466))
	_weight("Counterweight", Vector2(608, 550))
	pressure_switch = _switch("PressureSwitch", Vector2(800, 600))
	gate = _gate("Gate", Vector2(1840, 369), Vector2(32, 482))
	var lift := _moving("PulleyLift", Vector2(1120, 590), Vector2(0, -180))
	var shuttle := _moving("GapShuttle", Vector2(1300, 418), Vector2(160, 0), true)
	shuttle.platform_size = Vector2(144, 20)
	pressure_switch.active_changed.connect(func(active: bool):
		if not is_instance_valid(lift):
			return
		lift.set_active(active)
		_on_switch_changed(active)
	)
	_sample("m1", Vector2(310, 437))
	_sample("m2", Vector2(604, 352))
	_sample("m3", Vector2(1694, 376))

func _build_reactions() -> void:
	_platform(Rect2(0, 610, 900, 76))
	_platform(Rect2(1400, 610, 648, 76))
	# The overhead casing closes the jump bypass around the carbonate seal.
	_platform(Rect2(424, 128, 112, 342), Color("#34474b"))
	rock = _rock("CarbonateRock", Vector2(480, 540), Vector2(96, 140))
	var reaction_gate := _gate("ReactionGate", Vector2(1840, 369), Vector2(32, 482))
	rock.dissolved.connect(func():
		objectives[1] = true
		reaction_gate.set_open(true)
		_message("碳酸钙密封已解除。用蓝色胶囊冻结水槽，冰桥维持 6 秒。")
		audio.play_cue("reaction")
	)
	_water("TeachingWater", Vector2(1150, 614), Vector2(500, 48))
	_hazard("CorrosionHazard", Vector2(1540, 604), Vector2(240, 28))
	_platform(Rect2(1436, 466, 160, 24))
	_platform(Rect2(1664, 420, 128, 24))
	# Optional training balcony; targets never block the main puzzle route.
	_platform(Rect2(592, 470, 292, 20))
	_oxygen_target("OxygenTarget0", Vector2(760, 436))
	_oxygen_target("OxygenTarget1", Vector2(840, 436))
	_ladder("ReactionLadder", Vector2(1812, 515), 190)
	_sample("c1", Vector2(668, 568))
	_sample("c2", Vector2(1150, 480))
	_sample("c3", Vector2(1728, 380))

func _build_finale() -> void:
	_platform(Rect2(0, 610, 560, 76))
	_platform(Rect2(480, 742, 160, 60))
	_platform(Rect2(1120, 742, 256, 60))
	_platform(Rect2(1376, 642, 152, 28))
	_platform(Rect2(1536, 610, 512, 76))
	_platform(Rect2(560, 360, 760, 24))
	_platform(Rect2(1360, 438, 176, 24))
	_platform(Rect2(1584, 512, 120, 24))
	_moving("GravityLift", Vector2(476, 590), Vector2(0, -244))
	_weight("FinalWeight", Vector2(664, 332))
	var plate := _switch("FinalSwitch", Vector2(1096, 350))
	var magnet := _sensor("Magnet", MAGNET_SCRIPT, Vector2(1232, 328), Vector2(64, 58))
	plate.active_changed.connect(func(_active: bool): _try_physical_route())
	magnet.locked.connect(_try_physical_route)
	_water("FinalWater", Vector2(880, 744), Vector2(480, 48))
	_platform(Rect2(1216, 480, 88, 156), Color("#34474b"))
	var latch := _rock("ChemicalLatch", Vector2(1260, 690), Vector2(80, 104))
	latch.dissolved.connect(func(): _choose_route("chemical"))
	_gate("ExitGate", Vector2(1840, 369), Vector2(32, 482))
	_marker("Exit", Vector2(1960, 554), Vector2(76, 108), "exit", "exit")
	_sample("f1", Vector2(1000, 320))
	_sample("f2", Vector2(880, 610))
	_sample("f3", Vector2(1450, 400))

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

func _spring(node_name: String, pos: Vector2) -> void:
	var spring := _sensor(node_name, SPRING_SCRIPT, pos, Vector2(128, 42))
	var body := StaticBody2D.new()
	_shape(body, Vector2(128, 18))
	spring.add_child(body)

func _weight(node_name: String, pos: Vector2) -> CharacterBody2D:
	var weight := CharacterBody2D.new()
	weight.name = node_name
	weight.set_script(WEIGHT_SCRIPT)
	weight.position = pos
	_shape(weight, Vector2(56, 56))
	build_parent.add_child(weight)
	return weight

func _switch(node_name: String, pos: Vector2) -> Area2D:
	return _sensor(node_name, SWITCH_SCRIPT, pos, Vector2(108, 26))

func _gate(node_name: String, pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.set_script(GATE_SCRIPT)
	body.gate_size = size
	body.position = pos
	_shape(body, size)
	build_parent.add_child(body)
	return body

func _rock(node_name: String, pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.set_script(ROCK_SCRIPT)
	body.rock_size = size
	body.position = pos
	_shape(body, size)
	build_parent.add_child(body)
	return body

func _moving(node_name: String, pos: Vector2, offset: Vector2, automatic := false) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = node_name
	body.set_script(PLATFORM_SCRIPT)
	body.end_offset = offset
	body.automatic = automatic
	body.position = pos
	_shape(body, Vector2(144, 20))
	body.get_node("CollisionShape2D").one_way_collision = true
	build_parent.add_child(body)
	return body

func _water(node_name: String, pos: Vector2, size: Vector2) -> Area2D:
	var water := Area2D.new()
	water.name = node_name
	water.set_script(WATER_SCRIPT)
	water.trough_size = size
	water.position = pos
	_shape(water, size)
	build_parent.add_child(water)
	water.frozen.connect(func():
		audio.play_cue("reaction")
		_message("冰桥已形成 · 6 秒后融化；再次投放可刷新时间。")
	)
	return water

func _hazard(node_name: String, pos: Vector2, size: Vector2) -> void:
	var hazard := _sensor(node_name, HAZARD_SCRIPT, pos, size)
	hazard.hazard_size = size
	hazard.damage_per_second = 12

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

func _on_switch_changed(active: bool) -> void:
	gate.set_open(active)
	if active:
		objectives[0] = true
		audio.play_cue("gate")
		_message("配重供能成功：吊台上升，隔离门开启。")

func _try_physical_route() -> void:
	if final_route != "":
		return
	var zone: Node = zones[2]
	var plate := zone.get_node("FinalSwitch")
	var magnet := zone.get_node("Magnet")
	if plate.active and magnet.engaged:
		_choose_route("physical")
	elif magnet.engaged:
		_message("铁片锁定成功。再把上层配重推到圆形压板。")
	elif plate.active:
		_message("配重已就位。投掷轻薄铁片到右侧电磁锁。")

func _choose_route(route: String) -> void:
	if final_route != "" or active_checkpoint != 2:
		return
	final_route = route
	objectives[2] = true
	(zones[2].get_node("ExitGate") as StaticBody2D).set_open(true)
	if route == "physical":
		var latch: Node = zones[2].get_node_or_null("ChemicalLatch")
		if latch:
			latch.reaction_enabled = false
	else:
		zones[2].get_node("Magnet").reaction_enabled = false
	_message("出口能量锁已解除 · " + ("物理路线" if route == "physical" else "化学路线"))
	audio.play_cue("checkpoint")

func _oxygen_target(node_name: String, pos: Vector2) -> void:
	var target := StaticBody2D.new()
	target.name = node_name
	target.set_script(TARGET_SCRIPT)
	target.position = pos
	target.collision_layer = 2
	target.collision_mask = 0
	_shape(target, Vector2(50, 72))
	build_parent.add_child(target)
	target.damage_dealt.connect(_on_target_damage)

func _on_target_damage(amount: float, _kind: String) -> void:
	player.gain_oxygen(minf(18, amount * 0.35))
	audio.play_cue("reaction")

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
	audio.play_cue("throw")

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
	pulse.collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	pulse.add_child(collider)
	pulse.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pulse)
	pulse.add_to_group("projectiles")
	audio.play_cue("spring")

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
	var shot: RefCounted = AIR_BALLISTICS.new() if ELEMENTS.is_gas(element) else load("res://solid_ballistics.gd").new()
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
	var index := active_checkpoint
	var old_zone: Node = zones[index]
	old_zone.free()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	objectives[index] = false
	if index == 2:
		final_route = ""
	_build_zone(index)
	player.global_position = CHECKPOINTS[index]
	player.spawn_position = CHECKPOINTS[index]
	player.velocity = Vector2.ZERO
	player.resetting = false
	camera.reset_smoothing()
	_message("已恢复当前舱段 · 机关复位，已收集样本保留。")

func _try_complete() -> void:
	if demo_complete or not objectives[0] or not objectives[1] or not objectives[2] or final_route == "":
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
		file.store_line(JSON.stringify({"version": "level-2", "seconds": elapsed, "deaths": deaths, "resets": resets, "samples": samples.size(), "route": final_route, "shot_uses": shot_uses}))

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
		for index in range(4):
			var style := slots[index].get_theme_stylebox("panel") as StyleBoxFlat
			style.border_color = ELEMENTS.TINTS[index] if index == player.selected_element else Color("#35545d")
			style.set_border_width_all(2 if index == player.selected_element else 1)
			slots[index].modulate = Color.WHITE if index == player.selected_element else Color(0.65, 0.65, 0.65)
	if final_route != "" and not demo_complete:
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
	_label("A/D 移动  W/S 梯子  S 趴下爬行  Q/E 切元素  J 普攻  K 跳跃  L 冲刺  U 技能  I 蓄力  O 大招  R 恢复  Tab 能力  Esc 暂停", Vector2(32, 624), 12, Color("#9db9b8"), ui_layer)
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
		modal_body.text = "路线：%s    用时：%02d:%02d    样本：%d / %d\n失败：%d    主动恢复：%d    发射弹数：%d" % [final_route, int(elapsed) / 60, int(elapsed) % 60, samples.size(), SAMPLE_COUNT, deaths, resets, shot_uses.hydrogen + shot_uses.oxygen + shot_uses.carbon + shot_uses.iron]
		modal_primary.text = "再试另一条路线"
	else:
		modal_title.text = "基础能力" if mode == "skills" else "实验暂停"
		modal_body.text = "Q 上一个 / E 下一个元素：氢 → 氧 → 碳 → 铁 → 氢。\n氢、氧使用压缩气枪；碳、铁使用固体发射器。\n\nJ 普攻；K 跳跃 / 二段跳；L 冲刺。\n按住 I，松开释放当前元素的蓄力弹。\nU 消耗 25 元素能量，冷却 4 秒；O 消耗 100 能量。\n氧使用范围冲击，其他元素使用三发 / 五发扇形射击。\n命中训练靶与蓄力释放补充能量，切换元素保留能量与冷却。\n\nA/D 移动，W/S 梯子，S 趴下爬行。\nR 恢复，Tab 能力面板，Esc 暂停。"
		modal_primary.text = "继续实验"

func _close_modal() -> void:
	if menu_mode == "complete":
		_restart_demo()
		return
	menu_mode = ""
	modal.visible = false
	get_tree().paused = false

func _restart_demo() -> void:
	get_tree().paused = false
	menu_mode = ""
	modal.visible = false
	active_checkpoint = 0
	objectives = [false, false, false]
	final_route = ""
	samples.clear()
	elapsed = 0
	deaths = 0
	resets = 0
	shot_uses = {"hydrogen": 0, "oxygen": 0, "carbon": 0, "iron": 0}
	player.select_element(1)
	demo_complete = false
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
	player.pending_spring_launch = 0
	player.jump_buffer = 0
	player.coyote_remaining = 0
	player.resetting = false
	player.reset_combat()
	player._update_crouch(false)
	player._update_visuals()
	player.restore_stability(100)
	camera.reset_smoothing()
	_message("新实验开始 · 试试另一种解除出口锁的方法。")

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
		draw_string(world_font, Vector2(base + 182, 282), ["MASS / MOMENTUM", "REACTION / PHASE", "CHOOSE YOUR METHOD"][zone_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#638c88"))
	# World-space wiring makes the switch-to-machine relationship visible.
	draw_polyline(PackedVector2Array([Vector2(800, 596), Vector2(800, 552), Vector2(936, 552), Vector2(936, 310), Vector2(1120, 310)]), Color("#628570"), 3)
	draw_line(Vector2(1120, 310), Vector2(1120, 600), Color("#607b80"), 2)
	draw_line(Vector2(1120, 310), Vector2(1824, 310), Color("#628570"), 3)
	draw_circle(Vector2(1120, 310), 15, Color("#a9bbb1"))
	draw_circle(Vector2(1120, 310), 7, Color("#263f47"))
	draw_string(world_font, Vector2(224, 454), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d1bd84"))
	draw_string(world_font, Vector2(746, 643), "配重 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d1bd84"))
	draw_string(world_font, Vector2(2368, 440), "CaCO₃", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#bacebd"))
	draw_string(world_font, Vector2(2948, 670), "COOLANT / 6s", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#91c9d4"))
	draw_string(world_font, Vector2(4420, 448), "↑  配重 + 电磁锁", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d9c290"))
	draw_string(world_font, Vector2(4530, 703), "↓  冷却 + 酸蚀", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#a1cfca"))
	draw_string(world_font, Vector2(5444, 593), "出口 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#a8ddc1"))
