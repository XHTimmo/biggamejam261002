extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")

var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	await _wait_physics(20)
	player = world.get_node("Player") as CharacterBody2D

	await _test_ladder()
	await _test_spring()
	await _test_weight_switch_and_gate()
	await _test_acid_and_rock()
	await _test_corrosion_hazard()

	if failures.is_empty():
		print("PASS: ladder and all interactive modules responded correctly")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ladder() -> void:
	player.global_position = Vector2(713.0, 580.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(3)
	var start_y := player.global_position.y
	Input.action_press("move_up")
	await _wait_physics(24)
	Input.action_release("move_up")
	_expect(player.global_position.y < start_y - 45.0, "Ladder did not move the player upward")


func _test_spring() -> void:
	player.global_position = Vector2(330.0, 410.0)
	player.velocity = Vector2(0.0, 180.0)
	await _wait_physics(24)
	_expect(
		player.global_position.y < 380.0,
		"Spring did not launch the player (y=%.2f, vy=%.2f)" % [player.global_position.y, player.velocity.y]
	)


func _test_weight_switch_and_gate() -> void:
	var weight := world.get_node("Zone0/Counterweight") as CharacterBody2D
	var gate := world.get_node("Zone0/Gate")
	player.global_position = Vector2(550.0, 584.0)
	player.velocity = Vector2.ZERO
	weight.global_position = Vector2(608.0, 582.0)
	weight.velocity = Vector2.ZERO
	await _wait_physics(3)
	var start_x := weight.global_position.x
	Input.action_press("move_right")
	await _wait_physics(36)
	Input.action_release("move_right")
	var query_shape := RectangleShape2D.new()
	query_shape.size = Vector2(20.0, 40.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, player.global_position + Vector2(26.0, 5.0))
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var hits := player.get_world_2d().direct_space_state.intersect_shape(query, 8)
	var hit_names: Array[String] = []
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider:
			hit_names.append(collider.name)
	_expect(
		weight.global_position.x > start_x + 8.0,
		"Player could not push the counterweight (start=%.2f, end=%.2f, vx=%.2f, player=%.2f, hits=%s)" % [
			start_x, weight.global_position.x, weight.velocity.x, player.global_position.x, str(hit_names)
		]
	)

	weight.global_position = Vector2(800.0, 582.0)
	weight.velocity = Vector2.ZERO
	await _wait_physics(8)
	_expect(gate.is_open, "Counterweight did not open the gate through the switch")

	weight.global_position = Vector2(900.0, 582.0)
	weight.velocity = Vector2.ZERO
	await _wait_physics(8)
	_expect(not gate.is_open, "Gate stayed open after the counterweight left the switch")


func _test_acid_and_rock() -> void:
	var rock := world.get_node("Zone1/CarbonateRock")
	world._spawn_acid(Vector2(2410.0, 545.0), Vector2.RIGHT)
	await _wait_physics(16)
	_expect(rock.dissolving, "Acid bottle did not trigger the carbonate rock")


func _test_corrosion_hazard() -> void:
	player.stability = player.MAX_STABILITY
	player.global_position = Vector2(3588.0, 584.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(20)
	_expect(player.stability < player.MAX_STABILITY, "Corrosion area did not reduce stability")


func _wait_physics(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
