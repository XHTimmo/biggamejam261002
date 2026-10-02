extends CharacterBody2D

signal defeated

const IDLE_TEXTURE = preload("res://assets/enemies/dirt_mud_blob_idle_strip.png")
const ELEMENTS = preload("res://element_catalog.gd")
const FRAME_COUNT := 6
const FRAME_DURATION := 0.125
const GRAVITY := 1500.0
const MAX_HEALTH := 120.0
const CONTACT_DAMAGE := 18.0
const MOVE_SPEED := 70.0
const ACCELERATION := 540.0
const DETECTION_RADIUS := 240.0
const LOSE_TARGET_RADIUS := 420.0
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
var defeated_once := false
var sprite: Sprite2D

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
	if defeated_once:
		return
	state_time += delta
	animation_time += delta
	flash_time = maxf(0.0, flash_time - delta)
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
			_set_horizontal_velocity(0.0, delta)
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
	queue_redraw()

func _set_state(next_state: String) -> void:
	state = next_state
	state_time = 0.0
	if next_state == "lunge":
		attack_hit = false

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
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider:
		collider.set_deferred("disabled", true)
	defeated.emit()
	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _draw() -> void:
	if defeated_once:
		for index in range(3):
			var point := Vector2(-16.0 + index * 16.0, -18.0 - sin(animation_time * 5.0 + index) * 5.0)
			draw_rect(Rect2(point, Vector2(4, 4)), Color("#55D9D3", 0.45))
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
