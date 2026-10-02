extends Control

const PALETTE = preload("res://assets/palette.gd")
const PIXEL_CANVAS = preload("res://tools/pixel_canvas.gd")
const GRID_WIDTH := 32
const GRID_HEIGHT := 48

var palette: Array[Color] = []
var palette_names: Array[String] = []
var frames: Array[Image] = []
var current_frame := 0
var current_palette_index := 17
var playing := false
var playback_clock := 0.0

var pixel_canvas: Control
var frame_list: ItemList
var frame_label: Label
var status_label: Label
var hex_edit: LineEdit
var color_preview: ColorRect
var selected_name_label: Label
var onion_toggle: CheckButton
var grid_toggle: CheckButton
var playback_toggle: CheckButton
var fps_spin: SpinBox

func _ready() -> void:
	for color in PALETTE.COLORS:
		palette.append(color)
	for name in PALETTE.NAMES:
		palette_names.append(name)
	frames.append(_new_frame())
	_build_ui()
	_select_palette(current_palette_index)
	_refresh_frame_list()
	set_process(true)
	DisplayServer.window_set_title("像素调色与动画工作台")

func _process(delta: float) -> void:
	if not playing or frames.is_empty():
		return
	playback_clock += delta
	var frame_duration := 1.0 / maxf(1.0, fps_spin.value)
	if playback_clock >= frame_duration:
		playback_clock = 0.0
		current_frame = (current_frame + 1) % frames.size()
		_refresh_frame_list()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	var title := Label.new()
	title.text = "像素角色工作台"
	title.add_theme_font_size_override("font_size", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "32 色 · 32×48 · 多帧动画"
	subtitle.add_theme_color_override("font_color", Color("#8DA7BE"))
	header.add_child(subtitle)
	var back_button := Button.new()
	back_button.text = "返回 Demo"
	back_button.pressed.connect(_back_to_demo)
	header.add_child(back_button)

	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	page.add_child(workspace)
	workspace.add_child(_build_palette_panel())
	workspace.add_child(_build_canvas_panel())
	workspace.add_child(_build_frame_panel())

	status_label = Label.new()
	status_label.text = "选择颜色后，在画布上左键绘制，右键擦除。"
	status_label.add_theme_color_override("font_color", Color("#8DA7BE"))
	page.add_child(status_label)

func _build_palette_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(238, 0)
	panel.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "调色板 · 32 色"
	heading.add_theme_font_size_override("font_size", 18)
	panel.add_child(heading)

	var selected_row := HBoxContainer.new()
	color_preview = ColorRect.new()
	color_preview.custom_minimum_size = Vector2(34, 34)
	selected_row.add_child(color_preview)
	hex_edit = LineEdit.new()
	hex_edit.custom_minimum_size = Vector2(105, 34)
	hex_edit.placeholder_text = "#RRGGBB"
	selected_row.add_child(hex_edit)
	var apply_button := Button.new()
	apply_button.text = "应用"
	apply_button.pressed.connect(_apply_hex_color)
	selected_row.add_child(apply_button)
	panel.add_child(selected_row)

	selected_name_label = Label.new()
	selected_name_label.text = ""
	selected_name_label.add_theme_color_override("font_color", Color("#E7E3D2"))
	panel.add_child(selected_name_label)

	var swatches := GridContainer.new()
	swatches.columns = 4
	swatches.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index in range(palette.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(52, 31)
		swatch.text = "%02d" % index
		swatch.tooltip_text = "%s  %s" % [palette_names[index], palette[index].to_html(false)]
		swatch.modulate = palette[index]
		swatch.add_theme_color_override("font_color", Color.BLACK if palette[index].get_luminance() > 0.68 else Color.WHITE)
		swatch.pressed.connect(_select_palette.bind(index))
		swatches.add_child(swatch)
	panel.add_child(swatches)

	var save_palette := Button.new()
	save_palette.text = "保存调色板到 user://"
	save_palette.pressed.connect(_save_palette)
	panel.add_child(save_palette)
	return panel

func _build_canvas_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 8)
	frame_label = Label.new()
	frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(frame_label)

	pixel_canvas = PIXEL_CANVAS.new()
	pixel_canvas.image_changed.connect(_on_canvas_changed)
	panel.add_child(pixel_canvas)

	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	onion_toggle = CheckButton.new()
	onion_toggle.text = "洋葱皮"
	onion_toggle.toggled.connect(_onion_toggled)
	options.add_child(onion_toggle)
	grid_toggle = CheckButton.new()
	grid_toggle.text = "网格"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(_grid_toggled)
	options.add_child(grid_toggle)
	playback_toggle = CheckButton.new()
	playback_toggle.text = "播放"
	playback_toggle.toggled.connect(_playback_toggled)
	options.add_child(playback_toggle)
	var fps_label := Label.new()
	fps_label.text = "FPS"
	options.add_child(fps_label)
	fps_spin = SpinBox.new()
	fps_spin.min_value = 1
	fps_spin.max_value = 24
	fps_spin.value = 8
	fps_spin.custom_minimum_size = Vector2(62, 0)
	options.add_child(fps_spin)
	panel.add_child(options)
	return panel

func _build_frame_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(210, 0)
	panel.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "动画帧"
	heading.add_theme_font_size_override("font_size", 18)
	panel.add_child(heading)

	frame_list = ItemList.new()
	frame_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_list.item_selected.connect(_on_frame_selected)
	panel.add_child(frame_list)

	var add_row := HBoxContainer.new()
	var add_button := Button.new()
	add_button.text = "+ 新帧"
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_add_frame)
	add_row.add_child(add_button)
	var duplicate_button := Button.new()
	duplicate_button.text = "复制"
	duplicate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate_button.pressed.connect(_duplicate_frame)
	add_row.add_child(duplicate_button)
	panel.add_child(add_row)

	var edit_row := HBoxContainer.new()
	var clear_button := Button.new()
	clear_button.text = "清空"
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_button.pressed.connect(_clear_frame)
	edit_row.add_child(clear_button)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.pressed.connect(_delete_frame)
	edit_row.add_child(delete_button)
	panel.add_child(edit_row)

	var save_frame := Button.new()
	save_frame.text = "导出当前帧 PNG"
	save_frame.pressed.connect(_save_current_frame)
	panel.add_child(save_frame)
	var export_sheet := Button.new()
	export_sheet.text = "导出精灵条 PNG"
	export_sheet.pressed.connect(_export_sprite_sheet)
	panel.add_child(export_sheet)
	return panel

