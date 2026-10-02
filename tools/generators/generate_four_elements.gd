extends "res://tools/generators/generate_oxygen_bullets.gd"

# Design-stage sprites only. Reuses the established pixel raster and oxygen art.
const ELEMENT_OUTPUT := "res://assets/chemistry_bullets/four_elements/"
const ELEMENTS := ["hydrogen", "oxygen", "carbon", "iron"]
const LABELS := ["H2 / HYDROGEN", "O2 / OXYGEN", "C / CARBON", "Fe / IRON"]
const ACCENTS := [31, 17, 22, 29]
var catalog: Dictionary = {}
var art: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ELEMENT_OUTPUT))
	for element in ELEMENTS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ELEMENT_OUTPUT + element))
		var variants: Dictionary = {}
		for charged in [false, true]:
			var name := "charged" if charged else "normal"
			var flight: Array[Image] = []
			var impact: Array[Image] = []
			for frame in range(8):
				flight.append(_element_flight(element, charged, frame))
			for frame in range(12 if charged else 10):
				impact.append(_element_impact(element, charged, frame))
			art[element + "_" + name + "_flight"] = flight
			art[element + "_" + name + "_impact"] = impact
			variants[name] = {
				"flight": _export_frames(flight, element + "/" + name + "_flight", 16, true, Vector2i(31, 12) if charged else Vector2i(21, 8)),
				"impact": _export_frames(impact, element + "/" + name + "_impact", 24, false, Vector2i(32, 32) if charged else Vector2i(24, 24))
			}
		catalog[element] = variants
		_element_board(element).save_png(ELEMENT_OUTPUT + element + "/design.png")
		_icon(element).save_png(ELEMENT_OUTPUT + element + "/icon.png")
	var weapons: Dictionary = {}
	for solid in [false, true]:
		var key := "solid_launcher" if solid else "compressed_air_gun"
		var shot: Array[Image] = []
		for frame in range(6):
			shot.append(_weapon(solid, frame, false))
		art[key] = shot
		shot[0].save_png(ELEMENT_OUTPUT + key + ".png")
		weapons[key] = _export_frames(shot, key + "_shot", 16, false, Vector2i(22, 18))
	var reload: Array[Image] = []
	for frame in range(8):
		reload.append(_weapon(true, frame, true))
	weapons["solid_reload"] = _export_frames(reload, "solid_launcher_reload", 12, false, Vector2i(22, 18))
	var reaction: Array[Image] = []
	for frame in range(12):
		reaction.append(_hydrogen_reaction(frame))
	catalog["conditional_hydrogen_reaction"] = _export_frames(reaction, "hydrogen/ignited_reaction", 24, false, Vector2i(32, 32))
	_overview().save_png(ELEMENT_OUTPUT + "four_elements_design.png")
	var metadata := {"status": "design_prototype", "palette": "res://scripts/shared/palette.gd", "orientation": "right", "filter": "nearest", "elements": catalog, "weapons": weapons}
	var file := FileAccess.open(ELEMENT_OUTPUT + "catalog.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	var browser_data := FileAccess.open(ELEMENT_OUTPUT + "catalog.js", FileAccess.WRITE)
	browser_data.store_string("window.ELEMENT_CATALOG = " + JSON.stringify(metadata) + ";\n")
	print("Generated four-element design sprites, weapon animations, boards and catalog.")
	quit()

func _export_frames(frames: Array[Image], path: String, fps: int, loop: bool, pivot: Vector2i) -> Dictionary:
	var size := frames[0].get_size()
	var strip := _blank(size.x * frames.size(), size.y)
	for frame in range(frames.size()):
		strip.blit_rect(frames[frame], Rect2i(Vector2i.ZERO, size), Vector2i(frame * size.x, 0))
	strip.save_png(ELEMENT_OUTPUT + path + "_strip.png")
	frames[0].save_png(ELEMENT_OUTPUT + path + ".png")
	return {"file": path + "_strip.png", "size": [size.x, size.y], "frames": frames.size(), "fps": fps, "loop": loop, "pivot": [pivot.x, pivot.y]}

func _polygon(img: Image, points: PackedVector2Array, index: int) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				_rect(img, x, y, 1, 1, PALETTE.COLORS[index])

func _carbon_chip(img: Image, center: Vector2i, radius: int, phase: int) -> void:
	var points := PackedVector2Array()
	for corner in range(6):
		var angle := corner * TAU / 6.0 + phase * PI / 4.0
		points.append(Vector2(center) + Vector2(cos(angle), sin(angle)) * radius)
	_polygon(img, points, 1)
	points = PackedVector2Array()
	for corner in range(6):
		var angle := corner * TAU / 6.0 + phase * PI / 4.0
		points.append(Vector2(center) + Vector2(cos(angle), sin(angle)) * (radius - 1))
	_polygon(img, points, 3)
	_rect(img, center.x - radius + 2, center.y - 1, radius, 1, PALETTE.COLORS[6])
	_rect(img, center.x - 1, center.y + 1, maxi(1, radius - 1), 1, PALETTE.COLORS[4])

func _element_flight(element: String, charged: bool, frame: int) -> Image:
	if element == "oxygen":
		return _flight(charged, frame)
	var img := _blank(48 if charged else 32, 24 if charged else 16)
	var center := Vector2i(31, 12) if charged else Vector2i(21, 8)
	if element == "hydrogen":
		var bob: int = [0, -1, -2, -1, 0, 1, 2, 1][frame]
		var radius := 4 if charged else 3
		for atom in range(2):
			var point := center + Vector2i((atom * 2 - 1) * (5 if charged else 4), bob if atom == 0 else -bob / 2)
			_ellipse(img, point, radius, radius, 13)
			_ellipse(img, point, radius - 1, radius - 1, 31)
			_rect(img, point.x - 1, point.y - 1, 2, 1, PALETTE.COLORS[19])
		_rect(img, center.x - 2, center.y, 5, 1, PALETTE.COLORS[19])
		for particle in range(4):
			var age := (frame + particle * 2) % 8
			var x := center.x - 8 - age
			var y := center.y - age / 3 + particle % 2 * 3
			_rect(img, x, y, 2, 1, PALETTE.COLORS[31 if age < 4 else 13])
		if charged:
			_ellipse(img, center, 13, 8 + frame % 2, 26, true)
			for highlight in range(3):
				var angle := frame * TAU / 8.0 + highlight * TAU / 3.0
				_rect(img, center.x + roundi(cos(angle) * 13), center.y + roundi(sin(angle) * 8), 2, 1, PALETTE.COLORS[19])
	elif element == "carbon":
		_rect(img, 3 + frame % 3, center.y, 9, 1, PALETTE.COLORS[4])
		if charged:
			_carbon_chip(img, center, 10, frame / 2)
			_rect(img, center.x - 6, center.y - 3, 12, 1, PALETTE.COLORS[29])
			_rect(img, center.x - 5, center.y, 11, 1, PALETTE.COLORS[5])
			_rect(img, center.x - 4, center.y + 3, 9, 1, PALETTE.COLORS[4])
		else:
			_carbon_chip(img, center, 5, frame / 2)
			_carbon_chip(img, center + Vector2i(-8, -4), 3, (frame + 2) / 2)
			_carbon_chip(img, center + Vector2i(-9, 4), 3, (frame + 4) / 2)
		_rect(img, 7 - frame % 4, center.y + 4, 1, 1, PALETTE.COLORS[6])
	else:
		_rect(img, 4 + frame % 3, center.y, 10, 1, PALETTE.COLORS[5])
		if charged:
			_polygon(img, PackedVector2Array([Vector2(21, 7), Vector2(35, 7), Vector2(42, 12), Vector2(35, 17), Vector2(21, 17)]), 1)
			_polygon(img, PackedVector2Array([Vector2(23, 8), Vector2(34, 8), Vector2(40, 12), Vector2(34, 16), Vector2(23, 16)]), 5)
			_polygon(img, PackedVector2Array([Vector2(23, 8), Vector2(34, 8), Vector2(40, 12), Vector2(23, 12)]), 29)
			_rect(img, 25 + frame % 3, 9, 7, 1, PALETTE.COLORS[8])
			_rect(img, 23, 13, 11, 1, PALETTE.COLORS[4])
		else:
			_ellipse(img, center, 5, 5, 1)
			_ellipse(img, center, 4, 4, 5)
			_ellipse(img, center + Vector2i(0, -1), 3, 2, 29)
			_rect(img, center.x - 2 + frame % 3, center.y - 2, 2, 1, PALETTE.COLORS[8])
	return img

func _element_impact(element: String, charged: bool, frame: int) -> Image:
	if element == "oxygen":
		return _explosion(charged, frame)
	var size := 64 if charged else 48
	var img := _blank(size, size)
	var count := 12 if charged else 10
	var center := Vector2i(size / 2, size / 2)
	if frame == count - 1:
		return img
	if element == "hydrogen":
		var radius := mini(3 + frame * 2, size / 2 - 6)
		if frame < 5:
			_ellipse(img, center, radius, maxi(2, radius - 2), 31 if frame < 3 else 26, true)
		if frame < 2:
			_ellipse(img, center, 4 + frame * 2, 3 + frame * 2, 19)
		for particle in range(6):
			var angle := particle * TAU / 6.0
			var point := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius) - frame)
			_ellipse(img, point, 2 if frame < 6 else 1, 2 if frame < 6 else 1, 31 if frame < 6 else 13, true)
	elif element == "carbon":
		if frame < 3:
			_carbon_chip(img, center, (8 if charged else 5) - frame, frame)
		for particle in range(9 if charged else 6):
			var angle := particle * TAU / (9.0 if charged else 6.0)
			var radius := 3 + frame * (2 if charged else 1)
			var point := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius) + frame * frame / 8)
			if frame < count - 3:
				_carbon_chip(img, point, 3 if frame < 5 else 2, particle + frame)
			else:
				_rect(img, point.x, point.y, 1, 1, PALETTE.COLORS[4])
	else:
		if frame < 3:
			_rect(img, center.x - 1, center.y - 5, 2, 10, PALETTE.COLORS[8 if frame < 2 else 29])
			var reach := (10 if charged else 6) + frame * 2
			_polygon(img, PackedVector2Array([Vector2(center), Vector2(center.x - reach, center.y - 6), Vector2(center.x - 3, center.y - 1)]), 23)
			_polygon(img, PackedVector2Array([Vector2(center), Vector2(center.x - reach, center.y + 6), Vector2(center.x - 3, center.y + 1)]), 22)
		# Sparks fan backward from the hard-surface impact; never a gas cloud.
		for particle in range(7 if charged else 5):
			var angle := PI * (0.58 + particle * 0.14)
			var radius := 2 + frame * (2 if charged else 1)
			var point := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius) + frame * frame / 12)
			var index := 23 if frame < 3 else (21 if frame < 6 else 20)
			_rect(img, point.x, point.y, 4 if frame < 4 else 2, 2 if frame < 4 else 1, PALETTE.COLORS[index])
		if frame > 2 and frame < count - 2:
			_rect(img, center.x - 2, center.y + frame / 2, 4, 2, PALETTE.COLORS[5])
	return img

