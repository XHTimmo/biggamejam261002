extends SceneTree

const PALETTE = preload("res://assets/palette.gd")
const WIDTH := 32
const HEIGHT := 48
const SYMBOLS := "0123456789ABCDEFGHIJKLMNOPQRSTUV"

var pixels: Array = []

func _initialize() -> void:
	for y in range(HEIGHT):
		var row: Array[String] = []
		row.resize(WIDTH)
		row.fill(".")
		pixels.append(row)

	# Deep-blue silhouette outline.
	_rect(11, 4, 21, 13, "1")
	_rect(10, 8, 22, 19, "1")
	_rect(13, 17, 19, 22, "1")
	_rect(7, 20, 25, 35, "1")
	_rect(4, 22, 10, 34, "1")
	_rect(22, 22, 28, 34, "1")
	_rect(10, 33, 15, 46, "1")
	_rect(17, 33, 22, 46, "1")
	_rect(8, 44, 16, 48, "1")
	_rect(16, 44, 24, 48, "1")
	_rect(24, 22, 29, 38, "1")

	# Hair: dark blue base, blue body, bright blue edge highlights.
	_rect(12, 5, 20, 8, "C")
	_rect(11, 7, 21, 11, "D")
	_rect(10, 9, 12, 14, "C")
	_rect(19, 8, 22, 13, "C")
	_rect(13, 5, 17, 6, "E")
	_rect(18, 7, 20, 8, "E")
	_rect(11, 11, 12, 13, "D")

	# Face and neck.
	_rect(12, 11, 20, 17, "A")
	_rect(14, 12, 19, 14, "B")
	_rect(13, 15, 19, 17, "A")
	_rect(14, 13, 14, 14, "1")
	_rect(18, 13, 18, 14, "1")
	_rect(16, 15, 17, 15, "9")
	_rect(14, 18, 18, 21, "A")
	_rect(13, 19, 19, 20, "H")

	# Short teal academy jacket and light experimental inner shirt.
	_rect(8, 22, 12, 32, "F")
	_rect(19, 22, 24, 32, "F")
	_rect(10, 21, 22, 24, "G")
	_rect(11, 23, 21, 33, "7")
	_rect(12, 24, 20, 33, "8")
	_rect(8, 22, 10, 29, "G")
	_rect(21, 22, 24, 30, "G")
	_rect(9, 29, 11, 33, "F")
	_rect(21, 29, 23, 33, "F")
	_rect(11, 22, 12, 25, "L")
	_rect(20, 22, 21, 25, "L")
	_rect(15, 23, 16, 32, "2")
	_rect(16, 24, 17, 32, "H")
	_rect(13, 25, 14, 26, "M")
	_rect(18, 25, 19, 26, "M")

	# Arms and hands.
	_rect(5, 24, 8, 31, "G")
	_rect(23, 24, 26, 31, "G")
	_rect(5, 31, 8, 33, "A")
	_rect(23, 31, 26, 33, "A")
	_rect(4, 25, 5, 30, "F")
	_rect(26, 25, 27, 30, "F")

	# Dark pants with a bright academy stripe.
	_rect(11, 34, 14, 44, "3")
	_rect(18, 34, 21, 44, "3")
	_rect(12, 35, 14, 44, "2")
	_rect(18, 35, 20, 44, "2")
	_rect(14, 35, 14, 41, "L")
	_rect(18, 35, 18, 41, "L")

	# Orange-accented experiment boots.
	_rect(10, 44, 15, 46, "K")
	_rect(18, 44, 23, 46, "K")
	_rect(9, 46, 15, 47, "L")
	_rect(18, 46, 24, 47, "L")
	_rect(12, 44, 13, 44, "M")
	_rect(20, 44, 21, 44, "M")

	# Oxygen canister and hose on the back.
	_rect(25, 23, 28, 36, "4")
	_rect(26, 24, 28, 35, "G")
	_rect(27, 25, 28, 33, "H")
	_rect(26, 26, 26, 30, "I")
	_rect(24, 22, 26, 24, "L")
	_rect(23, 21, 25, 22, "H")
	_rect(24, 35, 28, 36, "K")

	# Export PNG and an editable palette-index source grid.
	var output_dir := ProjectSettings.globalize_path("res://assets/character")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var symbol: String = pixels[y][x]
			if symbol == ".":
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var index := SYMBOLS.find(symbol)
				image.set_pixel(x, y, PALETTE.COLORS[index])
	image.save_png("res://assets/character/hero_idle_01.png")

	var rows: Array[String] = []
	for row in pixels:
		rows.append("".join(row))
	var source := {
		"name": "hero_idle_01",
		"width": WIDTH,
		"height": HEIGHT,
		"palette": "res://assets/palette.gpl",
		"rows": rows
	}
	var source_file := FileAccess.open("res://assets/character/hero_idle_01.json", FileAccess.WRITE)
	source_file.store_string(JSON.stringify(source, "\t"))
	print("Generated hero idle frame: res://assets/character/hero_idle_01.png")
	quit()

func _rect(x0: int, y0: int, x1: int, y1: int, symbol: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
				pixels[y][x] = symbol

