extends SceneTree

const PALETTE = preload("res://assets/palette.gd")
const WIDTH := 32
const HEIGHT := 48
const FRAME_COUNT := 4
const MOTION_FRAME_COUNT := 6
const JUMP_FRAME_COUNT := 9
const ATTACK_FRAME_COUNT := 8
const SYMBOLS := "0123456789ABCDEFGHIJKLMNOPQRSTUV"

var pixels: Array = []

func _initialize() -> void:
	for y in range(HEIGHT):
		var row: Array[String] = []
		row.resize(WIDTH)
		row.fill(".")
		pixels.append(row)

	# Deep-blue silhouette outline for a clearly right-facing profile.
	# The back is narrow, only one arm is visible, and the chest, nose, knee,
	# and leading boot all project toward the right.
	_rect(11, 4, 18, 8, "1")
	_rect(9, 7, 20, 13, "1")
	_rect(10, 11, 22, 17, "1")
	_rect(12, 16, 22, 20, "1")
	_rect(14, 19, 19, 23, "1")
	_rect(9, 21, 20, 35, "1")
	_rect(4, 22, 9, 37, "1")
	_rect(18, 22, 25, 34, "1")
	_rect(10, 33, 14, 46, "1")
	_rect(15, 32, 21, 46, "1")
	_rect(8, 44, 14, 48, "1")
	_rect(18, 44, 25, 48, "1")

	# Hair: the fringe points toward the camera-facing (right) side.
	_rect(11, 5, 17, 8, "C")
	_rect(10, 7, 18, 11, "D")
	_rect(9, 9, 11, 16, "C")
	_rect(17, 8, 20, 12, "C")
	_rect(12, 5, 15, 6, "E")
	_rect(16, 7, 18, 8, "E")
	_rect(10, 11, 11, 14, "D")
	_rect(19, 10, 21, 12, "E")

	# One-sided face, eye, nose, and neck.
	_rect(12, 11, 19, 17, "A")
	_rect(14, 12, 20, 14, "B")
	_rect(13, 15, 19, 18, "A")
	_rect(18, 13, 19, 14, "1")
	_rect(20, 14, 23, 15, "A")
	_rect(20, 15, 22, 16, "9")
	_rect(15, 18, 19, 21, "A")
	_rect(14, 19, 19, 20, "H")

	# Short teal academy jacket and light experimental inner shirt.
	_rect(9, 22, 12, 32, "F")
	_rect(17, 22, 21, 33, "F")
	_rect(11, 21, 18, 24, "G")
	_rect(12, 23, 17, 33, "7")
	_rect(14, 24, 17, 33, "8")
	_rect(10, 22, 11, 30, "G")
	_rect(18, 22, 20, 30, "G")
	_rect(10, 29, 12, 33, "F")
	_rect(18, 29, 21, 33, "F")
	_rect(10, 22, 11, 25, "L")
	_rect(17, 22, 18, 25, "L")
	_rect(13, 23, 13, 32, "2")
	_rect(14, 24, 15, 32, "H")
	_rect(13, 25, 13, 26, "M")
	_rect(16, 25, 17, 26, "M")

	# One visible leading arm; the rear arm is hidden behind the torso and tank.
	_rect(19, 24, 22, 31, "G")
	_rect(22, 30, 24, 33, "A")
	_rect(23, 25, 25, 30, "F")

	# Dark pants with offset legs and a bright academy stripe.
	_rect(10, 34, 13, 38, "3")
	_rect(11, 38, 13, 44, "3")
	_rect(11, 35, 13, 44, "2")
	_rect(12, 35, 12, 41, "L")
	_rect(14, 33, 18, 39, "3")
	_rect(16, 39, 20, 44, "3")
	_rect(15, 35, 18, 39, "2")
	_rect(17, 39, 20, 44, "2")
	_rect(17, 35, 17, 38, "L")
	_rect(18, 39, 18, 42, "L")

	# Orange-accented experiment boots with a stepped walking stance.
	_rect(8, 44, 14, 46, "K")
	_rect(18, 44, 24, 46, "K")
	_rect(8, 46, 14, 47, "L")
	_rect(18, 46, 25, 47, "L")
	_rect(10, 44, 11, 44, "M")
	_rect(20, 44, 21, 44, "M")

	# Oxygen canister and hose are visibly mounted on the back (left side).
	# Orange/yellow equipment colors deliberately separate the rig from the teal jacket.
	_rect(4, 21, 9, 37, "1")
	_rect(5, 22, 8, 36, "K")
	_rect(6, 23, 9, 35, "L")
	_rect(7, 24, 8, 33, "M")
	_rect(7, 26, 7, 30, "N")
	_rect(5, 35, 9, 37, "K")
	_rect(9, 23, 9, 35, "1")
	# The hose arcs up behind the shoulder and uses a bright cyan highlight.
	_rect(8, 20, 10, 23, "1")
	_rect(9, 19, 12, 21, "1")
	_rect(11, 20, 13, 22, "1")
	_rect(9, 20, 9, 22, "V")
	_rect(10, 19, 11, 20, "V")
	_rect(12, 20, 12, 21, "V")

	# Export the still frame plus a four-frame strip for the in-game idle loop.
	# The upper body gently bobs while the feet stay planted, and the canister
	# highlight moves by one pixel so the breathing motion reads at 2x scale.
	var frames: Array = []
	for frame_index in range(FRAME_COUNT):
		var frame: Array = _copy_pixels()
		var bob_offset := 1 if frame_index == 1 or frame_index == 2 else 0
		if bob_offset != 0:
			frame = _shift_region(frame, 4, 33, bob_offset)
		if frame_index == 1:
			frame[27][7] = "N"
			frame[30][7] = "M"
		elif frame_index == 2:
			frame[26][7] = "N"
			frame[29][7] = "M"
		elif frame_index == 3:
			frame[25][7] = "N"
		_animate_oxygen_rig(frame, frame_index, bob_offset)
		frames.append(frame)

	# Export PNGs and an editable palette-index source grid.
	var output_dir := ProjectSettings.globalize_path("res://assets/character")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			_set_image_pixel(image, x, y, frames[0][y][x])
	image.save_png("res://assets/character/hero_idle_01.png")

	var strip_image := Image.create(WIDTH * FRAME_COUNT, HEIGHT, false, Image.FORMAT_RGBA8)
	for frame_index in range(FRAME_COUNT):
		for y in range(HEIGHT):
			for x in range(WIDTH):
				_set_image_pixel(strip_image, frame_index * WIDTH + x, y, frames[frame_index][y][x])
	strip_image.save_png("res://assets/character/hero_idle_strip.png")
	_write_strip(_build_motion_frames(false), "res://assets/character/hero_walk_strip.png")
	_write_strip(_build_motion_frames(true), "res://assets/character/hero_run_strip.png")
	_write_strip(_build_jump_frames(), "res://assets/character/hero_jump_strip.png")
	_write_strip(_build_attack_frames(), "res://assets/character/hero_attack_strip.png")

	var rows: Array[String] = []
	for row in pixels:
		rows.append("".join(row))
	var source := {
		"name": "hero_idle_01",
		"width": WIDTH,
		"height": HEIGHT,
		"frame_count": FRAME_COUNT,
		"palette": "res://assets/palette.gpl",
		"rows": rows
	}
	var source_file := FileAccess.open("res://assets/character/hero_idle_01.json", FileAccess.WRITE)
	source_file.store_string(JSON.stringify(source, "\t"))
	print("Generated hero idle frame: res://assets/character/hero_idle_01.png")
	print("Generated hero idle strip: res://assets/character/hero_idle_strip.png")
	print("Generated hero walk strip: res://assets/character/hero_walk_strip.png")
	print("Generated hero run strip: res://assets/character/hero_run_strip.png")
	print("Generated hero jump strip: res://assets/character/hero_jump_strip.png")
	print("Generated hero attack strip: res://assets/character/hero_attack_strip.png")
	quit()