func _hydrogen_reaction(frame: int) -> Image:
	var img := _blank(64, 64)
	if frame == 11:
		return img
	var center := Vector2i(32, 32)
	var radius := mini(4 + frame * 3, 26)
	if frame < 5:
		_ellipse(img, center, radius, radius, 21)
		_ellipse(img, center + Vector2i(0, -2), maxi(1, radius - 3), maxi(1, radius - 3), 23)
		_ellipse(img, center, maxi(1, radius - 6), maxi(1, radius - 6), 19)
	else:
		for particle in range(8):
			var angle := particle * TAU / 8.0
			var point := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius) - frame / 2)
			_ellipse(img, point, 2, 2, 31 if frame < 9 else 13, true)
	return img

func _weapon(solid: bool, frame: int, reload: bool) -> Image:
	var img := _blank(64, 32)
	var kick: int = 0 if reload else [0, -2, -3, -2, -1, 0][frame]
	var x := 12 + kick
	if solid:
		_rect(img, x, 10, 24, 14, PALETTE.COLORS[1])
		_rect(img, x + 1, 11, 22, 11, PALETTE.COLORS[4])
		_rect(img, x + 4, 12, 15, 3, PALETTE.COLORS[29])
		_rect(img, x + 7, 17, 13, 2, PALETTE.COLORS[20])
		_rect(img, x + 9, 17, 8, 1, PALETTE.COLORS[22])
		_rect(img, x + 23, 12, 22, 10, PALETTE.COLORS[1])
		_rect(img, x + 24, 13, 19, 7, PALETTE.COLORS[5])
		_rect(img, x + 26, 14, 13, 2, PALETTE.COLORS[6])
		_rect(img, x + 40, 11, 5, 12, PALETTE.COLORS[1])
		_rect(img, x + 42, 15, 3, 4, PALETTE.COLORS[29])
		var magazine_y := 5
		if reload:
			magazine_y = [-4, -2, 0, 2, 4, 5, 5, 5][frame]
		_rect(img, x + 8, magazine_y, 11, 7, PALETTE.COLORS[1])
		_rect(img, x + 9, magazine_y + 1, 9, 5, PALETTE.COLORS[20])
		_rect(img, x + 11, magazine_y + 2, 5, 1, PALETTE.COLORS[22])
	else:
		_ellipse(img, Vector2i(x + 3, 16), 6, 8, 1)
		_ellipse(img, Vector2i(x + 3, 16), 4, 6, 15)
		_rect(img, x + 1, 12, 3, 8, PALETTE.COLORS[17])
		_rect(img, x + 8, 11, 19, 12, PALETTE.COLORS[1])
		_rect(img, x + 9, 12, 17, 9, PALETTE.COLORS[4])
		_rect(img, x + 10, 13, 10, 2, PALETTE.COLORS[17])
		_rect(img, x + 25, 14, 20, 6, PALETTE.COLORS[1])
		_rect(img, x + 26, 15, 17, 4, PALETTE.COLORS[5])
		_rect(img, x + 42, 14, 3, 6, PALETTE.COLORS[17])
	_rect(img, x + 8, 22, 7, 8, PALETTE.COLORS[1])
	_rect(img, x + 9, 23, 5, 6, PALETTE.COLORS[20])
	if not reload and frame in [1, 2]:
		var index := 29 if solid else 18
		_rect(img, x + 46, 16, 4, 2, PALETTE.COLORS[index])
		_rect(img, x + 48, 14, 1, 6, PALETTE.COLORS[index])
	return img

