extends Node2D

const PLAYER_SCRIPT = preload("res://player.gd")
const SPRING_SCRIPT = preload("res://spring_platform.gd")
const ROCK_SCRIPT = preload("res://rock.gd")
const HAZARD_SCRIPT = preload("res://hazard.gd")
const WEIGHT_SCRIPT = preload("res://weight.gd")
const SWITCH_SCRIPT = preload("res://switch.gd")
const GATE_SCRIPT = preload("res://gate.gd")
const ACID_SCRIPT = preload("res://acid_bottle.gd")

var player: CharacterBody2D
var stability_bar: ProgressBar
var status_label: Label
var objective_label: Label
var gate: StaticBody2D
var pressure_switch: Area2D
var rock: StaticBody2D
var demo_complete := false
var platform_visuals: Array[Dictionary] = []

func _ready() -> void:
	_ensure_input_actions()
	_build_world()
	_build_ui()
	queue_redraw()

func _process(_delta: float) -> void:
	if player and player.global_position.x > 1450.0 and not demo_complete:
		demo_complete = true
		status_label.text = "演示完成！你通过了力学与简易反应舱。"
		objective_label.text = "Demo 完成 · 按 R 可重置"
		objective_label.modulate = Color("#8ce3b5")

func _ensure_input_actions() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("jump", KEY_W)
	_add_key_action("jump", KEY_UP)
	_add_key_action("use_acid", KEY_Q)
	_add_key_action("reset_demo", KEY_R)

func _add_key_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _build_world() -> void:
	# Main floor and the stepping-stone route through the lab.
	# Full-width floor also covers the spawn area at the far left of the lab.
	_create_platform(Rect2(0, 610, 1700, 76), Color("#2d3f5c"))
	_create_platform(Rect2(220, 475, 220, 24), Color("#49627f"))
	_create_platform(Rect2(515, 390, 180, 24), Color("#49627f"))
	_create_platform(Rect2(790, 465, 170, 24), Color("#49627f"))
	_create_platform(Rect2(1110, 420, 210, 24), Color("#49627f"))
	_create_platform(Rect2(1390, 500, 220, 24), Color("#49627f"))

	# Player and follow camera.
	player = CharacterBody2D.new()
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector2(120, 520)
	var player_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 16.0
	capsule.height = 52.0
	player_shape.shape = capsule
	player.add_child(player_shape)
	add_child(player)
	player.stability_changed.connect(_on_stability_changed)
	player.acid_requested.connect(_spawn_acid)
	player.player_reset.connect(_on_player_reset)
	var camera := Camera2D.new()
	camera.position = Vector2(0, -80)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = 1700
	camera.limit_top = 0
	camera.limit_bottom = 648
	player.add_child(camera)

	# Spring platform: bounce onto the upper route.
	var spring := Area2D.new()
	spring.set_script(SPRING_SCRIPT)
	spring.position = Vector2(365, 570)
	var spring_area_shape := CollisionShape2D.new()
	var spring_area_rect := RectangleShape2D.new()
	spring_area_rect.size = Vector2(128, 42)
	spring_area_shape.shape = spring_area_rect
	spring.add_child(spring_area_shape)
	var spring_body := StaticBody2D.new()
	var spring_body_shape := CollisionShape2D.new()
	var spring_rect := RectangleShape2D.new()
	spring_rect.size = Vector2(128, 18)
	spring_body_shape.shape = spring_rect
	spring_body.add_child(spring_body_shape)
	spring.add_child(spring_body)
	add_child(spring)

	# Pushable counterweight and pressure switch open the gate.
	var weight := RigidBody2D.new()
	weight.set_script(WEIGHT_SCRIPT)
	weight.position = Vector2(500, 535)
	weight.mass = 4.0
	weight.linear_damp = 3.0
	weight.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var weight_shape := CollisionShape2D.new()
	var weight_rect := RectangleShape2D.new()
	weight_rect.size = Vector2(56, 56)
	weight_shape.shape = weight_rect
	weight.add_child(weight_shape)
	add_child(weight)

	pressure_switch = Area2D.new()
	pressure_switch.set_script(SWITCH_SCRIPT)
	pressure_switch.position = Vector2(665, 570)
	var switch_shape := CollisionShape2D.new()
	var switch_rect := RectangleShape2D.new()
	switch_rect.size = Vector2(108, 26)
	switch_shape.shape = switch_rect
	pressure_switch.add_child(switch_shape)
	add_child(pressure_switch)
	pressure_switch.active_changed.connect(_on_switch_changed)

	gate = StaticBody2D.new()
	gate.set_script(GATE_SCRIPT)
	gate.position = Vector2(850, 500)
	var gate_shape := CollisionShape2D.new()
	var gate_rect := RectangleShape2D.new()
	gate_rect.size = Vector2(24, 144)
	gate_shape.shape = gate_rect
	gate.add_child(gate_shape)
	add_child(gate)

	# Acid-reactive carbonate rock blocks the lower passage.
	rock = StaticBody2D.new()
	rock.set_script(ROCK_SCRIPT)
	rock.position = Vector2(1035, 545)
	var rock_shape := CollisionShape2D.new()
	var rock_rect := RectangleShape2D.new()
	rock_rect.size = Vector2(112, 62)
	rock_shape.shape = rock_rect
	rock.add_child(rock_shape)
	add_child(rock)
	rock.dissolved.connect(_on_rock_dissolved)

	# A small corrosion pool teaches the stability system.
	var hazard := Area2D.new()
	hazard.set_script(HAZARD_SCRIPT)
	hazard.position = Vector2(1230, 575)
	var hazard_shape := CollisionShape2D.new()
	var hazard_rect := RectangleShape2D.new()
	hazard_rect.size = Vector2(180, 24)
	hazard_shape.shape = hazard_rect
	hazard.add_child(hazard_shape)
	add_child(hazard)

