extends SceneTree

const MAIN := preload("res://main.tscn")
var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []
var attacks := {"normal": 0, "charged": 0, "skill": 0, "ultimate": 0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	player.oxygen_projectile_requested.connect(func(_o, _d, _damage, kind): attacks[kind] += 1)
	player.oxygen_pulse_requested.connect(func(_o, _r, _damage, kind): attacks[kind] += 1)
	await _frames(40)
	await _keys_and_visuals()
	await _attacks()
	await _dash()
	await _pause_and_reset()
	paused = false
	world.free()
	await process_frame
	if failures.is_empty():
		print("PASS: physical K/L keys, oxygen hits/costs, charge, dash collisions/hazards, pause and all resets")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		print("FAIL: combat checks")
		quit(1)

func _keys_and_visuals() -> void:
	_expect(world.stability_bar.position.y + world.stability_bar.size.y <= world.oxygen_bar.position.y, "Stability and oxygen bars overlap: sizes %s / %s min %s bg %s font %d" % [world.stability_bar.size, world.oxygen_bar.size, world.stability_bar.get_minimum_size(), world.stability_bar.get_theme_stylebox("background").get_minimum_size(), world.stability_bar.get_theme_font_size("font_size")])
	_expect(world.oxygen_bar.position.y + world.oxygen_bar.size.y <= 106, "Oxygen bar extends past the HUD panel")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	_expect(not InputMap.action_has_event("jump", space), "Old Space jump binding remained")
	_key(KEY_K, true)
	await _frames(3)
	_expect(player.velocity.y < -400, "Physical K key did not jump")
	_key(KEY_K, false)
	await _frames(60)
	_expect(player.hero_sprite.texture.get_width() / player.hero_sprite.hframes == 32 and player.hero_sprite.texture.get_height() == 48, "Hero animation frame was not loaded")
	_expect(player.hero_sprite.scale == Vector2(2, 2), "Standing sprite did not use the scene display scale")
	_expect(is_equal_approx(player.hero_sprite.position.y + 48, 26), "Sprite feet do not align with collider")
	# A real low ceiling keeps the crouched body short until it clears the roof.
	var roof := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 20)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	roof.add_child(collider)
	root.add_child(roof)
	roof.position = Vector2(190, 559)
	Input.action_press("move_down")
	_place(Vector2(190, 584))
	await _frames(3)
	Input.action_release("move_down")
	await _frames(3)
	_expect(player.crouching and player.hero_sprite.scale.y < 2, "Low ceiling allowed standing or sprite did not crouch")
	roof.free()
	await _frames(3)
	_expect(not player.crouching, "Player could not stand after removing the ceiling")

func _attacks() -> void:
	world.objectives[0] = true
	_place(Vector2(2144, 584))
	await _frames(5)
	_expect(world.active_checkpoint == 1, "Combat test failed to reach checkpoint")
	_place(Vector2(2678, 444))
	await _frames(5)
	player.oxygen_energy = 20
	var target: StaticBody2D = world.zones[1].get_node("OxygenTarget0")
	var initial_health: float = target.health
	await _tap(KEY_J)
	await _frames(12)
	_expect(target.health == initial_health - 12 and attacks.normal == 1, "Normal projectile did not hit the target once")
	_expect(player.oxygen_energy > 20, "Target hit did not refill oxygen")
	_key(KEY_I, true)
	await _frames(90)
	_expect(player.charging and is_equal_approx(player.charge_time, player.MAX_CHARGE_TIME), "Charge was not clamped at maximum")
	_key(KEY_I, false)
	await _frames(16)
	_expect(attacks.charged == 1 and target.health <= 18.01, "Charged projectile did not damage the target")
	_expect(not player.charging and player.charge_time == 0 and world.charge_bar.value == 0, "Released charge did not clear UI/state")
	_place(Vector2(160, 584))
	player.reset_combat()
	player.consume_oxygen(50)
	await _tap(KEY_U)
	_expect(player.oxygen_energy == 25 and attacks.skill == 1, "Skill did not consume exactly 25 oxygen")
	_expect(world.oxygen_bar.value == 25, "Oxygen HUD did not update")
	await _tap(KEY_U)
	_expect(attacks.skill == 1, "Skill bypassed cooldown")
	player.skill_cooldown = 0
	player.consume_oxygen(20)
	await _tap(KEY_U)
	_expect(attacks.skill == 1, "Skill fired with insufficient oxygen")
	await _tap(KEY_O)
	_expect(attacks.ultimate == 0, "Ultimate fired without full oxygen")
	player.gain_oxygen(100)
	await _tap(KEY_O)
	_expect(player.oxygen_energy == 0 and attacks.ultimate == 1, "Ultimate did not require/consume full oxygen")
	await _frames(20)
	# Pulses hit each target only once; chemical materials stay unaffected.
	_place(Vector2(2678, 444))
	player.reset_combat()
	var other_target: StaticBody2D = world.zones[1].get_node("OxygenTarget1")
	var before_pulse: float = other_target.health
	await _tap(KEY_U)
	await _frames(20)
	_expect(other_target.health == before_pulse - 34, "Pulse missed or hit a target repeatedly")
	_expect(target.defeated, "Training target did not enter defeated state")
	await _frames(130)
	_expect(not target.defeated and target.health == 100, "Training target did not respawn")
	var rock: StaticBody2D = world.zones[1].get_node("CarbonateRock")
	world._spawn_oxygen_projectile(Vector2(2440, 540), Vector2.RIGHT, 70, "charged")
	await _frames(15)
	_expect(not rock.dissolving and not world.objectives[1], "Oxygen attack bypassed the carbonate puzzle")
	_place(Vector2(2190, 584))
	player.reset_combat()
	await _tap(KEY_O)
	await _frames(20)
	_expect(not rock.dissolving and not world.zones[1].get_node("ReactionGate").is_open, "Oxygen pulse opened a chemical gate")