func _icon(element: String) -> Image:
	var img := _blank(16, 16)
	var index := ELEMENTS.find(element)
	_rect(img, 0, 0, 16, 16, PALETTE.COLORS[ACCENTS[index]])
	_rect(img, 1, 1, 14, 14, PALETTE.COLORS[1])
	_label(img, "Fe" if element == "iron" else ["H", "O", "C"][index], 2 if element == "iron" else 5, 4, 1, PALETTE.COLORS[ACCENTS[index]])
	return img

func _label(img: Image, text: String, x: int, y: int, scale: int, color: Color) -> void:
	var extra_glyphs := {
		"B": "11110100011000111110100011000111110",
		"W": "10001100011000110101101011101110001",
		"Q": "01110100011000110001101011001001101",
		"e": "00000000000111010001111111000001111"
	}
	for letter in text:
		if extra_glyphs.has(letter):
			var glyph: String = extra_glyphs[letter]
			for row in range(7):
				for col in range(5):
					if glyph[row * 5 + col] == "1":
						_rect(img, x + col * scale, y + row * scale, scale, scale, color)
		else:
			_text(img, letter, x, y, scale, color)
		x += 6 * scale

func _element_board(element: String) -> Image:
	var board := _blank(1120, 1056)
	board.fill(PALETTE.COLORS[0])
	var index := ELEMENTS.find(element)
	_label(board, LABELS[index], 32, 32, 4, PALETTE.COLORS[ACCENTS[index]])
	_label(board, "FLIGHT / IMPACT / NORMAL AND CHARGED", 32, 78, 2, PALETTE.COLORS[6])
	for charged in [false, true]:
		var name := "charged" if charged else "normal"
		var x := 576 if charged else 32
		_rect(board, x, 120, 512, 306, PALETTE.COLORS[1])
		_label(board, name.to_upper(), x + 20, 140, 3, PALETTE.COLORS[ACCENTS[index]])
		var flight: Array[Image] = art[element + "_" + name + "_flight"]
		_paste(board, flight[2], x + 64, 190, 8 if charged else 10)
		for frame in range(8):
			_paste(board, flight[frame], x + frame * 64, 390, 1 if charged else 2)
	_rect(board, 32, 458, 1056, 174, PALETTE.COLORS[1])
	_label(board, "NORMAL IMPACT / 10 FRAMES / 24 FPS", 52, 476, 2, PALETTE.COLORS[ACCENTS[index]])
	var normal_impact: Array[Image] = art[element + "_normal_impact"]
	for frame in range(10):
		_paste(board, normal_impact[frame], 40 + frame * 104, 526, 2)
	_rect(board, 32, 656, 1056, 338, PALETTE.COLORS[1])
	_label(board, "CHARGED IMPACT / 12 FRAMES / 24 FPS", 52, 676, 2, PALETTE.COLORS[ACCENTS[index]])
	var charged_impact: Array[Image] = art[element + "_charged_impact"]
	for frame in range(12):
		_paste(board, charged_impact[frame], 48 + (frame % 6) * 174, 714 + (frame / 6) * 138, 2)
	_label(board, "DESIGN PROTOTYPE / SHARED 32 COLOR PALETTE", 32, 1022, 2, PALETTE.COLORS[6])
	return board

