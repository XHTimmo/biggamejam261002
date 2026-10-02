extends "res://scripts/enemies/element_enemy.gd"

const MAX_HEALTH := 210.0
const MAX_SHIELD := 80.0
const FIRE_INTERVAL := 2.2
const FIRE_RANGE := 460.0
const FIRE_WINDUP := 0.52
const PROJECTILE_DAMAGE := 22.0
const PATROL_SPEED := 48.0
const PATROL_RADIUS := 110.0

var shield := MAX_SHIELD
var fire_timer := 1.2
var shot_flash := 0.0
var facing := -1.0
var anchor_x := 0.0
var patrol_direction := -1.0
var attack_charge := 0.0
var aim_direction := Vector2.LEFT
var aim_distance := FIRE_RANGE
var aim_origin := Vector2.ZERO
var warning_time := 0.0

func _ready() -> void:
	health = MAX_HEALTH
	max_health = MAX_HEALTH
	super._ready()
	floor_snap_length = 5.0
	anchor_x = position.x

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
	if target == null:
		_patrol(delta)
		_enemy_process_gravity(delta)
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	if absf(offset.x) > 1.0:
		facing = signf(offset.x)
	if charging_attack:
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
		if attack_charge <= 0.0:
			fire_timer = FIRE_INTERVAL
			shot_flash = 0.24
			if _attack_hits_target(target) and target.has_method("take_damage"):
				target.take_damage(PROJECTILE_DAMAGE)
	elif distance <= FIRE_RANGE and fire_timer <= 0.0:
		attack_charge = FIRE_WINDUP
		warning_time = FIRE_WINDUP
		aim_origin = global_position
		aim_direction = offset.normalized()
		aim_distance = minf(distance, FIRE_RANGE)
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
	else:
		_patrol(delta, target)
	_enemy_process_gravity(delta)
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

func _patrol(delta: float, target: CharacterBody2D = null) -> void:
	if target and absf(target.global_position.x - global_position.x) < 180.0:
		# Back away when the player gets too close so the sentinel keeps its firing lane.
		var retreat := -signf(target.global_position.x - global_position.x)
		velocity.x = move_toward(velocity.x, retreat * PATROL_SPEED * 1.35, 500.0 * delta)
		return
	if position.x < anchor_x - PATROL_RADIUS:
		patrol_direction = 1.0
	elif position.x > anchor_x + PATROL_RADIUS:
		patrol_direction = -1.0
	velocity.x = move_toward(velocity.x, patrol_direction * PATROL_SPEED, 360.0 * delta)

func take_element_damage(amount: float, element: String, attack_kind := "normal", attack_direction := Vector2.ZERO) -> void:
	if defeated_once:
		return
	var multiplier := _damage_multiplier(element)
	var shield_damage := amount * multiplier
	if shield > 0.0:
		shield = maxf(0.0, shield - shield_damage)
		if shield_damage > 0.0:
			flash_time = 0.12
			hit_time = 0.18
			hit_element = element
			hit_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.0 else Vector2.ZERO
			_apply_element_status(element, attack_kind, attack_direction)
			queue_redraw()
			return
	super.take_element_damage(amount, element, attack_kind, attack_direction)

func _damage_multiplier(element: String) -> float:
	match element:
		"hydrogen": return 1.10
		"oxygen": return 0.90
		"carbon": return 1.35
		"iron": return 0.55
	return 1.0

func _enemy_process_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + 1500.0 * delta, 700.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

func _draw() -> void:
	if defeated_once:
		var progress := clampf(death_elapsed / death_duration, 0.0, 1.0)
		draw_set_transform(Vector2(0, progress * 18.0), -progress * 0.45, Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(-24, 10), Vector2(-21, -22), Vector2(-9, -30), Vector2(16, -27), Vector2(25, -12), Vector2(23, 12)]), Color("#142238", 1.0 - progress))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in range(6):
			var angle := float(i) * TAU / 6.0
			var point := Vector2(cos(angle), sin(angle)) * (20.0 + progress * 32.0)
			draw_rect(Rect2(point, Vector2(6, 6)), Color("#6FC7E8", 1.0 - progress))
		return
	var hit_progress := 1.0 - hit_time / 0.18 if hit_time > 0.0 else 0.0
	var hit_kick := hit_direction * (1.0 - hit_progress) * 3.0
	var hit_scale := Vector2(1.0 + hit_progress * 0.08, 1.0 - hit_progress * 0.05)
	draw_set_transform(hit_kick, 0.0, Vector2(facing, 1.0) * hit_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 10), Vector2(-21, -22), Vector2(-9, -30), Vector2(16, -27), Vector2(25, -12), Vector2(23, 12)]), Color("#142238"))
	draw_colored_polygon(PackedVector2Array([Vector2(-17, 7), Vector2(-15, -17), Vector2(-6, -23), Vector2(12, -21), Vector2(18, -10), Vector2(17, 7)]), Color("#6B8092"))
	draw_rect(Rect2(-7, -14, 19, 8), Color("#AABFD0"))
	draw_rect(Rect2(9, -13, 6, 6), Color("#F2C45F"))
	draw_line(Vector2(-14, 9), Vector2(-16, 19), Color("#142238"), 5)
	draw_line(Vector2(12, 9), Vector2(16, 19), Color("#142238"), 5)
	if attack_charge > 0.0 or shot_flash > 0.0:
		var beam_alpha := 0.35 if attack_charge > 0.0 else 0.95
		var beam_color := Color("#E05A60", beam_alpha) if attack_charge > 0.0 else Color("#F2C45F", beam_alpha)
		# The body is already mirrored by draw_set_transform; convert the world
		# aim vector back to local space so left-facing shots are not mirrored right.
		var local_aim := aim_direction * Vector2(facing, 1.0)
		var beam_end := local_aim * maxf(aim_distance, 64.0)
		draw_line(local_aim * 18.0, beam_end, beam_color, 5.0 if shot_flash > 0.0 else 3.0)
		draw_circle(beam_end, 10.0 if shot_flash > 0.0 else 7.0, Color(beam_color, beam_color.a * 0.7))
	if warning_time > 0.0:
		var pulse := 1.0 + sin(animation_time * 20.0) * 0.16
		draw_arc(Vector2.ZERO, 38.0 * pulse, 0.0, TAU, 18, Color("#E05A60", 0.8), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -52), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#E05A60"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_health_bar(Color("#F2C45F"))
	draw_rect(Rect2(-29, -51, 58, 4), Color("#142238"))
	draw_rect(Rect2(-29, -51, 58.0 * shield / MAX_SHIELD, 4), Color("#6FC7E8"))
	_draw_hit_sparks(31.0)