func _copy_pixels() -> Array:
	var copy: Array = []
	for row in pixels:
		copy.append(row.duplicate())
	return copy

func _shift_region(source: Array, y0: int, y1: int, offset: int) -> Array:
	var shifted: Array = []
	for y in range(HEIGHT):
		var row: Array[String] = []
		row.resize(WIDTH)
		row.fill(".")
		shifted.append(row)
	for y in range(HEIGHT):
		var target_y := y + offset if y >= y0 and y <= y1 else y
		if target_y < 0 or target_y >= HEIGHT:
			continue
		for x in range(WIDTH):
			shifted[target_y][x] = source[y][x]
	return shifted

func _set_image_pixel(image: Image, x: int, y: int, symbol: String) -> void:
	if symbol == ".":
		image.set_pixel(x, y, Color(0, 0, 0, 0))
	else:
		var index := SYMBOLS.find(symbol)
		image.set_pixel(x, y, PALETTE.COLORS[index])

func _build_motion_frames(running: bool) -> Array:
	var frames: Array = []
	var rear_positions: Array
	var front_positions: Array
	var rear_boots: Array
	var front_boots: Array
	var arm_positions: Array
	var arm_rows: Array
	if running:
		rear_positions = [8, 10, 13, 15, 12, 9]
		front_positions = [19, 18, 15, 11, 14, 18]
		rear_boots = [5, 8, 11, 14, 10, 6]
		front_boots = [22, 20, 17, 10, 15, 21]
		arm_positions = [21, 23, 24, 20, 19, 21]
		arm_rows = [24, 24, 25, 25, 24, 24]
	else:
		rear_positions = [10, 9, 11, 14, 12, 10]
		front_positions = [17, 19, 18, 15, 16, 17]
		rear_boots = [8, 7, 9, 12, 10, 8]
		front_boots = [19, 21, 20, 17, 18, 19]
		arm_positions = [21, 21, 22, 23, 22, 21]
		arm_rows = [24, 24, 25, 24, 24, 24]

	for frame_index in range(MOTION_FRAME_COUNT):
		var frame: Array = _copy_pixels()
		var bob_offset := 1 if frame_index == 1 or frame_index == 2 or frame_index == 4 else 0
		if bob_offset != 0:
			frame = _shift_region(frame, 4, 33, bob_offset)

		# Redraw the legs into a planted walk or a longer running stride.
		_clear_rect_on(frame, 10, 33, 27, 47)
		_clear_rect_on(frame, 8, 38, 9, 47)
		_draw_leg_pose(frame, rear_positions[frame_index], front_positions[frame_index], rear_boots[frame_index], front_boots[frame_index])

		# Swing the forward arm opposite the leading foot.
		_clear_rect_on(frame, 20, 23, 28, 34)
		_draw_front_arm_pose(frame, arm_positions[frame_index], arm_rows[frame_index])
		_animate_oxygen_rig(frame, frame_index, bob_offset)
		frames.append(frame)
	return frames

