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

	player.global_position = Vector2(713.0, 580.0)
	player.velocity = Vector2.ZERO
	await _frames(4)
	_expect(player.is_climbing, "Entering the ladder did not attach the player")
	_expect(absf(player.global_position.x - 713.0) < 0.1, "Ladder attachment did not center the player")
	_expect(player.hero_sprite.texture == CLIMB_TEXTURE, "Ladder state did not use the back-facing climb strip")
	_expect(not player.hero_sprite.flip_h, "Back-facing climb pose was flipped by movement direction")

	player.global_position = Vector2(300.0, 584.0)
	player.active_ladder = null
	player.is_climbing = false
	Input.action_press("move_down")
	await _frames(4)
	Input.action_release("move_down")
	_expect(player.crouching, "Down input did not enter the prone crawl state")
	_expect(player.hero_sprite.texture == CRAWL_TEXTURE, "Prone crawl state did not use the crawl strip")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: ladder attachment/back-facing climb and prone crawl animation states")
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
