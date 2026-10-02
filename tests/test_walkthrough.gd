extends SceneTree

const MAIN := preload("res://main.tscn")
var world: Node
var player: CharacterBody2D
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	await _frames(40)
	# Every step below uses player input. No teleport, direct reaction call,
	# gate manipulation or checkpoint manipulation is used in this test.
	Input.action_press("move_right")
	var previous_x := player.position.x
	var stalled := 0
	for _index in range(600):
		await _frames(1)
		if world.pressure_switch.active:
			break
		stalled = stalled + 1 if absf(player.position.x - previous_x) < 0.5 else 0
		previous_x = player.position.x
		if stalled > 18 and player.position.x < 540:
			await _jump(18)
			stalled = 0
	Input.action_release("move_right")
	if not _check(world.pressure_switch.active, "Tutorial plate not reachable"):
		return
	Input.action_press("move_right")
	await _jump(24)
	Input.action_release("move_right")
	await _frames(35)
	if not await _travel(940, 180):
		return
	Input.action_press("move_right")
	await _jump(19)
	await _frames(3)
	await _jump(18)
	Input.action_release("move_right")
	await _frames(35)
	if not _check(player.position.x > 1048 and player.position.x < 1192 and player.position.y < 425, "Pulley landing is unreachable"):
		return
	Input.action_press("move_right")
	await _jump(20)
	await _frames(4)
	await _jump(20)
	await _frames(55)
	Input.action_release("move_right")
	if not await _travel(2144, 300):
		return
	await _frames(8)
	if not _check(world.active_checkpoint == 1, "Cannot cross first gate"):
		return
	if not await _travel(2400, 120):
		return
	await _press("slot_1")
	await _press("use_acid")
	await _frames(55)
	if not _check(world.objectives[1], "Cannot solve acid seal using Q"):
		return
	if not await _travel(2910, 200):
		return
	await _press("slot_2")
	await _press("use_acid")
	await _frames(12)
	Input.action_press("move_right")
	await _jump(15)
	Input.action_release("move_right")
	if not await _travel(3500, 240):
		return
	if not await _travel(4192, 240):
		return
	await _frames(8)
	if not _check(world.active_checkpoint == 2, "Cannot reach third checkpoint"):
		return
	if "--physical-route" in OS.get_cmdline_user_args():
		await _physical_route()
		return
	if not await _travel(4700, 220):
		return
	await _frames(60)
	await _press("slot_2")
	await _press("use_acid")
	await _frames(15)
	Input.action_press("move_right")
	await _jump(18)
	Input.action_release("move_right")
	if not await _travel(5260, 240):
		return
	await _press("slot_1")
	await _press("use_acid")
	await _frames(55)
	if not _check(world.final_route == "chemical", "Cannot reach acid latch from lower path"):
		return
	if not await _travel(5410, 100):
		return
	Input.action_press("move_right")
	await _jump(24)
	await _frames(2)
	await _jump(20)
	await _frames(20)
	Input.action_release("move_right")
	if not await _travel(6056, 240):
		return
	await _frames(8)
	if not _check(world.demo_complete and world.deaths == 0, "Walkthrough did not finish without deaths"):
		return
	_finish("chemical")

func _physical_route() -> void:
	if not await _travel(4550, 160):
		return
	await _jump(18)
	await _frames(70)
	if not _check(player.is_on_floor() and player.position.y < 566, "Cannot board idle gravity lift"):
		return
	await _press("gravity_skill")
	await _frames(165)
	if not _check(player.position.y < 338, "E did not lift rider onto upper route"):
		return
	if not await _travel(4700, 120):
		return
	Input.action_press("move_right")
	for _index in range(300):
		await _frames(1)
		if world.zones[2].get_node("FinalSwitch").active:
			break
	Input.action_release("move_right")
	if not _check(world.zones[2].get_node("FinalSwitch").active, "Upper-route plate not reachable"):
		return
	Input.action_press("move_right")
	await _jump(24)
	Input.action_release("move_right")
	await _frames(50)
	if not await _travel(5280, 120):
		return
	await _press("slot_3")
	await _press("use_acid")
	await _frames(18)
	if not _check(world.final_route == "physical", "Cannot insert iron using Q"):
		return
	if not await _travel(6056, 300):
		return
	await _frames(8)
	if not _check(world.demo_complete and world.deaths == 0, "Physical walkthrough failed"):
		return
	_finish("physical")

func _finish(route: String) -> void:
	print("PASS: continuous input-only walkthrough from spawn to ", route, "-route exit, zero deaths")
	paused = false
	quit(0)

func _travel(target_x: float, max_frames: int) -> bool:
	Input.action_press("move_right")
	for _index in range(max_frames):
		if player.position.x >= target_x or world.demo_complete:
			break
		await _frames(1)
	Input.action_release("move_right")
	return _check(world.demo_complete or player.position.x >= target_x - 4, "Path blocked before x=%s" % target_x)

func _jump(hold_frames: int) -> void:
	Input.action_press("jump")
	await _frames(hold_frames)
	Input.action_release("jump")
	await _frames(1)

func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)

func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
	await process_frame

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		Input.action_release("move_right")
		Input.action_release("jump")
		push_error(message + " | player=%s checkpoint=%d deaths=%d" % [player.position, world.active_checkpoint, world.deaths])
		print("FAIL: input-only walkthrough")
		quit(1)
	return ok
