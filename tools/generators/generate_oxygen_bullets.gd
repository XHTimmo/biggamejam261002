extends SceneTree

# All sprite pixels come from the project's shared palette; no antialiasing.
const PALETTE = preload("res://scripts/shared/palette.gd")
const OUTPUT := "res://assets/chemistry_bullets/oxygen_v2/"
const GLYPHS := {
	"A": "01110100011000111111100011000110001", "C": "01111100001000010000100001000001111",
	"D": "11110100011000110001100011000111110", "E": "11111100001000011110100001000011111",
	"F": "11111100001000011110100001000010000", "G": "01111100001000010111100011000101111",
	"H": "10001100011000111111100011000110001", "I": "11111001000010000100001000010011111",
	"L": "10000100001000010000100001000011111", "M": "10001110111010110101100011000110001",
	"N": "10001110011010110011100011000110001", "O": "01110100011000110001100011000101110",
	"P": "11110100011000111110100001000010000", "R": "11110100011000111110101001001010001",
	"S": "01111100001000001110000010000111110", "T": "11111001000010000100001000010000100",
	"X": "10001100010101000100010101000110001", "Y": "10001100010101000100001000010000100",
	"U": "10001100011000110001100011000101110", "=": "00000000001111100000111110000000000",
	"0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110",
	"2": "01110100010000100010001000100011111", "3": "11110000010000101110000010000111110",
	"4": "00010001100101010010111110001000010", "6": "01110100001000011110100011000101110",
	"8": "01110100011000101110100011000101110", " ": "00000000000000000000000000000000000",
	"/": "00001000010001000100010001000010000", "-": "00000000000000011111000000000000000"
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var normal: Array[Image] = []
	var charged: Array[Image] = []
	var impacts: Array[Image] = []
	var charged_impacts: Array[Image] = []
	for frame in range(8):
		normal.append(_flight(false, frame))
		charged.append(_flight(true, frame))
	for frame in range(10):
		impacts.append(_explosion(false, frame))
	for frame in range(12):
		charged_impacts.append(_explosion(true, frame))
	_save_strip(normal, "oxygen_normal_strip.png")
	_save_strip(charged, "oxygen_charged_strip.png")
	_save_strip(impacts, "oxygen_impact_strip.png")
	_save_strip(charged_impacts, "oxygen_charged_impact_strip.png")
	normal[0].save_png(OUTPUT + "oxygen_normal.png")
	charged[0].save_png(OUTPUT + "oxygen_charged.png")
	_preview(normal, charged, impacts, charged_impacts).save_png(OUTPUT + "oxygen_design.png")
	var metadata := {
		"palette": "res://scripts/shared/palette.gd", "orientation": "right", "filter": "nearest",
		"normal": {"file": "oxygen_normal_strip.png", "frame_size": [32, 16], "frames": 8, "fps": 16, "loop": true, "pivot": [21, 8]},
		"charged": {"file": "oxygen_charged_strip.png", "frame_size": [48, 24], "frames": 8, "fps": 16, "loop": true, "pivot": [31, 12]},
		"impact": {"file": "oxygen_impact_strip.png", "frame_size": [48, 48], "frames": 10, "fps": 24, "loop": false, "pivot": [24, 24]},
		"charged_impact": {"file": "oxygen_charged_impact_strip.png", "frame_size": [64, 64], "frames": 12, "fps": 24, "loop": false, "pivot": [32, 32]}
	}
	var source := FileAccess.open(OUTPUT + "oxygen.json", FileAccess.WRITE)
	source.store_string(JSON.stringify(metadata, "\t"))
	print("Generated oxygen sprites and design board: ", OUTPUT)
	quit()

func _blank(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), color)

func _ellipse(img: Image, center: Vector2i, rx: int, ry: int, index: int, hollow: bool = false) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var distance := float(x * x) / (rx * rx) + float(y * y) / (ry * ry)
			if distance > 1.0:
				continue
			if hollow and float(x * x) / maxi(1, (rx - 1) * (rx - 1)) + float(y * y) / maxi(1, (ry - 1) * (ry - 1)) < 1.0:
				continue
			_rect(img, center.x + x, center.y + y, 1, 1, PALETTE.COLORS[index])

func _atom(img: Image, center: Vector2i, radius: int) -> void:
	_ellipse(img, center, radius, radius, 1)
	_ellipse(img, center, radius - 1, radius - 1, 15)
	_ellipse(img, center + Vector2i(0, -1), radius - 2, radius - 2, 17)
	_ellipse(img, center + Vector2i(0, -1), radius - 3, radius - 3, 18)
	_rect(img, center.x - radius + 3, center.y - radius + 2, 2, 1, PALETTE.COLORS[19])
	_rect(img, center.x - radius + 2, center.y - radius + 3, 1, 2, PALETTE.COLORS[19])
	_rect(img, center.x + 1, center.y + radius - 2, 2, 1, PALETTE.COLORS[16])

