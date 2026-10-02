extends CharacterBody2D

signal defeated

const ELEMENTS = preload("res://scripts/shared/element_catalog.gd")

var health := 100.0
var max_health := 100.0
var defeated_once := false
var flash_time := 0.0
var status_time := 0.0
var status_name := ""
var status_speed_multiplier := 1.0
var animation_time := 0.0
var hit_time := 0.0
var hit_direction := Vector2.ZERO
var hit_element := ""
var death_elapsed := 0.0
var death_duration := 0.62

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1
	collision_mask = 1
	queue_redraw()

func _physics_process(delta: float) -> void:
	animation_time += delta
	flash_time = maxf(0.0, flash_time - delta)
	hit_time = maxf(0.0, hit_time - delta)
	if defeated_once:
		death_elapsed += delta
		queue_redraw()
		if death_elapsed >= death_duration:
			queue_free()
		return
	status_time = maxf(0.0, status_time - delta)
	if status_time <= 0.0:
		status_name = ""
		status_speed_multiplier = 1.0
	_enemy_process(delta)
	queue_redraw()

func _enemy_process(_delta: float) -> void:
	pass

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

func take_element_damage(amount: float, element: String, attack_kind := "normal", attack_direction := Vector2.ZERO) -> void:
	if defeated_once:
		return
	var final_damage := amount * _damage_multiplier(element)
	health = clampf(health - final_damage, 0.0, max_health)
	flash_time = 0.12
	hit_time = 0.18
	hit_element = element
	hit_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.0 else Vector2.ZERO
	_apply_element_status(element, attack_kind, attack_direction)
	if health <= 0.0:
		_defeat()
	queue_redraw()

func take_oxygen_damage(amount: float, attack_kind := "normal") -> void:
	take_element_damage(amount, "oxygen", attack_kind)

func _damage_multiplier(element: String) -> float:
	return 1.0

func _apply_element_status(element: String, attack_kind: String, attack_direction: Vector2) -> void:
	status_name = ""
	status_speed_multiplier = 1.0
	match element:
		"hydrogen":
			status_name = "dispersed"
			status_time = 0.45
			if attack_direction.length_squared() > 0.0:
				velocity += attack_direction.normalized() * 70.0
		"oxygen":
			status_name = "aerated"
			status_time = 0.6
		"carbon":
			status_name = "caked"
			status_time = 1.0
			status_speed_multiplier = 0.62
		"iron":
			if attack_kind == "charged" or randf() < 0.3:
				status_name = "staggered"
				status_time = 0.35

func _defeat() -> void:
	if defeated_once:
		return
	defeated_once = true
	velocity = Vector2.ZERO
	death_elapsed = 0.0
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider:
		collider.set_deferred("disabled", true)
	defeated.emit()
	queue_redraw()

func _draw_health_bar(tint: Color) -> void:
	draw_rect(Rect2(-25, -43, 50, 5), Color("#142238"))
	draw_rect(Rect2(-25, -43, 50.0 * health / max_health, 5), tint)
	if flash_time > 0.0:
		draw_rect(Rect2(-18, -18, 36, 3), Color("#D8FFFF", 0.8))

func _hit_color() -> Color:
	match hit_element:
		"hydrogen": return Color("#6FC7E8")
		"oxygen": return Color("#9AF5E5")
		"carbon": return Color("#B84D83")
		"iron": return Color("#F2C45F")
	return Color("#D8FFFF")

func _draw_hit_sparks(radius: float) -> void:
	if hit_time <= 0.0:
		return
	var progress := 1.0 - hit_time / 0.18
	var tint := _hit_color()
	for index in range(4):
		var angle := float(index) * TAU / 4.0 + progress * 0.8
		var start := Vector2(cos(angle), sin(angle)) * radius * 0.45
		var finish := Vector2(cos(angle), sin(angle)) * lerpf(radius * 0.65, radius * 1.15, progress)
		draw_line(start, finish, Color(tint, 1.0 - progress), 2.0)
	if flash_time > 0.0:
		draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 16, Color(tint, 0.8), 2.0)
