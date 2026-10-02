extends SceneTree

const MAIN := preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world := MAIN.instantiate()
	root.add_child(world)
	for _index in range(30):
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/previews")
	var player: CharacterBody2D = world.player
	player.set_physics_process(false)
	await _save_frame(world, "01-mechanics", Vector2(510, 584))
	world.active_checkpoint = 1
	player.available_reagents = 2
	world.zones[1].get_node("TeachingWater").freeze_hit()
	await _save_frame(world, "02-reactions", Vector2(3020, 558))
	world.active_checkpoint = 2
	player.available_reagents = 3
	world.zones[2].get_node("GravityLift").activated = true
	await _save_frame(world, "03-physical-route", Vector2(4810, 334))
	world.zones[2].get_node("FinalWater").freeze_hit()
	await _save_frame(world, "04-chemical-route", Vector2(4910, 684))
	world.free()
	await process_frame
	print("PASS: saved four rendered level previews")
	quit(0)

func _save_frame(world: Node2D, file_name: String, pos: Vector2) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector2.ZERO
	world.camera.reset_smoothing()
	for _index in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://artifacts/previews/" + file_name + ".png")
	if error != OK:
		push_error("Could not save rendered preview: " + file_name)
