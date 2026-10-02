extends StaticBody2D

signal damage_dealt(amount: float, kind: String)

const MAX_HEALTH := 100.0
var health := MAX_HEALTH
var respawn_timer := 0.0
var flash_timer := 0.0
var defeated := false

func _ready() -> void:
	add_to_group("oxygen_targets")
	queue_redraw()

func _process(delta: float) -> void:
	flash_timer = maxf(0.0, flash_timer - delta)
	if defeated:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			defeated = false
			health = MAX_HEALTH
			var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape:
				shape.set_deferred("disabled", false)
		queue_redraw()

func take_oxygen_damage(amount: float, kind: String) -> void:
	if defeated:
		return
	health = clampf(health - amount, 0.0, MAX_HEALTH)
	flash_timer = 0.12
	damage_dealt.emit(amount, kind)
	if health <= 0.0:
		defeated = true
		respawn_timer = 2.0
		var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", true)
	queue_redraw()

func _draw() -> void:
	if defeated:
		for i in range(3):
			var p := Vector2(-20.0 + i * 20.0, -30.0 - sin(float(i) * 2.1 + respawn_timer) * 9.0)
			draw_circle(p, 6.0, Color(0.45, 0.8, 0.9, 0.35))
		return
	var body_color := Color("#f58b78") if flash_timer > 0.0 else Color("#8b4e70")
	draw_rect(Rect2(-25, -38, 50, 72), body_color, true)
	draw_rect(Rect2(-18, -25, 36, 22), Color("#d7f4ef"), true)
	draw_circle(Vector2(-8, -14), 4.0, Color("#2b4967"))
	draw_circle(Vector2(8, -14), 4.0, Color("#2b4967"))
	draw_line(Vector2(-12, 16), Vector2(12, 16), Color("#f2d48f"), 3.0)
	# Health bar.
	draw_rect(Rect2(-32, -55, 64, 7), Color("#162137"), true)
	draw_rect(Rect2(-32, -55, 64.0 * health / MAX_HEALTH, 7), Color("#ef7180"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-34, 53), "氧化靶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b9c9e7"))

