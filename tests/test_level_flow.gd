extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
var world: Node
var player: CharacterBody2D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	player = world.player
	await _frames(40)
	_expect(player.is_on_floor(), "Spawn is not grounded")
	await _test_locked_exit()
	await _test_movement()
	await _test_mechanics_and_checkpoint()
	await _test_chemistry_and_restore()
	await _test_two_final_routes()
	paused = false
	if failures.is_empty():
		print("PASS: legacy level fixtures, movement, ice expiry, checkpoint restoration, route states and exit guards (not player walkthrough)")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		print("FAIL: ", failures.size(), " level flow checks")
		quit(1)

func _test_locked_exit() -> void:
	world._marker_activated(world.zones[2].get_node("Exit"))
	_expect(not world.demo_complete, "Exit bypassed unsolved objectives")
	_expect(world.zones[0].get_node("Gate").get_node("CollisionShape2D").shape.size.y >= 480, "First gate has a walk/jump bypass")

func _test_movement() -> void:
	_place(Vector2(160, 584))
	await _frames(4)
	Input.action_press("jump")
	await _frames(10)
	Input.action_release("jump")
	await _frames(4)
	var before_second := player.velocity.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(player.velocity.y < before_second - 100, "Air spray boost did not refresh upward velocity")
	_expect(not player.air_spray_available and player.air_spray_timer > 0, "Air spray boost did not consume its charge")
	await _frames(70)
	_place(Vector2(713, 582))
	await _frames(4)
	Input.action_press("move_up")
	await _frames(20)
	Input.action_release("move_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(not player.is_climbing and player.velocity.y < -200, "Ladder jump detach failed")
	await _frames(60)

func _test_mechanics_and_checkpoint() -> void:
	_place(Vector2(550, 584))
	var weight: CharacterBody2D = world.zones[0].get_node("Counterweight")
	weight.position = Vector2(608, 582)
	weight.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("move_right")
	for _index in range(180):
		await _frames(1)
		if world.pressure_switch.active:
			break
	Input.action_release("move_right")
	_expect(weight.position.x > 700, "Cannot push weight onto its switch: weight %s player %s" % [weight.position, player.position])
	_expect(world.pressure_switch.active and world.gate.is_open, "Weight did not open gate")
	_expect(world.zones[0].get_node("PulleyLift").activated, "Switch did not power pulley lift")
	var lift: AnimatableBody2D = world.zones[0].get_node("PulleyLift")
	await _frames(120)
	_place(lift.global_position + Vector2(0, -40))
	await _frames(15)
	_expect(player.is_on_floor(), "Player cannot stand on a moving platform")
	_place(Vector2(2144, 584))
	await _frames(5)
	_expect(world.active_checkpoint == 1, "Second checkpoint failed")

func _test_chemistry_and_restore() -> void:
	var old_zone0_id: int = world.zones[0].get_instance_id()
	world.zones[1].get_node("CarbonateRock").acid_hit()
	await _frames(55)
	_expect(world.zones[1].get_node_or_null("CarbonateRock") == null, "Acid did not remove the rock")
	_expect(world.zones[1].get_node("ReactionGate").is_open, "Acid did not open reaction gate")
	_place(Vector2(2900, 584))
	# Exercise unchanged level modules with fixtures, independently of player abilities.
	world.zones[1].get_node("TeachingWater").freeze_hit()
	await _frames(15)
	var water: Area2D = world.zones[1].get_node("TeachingWater")
	_expect(water.freeze_remaining > 0 and not water.ice_collision.disabled, "Water fixture did not freeze")
	_place(Vector2(3060, 548))
	await _frames(8)
	_expect(player.is_on_floor(), "Ice bridge has no usable collision")
	Input.action_press("move_right")
	await _frames(100)
	Input.action_release("move_right")
	_expect(player.global_position.x > 3448 and player.global_position.y < 650, "Ice bridge cannot be crossed")
	_place(Vector2(3450, 584))
	await _frames(390)
	_expect(water.freeze_remaining == 0 and water.ice_collision.disabled, "Ice did not melt")
	# Collect a sample, then ensure only the current zone is re-instantiated.
	world._marker_activated(world.zones[1].get_node("Sample_c1"))
	player.reset_to_spawn("manual")
	await _frames(6)
	_expect(world.active_checkpoint == 1, "Reset lost checkpoint")
	_expect(world.zones[0].get_instance_id() == old_zone0_id, "Reset modified a completed zone")
	_expect(world.zones[1].get_node_or_null("CarbonateRock") != null, "Reset did not restore the acid puzzle")
	_expect(not world.zones[1].get_node("ReactionGate").is_open, "Reset left the gate open")
	_expect(world.samples.has("c1") and world.zones[1].get_node_or_null("Sample_c1") == null, "Sample duplicated after reset")
	_expect(not player.resetting, "Reset froze player")
	world.zones[1].get_node("CarbonateRock").acid_hit()
	await _frames(55)
	_place(Vector2(4192, 584))
	await _frames(5)
	_expect(world.active_checkpoint == 2, "Final checkpoint failed")

func _test_two_final_routes() -> void:
	var lift: AnimatableBody2D = world.zones[2].get_node("GravityLift")
	_place(Vector2(4572, 553))
	await _frames(5)
	lift.gravity_hit()
	await _frames(165)
	_expect(lift.progress > 0.9, "Gravity skill did not lift the platform")
	_expect(player.is_on_floor() and player.global_position.y < 338, "Player was not carried by the lift")
	# Test the platform's actual upper landing, then walk/push the full upper route.
	Input.action_press("move_right")
	await _frames(100)
	Input.action_release("move_right")
	_expect(player.global_position.x > 4760 and player.global_position.y < 370, "Cannot dismount lift onto upper route")
	_place(Vector2(4708, 334))
	await _frames(5)
	Input.action_press("move_right")
	for _index in range(300):
		await _frames(1)
		if world.zones[2].get_node("FinalSwitch").active:
			break
	Input.action_release("move_right")
	_expect(world.zones[2].get_node("FinalSwitch").active, "Upper route weight cannot reach final switch")
	world.zones[2].get_node("Magnet").iron_hit()
	await _frames(15)
	_expect(world.final_route == "physical" and world.zones[2].get_node("ExitGate").is_open, "Physical route did not unlock exit")
	world._choose_route("chemical")
	_expect(world.final_route == "physical", "Alternative route overwrote physical result")
	_expect(not world.zones[2].get_node("ChemicalLatch").reaction_enabled, "Unchosen chemical route stayed active")
	player.reset_to_spawn("manual")
	await _frames(6)
	_expect(world.final_route == "" and not world.zones[2].get_node("ExitGate").is_open, "Reset did not restore final route choice")
	# Lower route: frozen bridge, acid latch, then physical traversal to the exit.
	var water: Area2D = world.zones[2].get_node("FinalWater")
	_place(Vector2(4716, 716))
	water.freeze_hit()
	await _frames(12)
	_expect(water.freeze_remaining > 0, "Final water could not be frozen")
	_place(Vector2(4790, 677))
	await _frames(8)
	Input.action_press("move_right")
	await _frames(100)
	Input.action_release("move_right")
	_expect(player.global_position.x > 5220 and player.global_position.y < 770, "Lower route ice crossing failed")
	world.zones[2].get_node("ChemicalLatch").acid_hit()
	await _frames(55)
	_expect(world.final_route == "chemical" and world.zones[2].get_node("ExitGate").is_open, "Chemical route did not unlock exit")
	_expect(not world.zones[2].get_node("Magnet").reaction_enabled, "Unchosen physical route stayed active")
	world._choose_route("physical")
	_expect(world.final_route == "chemical", "Physical result overwrote chemical choice")
	_place(Vector2(6056, 584))
	await _frames(5)
	_expect(world.demo_complete and paused, "Exit did not show completion")
	world._restart_demo()
	await _frames(12)
	_expect(not world.demo_complete and not paused and world.active_checkpoint == 0, "Completion restart failed")
	_expect(world.samples.is_empty() and player.selected_element == 1, "New run retained old progression")

func _place(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	player.pending_spring_launch = 0
	player.jump_buffer = 0
	player.coyote_remaining = 0

func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("FAILED CHECK: ", message)
