extends SceneTree

const PALETTE = preload("res://scripts/shared/palette.gd")

const BACKGROUND_WIDTH := 256
const BACKGROUND_HEIGHT := 144
const GROUND_WIDTH := 64
const GROUND_HEIGHT := 32
const PLATFORM_WIDTH := 64
const PLATFORM_HEIGHT := 20

const VOID := 0
const NAVY := 1
const DEEP_BLUE := 2
const BLUE_BLACK := 3
const STEEL_BLUE := 4
const DARK_TEAL := 15
const TEAL := 16
const CYAN := 17
const OXYGEN := 18
const DARK_ORANGE := 20
const ORANGE := 21
const GOLD := 22
const GOLD_HIGHLIGHT := 23

func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://assets/environment")
	DirAccess.make_dir_recursive_absolute(output_dir)
	_write_background()
	_write_ground_tile()
	_write_platform_tile()
	print("Generated environment textures in res://assets/environment")
	quit()

func _write_background() -> void:
	var image := Image.create(BACKGROUND_WIDTH, BACKGROUND_HEIGHT, false, Image.FORMAT_RGBA8)
	_fill(image, VOID)
	_rect(image, 0, 0, 255, 7, NAVY)
	_rect(image, 0, 136, 255, 143, NAVY)
	# A low-contrast 16 px technical grid keeps the background readable behind gameplay.
	for x in range(8, BACKGROUND_WIDTH, 16):
		_vline(image, x, 8, 135, BLUE_BLACK)
	for y in range(16, BACKGROUND_HEIGHT, 16):
		_hline(image, y, 0, 255, BLUE_BLACK)
	# Repeating wall panels suggest a modular research facility.
	_rect(image, 16, 20, 88, 70, DEEP_BLUE)
	_border(image, 16, 20, 88, 70, STEEL_BLUE)
	_rect(image, 22, 27, 82, 63, NAVY)
	_border(image, 22, 27, 82, 63, BLUE_BLACK)
	_rect(image, 31, 35, 73, 50, BLUE_BLACK)
	_rect(image, 36, 39, 68, 46, DEEP_BLUE)
	_rect(image, 42, 42, 62, 43, STEEL_BLUE)
	_rect(image, 49, 43, 55, 45, DARK_TEAL)

	_rect(image, 164, 18, 240, 72, DEEP_BLUE)
	_border(image, 164, 18, 240, 72, STEEL_BLUE)
	_rect(image, 170, 25, 234, 66, NAVY)
	_border(image, 170, 25, 234, 66, BLUE_BLACK)
	_rect(image, 181, 34, 223, 57, BLUE_BLACK)
	_rect(image, 187, 39, 217, 53, DEEP_BLUE)
	_rect(image, 193, 44, 211, 48, STEEL_BLUE)
	_rect(image, 199, 45, 205, 47, DARK_TEAL)

	# Cyan signal traces and gold service indicators connect the panels.
	_hline(image, 94, 8, 66, DARK_TEAL)
	_hline(image, 95, 8, 52, TEAL)
	_vline(image, 66, 94, 119, DARK_TEAL)
	_hline(image, 119, 66, 112, DARK_TEAL)
	_hline(image, 120, 66, 96, TEAL)
	_rect(image, 63, 92, 68, 97, OXYGEN)
	_rect(image, 64, 93, 67, 96, TEAL)
	_rect(image, 109, 117, 114, 122, GOLD)
	_rect(image, 110, 118, 113, 120, GOLD_HIGHLIGHT)

	_hline(image, 101, 151, 188, DARK_TEAL)
	_vline(image, 151, 101, 128, DARK_TEAL)
	_hline(image, 128, 151, 221, DARK_TEAL)
	_hline(image, 102, 151, 176, TEAL)
	_rect(image, 146, 98, 153, 105, CYAN)
	_rect(image, 148, 100, 151, 103, OXYGEN)
	_rect(image, 217, 125, 223, 131, ORANGE)
	_rect(image, 218, 126, 221, 128, GOLD_HIGHLIGHT)

	# Small vents and status pixels add depth without competing with the character.
	for x in [8, 12, 16, 20, 24, 228, 232, 236, 240, 244]:
		_rect(image, x, 78, x + 1, 83, BLUE_BLACK)
		_rect(image, x, 79, x, 82, STEEL_BLUE)
	for x in [116, 124, 132, 140]:
		_rect(image, x, 28, x + 3, 29, DARK_TEAL)
		_rect(image, x + 1, 28, x + 2, 28, CYAN)

	image.save_png("res://assets/environment/tech_background.png")

