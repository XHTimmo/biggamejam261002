extends SceneTree

const PALETTE = preload("res://assets/palette.gd")
const WIDTH := 32
const HEIGHT := 32
const FRAME_COUNT := 6
const OUTLINE := 1
const MUD_SHADOW := 20
const MUD_BODY := 21
const MUD_HIGHLIGHT := 22
const SLUDGE_SHADOW := 15
const SLUDGE_BODY := 16
const CORE := 17
const CORE_HIGHLIGHT := 18

func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://assets/enemies")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var frames: Array[Image] = []
	for frame_index in range(FRAME_COUNT):
		frames.append(_build_frame(frame_index))
	var strip := Image.create(WIDTH * FRAME_COUNT, HEIGHT, false, Image.FORMAT_RGBA8)
	for frame_index in range(FRAME_COUNT):
		for y in range(HEIGHT):
			for x in range(WIDTH):
				strip.set_pixel(frame_index * WIDTH + x, y, frames[frame_index].get_pixel(x, y))
	strip.save_png("res://assets/enemies/dirt_mud_blob_idle_strip.png")
	frames[0].save_png("res://assets/enemies/dirt_mud_blob_idle_01.png")
	print("Generated dirt mud blob idle strip")
	quit()

func _build_frame(frame_index: int) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var bob := 1 if frame_index == 1 or frame_index == 2 else 0
	var center_y := 16 + bob
	var width_scale: float = [0.94, 1.0, 1.05, 1.02, 0.95, 0.98][frame_index]
	var height_scale: float = [0.95, 1.0, 1.05, 1.02, 0.96, 0.98][frame_index]
	var center_x := 16
	var radius_y: float = 10.5 * height_scale
	# Draw an expanded silhouette first, then the inset mud body.
	_draw_ellipse(image, center_x, center_y, 12.5 * width_scale, radius_y + 1.0, OUTLINE, 5, 29)
	_draw_ellipse(image, center_x, center_y, 11.5 * width_scale, radius_y, MUD_BODY, 6, 28)
	# Dark lower mud and a teal sludge rim establish the material boundary.
	for y in range(19, 28):
		var half_width := _ellipse_half_width(y, center_y, 11.5 * width_scale, radius_y)
		for x in range(center_x - half_width, center_x + half_width + 1):
			if x >= 0 and x < WIDTH:
				image.set_pixel(x, y, PALETTE.COLORS[MUD_SHADOW])
	for y in range(23, 28):
		var half_width := _ellipse_half_width(y, center_y, 11.5 * width_scale, radius_y)
		for x in range(center_x - half_width, center_x + half_width + 1):
			if x >= 0 and x < WIDTH:
				image.set_pixel(x, y, PALETTE.COLORS[SLUDGE_SHADOW if (x + y + frame_index) % 3 else SLUDGE_BODY])
	# Wet top planes and a few stepped pixels give the silhouette readable highlights.
	_rect(image, 10, 8 + bob, 20, 9 + bob, MUD_HIGHLIGHT)
	_rect(image, 8, 10 + bob, 13, 11 + bob, MUD_HIGHLIGHT)
	_rect(image, 7, 12 + bob, 9, 13 + bob, MUD_HIGHLIGHT)
	_rect(image, 22, 13 + bob, 24, 14 + bob, MUD_SHADOW)
	# Two sensor dots and the exposed inner core avoid a humanoid face.
	_set_pixel(image, 11, 14 + bob, CORE_HIGHLIGHT)
	_set_pixel(image, 20, 14 + bob, CORE_HIGHLIGHT)
	_rect(image, 14, 15 + bob, 17, 18 + bob, CORE)
	_rect(image, 15, 15 + bob, 16, 16 + bob, CORE_HIGHLIGHT)
	if frame_index == 2 or frame_index == 3:
		_set_pixel(image, 15, 17 + bob, CORE_HIGHLIGHT)
	# Small trailing splats follow the breathing cycle.
	_rect(image, 4 + frame_index % 2, 26, 7 + frame_index % 2, 27, MUD_SHADOW)
	_rect(image, 24 - frame_index % 2, 27, 27 - frame_index % 2, 28, SLUDGE_SHADOW)
	return image

func _draw_ellipse(image: Image, center_x: int, center_y: int, radius_x: float, radius_y: float, color_index: int, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		var half_width := _ellipse_half_width(y, center_y, radius_x, radius_y)
		for x in range(center_x - half_width, center_x + half_width + 1):
			if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
				image.set_pixel(x, y, PALETTE.COLORS[color_index])

func _ellipse_half_width(y: int, center_y: int, radius_x: float, radius_y: float) -> int:
	var normalized_y := float(y - center_y) / radius_y
	if absf(normalized_y) > 1.0:
		return 0
	return maxi(0, int(floor(radius_x * sqrt(1.0 - normalized_y * normalized_y))))

func _rect(image: Image, x0: int, y0: int, x1: int, y1: int, color_index: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_set_pixel(image, x, y, color_index)

func _set_pixel(image: Image, x: int, y: int, color_index: int) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, PALETTE.COLORS[color_index])
