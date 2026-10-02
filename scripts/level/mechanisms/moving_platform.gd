extends AnimatableBody2D

const PLATFORM_TILE_TEXTURE = preload("res://assets/environment/tech_floating_platform_tile.png")

@export var platform_size := Vector2(144, 20)
@export var end_offset := Vector2(0, -190)
@export var travel_speed := 95.0
@export var automatic := false

var origin := Vector2.ZERO
var activated := false
var progress := 0.0
var travel_direction := 1.0
var gravity_remaining := 0.0

func gravity_hit() -> void:
	gravity_remaining = 4.0

func _ready() -> void:
	origin = position
	sync_to_physics = true
	add_to_group("gravity_affected")
	queue_redraw()

func set_active(value: bool) -> void:
	activated = value

func _physics_process(delta: float) -> void:
	gravity_remaining = maxf(0, gravity_remaining - delta)
	var step := travel_speed * delta / maxf(end_offset.length(), 1.0)
	if automatic:
		progress = clampf(progress + step * travel_direction, 0.0, 1.0)
		if progress >= 1.0 or progress <= 0.0:
			travel_direction *= -1.0
	else:
		progress = move_toward(progress, 1.0 if activated or gravity_remaining > 0 else 0.0, step)
	position = origin + end_offset * progress
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-platform_size * 0.5, platform_size)
	draw_texture_rect(PLATFORM_TILE_TEXTURE, rect, true)
	var edge_color := Color("#D8FFFF") if activated or gravity_remaining > 0 else Color("#9AF5E5")
	draw_line(rect.position, rect.position + Vector2(platform_size.x, 0), edge_color, 2)