func _flight(is_charged: bool, frame: int) -> Image:
	var img := _blank(48 if is_charged else 32, 24 if is_charged else 16)
	var cy := 12 if is_charged else 8
	var front := 36 if is_charged else 25
	var rear := 26 if is_charged else 17
	var radius := 6 if is_charged else 4
	var bob := [0, -1, -1, 0, 1, 1, 0, 0]
	var pulse := [0, 1, 2, 1, 0, -1, -2, -1]
	rear -= int(pulse[frame])
	# Vapor trails change, while the leading silhouette and pivot stay stable.
	_rect(img, 3 + frame % 3, cy - 1, 10 if is_charged else 7, 2, PALETTE.COLORS[15])
	_rect(img, 6 + frame % 3, cy, 8 if is_charged else 5, 1, PALETTE.COLORS[17])
	for particle in range(3):
		var age := (frame + particle * 3) % 8
		var px := 12 - age
		var py := cy + (-1 if particle % 2 == 0 else 1) * (3 + age / 3)
		_ellipse(img, Vector2i(px, py), 1, 1, 18 if age < 3 else 16, age > 4)
	if is_charged:
		var shell_height: int = [9, 9, 10, 10, 11, 11, 10, 9][frame]
		_ellipse(img, Vector2i(31, cy), 14, shell_height, 16, true)
		_ellipse(img, Vector2i(32, cy), 12, shell_height - 2, 18, true)
		for highlight in range(2):
			var angle := frame * TAU / 8.0 + highlight * PI
			var point := Vector2i(31 + roundi(cos(angle) * 13), cy + roundi(sin(angle) * (shell_height - 1)))
			_rect(img, point.x, point.y, 2, 1, PALETTE.COLORS[23])
		_rect(img, 19 - frame % 3, 2, 10 + frame % 3, 1, PALETTE.COLORS[22])
		_rect(img, 24 - frame % 3, 22, 10, 1, PALETTE.COLORS[23])
		_rect(img, 10 - frame % 3, 5, 7, 1, PALETTE.COLORS[22])
		_rect(img, 12 - frame % 3, 19, 8, 1, PALETTE.COLORS[22])
		_rect(img, 44, cy - 1, 3, 3, PALETTE.COLORS[19])
	else:
		_rect(img, 11, cy - 5, 8, 1, PALETTE.COLORS[16])
		_rect(img, 12, cy + 5, 7, 1, PALETTE.COLORS[16])
	_atom(img, Vector2i(rear, cy + bob[frame]), radius)
	_atom(img, Vector2i(front, cy), radius)
	# Two short parallel bars are the O=O visual mnemonic.
	_rect(img, rear + 2, cy - 1, front - rear - 3, 1, PALETTE.COLORS[19 if frame < 4 else 18])
	_rect(img, rear + 2, cy + 1, front - rear - 3, 1, PALETTE.COLORS[18])
	return img

func _explosion(is_charged: bool, frame: int) -> Image:
	var size := 64 if is_charged else 48
	var img := _blank(size, size)
	var center := Vector2i(size / 2, size / 2)
	var count := 12 if is_charged else 10
	if frame == count - 1:
		return img # End fully transparent, rather than popping out on a visible frame.
	var maximum := 27 if is_charged else 20
	var radii := [3, 7, 11, 15, 18, 20, 21, 22, 23, 24, 25, 26]
	var radius := mini(int(radii[frame]) + (3 if is_charged else 0), maximum)
	if frame < 2:
		# A sharp two-frame hit flash with a larger white core at frame 1.
		_ellipse(img, center, radius, radius, 18)
		_ellipse(img, center, radius - 1, radius - 1, 19)
		_rect(img, center.x - 1, center.y - radius - 3, 3, radius * 2 + 7, PALETTE.COLORS[19])
		_rect(img, center.x - radius - 3, center.y - 1, radius * 2 + 7, 3, PALETTE.COLORS[19])
	elif frame < 6:
		# An uneven gas cloud rolls outward, leaving a hollow center.
		for lobe in range(6):
			var angle := float(lobe) * TAU / 6.0
			var point := center + Vector2i(roundi(cos(angle) * (radius - 4)), roundi(sin(angle) * (radius - 4)))
			_ellipse(img, point, 5 if frame < 4 else 3, 4 if frame < 4 else 3, 15)
			_ellipse(img, point + Vector2i(0, -1), 4 if frame < 4 else 2, 3 if frame < 4 else 2, 17)
		_ellipse(img, center, radius - 2, radius - 2, 18, true)
		if frame < 4:
			_ellipse(img, center, 7 - frame, 6 - frame, 19)
	elif frame < count - 2:
		# Progressively shorter arcs bridge the solid ring and scattered bubbles.
		var coverage := 0.65 - float(frame - 6) * 0.18
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var distance := x * x + y * y
				if distance > radius * radius or distance < (radius - 1) * (radius - 1):
					continue
				var segment := fposmod(atan2(float(y), float(x)) + PI + 0.1, TAU / 8.0) / (TAU / 8.0)
				if segment < coverage:
					_rect(img, center.x + x, center.y + y, 1, 1, PALETTE.COLORS[16 if frame < 8 else 15])
	# Ring breaks into arcs, then bubbles and individual pixels.
	for particle in range(8 if is_charged else 6):
		var angle := float(particle) * TAU / (8.0 if is_charged else 6.0) + 0.2
		var travel := mini(radius + (frame - 5 if frame > 5 else 0), maximum)
		var point := center + Vector2i(roundi(cos(angle) * travel), roundi(sin(angle) * travel))
		var bubble_size := 3 if frame < 6 else (2 if frame < count - 3 else 1)
		var color := 18 if frame < 5 else (17 if frame < count - 3 else 16)
		_ellipse(img, point, bubble_size, bubble_size, color, frame >= 3)
		if is_charged and frame >= 2 and frame < 8 and particle % 2 == 0:
			_rect(img, point.x - 1, point.y - 1, 2, 1, PALETTE.COLORS[23 if frame < 5 else 22])
		if frame >= 4 and frame < count - 2:
			var dust := center + Vector2i(roundi(cos(angle + 0.3) * (travel - 5)), roundi(sin(angle + 0.3) * (travel - 5)))
			_rect(img, dust.x, dust.y, 1, 1, PALETTE.COLORS[16])
	return img

