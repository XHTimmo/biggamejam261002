extends Area2D

var radius := 150.0
var damage := 30.0
var attack_kind := "skill"
var duration := 0.28
var elapsed := 0.0
var hit_targets: Dictionary = {}

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	for body in get_overlapping_bodies():
		if body.has_method("take_element_damage") and not hit_targets.has(body):
			hit_targets[body] = true
			body.take_element_damage(damage, "oxygen", attack_kind)
		elif body.has_method("take_oxygen_damage") and not hit_targets.has(body):
			hit_targets[body] = true
			body.take_oxygen_damage(damage, attack_kind)
	if elapsed >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var color := Color("#89efff") if attack_kind == "skill" else Color("#ffdb71")
	draw_circle(Vector2.ZERO, radius * progress, Color(color, 0.10))
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 48, Color(color, 0.95), 7.0)
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + progress
		var point := Vector2(cos(angle), sin(angle)) * radius * progress
		draw_circle(point, 6.0, Color(color, 0.9))