func _new_frame() -> Image:
	var frame := Image.create(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0, 0, 0, 0))
	return frame

func _select_palette(index: int) -> void:
	current_palette_index = clampi(index, 0, palette.size() - 1)
	var color := palette[current_palette_index]
	if pixel_canvas:
		pixel_canvas.set_paint_color(color)
	if color_preview:
		color_preview.color = color
	if hex_edit:
		hex_edit.text = "#" + color.to_html(false).to_upper()
	if selected_name_label:
		selected_name_label.text = "%02d · %s" % [current_palette_index, palette_names[current_palette_index]]

func _apply_hex_color() -> void:
	var fallback := palette[current_palette_index]
	var parsed := Color.from_string(hex_edit.text.strip_edges(), fallback)
	palette[current_palette_index] = parsed
	_select_palette(current_palette_index)
	status_label.text = "已修改颜色 %02d：%s" % [current_palette_index, parsed.to_html(false)]

func _refresh_frame_list() -> void:
	if not frame_list:
		return
	frame_list.clear()
	for index in range(frames.size()):
		frame_list.add_item("Frame %02d" % (index + 1))
	frame_list.select(current_frame)
	frame_label.text = "Frame %02d / %02d" % [current_frame + 1, frames.size()]
	pixel_canvas.set_image(frames[current_frame])
	if current_frame > 0:
		pixel_canvas.set_onion_image(frames[current_frame - 1])
	else:
		pixel_canvas.set_onion_image(null)

func _on_frame_selected(index: int) -> void:
	current_frame = clampi(index, 0, frames.size() - 1)
	_refresh_frame_list()

func _on_canvas_changed() -> void:
	status_label.text = "Frame %02d 已修改。" % (current_frame + 1)

func _onion_toggled(enabled: bool) -> void:
	pixel_canvas.set_onion_enabled(enabled)

func _grid_toggled(enabled: bool) -> void:
	pixel_canvas.show_grid = enabled
	pixel_canvas.queue_redraw()

func _playback_toggled(enabled: bool) -> void:
	playing = enabled
	playback_clock = 0.0

func _add_frame() -> void:
	frames.insert(current_frame + 1, _new_frame())
	current_frame += 1
	_refresh_frame_list()
	status_label.text = "已添加空白帧。"

func _duplicate_frame() -> void:
	frames.insert(current_frame + 1, frames[current_frame].duplicate())
	current_frame += 1
	_refresh_frame_list()
	status_label.text = "已复制当前帧。"

func _clear_frame() -> void:
	frames[current_frame].fill(Color(0, 0, 0, 0))
	pixel_canvas.queue_redraw()
	status_label.text = "当前帧已清空。"

func _delete_frame() -> void:
	if frames.size() <= 1:
		status_label.text = "至少保留一帧。"
		return
	frames.remove_at(current_frame)
	current_frame = clampi(current_frame, 0, frames.size() - 1)
	_refresh_frame_list()
	status_label.text = "已删除当前帧。"

func _ensure_output_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir("pixel_workbench")

func _save_current_frame() -> void:
	_ensure_output_dir()
	var path := "user://pixel_workbench/frame_%02d.png" % (current_frame + 1)
	frames[current_frame].save_png(path)
	status_label.text = "当前帧已保存：%s" % path

func _export_sprite_sheet() -> void:
	_ensure_output_dir()
	var sheet := Image.create(GRID_WIDTH * frames.size(), GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for index in range(frames.size()):
		sheet.blit_rect(frames[index], Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT), Vector2i(index * GRID_WIDTH, 0))
	var path := "user://pixel_workbench/character_sheet.png"
	sheet.save_png(path)
	status_label.text = "精灵条已保存：%s" % path

func _save_palette() -> void:
	_ensure_output_dir()
	var json_colors: Array[String] = []
	for color in palette:
		json_colors.append("#" + color.to_html(false).to_upper())
	var json_file := FileAccess.open("user://pixel_workbench/palette.json", FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify({"colors": json_colors, "names": palette_names}, "\t"))
	var gpl_file := FileAccess.open("user://pixel_workbench/palette.gpl", FileAccess.WRITE)
	if gpl_file:
		gpl_file.store_line("GIMP Palette")
		gpl_file.store_line("Name: Chemistry Lab 32")
		gpl_file.store_line("Columns: 8")
		gpl_file.store_line("#")
		for index in range(palette.size()):
			var color := palette[index]
			gpl_file.store_line("%d %d %d\t%02d %s" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0), index, palette_names[index]])
	status_label.text = "调色板已保存到 user://pixel_workbench/。"

func _back_to_demo() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
