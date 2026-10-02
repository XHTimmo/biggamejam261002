extends CharacterBody2D

const GRAVITY := 1500.0
const PUSH_SPEED := 150.0
const PUSH_ACCELERATION := 900.0
const FRICTION := 700.0

var requested_push := 0.0

func _ready() -> void:
	add_to_group("weights")
	queue_redraw()

func request_push(direction: float) -> void:
	requested_push = clampf(direction, -1.0, 1.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if not is_zero_approx(requested_push):
		velocity.x = move_toward(velocity.x, requested_push * PUSH_SPEED, PUSH_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	requested_push = 0.0
	move_and_slide()

func _draw() -> void:
	draw_rect(Rect2(-28, -28, 56, 56), Color("#d47f58"), true)
	draw_rect(Rect2(-21, -21, 42, 42), Color("#f2b36a"), true)
	draw_line(Vector2(-15, -15), Vector2(15, 15), Color("#985744"), 4.0)
	draw_line(Vector2(15, -15), Vector2(-15, 15), Color("#985744"), 4.0)