func _overview() -> Image:
	var board := _blank(1200, 1248)
	board.fill(PALETTE.COLORS[0])
	_label(board, "FOUR ELEMENTS / TWO LAUNCHERS", 32, 28, 4, PALETTE.COLORS[19])
	_label(board, "AIR GUN / H2 O2", 32, 90, 2, PALETTE.COLORS[17])
	_label(board, "SOLID LAUNCHER / C Fe", 624, 90, 2, PALETTE.COLORS[22])
	_paste(board, art["compressed_air_gun"][0], 42, 116, 5)
	_paste(board, art["solid_launcher"][0], 634, 116, 5)
	for index in range(4):
		var element: String = ELEMENTS[index]
		var y := 300 + index * 230
		_rect(board, 32, y, 1136, 210, PALETTE.COLORS[1])
		_rect(board, 32, y, 4, 210, PALETTE.COLORS[ACCENTS[index]])
		_label(board, LABELS[index], 52, y + 16, 3, PALETTE.COLORS[ACCENTS[index]])
		_label(board, "NORMAL", 52, y + 56, 2, PALETTE.COLORS[6])
		_label(board, "CHARGED", 324, y + 56, 2, PALETTE.COLORS[6])
		_label(board, "IMPACT SEQUENCE", 640, y + 56, 2, PALETTE.COLORS[6])
		_paste(board, art[element + "_normal_flight"][2], 52, y + 92, 6)
		_paste(board, art[element + "_charged_flight"][2], 324, y + 82, 5)
		for frame in range(3):
			_paste(board, art[element + "_charged_impact"][1 + frame * 3], 640 + frame * 172, y + 78, 2)
	return board