func _save_strip(frames: Array[Image], filename: String) -> void:
	var strip := _blank(frames[0].get_width() * frames.size(), frames[0].get_height())
	for i in range(frames.size()):
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, frames[i].get_size()), Vector2i(i * frames[i].get_width(), 0))
	strip.save_png(OUTPUT + filename)

func _text(img: Image, text: String, x: int, y: int, scale: int, color: Color) -> void:
	for letter in text:
		var glyph: String = GLYPHS.get(letter, GLYPHS[" "])
		for row in range(7):
			for col in range(5):
				if glyph[row * 5 + col] == "1":
					_rect(img, x + col * scale, y + row * scale, scale, scale, color)
		x += 6 * scale

func _paste(img: Image, sprite: Image, x: int, y: int, scale: int) -> void:
	var large := sprite.duplicate() as Image
	large.resize(sprite.get_width() * scale, sprite.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.blend_rect(large, Rect2i(Vector2i.ZERO, large.get_size()), Vector2i(x, y))

func _preview(normal: Array[Image], charged: Array[Image], impacts: Array[Image], charged_impacts: Array[Image]) -> Image:
	var board := _blank(1120, 1056)
	board.fill(PALETTE.COLORS[0])
	for x in range(0, 1120, 16):
		_rect(board, x, 0, 1, 1056, Color("#101c2e"))
	for y in range(0, 1056, 16):
		_rect(board, 0, y, 1120, 1, Color("#101c2e"))
	_rect(board, 32, 32, 5, 63, PALETTE.COLORS[17])
	_text(board, "O2 / OXYGEN", 52, 34, 5, PALETTE.COLORS[19])
	_text(board, "FLIGHT / EXPLOSION ANIMATION", 54, 80, 2, PALETTE.COLORS[6])
	for x in [32, 576]:
		_rect(board, x, 128, 512, 312, PALETTE.COLORS[1])
		_rect(board, x, 128, 512, 2, PALETTE.COLORS[15])
	_text(board, "01 NORMAL", 52, 148, 3, PALETTE.COLORS[18])
	_text(board, "32 X 16 / 8 FRAMES / 16 FPS", 52, 182, 2, PALETTE.COLORS[6])
	_paste(board, normal[2], 105, 217, 10)
	_text(board, "02 CHARGED", 596, 148, 3, PALETTE.COLORS[23])
	_text(board, "48 X 24 / 8 FRAMES / 16 FPS", 596, 182, 2, PALETTE.COLORS[6])
	_paste(board, charged[2], 634, 202, 8)
	for i in range(8):
		_paste(board, normal[i], 32 + i * 64, 397, 2)
		_paste(board, charged[i], 600 + i * 60, 397, 1)
	_rect(board, 32, 464, 1056, 172, PALETTE.COLORS[1])
	_text(board, "03 NORMAL EXPLOSION / 48 X 48 / 10 FRAMES / 24 FPS", 52, 482, 2, PALETTE.COLORS[18])
	for i in range(10):
		_paste(board, impacts[i], 40 + i * 104, 528, 2)
	_rect(board, 32, 660, 1056, 338, PALETTE.COLORS[1])
	_text(board, "04 CHARGED EXPLOSION / 64 X 64 / 12 FRAMES / 24 FPS", 52, 680, 2, PALETTE.COLORS[23])
	for i in range(12):
		_paste(board, charged_impacts[i], 48 + (i % 6) * 174, 718 + (i / 6) * 138, 2)
	for i in range(7):
		_rect(board, 32 + i * 42, 1020, 30, 26, PALETTE.COLORS[[1, 15, 16, 17, 18, 19, 22][i]])
	_text(board, "FLASH - GAS CLOUD - RING - DISSIPATE", 356, 1026, 2, PALETTE.COLORS[6])
	return board