func _draw_leg_pose(target: Array, rear_x: int, front_x: int, rear_boot_x: int, front_boot_x: int) -> void:
	_draw_rear_leg_at(target, rear_x, rear_boot_x, 33)
	_draw_single_leg(target, front_x, front_boot_x)

func _draw_single_leg(target: Array, leg_x: int, boot_x: int) -> void:
	_draw_single_leg_at(target, leg_x, boot_x, 33)

func _draw_single_leg_at(target: Array, leg_x: int, boot_x: int, base_y: int) -> void:
	_rect_on(target, leg_x, base_y, leg_x + 4, base_y + 11, "1")
	_rect_on(target, leg_x + 1, base_y + 2, leg_x + 4, base_y + 11, "2")
	_rect_on(target, leg_x + 3, base_y + 2, leg_x + 3, base_y + 7, "L")
	_rect_on(target, boot_x, base_y + 10, boot_x + 6, base_y + 14, "1")
	_rect_on(target, boot_x + 1, base_y + 11, boot_x + 6, base_y + 13, "K")
	_rect_on(target, boot_x, base_y + 13, boot_x + 6, base_y + 14, "L")
	_rect_on(target, boot_x + 3, base_y + 11, boot_x + 4, base_y + 11, "M")

func _draw_rear_leg_at(target: Array, leg_x: int, boot_x: int, base_y: int) -> void:
	# The far leg is darker, narrower, and partially hidden behind the leading leg.
	_rect_on(target, leg_x, base_y + 1, leg_x + 3, base_y + 11, "1")
	_rect_on(target, leg_x + 1, base_y + 3, leg_x + 3, base_y + 11, "3")
	_rect_on(target, leg_x + 2, base_y + 3, leg_x + 2, base_y + 8, "2")
	_rect_on(target, boot_x, base_y + 10, boot_x + 5, base_y + 14, "1")
	_rect_on(target, boot_x + 1, base_y + 11, boot_x + 5, base_y + 13, "K")
	_rect_on(target, boot_x, base_y + 13, boot_x + 5, base_y + 14, "L")

