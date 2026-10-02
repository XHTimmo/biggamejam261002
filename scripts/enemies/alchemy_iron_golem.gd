extends CharacterBody2D

signal phase_changed(element: String)
signal phase_warning(element: String, hint: String)
signal health_changed(value: float, maximum: float)
signal attack_started(attack_name: String)
signal defeated

const MAX_HEALTH := 600.0
const GRAVITY := 1500.0
const PHASE_DURATION := 7.0
const PHASE_WARNING_DURATION := 1.0
const MOVE_SPEED := 58.0
const ARENA_MIN_X := 2100.0
const ARENA_MAX_X := 2750.0
const ATTACK_RANGE := 820.0
const ATTACK_WINDUP := 0.68
const RECOVERY_DURATION := 0.58
const PROJECTILE_DAMAGE := 28.0
const SLAM_DAMAGE := 34.0
const CHARGE_DAMAGE := 38.0
const LUNGE_DAMAGE := 30.0
const BARRAGE_DAMAGE := 18.0
const DEATH_DURATION := 1.0
const ATTACK_SEQUENCE := ["slam", "wisp_beam", "crawler_dash", "sentinel_barrage", "mud_lunge"]

const ELEMENT_ORDER := ["hydrogen", "oxygen", "carbon", "iron"]
const ELEMENT_TINTS := {
	"hydrogen": Color("#6FC7E8"),
	"oxygen": Color("#9AF5E5"),
	"carbon": Color("#B84D83"),
	"iron": Color("#F2C45F")
}
const DAMAGE_MATRIX := {
	"hydrogen": {"hydrogen": 0.55, "oxygen": 1.35, "carbon": 0.80, "iron": 0.95},
	"oxygen": {"hydrogen": 0.95, "oxygen": 0.55, "carbon": 1.35, "iron": 0.80},
	"carbon": {"hydrogen": 0.80, "oxygen": 0.95, "carbon": 0.55, "iron": 1.35},
	"iron": {"hydrogen": 1.35, "oxygen": 0.80, "carbon": 0.95, "iron": 0.55}
}

var health := MAX_HEALTH
var current_element := "iron"
var phase_index := 3
var phase_time := PHASE_DURATION
var phase_warning_time := 0.0
var phase_warning_sent := false
var next_phase_index := -1
var exposed_core_time := 0.0
var status_time := 0.0
var status_speed_multiplier := 1.0
var state := "patrol"
var state_time := 0.0
var attack_cooldown := 1.0
var attack_name := ""
var attack_sequence_index := 0
var attack_direction := Vector2.LEFT
var attack_origin := Vector2.ZERO
var attack_distance := 0.0
var attack_flash := 0.0
var attack_hit := false
var barrage_remaining := 0
var barrage_timer := 0.0
var patrol_direction := -1.0
var facing := -1.0
var animation_time := 0.0
var hit_time := 0.0
var hit_element := ""
var flash_time := 0.0
var death_elapsed := 0.0
var defeated_once := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 6.0
	rng.randomize()
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()

