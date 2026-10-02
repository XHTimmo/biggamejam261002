extends Area2D

signal frozen

@export var trough_size := Vector2(240, 28)
@export var freeze_duration := 6.0
var freeze_remaining := 0.0
var phase := 0.0
var ice_collision: CollisionShape2D

func _ready() -> void:
	add_to_group("water_troughs")
	var body := StaticBody2D.new()
	body.name = "IcePlatform"
	ice_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(trough_size.x, 12)
	ice_collision.shape = shape
	ice_collision.position.y = -trough_size.y / 2
	ice_collision.disabled = true
	body.add_child(ice_collision)
	add_child(body)

func freeze_hit() -> void:
	freeze_remaining = freeze_duration
	ice_collision.set_deferred("disabled", false)
	frozen.emit()
	queue_redraw()

func _physics_process(delta: float) -> void:
	phase += delta
	if freeze_remaining > 0:
		freeze_remaining = maxf(0, freeze_remaining - delta)
		if is_zero_approx(freeze_remaining):
			ice_collision.set_deferred("disabled", true)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-trough_size * 0.5, trough_size)
	draw_rect(rect, Color("#214b72"))
	var tint := Color("#b7f1f5") if freeze_remaining > 0 else Color("#5294aa")
	if freeze_remaining > 0:
		if freeze_remaining > 1.5 or int(phase * 8) % 2 == 0:
			draw_rect(Rect2(-trough_size.x / 2, -trough_size.y / 2 - 6, trough_size.x, 12), tint)
		for x in range(int(-trough_size.x / 2) + 16, int(trough_size.x / 2), 40):
			draw_line(Vector2(x, -12), Vector2(x + 12, -4), Color("#588eaf"), 2)
	else:
		for x in range(int(-trough_size.x / 2), int(trough_size.x / 2), 20):
			draw_line(Vector2(x, -12 + sin(phase * 3 + x) * 2), Vector2(x + 16, -12), tint, 2)