func _build_jump_frames() -> Array:
	var frames: Array = []
	var vertical_offsets: Array = [1, 0, -1, -2, -2, -1, 0, 1, 1]
	var rear_positions: Array = [10, 10, 11, 12, 13, 12, 10, 9, 10]
	var front_positions: Array = [17, 18, 18, 17, 16, 16, 18, 19, 17]
	var rear_boots: Array = [8, 8, 9, 10, 11, 10, 8, 6, 8]
	var front_boots: Array = [19, 20, 20, 19, 18, 18, 20, 22, 19]
	var arm_positions: Array = [21, 22, 23, 22, 21, 20, 20, 21, 21]
	var arm_rows: Array = [26, 25, 24, 24, 25, 25, 24, 23, 24]
	for frame_index in range(JUMP_FRAME_COUNT):
		var frame: Array = _copy_pixels()
		frame = _shift_region(frame, 4, 43, vertical_offsets[frame_index])
		_clear_rect_on(frame, 10, 31, 28, 47)
		_clear_rect_on(frame, 8, 38, 9, 47)
		if frame_index == 1 or frame_index == 2 or frame_index == 3:
			# Tuck both knees under the body during the launch and rise.
			_draw_rear_leg_at(frame, rear_positions[frame_index], rear_boots[frame_index], 36)
			_draw_single_leg_at(frame, front_positions[frame_index], front_boots[frame_index], 35)
		elif frame_index == 4 or frame_index == 5:
			# Bent legs at the apex and the first part of the fall.
			_draw_rear_leg_at(frame, rear_positions[frame_index], rear_boots[frame_index], 34)
			_draw_single_leg_at(frame, front_positions[frame_index], front_boots[frame_index], 33)
		else:
			_draw_rear_leg_at(frame, rear_positions[frame_index], rear_boots[frame_index], 33 + vertical_offsets[frame_index])
			_draw_single_leg_at(frame, front_positions[frame_index], front_boots[frame_index], 33 + vertical_offsets[frame_index])
		_clear_rect_on(frame, 20, 23, 28, 34)
		_draw_front_arm_pose(frame, arm_positions[frame_index], arm_rows[frame_index])
		if frame_index == 5 or frame_index == 6:
			# Loose hair and coat tails trail behind during the fall.
			_rect_on(frame, 9, 13, 10, 16, "E")
			_rect_on(frame, 18, 21, 19, 23, "H")
		_animate_oxygen_rig(frame, frame_index, vertical_offsets[frame_index])
		frames.append(frame)
	return frames

func _build_attack_frames() -> Array:
	var frames: Array = []
	var body_offsets: Array = [1, 0, 0, -1, -1, 0, 0, 0]
	var arm_positions: Array = [19, 20, 22, 24, 25, 23, 21, 21]
	var arm_rows: Array = [26, 25, 24, 24, 24, 25, 24, 24]
	for frame_index in range(ATTACK_FRAME_COUNT):
		var frame: Array = _copy_pixels()
		if body_offsets[frame_index] != 0:
			frame = _shift_region(frame, 4, 33, body_offsets[frame_index])
		_clear_rect_on(frame, 20, 23, 30, 35)
		_draw_front_arm_pose(frame, arm_positions[frame_index], arm_rows[frame_index])
		if frame_index == 1:
			_rect_on(frame, 27, 28, 28, 29, "I")
		elif frame_index == 2:
			_rect_on(frame, 27, 27, 29, 30, "I")
			_rect_on(frame, 28, 28, 29, 29, "J")
		elif frame_index == 3:
			_rect_on(frame, 28, 26, 30, 31, "I")
			_rect_on(frame, 29, 27, 30, 30, "J")
		elif frame_index == 4:
			_rect_on(frame, 27, 28, 29, 30, "J")
			_rect_on(frame, 28, 27, 28, 31, "I")
		_animate_oxygen_rig(frame, frame_index, body_offsets[frame_index])
		frames.append(frame)
	return frames

func _draw_front_arm_pose(target: Array, arm_x: int, arm_y: int) -> void:
	_rect_on(target, arm_x - 1, arm_y - 1, arm_x + 4, arm_y + 9, "1")
	_rect_on(target, arm_x, arm_y, arm_x + 3, arm_y + 6, "G")
	_rect_on(target, arm_x + 3, arm_y + 6, arm_x + 5, arm_y + 9, "A")
	_rect_on(target, arm_x + 4, arm_y, arm_x + 5, arm_y + 5, "F")

func _animate_oxygen_rig(target: Array, frame_index: int, vertical_offset: int = 0) -> void:
	# A single pale-yellow indicator travels down the orange canister so the
	# backpack remains readable as equipment instead of blending into clothing.
	var pulse_y := 25 + ((frame_index * 2) % 8) + vertical_offset
	if pulse_y >= 24 and pulse_y <= 33:
		target[pulse_y][7] = "N"
		if pulse_y + 1 <= 33:
			target[pulse_y + 1][7] = "M"

func _clear_rect_on(target: Array, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
				target[y][x] = "."

func _rect_on(target: Array, x0: int, y0: int, x1: int, y1: int, symbol: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
				target[y][x] = symbol

func _write_strip(frames: Array, path: String) -> void:
	var image := Image.create(WIDTH * frames.size(), HEIGHT, false, Image.FORMAT_RGBA8)
	for frame_index in range(frames.size()):
		for y in range(HEIGHT):
			for x in range(WIDTH):
				_set_image_pixel(image, frame_index * WIDTH + x, y, frames[frame_index][y][x])
	image.save_png(path)

func _rect(x0: int, y0: int, x1: int, y1: int, symbol: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
				pixels[y][x] = symbol
