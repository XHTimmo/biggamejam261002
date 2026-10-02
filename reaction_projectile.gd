extends Area2D

@export var reagent := "acid"
var direction := Vector2.RIGHT
var speed := 620.0
var lifetime := 1.8
var spent := false
var thrower: PhysicsBody2D

func _physics_process(delta: float) -> void:
	if spent:
		return
	var start := global_position
	var target := start + direction.normalized() * speed * delta
	var query := PhysicsRayQueryParameters2D.create(start, target, collision_mask)
	query.collide_with_areas = true
	if thrower:
		query.exclude = [thrower.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body := hit["collider"] as Node2D
		# Sensors (ladders, checkpoints, switches) are permeable to reagents.
		if body is PhysicsBody2D or body.has_method("freeze_hit") or body.has_method("iron_hit"):
			global_position = hit["position"]
			_impact(body)
			return
	global_position = target
	for area in get_overlapping_areas():
		if (reagent == "ice" and area.has_method("freeze_hit")) or (reagent == "iron" and area.has_method("iron_hit")):
			_impact(area)
			return
	for body in get_overlapping_bodies():
		if body != thrower:
			_impact(body)
			return
	lifetime -= delta
	rotation += delta * 7
	if lifetime <= 0:
		queue_free()

func _impact(body: Node2D) -> void:
	if spent:
		return
	spent = true
	if reagent == "acid" and body.has_method("acid_hit"):
		body.acid_hit()
	elif reagent == "ice" and body.has_method("freeze_hit"):
		body.freeze_hit()
	elif reagent == "iron" and body.has_method("iron_hit"):
		body.iron_hit()
	queue_free()

func _draw() -> void:
	var tint := Color("#8ce3b5") if reagent == "acid" else Color("#a2e0fa")
	if reagent == "iron":
		draw_rect(Rect2(-11, -4, 22, 8), Color("#d8b477"))
		return
	draw_rect(Rect2(-7, -9, 14, 18), tint)
	draw_rect(Rect2(-4, -13, 8, 5), Color("#e8f3eb"))
	draw_line(Vector2(-3, 5), Vector2(3, -3), Color("#ffffff"), 2)
