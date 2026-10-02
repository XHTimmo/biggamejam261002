extends CharacterBody2D

signal stability_changed(value: float, maximum: float)
signal acid_requested(origin: Vector2, direction: Vector2)
signal player_reset

const SPEED := 300.0
const JUMP_VELOCITY := -620.0
const MAX_STABILITY := 100.0
const GRAVITY := 1500.0

var stability := MAX_STABILITY
var spawn_position := Vector2.ZERO
var acid_cooldown := 0.0
var facing := 1.0

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_demo"):
		reset_to_spawn()

	var axis := Input.get_axis("move_left", "move_right")
	if abs(axis) > 0.01:
		facing = sign(axis)
		velocity.x = move_toward(velocity.x, axis * SPEED, 1800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	acid_cooldown = maxf(0.0, acid_cooldown - delta)
	if Input.is_action_just_pressed("use_acid") and acid_cooldown <= 0.0:
		acid_cooldown = 0.35
		acid_requested.emit(global_position + Vector2(28.0 * facing, -6.0), Vector2(facing, -0.08))

	move_and_slide()
	if global_position.y > 900.0:
		reset_to_spawn()
	queue_redraw()

func take_damage(amount: float) -> void:
	stability = clampf(stability - amount, 0.0, MAX_STABILITY)
	stability_changed.emit(stability, MAX_STABILITY)
	if stability <= 0.0:
		reset_to_spawn()

func restore_stability(amount: float) -> void:
	stability = clampf(stability + amount, 0.0, MAX_STABILITY)
	stability_changed.emit(stability, MAX_STABILITY)

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	stability = MAX_STABILITY
	stability_changed.emit(stability, MAX_STABILITY)
	player_reset.emit()

func _draw() -> void:
	# Simple pixel-like researcher placeholder.
	draw_rect(Rect2(-16, -26, 32, 40), Color("#f2c078"), true)
	draw_rect(Rect2(-18, -31, 36, 12), Color("#dbe8ff"), true)
	draw_rect(Rect2(-11, -27, 22, 7), Color("#344a69"), true)
	draw_rect(Rect2(-14, 14, 11, 12), Color("#5e6ad2"), true)
	draw_rect(Rect2(3, 14, 11, 12), Color("#5e6ad2"), true)
	draw_circle(Vector2(10.0 * facing, -8.0), 3.0, Color("#74e0ce"))
