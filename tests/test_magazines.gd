extends SceneTree

const MAIN = preload("res://main.tscn")
var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []
var shots := 0
var pulses := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	player.element_projectile_requested.connect(func(_origin, _direction, _damage, _kind, _element): shots += 1)
	player.oxygen_pulse_requested.connect(func(_origin, _radius, _damage, _kind): pulses += 1)
	await _frames(30)
	for index in range(4):
		player.select_element(index)
		player.reset_combat()
		var capacity: int = 12 if index < 2 else 6
		var before := shots
		_expect(player.magazine_ammo[index] == capacity and player.magazine_capacity() == capacity, "Wrong capacity")
		for round_index in range(capacity):
			await _tap(KEY_J)
			_expect(player.magazine_ammo[index] == capacity - round_index - 1, "Normal shot ammo count is wrong")
		_expect(shots - before == capacity, "Last round was lost or extra round was fired")
		_expect(player.is_reloading() and not player.charging, "Empty magazine did not auto-reload")
		_expect(world.ammo_label.text.begins_with("换弹"), "HUD did not show reload countdown")
		_expect(player.weapon_visual.reload_progress >= 0, "Reload visual did not start")
		if index >= 2:
			_expect(player.weapon_visual.sprite.texture.resource_path.ends_with("solid_launcher_reload_strip.png"), "Solid magazine animation missing")
		before = shots
		var before_pulses := pulses
		var before_energy: float = player.oxygen_energy
		await _tap(KEY_J)
		await _tap(KEY_U)
		await _tap(KEY_I)
		await _tap(KEY_O)
		_expect(shots == before and pulses == before_pulses and not player.charging, "Attack or charge bypassed reload")
		_expect(player.oxygen_energy == before_energy and player.skill_cooldown == 0, "Blocked attack spent energy/cooldown")
		await _frames(int(ceil(player.reload_remaining[index] * 60)) + 2)
		_expect(not player.is_reloading() and player.magazine_ammo[index] == capacity, "Reload did not refill")
		_expect(player.weapon_visual.reload_progress < 0 and player.weapon_visual.sprite.hframes == 6, "Reload animation did not restore shot texture")
		_expect(world.ammo_label.text == "弹 %d / %d" % [capacity, capacity], "HUD did not show refilled magazine")
		await _tap(KEY_J)
		_expect(shots == before + 1 and player.magazine_ammo[index] == capacity - 1, "Cannot shoot after reload")
		for projectile in get_nodes_in_group("projectiles"):
			projectile.queue_free()
		await _frames(2)
	await _test_charge_and_volley()
	await _test_switch_pause_movement_reset()
	world.free()
	await process_frame
	if failures.is_empty():
		print("PASS: 12/6 capacities, exact last round, reload blocking/animations/HUD, charged and volley costs, no partial skill spending, switch/pause/movement/reset")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_charge_and_volley() -> void:
	player.select_element(3)
	player.reset_combat()
	_key(KEY_I, true)
	await _frames(10)
	_expect(player.magazine_ammo[3] == 6, "Charge start spent ammo")
	await _tap(KEY_Q)
	_key(KEY_I, false)
	await _frames(2)
	_expect(player.magazine_ammo[3] == 6 and player.magazine_ammo[2] == 6, "Cancelled charge spent ammo")
	var before := shots
	_key(KEY_I, true)
	await _frames(10)
	_key(KEY_I, false)
	await _frames(2)
	_expect(shots == before + 1 and player.magazine_ammo[2] == 5, "Charged release did not cost one round")
	await _tap(KEY_U)
	_expect(player.magazine_ammo[2] == 2 and shots == before + 4, "Three-shot skill did not cost three rounds")
	player.gain_oxygen(100)
	var before_cooldown: float = player.skill_cooldown
	before = shots
	await _tap(KEY_O)
	_expect(shots == before and player.magazine_ammo[2] == 2 and player.is_reloading(), "Insufficient ammo emitted partial ultimate")
	_expect(player.oxygen_energy == 100 and player.skill_cooldown < before_cooldown, "Rejected ultimate spent resources")
	await _frames(52)
	await _tap(KEY_O)
	_expect(shots == before + 5 and player.magazine_ammo[2] == 1 and player.oxygen_energy == 0, "Five-round ultimate did not fire atomically")
	player.select_element(1)
	player.reset_combat()
	await _tap(KEY_U)
	_expect(player.magazine_ammo[1] == 11, "Oxygen pulse did not cost one packet")
	player.gain_oxygen(100)
	await _tap(KEY_O)
	_expect(player.magazine_ammo[1] == 10, "Oxygen field did not cost one packet")
	player.select_element(3)
	player.reset_combat()
	# Exhaust a solid magazine via a five-round volley plus a charged final round.
	await _tap(KEY_O)
	_key(KEY_I, true)
	await _frames(10)
	_key(KEY_I, false)
	await _frames(2)
	_expect(player.magazine_ammo[3] == 0 and player.is_reloading(), "Charged last round did not start reload")

func _test_switch_pause_movement_reset() -> void:
	var remaining: float = player.reload_remaining[3]
	player.select_element(1)
	await _frames(15)
	_expect(player.reload_remaining[3] == remaining and player.magazine_ammo[3] == 0, "Switch refilled or advanced stowed magazine")
	player.select_element(3)
	await _frames(3)
	_expect(player.reload_remaining[3] < remaining and player.is_reloading(), "Returning did not resume reload")
	world._show_modal("pause")
	remaining = player.reload_remaining[3]
	await _frames(12)
	_expect(player.reload_remaining[3] == remaining, "Pause advanced reload")
	world._close_modal()
	player.position = Vector2(160, 584)
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	await _frames(3)
	Input.action_press("move_right")
	await _frames(5)
	Input.action_release("move_right")
	_expect(player.position.x > 160, "Reload blocked movement")
	await _tap(KEY_K)
	_expect(player.velocity.y < 0 and player.is_reloading(), "Reload blocked jump")
	player.facing = 1
	await _tap(KEY_L)
	_expect(player.dash_timer > 0 and player.is_reloading(), "Reload blocked dash")
	player.reset_to_spawn()
	await _frames(6)
	_expect(player.selected_element == 3 and player.magazine_ammo == [12, 12, 6, 6] and not player.is_reloading(), "Respawn did not reset magazines")
	player.magazine_ammo[3] = 0
	player._start_reload()
	world._restart_demo()
	_expect(player.selected_element == 1 and player.magazine_ammo == [12, 12, 6, 6] and player.reload_remaining == [0.0, 0.0, 0.0, 0.0], "Restart kept stale ammo/reload")

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
	for index in range(count):
		await physics_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
