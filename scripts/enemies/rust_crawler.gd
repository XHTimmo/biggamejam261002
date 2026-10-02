extends "res://scripts/enemies/element_enemy.gd"

const MAX_HEALTH := 155.0
const MOVE_SPEED := 102.0
const DETECTION_RADIUS := 560.0
const ATTACK_RANGE := 52.0
const WINDUP := 0.46
const DASH_TIME := 0.32
const DASH_SPEED := 720.0
const DASH_DISTANCE := 240.0
const CONTACT_DAMAGE := 24.0

var state := "idle"
var state_time := 0.0
var facing := -1.0
var attack_hit := false
var dash_distance_left := 0.0
var warning_time := 0.0
var detected := false

func _ready() -> void:
	health = MAX_HEALTH
	max_health = MAX_HEALTH
	super._ready()
	floor_snap_length = 5.0

func _enemy_process(delta: float) -> void:
	if defeated_once:
		return
	state_time += delta
	warning_time = maxf(0.0, warning_time - delta)
	var target := _player()
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		_apply_gravity(delta)
		return
	var offset := target.global_position - global_position
	var horizontal := absf(offset.x)
	var vertical := absf(offset.y)
	if horizontal > 1.0:
		facing = signf(offset.x)
	match state:
		"idle":
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if offset.length() <= DETECTION_RADIUS:
				detected = true
				warning_time = WINDUP
				# The first sighting immediately arms a limited dash. After it
				# finishes the crawler falls back to its normal approach loop.
				_set_state("windup")
		"approach":
			if offset.length() > DETECTION_RADIUS * 1.5:
				detected = false
				_set_state("idle")
			elif horizontal <= ATTACK_RANGE and vertical <= 40.0:
				_set_state("windup")
			else:
				velocity.x = move_toward(velocity.x, facing * MOVE_SPEED * status_speed_multiplier, 620.0 * delta)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= WINDUP:
				attack_hit = false
				dash_distance_left = DASH_DISTANCE
				_set_state("dash")
		"dash":
			var step := minf(DASH_SPEED * delta, dash_distance_left)
			velocity.x = facing * (step / maxf(delta, 0.001))
			dash_distance_left -= step
			if not attack_hit and horizontal <= ATTACK_RANGE + 12.0 and vertical <= 44.0:
				attack_hit = true
				if target.has_method("take_damage"):
					target.take_damage(CONTACT_DAMAGE)
			if state_time >= DASH_TIME or dash_distance_left <= 0.0:
				_set_state("recovery")
		"recovery":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= 0.46:
				_set_state("approach")
	_apply_gravity(delta)
	queue_redraw()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + 1500.0 * delta, 700.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

func _set_state(next_state: String) -> void:
	state = next_state
	state_time = 0.0
	if next_state == "windup":
		warning_time = WINDUP

func _damage_multiplier(element: String) -> float:
	match element:
		"hydrogen": return 1.15
		"oxygen": return 0.75
		"carbon": return 0.90
		"iron": return 1.35
	return 1.0

func _draw() -> void:
	if defeated_once:
		var progress := clampf(death_elapsed / death_duration, 0.0, 1.0)
		draw_set_transform(Vector2(0, progress * 14.0), progress * 0.7, Vector2(1.0 + progress * 0.25, 1.0 - progress * 0.72))
		draw_colored_polygon(PackedVector2Array([Vector2(-22, 5), Vector2(-16, -14), Vector2(-4, -23), Vector2(15, -18), Vector2(23, -4), Vector2(18, 10), Vector2(-15, 12)]), Color(0.15, 0.22, 0.34, 1.0 - progress))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in range(5):
			var angle := float(i) * TAU / 5.0
			var point := Vector2(cos(angle), sin(angle)) * (18.0 + progress * 28.0)
			draw_rect(Rect2(point, Vector2(5, 5)), Color("#E05A60", 1.0 - progress))
		return
	var bob := sin(animation_time * 9.0) * 1.5 if state == "approach" else 0.0
	var hit_progress := 1.0 - hit_time / 0.18 if hit_time > 0.0 else 0.0
	var hit_kick := hit_direction * (1.0 - hit_progress) * 5.0
	var hit_scale := Vector2(1.0 + hit_progress * 0.12, 1.0 - hit_progress * 0.10)
	draw_set_transform(Vector2(0, bob) + hit_kick, 0.0, Vector2(facing, 1.0) * hit_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 5), Vector2(-16, -14), Vector2(-4, -23), Vector2(15, -18), Vector2(23, -4), Vector2(18, 10), Vector2(-15, 12)]), Color("#263957"))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, 3), Vector2(-10, -11), Vector2(0, -17), Vector2(14, -12), Vector2(17, -2), Vector2(10, 7), Vector2(-12, 8)]), Color("#AABFD0"))
	draw_rect(Rect2(4, -11, 8, 7), Color("#D9854B"))
	draw_line(Vector2(-12, 10), Vector2(-18, 17), Color("#142238"), 4)
	draw_line(Vector2(10, 9), Vector2(17, 17), Color("#142238"), 4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_health_bar(Color("#E05A60"))
	_draw_hit_sparks(27.0)
	if state == "windup" or (detected and state == "approach" and warning_time > 0.0):
		var pulse := 1.0 + sin(animation_time * 18.0) * 0.12
		draw_arc(Vector2.ZERO, 28.0 * pulse, PI, TAU, 12, Color("#F2C45F", 0.9), 3)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -45), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#F2C45F"))
	if state == "dash":
		draw_line(Vector2(-facing * 14.0, 2), Vector2(-facing * 38.0, 2), Color("#E05A60", 0.75), 3)
