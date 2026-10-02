extends CharacterBody2D

const HERO_IDLE_TEXTURE = preload("res://assets/character/hero_idle_01.png")

signal stability_changed(value: float, maximum: float)
signal acid_requested(origin: Vector2, direction: Vector2)
signal oxygen_projectile_requested(origin: Vector2, direction: Vector2, damage: float, attack_kind: String)
signal oxygen_pulse_requested(origin: Vector2, radius: float, damage: float, attack_kind: String)
signal oxygen_energy_changed(value: float, maximum: float)
signal charge_changed(value: float, maximum: float)
signal attack_state_changed(message: String)
signal player_reset

const SPEED := 300.0
const JUMP_VELOCITY := -620.0
const MAX_STABILITY := 100.0
const GRAVITY := 1500.0
const MAX_OXYGEN := 100.0
const SKILL_COST := 25.0
const SKILL_COOLDOWN := 4.0
const MAX_CHARGE_TIME := 1.4
const DASH_SPEED := 900.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.8

var stability := MAX_STABILITY
var spawn_position := Vector2.ZERO
var acid_cooldown := 0.0
var facing := 1.0
var oxygen_energy := MAX_OXYGEN
var charge_time := 0.0
var charging := false
var skill_cooldown := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var hero_sprite: Sprite2D

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	hero_sprite = Sprite2D.new()
	hero_sprite.texture = HERO_IDLE_TEXTURE
	hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero_sprite.scale = Vector2(2.0, 2.0)
	# Keep the enlarged sprite's feet aligned with the collision body's base.
	hero_sprite.position = Vector2(0.0, -4.0)
	add_child(hero_sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_demo"):
		reset_to_spawn()

	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		attack_state_changed.emit("L 冲刺")

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		move_and_slide()
		queue_redraw()
		return

	var axis := Input.get_axis("move_left", "move_right")
	if abs(axis) > 0.01:
		facing = sign(axis)
		velocity.x = move_toward(velocity.x, axis * SPEED, 1800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	acid_cooldown = maxf(0.0, acid_cooldown - delta)
	if Input.is_action_just_pressed("use_acid") and acid_cooldown <= 0.0:
		acid_cooldown = 0.35
		acid_requested.emit(global_position + Vector2(28.0 * facing, -6.0), Vector2(facing, -0.08))

	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	if Input.is_action_just_pressed("oxygen_normal"):
		oxygen_projectile_requested.emit(_attack_origin(), Vector2(facing, -0.04), 12.0, "normal")
		attack_state_changed.emit("氧元素普攻：氧气弹")

	if Input.is_action_just_pressed("oxygen_skill2"):
		charging = true
		charge_time = 0.0
		attack_state_changed.emit("技能 2 蓄力中：松开 I 释放压缩氧核")

	if charging:
		charge_time = minf(MAX_CHARGE_TIME, charge_time + delta)
		charge_changed.emit(charge_time, MAX_CHARGE_TIME)
		if Input.is_action_just_released("oxygen_skill2"):
			var ratio := clampf(charge_time / MAX_CHARGE_TIME, 0.2, 1.0)
			var charge_damage := lerpf(22.0, 70.0, ratio)
			oxygen_projectile_requested.emit(_attack_origin(), Vector2(facing, -0.04), charge_damage, "charged")
			gain_oxygen(12.0 + 18.0 * ratio)
			attack_state_changed.emit("技能 2：压缩氧核 %.0f%%" % (ratio * 100.0))
			charging = false
			charge_time = 0.0
			charge_changed.emit(0.0, MAX_CHARGE_TIME)

	if Input.is_action_just_pressed("oxygen_skill"):
		if skill_cooldown <= 0.0 and oxygen_energy >= SKILL_COST:
			consume_oxygen(SKILL_COST)
			skill_cooldown = SKILL_COOLDOWN
			oxygen_pulse_requested.emit(global_position + Vector2(118.0 * facing, -8.0), 165.0, 34.0, "skill")
			attack_state_changed.emit("技能：氧化冲击（冷却 %.1fs）" % SKILL_COOLDOWN)
		else:
			attack_state_changed.emit("技能无法使用：需要氧能量 %.0f 或等待冷却" % SKILL_COST)

	if Input.is_action_just_pressed("oxygen_ultimate"):
		if oxygen_energy >= MAX_OXYGEN:
			consume_oxygen(MAX_OXYGEN)
			oxygen_pulse_requested.emit(global_position + Vector2(170.0 * facing, -12.0), 330.0, 120.0, "ultimate")
			attack_state_changed.emit("大招：纯氧领域！")
		else:
			attack_state_changed.emit("大招未就绪：氧能量需要充满")

	move_and_slide()
	if hero_sprite:
		hero_sprite.flip_h = facing < 0.0
	if global_position.y > 900.0:
		reset_to_spawn()
	queue_redraw()

func _attack_origin() -> Vector2:
	return global_position + Vector2(30.0 * facing, -10.0)

func gain_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy + amount, 0.0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func consume_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy - amount, 0.0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func take_damage(amount: float) -> void:
	stability = clampf(stability - amount, 0.0, MAX_STABILITY)
	stability_changed.emit(stability, MAX_STABILITY)
	if stability <= 0.0:
		reset_to_spawn()

func restore_stability(amount: float) -> void:
	stability = clampf(stability + amount, 0.0, MAX_STABILITY)
	stability_changed.emit(stability, MAX_STABILITY)

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	stability = MAX_STABILITY
	oxygen_energy = MAX_OXYGEN
	charging = false
	charge_time = 0.0
	skill_cooldown = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	stability_changed.emit(stability, MAX_STABILITY)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)
	charge_changed.emit(0.0, MAX_CHARGE_TIME)
	player_reset.emit()

func _draw() -> void:
	if charging:
		var charge_ratio := clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 32.0 + charge_ratio * 12.0, -PI * 0.8, PI * 0.8, 24, Color("#ffd76e"), 4.0)