func _physics_process(delta: float) -> void:
	animation_time += delta
	flash_time = maxf(0.0, flash_time - delta)
	hit_time = maxf(0.0, hit_time - delta)
	attack_flash = maxf(0.0, attack_flash - delta)
	if defeated_once:
		death_elapsed += delta
		velocity = Vector2.ZERO
		queue_redraw()
		if death_elapsed >= DEATH_DURATION:
			queue_free()
		return

	phase_time -= delta
	phase_warning_time = PHASE_WARNING_DURATION if phase_time <= PHASE_WARNING_DURATION else 0.0
	if phase_time <= PHASE_WARNING_DURATION and not phase_warning_sent:
		next_phase_index = _choose_next_phase()
		phase_warning_sent = true
		var next_element: String = ELEMENT_ORDER[next_phase_index]
		phase_warning.emit(next_element, _phase_hint(next_element))
	exposed_core_time = maxf(0.0, exposed_core_time - delta)
	status_time = maxf(0.0, status_time - delta)
	if status_time <= 0.0:
		status_speed_multiplier = 1.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	state_time += delta
	if phase_time <= 0.0:
		_switch_element()

	var target := _player()
	if state == "windup":
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if state_time >= ATTACK_WINDUP:
			_resolve_attack(target)
	elif state == "crawler_dash":
		velocity.x = facing * 620.0 * status_speed_multiplier
		if not attack_hit and target and absf(target.global_position.x - global_position.x) <= 78.0 and absf(target.global_position.y - global_position.y) <= 76.0:
			attack_hit = true
			_damage_player(target, CHARGE_DAMAGE)
		if state_time >= 0.34 or is_on_wall():
			_set_state("recovery")
	elif state == "mud_lunge":
		velocity.x = facing * 330.0 * status_speed_multiplier
		if not attack_hit and target and absf(target.global_position.x - global_position.x) <= 82.0 and absf(target.global_position.y - global_position.y) <= 76.0:
			attack_hit = true
			_damage_player(target, LUNGE_DAMAGE)
		if state_time >= 0.28 or is_on_wall():
			_set_state("recovery")
	elif state == "sentinel_barrage":
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		barrage_timer -= delta
		if barrage_remaining > 0 and barrage_timer <= 0.0:
			barrage_remaining -= 1
			barrage_timer = 0.18
			attack_flash = 0.16
			if target and _attack_hits_target(target):
				_damage_player(target, BARRAGE_DAMAGE)
		elif barrage_remaining <= 0:
			_set_state("recovery")
	elif state == "charge":
		# Legacy state name kept for old save/test scenes; use the stronger dash.
		_set_state("crawler_dash")
	elif state == "lunge":
		_set_state("mud_lunge")
	elif state == "barrage":
		_set_state("sentinel_barrage")
	elif state == "recovery":
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		if state_time >= RECOVERY_DURATION:
			_set_state("patrol")
	else:
		if target:
			var offset := target.global_position - global_position
			if absf(offset.x) > 1.0:
				facing = signf(offset.x)
			if attack_cooldown <= 0.0 and offset.length() <= ATTACK_RANGE:
				_begin_attack(target)
			else:
				_patrol(delta)
		else:
			_patrol(delta)

	_apply_gravity(delta)
	queue_redraw()

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

func _patrol(delta: float) -> void:
	if position.x <= ARENA_MIN_X:
		patrol_direction = 1.0
	elif position.x >= ARENA_MAX_X:
		patrol_direction = -1.0
	if fmod(animation_time, 1.8) < delta:
		patrol_direction = -patrol_direction if rng.randf() < 0.45 else patrol_direction
	velocity.x = move_toward(velocity.x, patrol_direction * MOVE_SPEED * status_speed_multiplier, 360.0 * delta)
	facing = patrol_direction

func _begin_attack(target: CharacterBody2D) -> void:
	attack_name = ATTACK_SEQUENCE[attack_sequence_index]
	attack_sequence_index = (attack_sequence_index + 1) % ATTACK_SEQUENCE.size()
	attack_origin = global_position
	var offset := target.global_position - attack_origin
	attack_direction = offset.normalized() if offset.length_squared() > 0.01 else Vector2(facing, 0.0)
	attack_distance = minf(offset.length(), ATTACK_RANGE)
	attack_hit = false
	attack_cooldown = _attack_interval()
	attack_started.emit(attack_name)
	_set_state("windup")

func _resolve_attack(target: CharacterBody2D) -> void:
	attack_flash = 0.24
	if attack_name == "crawler_dash":
		_set_state("crawler_dash")
		return
	if attack_name == "mud_lunge":
		_set_state("mud_lunge")
		return
	if attack_name == "sentinel_barrage":
		barrage_remaining = 3 + _enrage_level()
		barrage_timer = 0.0
		_set_state("sentinel_barrage")
		return
	if target:
		if attack_name == "slam":
			if absf(target.global_position.x - global_position.x) <= 180.0 and absf(target.global_position.y - global_position.y) <= 90.0:
				_damage_player(target, SLAM_DAMAGE)
		elif attack_name == "wisp_beam" and _attack_hits_target(target):
			_damage_player(target, PROJECTILE_DAMAGE)
	_set_state("recovery")

