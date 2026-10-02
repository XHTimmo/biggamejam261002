extends SceneTree

const WORKBENCH := preload("res://tools/pixel_workbench.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var workbench := WORKBENCH.instantiate()
	root.add_child(workbench)
	await process_frame
	if workbench.palette.size() != 32 or workbench.frames.size() != 1:
		push_error("Workbench failed to load its palette or initial frame")
		quit(1)
		return
	workbench._add_frame()
	workbench._duplicate_frame()
	workbench._delete_frame()
	if workbench.frames.size() != 2 or workbench.frames[0].get_size() != Vector2i(32, 48):
		push_error("Workbench frame editing failed")
		quit(1)
		return
	workbench._onion_toggled(true)
	workbench._grid_toggled(true)
	workbench._playback_toggled(true)
	for _index in range(8):
		await process_frame
	workbench._playback_toggled(false)
	workbench.free()
	await process_frame
	print("PASS: pixel workbench scene, 32-color palette, frame editing and playback loaded")
	quit(0)
