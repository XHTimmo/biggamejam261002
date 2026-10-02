extends Area2D

@export var damage_per_second := 14.0
var player_inside := false
var tick := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _process(delta: float) -> void:
	if not player_inside:
		return
	tick -= delta
	if tick <= 0.0:
		tick = 0.25
		for body in get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(damage_per_second * 0.25)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _draw() -> void:
	draw_rect(Rect2(-90, -8, 180, 16), Color("#bd5a8f"), true)
	for x in range(-70, 71, 28):
		draw_circle(Vector2(x, -13 - sin(float(x)) * 2.0), 5.0, Color("#f27fbe"))