func _attack_hits_target(target: CharacterBody2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var offset := target.global_position - attack_origin
	var locked_direction := attack_direction.normalized()
	var projected := locked_direction.dot(offset)
	var lateral := absf(locked_direction.cross(offset))
	if offset.length() > attack_distance + 24.0 or projected < 0.0 or projected > attack_distance + 24.0 or lateral > 24.0:
		return false
	var query := PhysicsRayQueryParameters2D.create(attack_origin, target.global_position, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _damage_player(target: CharacterBody2D, amount: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount * (1.0 + 0.16 * float(_enrage_level())))

func _set_state(next_state: String) -> void:
	state = next_state
	state_time = 0.0

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

func _switch_element() -> void:
	var next_index := next_phase_index if next_phase_index >= 0 else _choose_next_phase()
	phase_index = next_index
	current_element = ELEMENT_ORDER[phase_index]
	phase_time = PHASE_DURATION
	phase_warning_time = 0.0
	phase_warning_sent = false
	next_phase_index = -1
	exposed_core_time = 0.0
	phase_changed.emit(current_element)

func _choose_next_phase() -> int:
	var next_index := phase_index
	while next_index == phase_index:
		next_index = rng.randi_range(0, ELEMENT_ORDER.size() - 1)
	return next_index

func _phase_hint(element: String) -> String:
	match element:
		"hydrogen": return "HIGH DAMAGE: OXYGEN"
		"oxygen": return "HIGH DAMAGE: CARBON"
		"carbon": return "HIGH DAMAGE: IRON"
		"iron": return "HIGH DAMAGE: HYDROGEN"
	return "USE THE NEXT ELEMENT IN THE CYCLE"

func _attack_interval() -> float:
	return 2.1 / (1.0 + 0.25 * float(_enrage_level()))

func _enrage_level() -> int:
	var ratio := health / MAX_HEALTH
	if ratio <= 0.25:
		return 3
	if ratio <= 0.50:
		return 2
	if ratio <= 0.75:
		return 1
	return 0

func take_element_damage(amount: float, element: String, attack_kind := "normal", attack_direction := Vector2.ZERO) -> void:
	if defeated_once:
		return
	var row: Dictionary = DAMAGE_MATRIX.get(current_element, {})
	var multiplier := float(row.get(element, 0.8))
	var final_damage := amount * multiplier
	if exposed_core_time > 0.0:
		final_damage *= 1.25
	health = clampf(health - final_damage, 0.0, MAX_HEALTH)
	flash_time = 0.12
	hit_time = 0.18
	hit_element = element
	health_changed.emit(health, MAX_HEALTH)
	_apply_element_status(element, attack_kind, attack_direction)
	if health <= 0.0:
		_defeat()
	queue_redraw()

func take_oxygen_damage(amount: float, attack_kind := "normal") -> void:
	take_element_damage(amount, "oxygen", attack_kind)

func _apply_element_status(element: String, attack_kind: String, attack_direction: Vector2) -> void:
	match element:
		"hydrogen":
			var push := attack_direction.normalized() if attack_direction.length_squared() > 0.01 else Vector2(-facing, 0.0)
			velocity += push * 150.0
			if state == "windup":
				_set_state("recovery")
		"oxygen":
			exposed_core_time = 1.25
		"carbon":
			status_time = 1.20
			status_speed_multiplier = 0.55
		"iron":
			if attack_kind == "charged" or rng.randf() < 0.45:
				_set_state("recovery")

func _damage_multiplier(element: String) -> float:
	var row: Dictionary = DAMAGE_MATRIX.get(current_element, {})
	return float(row.get(element, 0.8))

func _defeat() -> void:
	if defeated_once:
		return
	defeated_once = true
	state = "defeated"
	velocity = Vector2.ZERO
	death_elapsed = 0.0
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider:
		collider.set_deferred("disabled", true)
	defeated.emit()

func _element_color() -> Color:
	return ELEMENT_TINTS.get(current_element, Color.WHITE)

func _draw() -> void:
	if defeated_once:
		var progress := clampf(death_elapsed / DEATH_DURATION, 0.0, 1.0)
		draw_set_transform(Vector2(0, progress * 20.0), progress * 0.25, Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.82))
		draw_colored_polygon(PackedVector2Array([Vector2(-28, 24), Vector2(-25, -34), Vector2(-12, -48), Vector2(20, -42), Vector2(29, 20)]), Color("#142238", 1.0 - progress))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for index in range(8):
			var angle := float(index) * TAU / 8.0
			draw_circle(Vector2(cos(angle), sin(angle)) * (24.0 + progress * 45.0), 4.0, Color(_element_color(), 1.0 - progress))
		return
	var tint := _element_color()
	var bob := sin(animation_time * 5.0) * 1.2 if state == "patrol" else 0.0
	var body_scale := Vector2(facing, 1.0)
	draw_set_transform(Vector2(0, bob), 0.0, body_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-29, 25), Vector2(-27, -35), Vector2(-17, -49), Vector2(19, -45), Vector2(29, -30), Vector2(27, 25)]), Color("#142238"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 21), Vector2(-21, -29), Vector2(-12, -40), Vector2(14, -37), Vector2(21, -25), Vector2(20, 20)]), Color("#6B8092"))
	draw_rect(Rect2(-34, -43, 10, 18), Color("#263957"))
	draw_rect(Rect2(24, -43, 10, 18), Color("#263957"))
	draw_line(Vector2(-17, 24), Vector2(-23, 45), Color("#142238"), 8)
	draw_line(Vector2(14, 22), Vector2(20, 45), Color("#142238"), 8)
	draw_circle(Vector2(0, -10), 15.0 if exposed_core_time <= 0.0 else 19.0, tint)
	draw_circle(Vector2(0, -10), 7.0, Color("#D8FFFF", 0.85))
	draw_line(Vector2(-12, -29), Vector2(12, -29), tint, 3)
	draw_line(Vector2(-15, 4), Vector2(15, 4), Color(tint, 0.75), 2)
	if flash_time > 0.0:
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 20, Color("#D8FFFF", 0.9), 3)
	if phase_warning_time > 0.0:
		draw_arc(Vector2(0, -10), 27.0 + sin(animation_time * 18.0) * 3.0, 0.0, TAU, 20, Color(tint, 0.95), 3)
		draw_string(ThemeDB.fallback_font, Vector2(-5, -59), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tint)
	if state == "windup" or attack_name == "wisp_beam" and attack_flash > 0.0:
		var local_attack := attack_direction * Vector2(facing, 1.0)
		var end := local_attack * maxf(attack_distance, 90.0)
		draw_line(local_attack * 22.0, end, Color(tint, 0.65), 4 if attack_flash > 0.0 else 3)
		draw_circle(end, 14.0 if attack_flash > 0.0 else 12.0, Color(tint, 0.35))
	if state == "crawler_dash":
		for trail in range(3):
			draw_line(Vector2(-facing * (28.0 + trail * 13.0), 8.0), Vector2(-facing * (52.0 + trail * 18.0), 8.0), Color(tint, 0.7 - trail * 0.16), 4)
	if state == "mud_lunge":
		draw_arc(Vector2(0, 10), 38.0, PI if facing > 0.0 else 0.0, TAU if facing > 0.0 else PI, 12, Color(tint, 0.8), 4)
	if state == "sentinel_barrage":
		var local_attack := attack_direction * Vector2(facing, 1.0)
		var end := local_attack * maxf(attack_distance, 100.0)
		for shot in range(3):
			var offset_y := float(shot - 1) * 8.0
			draw_line(local_attack * 22.0 + Vector2(0, offset_y), end + Vector2(0, offset_y), Color(tint, 0.55), 3)
	if attack_flash > 0.0:
		draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 24, Color(tint, 1.0), 5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-48, -75, 96, 6), Color("#142238"))
	draw_rect(Rect2(-48, -75, 96.0 * health / MAX_HEALTH, 6), Color("#E05A60"))
	draw_rect(Rect2(-48, -66, 96, 4), Color("#142238"))
	draw_rect(Rect2(-48, -66, 96.0 * phase_time / PHASE_DURATION, 4), tint)
