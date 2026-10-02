extends AnimatableBody2D

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
	draw_rect(rect, Color("#24494c"))
	draw_rect(rect.grow(-3), Color("#438c89"))
	draw_line(rect.position, rect.position + Vector2(platform_size.x, 0), Color("#a9fff0"), 3)
	for x in range(int(-platform_size.x / 2) + 8, int(platform_size.x / 2) - 4, 20):
		draw_line(Vector2(x, 2), Vector2(x + 8, 7), Color("#e8b66d"), 3)
