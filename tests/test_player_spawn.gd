extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")

var frames := 0
var world: Node


func _initialize() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 90:
		return false

	var player := world.get("player") as CharacterBody2D
	if player == null:
		push_error("Spawn regression: main scene did not create a player")
		quit(1)
		return true

	if not player.is_on_floor():
		push_error("Spawn regression: player did not settle on the floor")
		quit(1)
		return true

	if player.global_position.y > 585.0:
		push_error("Spawn regression: player fell below the expected floor")
		quit(1)
		return true

	print("PASS: player settled at ", player.global_position)
	quit(0)
	return true
