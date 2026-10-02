extends Area2D

const OXYGEN_TEXTURE = preload("res://assets/chemistry_bullets/bullet_oxygen.png")

var direction := Vector2.RIGHT
var speed := 720.0
var damage := 12.0
var attack_kind := "normal"
var lifetime := 1.8

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = OXYGEN_TEXTURE
	sprite.scale = Vector2.ONE * (0.23 if attack_kind == "normal" else 0.32)
	sprite.rotation = direction.angle()
	if attack_kind == "charged":
		sprite.modulate = Color("#ffe18a")
	add_child(sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	lifetime -= delta
	rotation += delta * 9.0
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_oxygen_damage"):
		body.take_oxygen_damage(damage, attack_kind)
		queue_free()
	elif body is StaticBody2D and not body.is_in_group("player"):
		queue_free()

func _draw() -> void:
	var color := Color("#a4f4ff") if attack_kind == "normal" else Color("#ffd76e")
	var radius := 10.0 if attack_kind == "normal" else 20.0
	draw_circle(Vector2.ZERO, radius, Color(color, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(color, 0.75), 2.0)
