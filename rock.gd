extends StaticBody2D

signal dissolved

var dissolving := false
var reaction_enabled := true
var dissolve_time := 0.0
var dissolve_duration := 0.45
@export var rock_size := Vector2(112, 62)

func _ready() -> void:
	add_to_group("acid_rocks")
	queue_redraw()

func acid_hit() -> void:
	if dissolving or not reaction_enabled:
		return
	dissolving = true
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	dissolved.emit()
	queue_redraw()

func _process(delta: float) -> void:
	if not dissolving:
		return
	dissolve_time += delta
	if dissolve_time >= dissolve_duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0
	if dissolving:
		alpha = 1.0 - dissolve_time / dissolve_duration
	var rock_color := Color(0.48, 0.58, 0.65, alpha)
	var scale_factor := rock_size / Vector2(112, 62)
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-54, 28), Vector2(-44, -6), Vector2(-21, -31), Vector2(15, -26),
		Vector2(45, -4), Vector2(57, 28)
	]), rock_color)
	draw_line(Vector2(-27, -10), Vector2(-6, 5), Color(0.7, 0.82, 0.86, alpha), 3.0)
	draw_line(Vector2(9, -18), Vector2(16, 4), Color(0.7, 0.82, 0.86, alpha), 3.0)
	draw_circle(Vector2(-10, 14), 4.0, Color(0.87, 0.9, 0.78, alpha))
	draw_circle(Vector2(27, 13), 3.0, Color(0.87, 0.9, 0.78, alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

