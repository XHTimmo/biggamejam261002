extends CharacterBody2D

signal defeated

const IDLE_TEXTURE = preload("res://assets/enemies/dirt_mud_blob_idle_strip.png")
const ELEMENTS = preload("res://scripts/shared/element_catalog.gd")
const FRAME_COUNT := 6
const FRAME_DURATION := 0.125
const GRAVITY := 1500.0
const MAX_HEALTH := 120.0
const CONTACT_DAMAGE := 18.0
const MOVE_SPEED := 70.0
const ACCELERATION := 540.0
const DETECTION_RADIUS := 240.0
const LOSE_TARGET_RADIUS := 420.0
const WANDER_SPEED := 38.0
const WANDER_INTERVAL_MIN := 0.65
const WANDER_INTERVAL_MAX := 1.45
const ATTACK_RANGE := 40.0
const ATTACK_WINDUP := 0.42
const LUNGE_DURATION := 0.24
const LUNGE_SPEED := 210.0
const RECOVERY_DURATION := 0.52
const HIT_COOLDOWN := 0.48
const STAGGER_DURATION := 0.45

var health := MAX_HEALTH
var state := "idle"
var state_time := 0.0
var animation_time := 0.0
var flash_time := 0.0
var hit_cooldown := 0.0
var status_time := 0.0
var status_name := ""
var status_speed_multiplier := 1.0
var exposed_solid_multiplier := 1.0
var facing := -1.0
var attack_hit := false
var wander_direction := 1.0
var wander_time := 0.0
var defeated_once := false
var sprite: Sprite2D
var hit_time := 0.0
var hit_direction := Vector2.ZERO
var hit_element := ""
var death_elapsed := 0.0
const DEATH_DURATION := 0.68

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 5.0
	sprite = Sprite2D.new()
	sprite.texture = IDLE_TEXTURE
	sprite.hframes = FRAME_COUNT
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	sprite.position = Vector2(0, -12)
	add_child(sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	animation_time += delta
	flash_time = maxf(0.0, flash_time - delta)
	hit_time = maxf(0.0, hit_time - delta)
	if defeated_once:
		death_elapsed += delta
		if sprite:
			sprite.visible = false
		queue_redraw()
		if death_elapsed >= DEATH_DURATION:
			queue_free()
		return
	state_time += delta
	wander_time = maxf(0.0, wander_time - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	status_time = maxf(0.0, status_time - delta)
	if status_time <= 0.0:
		status_name = ""
		status_speed_multiplier = 1.0
		if exposed_solid_multiplier != 1.0:
			exposed_solid_multiplier = 1.0

	var target := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if target == null or not is_instance_valid(target):
		_set_horizontal_velocity(0.0, delta)
		_apply_motion(delta)
		return
	var offset := target.global_position - global_position
	var horizontal_distance := absf(offset.x)
	var vertical_distance := absf(offset.y)
	if horizontal_distance > 0.5:
		facing = signf(offset.x)

	match state:
		"idle":
			_set_wander_velocity(delta)
			if offset.length() <= DETECTION_RADIUS:
				_set_state("notice")
			elif state_time >= 0.35:
				_set_state("wander")
		"wander":
			_set_wander_velocity(delta)
			if offset.length() <= DETECTION_RADIUS:
				_set_state("notice")
		"notice":
			_set_horizontal_velocity(0.0, delta)
			if state_time >= 0.18:
				_set_state("approach")
		"approach":
			if offset.length() > LOSE_TARGET_RADIUS:
				_set_state("idle")
			elif horizontal_distance <= ATTACK_RANGE and vertical_distance <= 34.0:
				_set_state("windup")
			else:
				_set_horizontal_velocity(facing * MOVE_SPEED * status_speed_multiplier, delta)
		"windup":
			_set_horizontal_velocity(0.0, delta)
			if state_time >= ATTACK_WINDUP:
				attack_hit = false
				_set_state("lunge")
		"lunge":
			_set_horizontal_velocity(facing * LUNGE_SPEED, delta)
			if not attack_hit and hit_cooldown <= 0.0 and horizontal_distance <= ATTACK_RANGE and vertical_distance <= 36.0:
				attack_hit = true
				hit_cooldown = HIT_COOLDOWN
				if target.has_method("take_damage"):
					target.take_damage(CONTACT_DAMAGE)
			if state_time >= LUNGE_DURATION:
				_set_state("recovery")
		"recovery":
			_set_horizontal_velocity(0.0, delta)
			if state_time >= RECOVERY_DURATION:
				_set_state("approach")
		"staggered":
			_set_horizontal_velocity(0.0, delta)
			if state_time >= STAGGER_DURATION:
				_set_state("approach")
	_apply_motion(delta)
	sprite.flip_h = facing > 0.0
	sprite.frame = int(floor(animation_time / FRAME_DURATION)) % FRAME_COUNT
	var hit_progress := 1.0 - hit_time / 0.18 if hit_time > 0.0 else 0.0
	var hit_kick := hit_direction * (1.0 - hit_progress) * 5.0
	sprite.position = Vector2(hit_kick.x, -12.0 - hit_progress * 2.0)
	sprite.scale = Vector2(2.0 + hit_progress * 0.18, 2.0 - hit_progress * 0.16)
	sprite.modulate = Color("#D8FFFF") if flash_time > 0.0 else Color.WHITE
	queue_redraw()

func _set_state(next_state: String) -> void:
	state = next_state
	state_time = 0.0
	if next_state == "wander":
		wander_time = 0.0
		wander_direction = -1.0 if randf() < 0.5 else 1.0
	if next_state == "approach":
		wander_time = 0.0
	if next_state == "lunge":
		attack_hit = false

func _set_wander_velocity(delta: float) -> void:
	if wander_time <= 0.0:
		wander_direction = -wander_direction if randf() < 0.35 else (-1.0 if randf() < 0.5 else 1.0)
		wander_time = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	facing = wander_direction
	_set_horizontal_velocity(wander_direction * WANDER_SPEED * status_speed_multiplier, delta)

func _set_horizontal_velocity(target_x: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target_x, ACCELERATION * delta)

func _apply_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

func take_element_damage(amount: float, element: String, attack_kind := "normal", attack_direction := Vector2.ZERO) -> void:
	if defeated_once:
		return
	var multiplier := _damage_multiplier(element)
	if element == "carbon" and exposed_solid_multiplier != 1.0:
		multiplier *= exposed_solid_multiplier
	var final_damage := amount * multiplier
	health = clampf(health - final_damage, 0.0, MAX_HEALTH)
	flash_time = 0.12
	hit_time = 0.18
	hit_element = element
	hit_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.0 else Vector2.ZERO
	_apply_element_status(element, attack_kind, attack_direction)
	if health <= 0.0:
		_defeat()
	queue_redraw()

func take_oxygen_damage(amount: float, attack_kind := "normal") -> void:
	# Oxygen pulse uses the legacy target interface; treat it as an oxygen hit.
	take_element_damage(amount, "oxygen", attack_kind)

func _damage_multiplier(element: String) -> float:
	match element:
		"hydrogen": return 0.80
		"oxygen": return 1.10
		"carbon": return 0.65
		"iron": return 1.30
	return 1.0

func _apply_element_status(element: String, attack_kind: String, attack_direction: Vector2) -> void:
	status_name = ""
	status_speed_multiplier = 1.0
	match element:
		"hydrogen":
			status_name = "dispersed"
			status_time = 0.55
			velocity += attack_direction.normalized() * 90.0 if attack_direction.length_squared() > 0 else Vector2(-facing * 90.0, 0)
		"oxygen":
			status_name = "aerated"
			status_time = 0.65
			if attack_kind == "charged":
				exposed_solid_multiplier = 1.10
		"carbon":
			status_name = "caked"
			status_time = 1.10
			status_speed_multiplier = 0.65
		"iron":
			if attack_kind == "charged" or randf() < 0.35:
				status_name = "staggered"
				status_time = STAGGER_DURATION
				_set_state("staggered")

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
	queue_redraw()

func _draw() -> void:
	if defeated_once:
		var progress := clampf(death_elapsed / DEATH_DURATION, 0.0, 1.0)
		draw_set_transform(Vector2(0, progress * 15.0), 0.0, Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.78))
		draw_colored_polygon(PackedVector2Array([Vector2(-17, 3), Vector2(-12, -14), Vector2(0, -20), Vector2(17, -12), Vector2(15, 8), Vector2(-13, 10)]), Color("#D9854B", 1.0 - progress))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for index in range(6):
			var angle := float(index) * TAU / 6.0
			var point := Vector2(cos(angle), sin(angle)) * (12.0 + progress * 32.0)
			draw_circle(point, 3.0, Color("#55D9D3", 1.0 - progress))
		return
	var health_ratio := health / MAX_HEALTH
	draw_rect(Rect2(-25, -43, 50, 5), Color("#142238"))
	draw_rect(Rect2(-25, -43, 50.0 * health_ratio, 5), Color("#D9854B"))
	if flash_time > 0.0:
		draw_rect(Rect2(-18, -17, 36, 3), Color("#D8FFFF", 0.8))
	if state == "windup":
		draw_line(Vector2(-13 * facing, -20), Vector2(13 * facing, -20), Color("#E05A60"), 2.0)
	if status_name == "caked":
		draw_line(Vector2(-11, 5), Vector2(11, 5), Color("#6B8092"), 2.0)
	_draw_hit_sparks(25.0)

func _draw_hit_sparks(radius: float) -> void:
	if hit_time <= 0.0:
		return
	var progress := 1.0 - hit_time / 0.18
	var tint := Color("#6FC7E8")
	match hit_element:
		"oxygen": tint = Color("#9AF5E5")
		"carbon": tint = Color("#B84D83")
		"iron": tint = Color("#F2C45F")
	for index in range(4):
		var angle := float(index) * TAU / 4.0 + progress
		var start := Vector2(cos(angle), sin(angle)) * radius * 0.45
		var finish := Vector2(cos(angle), sin(angle)) * lerpf(radius * 0.65, radius * 1.2, progress)
		draw_line(start, finish, Color(tint, 1.0 - progress), 2.0)