func _write_ground_tile() -> void:
	var image := Image.create(GROUND_WIDTH, GROUND_HEIGHT, false, Image.FORMAT_RGBA8)
	_fill(image, DEEP_BLUE)
	_rect(image, 0, 0, 63, 1, BLUE_BLACK)
	_rect(image, 0, 2, 63, 3, DARK_TEAL)
	_rect(image, 0, 4, 63, 5, TEAL)
	_rect(image, 0, 6, 63, 7, DEEP_BLUE)
	_rect(image, 0, 26, 63, 31, NAVY)
	_rect(image, 0, 28, 63, 29, BLUE_BLACK)
	_rect(image, 0, 30, 63, 31, VOID)
	# Two offset armor panels break up long floor runs.
	_rect(image, 4, 10, 28, 23, BLUE_BLACK)
	_rect(image, 6, 11, 27, 21, DEEP_BLUE)
	_rect(image, 35, 9, 59, 23, BLUE_BLACK)
	_rect(image, 37, 10, 58, 21, DEEP_BLUE)
	# Embedded circuit traces and maintenance bolts.
	_hline(image, 15, 8, 24, DARK_TEAL)
	_hline(image, 16, 8, 19, TEAL)
	_vline(image, 24, 15, 19, DARK_TEAL)
	_hline(image, 19, 24, 28, DARK_TEAL)
	_hline(image, 13, 39, 53, DARK_TEAL)
	_hline(image, 14, 39, 47, TEAL)
	_vline(image, 53, 13, 18, DARK_TEAL)
	_rect(image, 4, 9, 6, 11, GOLD)
	_rect(image, 5, 10, 5, 10, GOLD_HIGHLIGHT)
	_rect(image, 57, 20, 59, 22, DARK_ORANGE)
	_rect(image, 58, 20, 58, 21, ORANGE)
	# Crisp seams make the tile repeat legible at the game's 2x pixel scale.
	_vline(image, 0, 6, 27, BLUE_BLACK)
	_vline(image, 31, 8, 27, NAVY)
	_vline(image, 32, 8, 27, STEEL_BLUE)
	_vline(image, 63, 6, 27, BLUE_BLACK)
	image.save_png("res://assets/environment/tech_ground_tile.png")

func _write_platform_tile() -> void:
	var image := Image.create(PLATFORM_WIDTH, PLATFORM_HEIGHT, false, Image.FORMAT_RGBA8)
	_fill(image, DARK_TEAL)
	_rect(image, 0, 0, 63, 0, BLUE_BLACK)
	_rect(image, 0, 1, 63, 2, CYAN)
	_rect(image, 0, 3, 63, 4, OXYGEN)
	_rect(image, 0, 5, 63, 14, TEAL)
	_rect(image, 0, 15, 63, 16, DARK_TEAL)
	_rect(image, 0, 17, 63, 19, NAVY)
	# Gold suspension brackets and a dark center seam signal a moving platform.
	_rect(image, 5, 14, 14, 16, DARK_ORANGE)
	_rect(image, 7, 13, 12, 15, ORANGE)
	_rect(image, 9, 12, 10, 14, GOLD)
	_rect(image, 49, 14, 58, 16, DARK_ORANGE)
	_rect(image, 51, 13, 56, 15, ORANGE)
	_rect(image, 53, 12, 54, 14, GOLD)
	_vline(image, 31, 5, 16, BLUE_BLACK)
	_vline(image, 32, 5, 16, STEEL_BLUE)
	_rect(image, 21, 8, 26, 9, DARK_TEAL)
	_rect(image, 38, 8, 43, 9, DARK_TEAL)
	_rect(image, 22, 8, 24, 8, CYAN)
	_rect(image, 39, 8, 41, 8, CYAN)
	image.save_png("res://assets/environment/tech_floating_platform_tile.png")

func _fill(image: Image, color_index: int) -> void:
	image.fill(PALETTE.COLORS[color_index])

func _rect(image: Image, x0: int, y0: int, x1: int, y1: int, color_index: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, PALETTE.COLORS[color_index])

func _border(image: Image, x0: int, y0: int, x1: int, y1: int, color_index: int) -> void:
	_hline(image, y0, x0, x1, color_index)
	_hline(image, y1, x0, x1, color_index)
	_vline(image, x0, y0, y1, color_index)
	_vline(image, x1, y0, y1, color_index)

func _hline(image: Image, y: int, x0: int, x1: int, color_index: int) -> void:
	_rect(image, x0, y, x1, y, color_index)

func _vline(image: Image, x: int, y0: int, y1: int, color_index: int) -> void:
	_rect(image, x, y0, x, y1, color_index)
