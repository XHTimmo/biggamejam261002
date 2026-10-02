extends Area2D

@export var damage_per_second := 14.0
@export var hazard_size := Vector2(180, 24)
@export var hot := false
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
	var tint := Color("#ee9768") if hot else Color("#df72a6")
	draw_rect(Rect2(-hazard_size * 0.5, hazard_size), tint.darkened(0.5))
	for x in range(int(-hazard_size.x / 2) + 14, int(hazard_size.x / 2), 28):
		draw_circle(Vector2(x, -hazard_size.y / 2), 5, tint)
