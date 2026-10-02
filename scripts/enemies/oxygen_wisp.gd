extends "res://scripts/enemies/element_enemy.gd"

const MAX_HEALTH := 90.0
const DETECTION_RADIUS := 560.0
const FIRE_RANGE := 500.0
const FIRE_INTERVAL := 1.8
const FIRE_WINDUP := 0.34
const PROJECTILE_DAMAGE := 16.0

var fire_timer := 0.7
var facing := -1.0
var shot_flash := 0.0
var anchor_y := 0.0
var attack_charge := 0.0
var aim_direction := Vector2.RIGHT
var aim_distance := FIRE_RANGE
var aim_origin := Vector2.ZERO
var warning_time := 0.0

func _ready() -> void:
	health = MAX_HEALTH
	max_health = MAX_HEALTH
	super._ready()
	anchor_y = position.y
	collision_layer = 1
	collision_mask = 0

func _enemy_process(delta: float) -> void:
	if defeated_once:
		return
	var target := _player()
	fire_timer -= delta
	shot_flash = maxf(0.0, shot_flash - delta)
	warning_time = maxf(0.0, warning_time - delta)
	var charging_attack := attack_charge > 0.0
	if charging_attack:
		attack_charge = maxf(0.0, attack_charge - delta)
	position.y = anchor_y + sin(animation_time * 2.2) * 18.0
	if target == null:
		return
	var offset := target.global_position - global_position
	if absf(offset.x) > 1.0:
		facing = signf(offset.x)
	if charging_attack:
		if attack_charge <= 0.0:
			shot_flash = 0.22
			fire_timer = FIRE_INTERVAL
			if _attack_hits_target(target) and target.has_method("take_damage"):
				target.take_damage(PROJECTILE_DAMAGE)
	elif offset.length() <= DETECTION_RADIUS and offset.length() <= FIRE_RANGE and fire_timer <= 0.0:
		attack_charge = FIRE_WINDUP
		warning_time = FIRE_WINDUP
		aim_origin = global_position
		aim_direction = offset.normalized()
		aim_distance = minf(offset.length(), FIRE_RANGE)
	queue_redraw()

func _attack_hits_target(target: CharacterBody2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var origin := aim_origin if aim_origin != Vector2.ZERO else global_position
	var offset := target.global_position - origin
	if offset.length() > FIRE_RANGE:
		return false
	var locked_direction := aim_direction.normalized()
	var projected_distance := locked_direction.dot(offset)
	var lateral_distance := absf(locked_direction.cross(offset))
	if aim_direction.length_squared() < 0.01 or projected_distance < 0.0 or projected_distance > aim_distance + 20.0 or lateral_distance > 20.0:
		return false
	var query := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _damage_multiplier(element: String) -> float:
	match element:
		"hydrogen": return 0.85
		"oxygen": return 0.55
		"carbon": return 1.25
		"iron": return 1.10
	return 1.0

func _draw() -> void:
	if defeated_once:
		var progress := clampf(death_elapsed / death_duration, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 18.0 + progress * 34.0, Color("#9AF5E5", 0.32 * (1.0 - progress)))
		draw_arc(Vector2.ZERO, 12.0 + progress * 28.0, 0.0, TAU, 20, Color("#D8FFFF", 1.0 - progress), 3.0)
		for i in range(6):
			var angle := float(i) * TAU / 6.0 + progress
			var point := Vector2(cos(angle), sin(angle)) * (10.0 + progress * 42.0)
			draw_circle(point, 3.0, Color("#55D9D3", 1.0 - progress))
		return
	var hit_progress := 1.0 - hit_time / 0.18 if hit_time > 0.0 else 0.0
	var hit_kick := hit_direction * (1.0 - hit_progress) * 4.0
	var hit_scale := Vector2(1.0 + hit_progress * 0.16, 1.0 - hit_progress * 0.16)
	draw_set_transform(hit_kick, 0.0, Vector2(facing, 1.0) * hit_scale)
	draw_circle(Vector2.ZERO, 22, Color("#142238"))
	draw_circle(Vector2.ZERO, 17, Color("#2D9AA0"))
	draw_circle(Vector2(-5, -5), 9, Color("#9AF5E5", 0.55))
	draw_arc(Vector2.ZERO, 28, -2.6, -0.4, 16, Color("#D8FFFF"), 2)
	draw_line(Vector2(-13, 13), Vector2(-20, 21), Color("#55D9D3"), 3)
	draw_line(Vector2(13, 13), Vector2(20, 21), Color("#55D9D3"), 3)
	if attack_charge > 0.0 or shot_flash > 0.0:
		var beam_alpha := 0.35 if attack_charge > 0.0 else 0.9
		var beam_color := Color("#F2C45F", beam_alpha) if attack_charge > 0.0 else Color("#D8FFFF", beam_alpha)
		# The body is already mirrored by draw_set_transform; convert the world
		# aim vector back to local space so left-facing shots are not mirrored right.
		var local_aim := aim_direction * Vector2(facing, 1.0)
		var beam_end := local_aim * maxf(aim_distance, 56.0)
		draw_line(local_aim * 18.0, beam_end, beam_color, 5.0 if shot_flash > 0.0 else 2.0)
		draw_circle(beam_end, 8.0 if shot_flash > 0.0 else 5.0, Color(beam_color, beam_color.a * 0.65))
	if warning_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#F2C45F"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_health_bar(Color("#55D9D3"))
	_draw_hit_sparks(29.0)