func _dash() -> void:
	_place(Vector2(160, 584))
	await _frames(4)
	player.reset_combat()
	player.skill_cooldown = 3
	player.gravity_cooldown = 3
	player.acid_cooldown = 0.5
	_key(KEY_L, true)
	await _frames(2)
	_key(KEY_L, false)
	var start_x := player.position.x
	Input.action_press("move_left")
	await _frames(5)
	_expect(player.position.x > start_x + 40 and player.velocity.x == 900, "Dash reversed when direction changed: x=%.2f start=%.2f vx=%.2f timer=%.3f" % [player.position.x, start_x, player.velocity.x, player.dash_timer])
	_expect(player.skill_cooldown < 3 and player.gravity_cooldown < 3 and player.acid_cooldown < 0.5, "Dash froze other cooldowns")
	Input.action_release("move_left")
	await _frames(8)
	_expect(player.dash_timer == 0, "Dash did not end after its duration")
	_place(Vector2(1800, 584))
	await _frames(4)
	player.reset_combat()
	await _tap(KEY_L)
	_expect(player.dash_timer == 0 and player.position.x <= 1808.1, "Dash passed through the gate or did not stop on impact")
	_place(Vector2(160, 584))
	player.reset_combat()
	Input.action_press("move_down")
	await _frames(4)
	await _tap(KEY_L)
	_expect(player.crouching and player.dash_cooldown == 0, "Dash started while crouched")
	Input.action_release("move_down")
	await _frames(3)
	_place(Vector2(713, 550))
	Input.action_press("move_up")
	await _frames(4)
	player.reset_combat()
	await _tap(KEY_L)
	_expect(player.is_climbing and player.dash_cooldown == 0, "Dash started on a ladder")
	Input.action_release("move_up")
	_place(Vector2(3540, 584))
	player.reset_combat()
	player.stability = 100
	await _tap(KEY_L)
	await _frames(6)
	_expect(player.stability < 100, "Dash ignored corrosion damage")
	var before_deaths: int = world.deaths
	_place(Vector2(160, 930))
	player.reset_combat()
	await _tap(KEY_L)
	await _frames(6)
	_expect(world.deaths == before_deaths + 1 and player.position.y < 650, "Dash bypassed fall/respawn detection")

func _pause_and_reset() -> void:
	world._restart_demo()
	await _frames(30)
	_key(KEY_I, true)
	await _frames(4)
	world._show_modal("pause")
	var before_position := player.position
	var before_charge: float = player.charge_time
	var before_attacks: int = attacks.normal
	await _tap(KEY_J)
	_key(KEY_I, false)
	await _frames(8)
	_expect(player.position == before_position and player.charge_time == before_charge and attacks.normal == before_attacks, "Pause did not freeze movement/charge/attacks")
	world._close_modal()
	await _frames(4)
	_expect(not player.charging, "Releasing charge while paused got stuck on resume")
	world._spawn_oxygen_pulse(player.position, 160, 30, "skill")
	player.oxygen_energy = 3
	player.charging = true
	player.charge_time = 1
	player.skill_cooldown = 3
	player.dash_cooldown = 0.7
	player.dash_timer = 0.1
	await _tap(KEY_R)
	await _frames(4)
	_expect(player.oxygen_energy == 100 and not player.charging and player.dash_timer == 0 and player.dash_cooldown == 0 and player.skill_cooldown == 0, "R did not reset all combat state")
	_expect(get_nodes_in_group("projectiles").is_empty(), "R left an attack/projectile behind")
	var before_deaths: int = world.deaths
	player.take_damage(101)
	player.take_damage(101)
	await _frames(6)
	_expect(world.deaths == before_deaths + 1 and player.oxygen_energy == 100, "Stability depletion reset twice or lost oxygen")
	player.oxygen_energy = 0
	player.charging = true
	player.dash_cooldown = 0.5
	world._restart_demo()
	await _frames(6)
	_expect(player.oxygen_energy == 100 and not player.charging and player.dash_cooldown == 0, "Whole-level restart kept combat state")

func _place(pos: Vector2) -> void:
	player.position = pos
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	player.pending_spring_launch = 0
	player.facing = 1

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)

func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAILED CHECK: ", message)
