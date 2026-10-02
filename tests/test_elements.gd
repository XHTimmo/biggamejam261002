extends SceneTree

const MAIN = preload("res://main.tscn")
const CATALOG = preload("res://scripts/shared/element_catalog.gd")
const AIR = preload("res://scripts/combat/ballistics/air_gun_environment.gd")
const GAS = preload("res://scripts/combat/ballistics/air_gun_ballistics.gd")
const SOLID = preload("res://scripts/combat/ballistics/solid_ballistics.gd")
var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []
var shots: Array[Dictionary] = []
var pulses := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	player.element_projectile_requested.connect(func(origin, direction, damage, kind, element): shots.append({"origin": origin, "direction": direction, "damage": damage, "kind": kind, "element": element}))
	player.oxygen_pulse_requested.connect(func(_origin, _radius, _damage, _kind): pulses += 1)
	await _frames(35)
	_expect(player.selected_element == 1, "Default element is not oxygen")
	for action in ["use_acid", "throw_item", "gravity_skill", "next_item", "previous_item", "slot_1", "slot_2", "slot_3"]:
		_expect(not InputMap.has_action(action), "Retired action remains: " + action)
	await _tap(KEY_Q)
	_expect(player.selected_element == 0, "Q did not select previous element")
	await _tap(KEY_Q)
	_expect(player.selected_element == 3, "Q did not wrap hydrogen to iron")
	await _tap(KEY_E)
	_expect(player.selected_element == 0, "E did not wrap iron to hydrogen")
	await _tap(KEY_E)
	_expect(player.selected_element == 1 and shots.is_empty(), "Switching fired ammunition")
	for index in range(4):
		player.select_element(index)
		player.reset_combat()
		var element: String = CATALOG.IDS[index]
		var family := "compressed_air_gun" if index < 2 else "solid_launcher"
		_expect(player.weapon_visual.sprite.texture.resource_path.ends_with(family + "_shot_strip.png"), "Wrong weapon for " + element)
		player.facing = -1
		await _tap(KEY_J)
		var shot: Dictionary = shots.back()
		_expect(shot.element == element and shot.kind == "normal", "Wrong normal ammo for " + element)
		_expect(shot.direction.x < 0 and shot.origin.distance_to(player._attack_origin()) < 0.1, "Left-facing muzzle mismatch")
		# Inspect a live round's animation and physical material without relying on level puzzles.
		world._spawn_element_projectile(Vector2(250, 250), Vector2.RIGHT, 12, "normal", element)
		var live: Node = get_nodes_in_group("projectiles").back()
		_expect(live.sprite.texture.resource_path.ends_with(element + "/normal_flight_strip.png"), "Wrong flight animation for " + element)
		live._spawn_impact()
		var effect := world.get_child(world.get_child_count() - 2) as AnimatedSprite2D if index < 2 else world.get_child(world.get_child_count() - 1) as AnimatedSprite2D
		_expect(effect != null, "Impact animation missing for " + element)
		if effect:
			var frame: AtlasTexture = effect.sprite_frames.get_frame_texture("default", 0)
			_expect(frame.atlas.resource_path.ends_with(element + "/normal_impact_strip.png"), "Wrong impact animation for " + element)
		_key(KEY_I, true)
		await _frames(88)
		_key(KEY_I, false)
		await _frames(2)
		shot = shots.back()
		_expect(shot.element == element and shot.kind == "charged" and is_equal_approx(shot.damage, CATALOG.CHARGED_DAMAGE[index]), "Wrong charged round for " + element)
		var before := shots.size()
		var before_pulses := pulses
		await _tap(KEY_U)
		_expect(player.oxygen_energy == 75 and player.skill_cooldown > 0, "U resource/cooldown mismatch")
		_expect(shots.size() - before == (0 if index == 1 else 3), "U shot count mismatch")
		_expect(pulses - before_pulses == (1 if index == 1 else 0), "Non-oxygen element emitted oxygen pulse")
		player.select_element((index + 1) % 4)
		_expect(player.oxygen_energy == 75 and player.skill_cooldown > 0, "Switch bypassed resource/cooldown")
		player.select_element(index)
		# Exercise O independently with a full magazine and full energy.
		player.reset_combat()
		before = shots.size()
		before_pulses = pulses
		await _tap(KEY_O)
		_expect(player.oxygen_energy == 0, "O did not consume full energy")
		_expect(shots.size() - before == (0 if index == 1 else 5), "O shot count mismatch")
		_expect(pulses - before_pulses == (1 if index == 1 else 0), "Wrong O effect family")
		for projectile in get_nodes_in_group("projectiles"):
			projectile.queue_free()
		await _frames(2)
	player.select_element(1)
	_key(KEY_I, true)
	await _frames(10)
	var before := shots.size()
	await _tap(KEY_E)
	_key(KEY_I, false)
	await _frames(3)
	_expect(player.selected_element == 2 and not player.charging and player.charge_time == 0 and shots.size() == before, "Switch did not cancel old charge")
	world._show_modal("pause")
	await _tap(KEY_Q)
	_expect(player.selected_element == 2, "Paused input changed element")
	world._close_modal()
	await _frames(2)
	_expect(player.selected_element == 2, "Paused switch replayed on resume")
	player.reset_to_spawn()
	await _frames(5)
	_expect(player.selected_element == 2 and not player.resetting, "Checkpoint reset lost selection")
	world._restart_demo()
	_expect(player.selected_element == 1, "New run did not restore default oxygen")
	_test_physics()
	world.free()
	await process_frame
	if failures.is_empty():
		print("PASS: physical Q/E cycling, four weapons/ammo animations, J/I/U/O, charge cancellation, shared cooldown, pause/reset and gas/solid physics")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_physics() -> void:
	var air := AIR.new()
	var hydrogen := GAS.new()
	hydrogen.molar_mass_ratio = 2.016 / 28.965
	hydrogen.launch(Vector2.RIGHT, 1.0, air)
	var oxygen := GAS.new()
	oxygen.launch(Vector2.RIGHT, 1.0, air)
	_expect(hydrogen.buoyancy_acceleration() < 0 and oxygen.buoyancy_acceleration() > 0, "Gas buoyancy directions are wrong")
	for element in ["carbon", "iron"]:
		var solid := SOLID.new()
		solid.element = element
		solid.launch(Vector2.RIGHT, 1.0, air)
		solid.advance(0.5)
		_expect(solid.position_m.y > 0 and solid.velocity_mps.x < solid.initial_speed_mps, "Solid ignores gravity/drag")

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
