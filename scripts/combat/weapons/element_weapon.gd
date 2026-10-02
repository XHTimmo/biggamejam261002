extends Node2D

const CATALOG = preload("res://scripts/shared/element_catalog.gd")
const ROOT := "res://assets/chemistry_bullets/four_elements/"
var element := "oxygen"
var charge_ratio := 0.0
var sprite: Sprite2D
var shot_time := -1.0
var reload_progress := -1.0
var muzzle := Vector2(35, -1)

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Authored grip pivot (22,18), 64×32 source cells.
	sprite.position = Vector2(10, -2)
	add_child(sprite)
	set_element(element)

func set_element(value: String) -> void:
	element = value
	shot_time = -1.0
	reload_progress = -1.0
	sprite.rotation = 0.0
	var family := "compressed_air_gun" if CATALOG.is_gas(element) else "solid_launcher"
	sprite.texture = load(ROOT + family + "_shot_strip.png")
	sprite.hframes = 6
	sprite.frame = 0
	muzzle = Vector2(35, -1)
	queue_redraw()

func fire() -> void:
	shot_time = 0.0
	sprite.frame = 0

func set_reload_progress(progress: float) -> void:
	var was_reloading := reload_progress >= 0.0
	reload_progress = progress
	if progress >= 0.0:
		shot_time = -1.0
		if not CATALOG.is_gas(element):
			if not was_reloading:
				sprite.texture = load(ROOT + "solid_launcher_reload_strip.png")
				sprite.hframes = 8
			sprite.frame = mini(int(progress * 8.0), 7)
		else:
			sprite.frame = 0
			sprite.rotation = -0.15 * sin(progress * PI)
	elif was_reloading:
		var family := "compressed_air_gun" if CATALOG.is_gas(element) else "solid_launcher"
		sprite.texture = load(ROOT + family + "_shot_strip.png")
		sprite.hframes = 6
		sprite.frame = 0
		sprite.rotation = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if shot_time >= 0:
		shot_time += delta
		var frame := int(shot_time * 16.0)
		sprite.frame = mini(frame, 5)
		if frame >= 6:
			shot_time = -1.0
			sprite.frame = 0
	queue_redraw()

func _draw() -> void:
	var tint: Color = CATALOG.TINTS[CATALOG.index_of(element)]
	# Material marker stays distinct even when two elements share a launcher.
	if CATALOG.is_gas(element):
		draw_rect(Rect2(-9, -5, 6, 8), tint)
	else:
		draw_rect(Rect2(0, -13, 12, 4), tint)
		draw_line(Vector2(2, -12), Vector2(10, -12), tint.darkened(0.5), 1)
	if charge_ratio > 0:
		draw_rect(Rect2(0, -16, roundf(20 * charge_ratio), 2), tint)
	if reload_progress >= 0.0:
		# Gas bottle lift and pressure refill; solid reload uses authored magazine frames.
		if CATALOG.is_gas(element):
			var lift := roundf(sin(reload_progress * PI) * 7.0)
			draw_rect(Rect2(-10, -6 - lift, 8, 10), Color("#10262e"))
			draw_rect(Rect2(-9, -5 - lift, 6, 8), tint)
		draw_rect(Rect2(-6, -19, 28, 3), Color("#10262e"))
		draw_rect(Rect2(-5, -18, roundf(26 * reload_progress), 1), tint)