func _create_platform(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	platform_visuals.append({"rect": rect, "color": color})

func _spawn_acid(origin: Vector2, direction: Vector2) -> void:
	var bottle := Area2D.new()
	bottle.set_script(ACID_SCRIPT)
	bottle.global_position = origin
	bottle.direction = direction
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	shape_node.shape = shape
	bottle.add_child(shape_node)
	add_child(bottle)

func _on_stability_changed(value: float, maximum: float) -> void:
	if stability_bar:
		stability_bar.value = value
		stability_bar.tooltip_text = "稳态值 %.0f / %.0f" % [value, maximum]
	if status_label and value < 40.0:
		status_label.text = "警告：稳态值偏低，避开腐蚀区域！"

func _on_player_reset() -> void:
	if status_label:
		status_label.text = "稳态恢复，回到实验舱入口。"

func _on_switch_changed(active: bool) -> void:
	gate.set_open(active)
	if active:
		status_label.text = "配重压住开关，闸门已开启。"
	else:
		status_label.text = "闸门关闭：推动橙色配重到绿色开关。"

func _on_rock_dissolved() -> void:
	status_label.text = "反应成功：碳酸钙岩石已溶解，通道打开。"

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.position = Vector2(24, 18)
	title.text = "理化实验舱  ·  DEMO 01"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#dbe8ff"))
	layer.add_child(title)

	stability_bar = ProgressBar.new()
	stability_bar.position = Vector2(24, 58)
	stability_bar.size = Vector2(280, 26)
	stability_bar.min_value = 0.0
	stability_bar.max_value = 100.0
	stability_bar.value = 100.0
	stability_bar.show_percentage = false
	stability_bar.add_theme_color_override("font_color", Color("#ffffff"))
	layer.add_child(stability_bar)

	var stability_text := Label.new()
	stability_text.position = Vector2(32, 59)
	stability_text.text = "稳态值"
	stability_text.add_theme_font_size_override("font_size", 16)
	layer.add_child(stability_text)

	objective_label = Label.new()
	objective_label.position = Vector2(24, 105)
	objective_label.text = "目标：推动配重 → 压下开关 → 用 Q 投掷盐酸溶解岩石"
	objective_label.add_theme_font_size_override("font_size", 16)
	objective_label.add_theme_color_override("font_color", Color("#f2d48f"))
	layer.add_child(objective_label)

	var controls := Label.new()
	controls.position = Vector2(24, 610)
	controls.text = "A/D 或 ←/→ 移动    Space 跳跃    Q 投掷盐酸    R 重置"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("#b9c9e7"))
	layer.add_child(controls)

	status_label = Label.new()
	status_label.position = Vector2(24, 142)
	status_label.text = "闸门关闭：推动橙色配重到绿色开关。"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#8ce3b5"))
	layer.add_child(status_label)

func _draw() -> void:
	# Cold-toned laboratory background.
	draw_rect(Rect2(-100, -100, 1900, 850), Color("#0b1426"), true)
	draw_rect(Rect2(-100, 260, 1900, 390), Color("#111f37"), true)
	for x in range(0, 1800, 80):
		draw_line(Vector2(x, 260), Vector2(x, 650), Color(0.16, 0.26, 0.4, 0.28), 1.0)
	for y in range(280, 650, 56):
		draw_line(Vector2(0, y), Vector2(1800, y), Color(0.16, 0.26, 0.4, 0.2), 1.0)
	# Pipes, lamps and lab silhouettes.
	draw_line(Vector2(60, 210), Vector2(1540, 210), Color("#324e6c"), 8.0)
	draw_line(Vector2(210, 210), Vector2(210, 290), Color("#324e6c"), 8.0)
	draw_line(Vector2(1040, 210), Vector2(1040, 320), Color("#324e6c"), 8.0)
	for x in [100, 480, 900, 1320]:
		draw_circle(Vector2(x, 205), 10.0, Color("#f2d48f"))
	for item in platform_visuals:
		var rect: Rect2 = item["rect"]
		var color: Color = item["color"]
		draw_rect(rect, color, true)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("#83a2c7"), 3.0)
	# Objective markers.
	draw_string(ThemeDB.fallback_font, Vector2(598, 532), "配重开关", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f2d48f"))
	draw_string(ThemeDB.fallback_font, Vector2(970, 478), "碳酸钙岩石", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c4d2dc"))
	draw_string(ThemeDB.fallback_font, Vector2(1170, 548), "腐蚀区", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f27fbe"))
