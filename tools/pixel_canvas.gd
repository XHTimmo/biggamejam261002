extends Control

signal image_changed

const GRID_WIDTH := 32
const GRID_HEIGHT := 48
const CELL_SIZE := 8.0
const PADDING := 16.0

var image := Image.create(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8)
var onion_image: Image
var paint_color := Color.WHITE
var show_grid := true
var show_onion := false

func _ready() -> void:
	custom_minimum_size = Vector2(GRID_WIDTH * CELL_SIZE + PADDING * 2.0, GRID_HEIGHT * CELL_SIZE + PADDING * 2.0)
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func set_image(next_image: Image) -> void:
	image = next_image
	queue_redraw()

func set_onion_image(next_image: Image) -> void:
	onion_image = next_image
	queue_redraw()

func set_paint_color(color: Color) -> void:
	paint_color = color

func set_onion_enabled(enabled: bool) -> void:
	show_onion = enabled
	queue_redraw()

func clear_image() -> void:
	image.fill(Color(0, 0, 0, 0))
	image_changed.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_paint_at(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_paint_at(event.position, true)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_at(event.position, false)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_paint_at(event.position, true)

func _paint_at(position: Vector2, erase: bool) -> void:
	var pixel := Vector2i(
		floor((position.x - PADDING) / CELL_SIZE),
		floor((position.y - PADDING) / CELL_SIZE)
	)
	if pixel.x < 0 or pixel.x >= GRID_WIDTH or pixel.y < 0 or pixel.y >= GRID_HEIGHT:
		return
	var color := Color(0, 0, 0, 0) if erase else paint_color
	if image.get_pixel(pixel.x, pixel.y) == color:
		return
	image.set_pixel(pixel.x, pixel.y, color)
	image_changed.emit()
	queue_redraw()

func _draw() -> void:
	var canvas_rect := Rect2(PADDING, PADDING, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
	draw_rect(Rect2(0, 0, custom_minimum_size.x, custom_minimum_size.y), Color("#111a2c"), true)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var checker := Color("#27344b") if (x + y) % 2 == 0 else Color("#1f2a40")
			draw_rect(Rect2(PADDING + x * CELL_SIZE, PADDING + y * CELL_SIZE, CELL_SIZE, CELL_SIZE), checker, true)
	if show_onion and onion_image:
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var onion_color := onion_image.get_pixel(x, y)
				if onion_color.a > 0.0:
					onion_color.a = 0.25
					draw_rect(Rect2(PADDING + x * CELL_SIZE, PADDING + y * CELL_SIZE, CELL_SIZE, CELL_SIZE), onion_color, true)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var pixel_color := image.get_pixel(x, y)
			if pixel_color.a > 0.0:
				draw_rect(Rect2(PADDING + x * CELL_SIZE, PADDING + y * CELL_SIZE, CELL_SIZE, CELL_SIZE), pixel_color, true)
	if show_grid:
		for x in range(GRID_WIDTH + 1):
			var line_x := PADDING + x * CELL_SIZE
			draw_line(Vector2(line_x, PADDING), Vector2(line_x, PADDING + GRID_HEIGHT * CELL_SIZE), Color(0.55, 0.7, 0.85, 0.20), 1.0)
		for y in range(GRID_HEIGHT + 1):
			var line_y := PADDING + y * CELL_SIZE
			draw_line(Vector2(PADDING, line_y), Vector2(PADDING + GRID_WIDTH * CELL_SIZE, line_y), Color(0.55, 0.7, 0.85, 0.20), 1.0)
	draw_rect(canvas_rect, Color("#9AF5E5"), false, 2.0)

