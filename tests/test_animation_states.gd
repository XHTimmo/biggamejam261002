extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const CLIMB_TEXTURE := preload("res://assets/character/hero_climb_strip.png")
const CRAWL_TEXTURE := preload("res://assets/character/hero_crouch_strip.png")

var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	await _frames(30)
	player = world.get_node("Player") as CharacterBody2D

	player.global_position = Vector2(713.0, 500.0)
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	await _frames(4)
	_expect(player.active_ladder != null, "Entering the ladder area did not register the ladder")
	_expect(not player.is_climbing, "Entering the ladder area automatically started climbing")
	_expect(absf(player.global_position.x - 713.0) < 0.1, "Ladder entry did not center the player")

	Input.action_press("move_up")
	await _frames(4)
	Input.action_release("move_up")
	_expect(player.is_climbing, "W did not start ladder climbing")
	_expect(player.hero_sprite.texture == CLIMB_TEXTURE, "Ladder state did not use the back-facing climb strip")
	_expect(not player.hero_sprite.flip_h, "Back-facing climb pose was flipped by movement direction")

	var ladder_velocity := player.velocity.y
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	await _frames(1)
	_expect(not player.is_climbing, "Horizontal input did not detach the player from the ladder")
	_expect(player.active_ladder == null, "Detached player still retained the active ladder")
	_expect(player.velocity.y > ladder_velocity, "Detached player did not regain gravity")

	player.global_position = Vector2(300.0, 584.0)
	player.velocity = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.active_ladder = null
	player.is_climbing = false
	Input.action_press("move_down")
	await _frames(4)
	Input.action_release("move_down")
	_expect(player.crouching, "Down input did not enter the prone crawl state")
	_expect(player.hero_sprite.texture == CRAWL_TEXTURE, "Prone crawl state did not use the crawl strip")

	# The first jump rolls in place; the follow-up jump keeps the jet-assisted
	# state and leaves the roll transform cleared.
	player.global_position = Vector2(300.0, 584.0)
	player.velocity = Vector2.ZERO
	player._update_crouch(false)
	await _frames(3)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(2)
	_expect(player.airborne_jump_mode == player.JUMP_MODE_ROLL, "First jump did not enter the roll animation")
	_expect(absf(player.hero_sprite.rotation) > 0.01, "First jump roll did not rotate the hero sprite")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(player.airborne_jump_mode == player.JUMP_MODE_JET, "Second jump did not switch to the jet animation")
	_expect(not player.air_spray_available and player.air_spray_timer > 0, "Second jump did not preserve the jet boost")
	_expect(is_zero_approx(player.hero_sprite.rotation), "Jet jump retained the first-jump roll rotation")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: explicit W ladder entry, horizontal ladder detach, and prone crawl animation states")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
