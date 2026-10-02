extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const MUD_BLOB := preload("res://scripts/enemies/dirt_mud_blob.gd")

var world: Node2D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	await _frames(30)
	var first := world.get_node("Zone0/MudBlob_0A") as CharacterBody2D
	var second := world.get_node("Zone0/MudBlob_0B") as CharacterBody2D
	var crawler := world.get_node("Zone0/RustCrawler_0A") as CharacterBody2D
	_expect(first is MUD_BLOB, "Zone 0 did not spawn a dirt mud blob")
	_expect(first.health == 120.0, "Dirt mud blob did not use the 120 HP profile")
	first.take_element_damage(10.0, "carbon")
	_expect(is_equal_approx(first.health, 113.5), "Carbon resistance multiplier is incorrect")
	_expect(first.hit_time > 0.0, "Dirt mud blob did not enter hit reaction")
	first.take_element_damage(10.0, "iron")
	_expect(is_equal_approx(first.health, 100.5), "Iron weakness multiplier is incorrect")
	first._defeat()
	_expect(world.get_node_or_null("Zone0/MudBlob_0A") != null, "Dirt mud blob was removed before its death animation")
	await _frames(35)
	_expect(not world.objectives[0], "Zone objective completed before every blob was defeated")
	second._defeat()
	crawler._defeat()
	await _frames(35)
	_expect(world.objectives[0], "Clearing all Zone 0 blobs did not unlock the checkpoint")
	for forbidden in ["Counterweight", "PressureSwitch", "PulleyLift", "GapShuttle", "Gate"]:
		_expect(world.get_node_or_null("Zone0/" + forbidden) == null, "Physical mechanism remains: " + forbidden)
	world.free()
	await process_frame
	if failures.is_empty():
		print("PASS: dirt mud blob spawn, elemental resistance, defeat objective, and physical mechanism removal")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
