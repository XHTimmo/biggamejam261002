extends CharacterBody2D

const HERO_IDLE_TEXTURE = preload("res://assets/character/hero_idle_01.png")

signal stability_changed(value: float, maximum: float)
signal acid_requested(origin: Vector2, direction: Vector2)
signal reagent_requested(origin: Vector2, direction: Vector2, reagent: String)
signal gravity_requested(target: Vector2)
signal player_reset
signal jumped
signal selection_changed
signal oxygen_projectile_requested(origin: Vector2, direction: Vector2, damage: float, attack_kind: String)
signal oxygen_pulse_requested(origin: Vector2, radius: float, damage: float, attack_kind: String)
signal oxygen_energy_changed(value: float, maximum: float)
signal charge_changed(value: float, maximum: float)
signal attack_state_changed(message: String)

const SPEED := 300.0
const JUMP_VELOCITY := -620.0
const MAX_STABILITY := 100.0
const GRAVITY := 1500.0
const CLIMB_SPEED := 210.0
const REAGENTS := ["acid", "ice", "iron"]
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
var gravity_cooldown := 0.0
var facing := 1.0
var active_ladder: Area2D
var is_climbing := false
var push_shape := RectangleShape2D.new()
var pending_spring_launch := 0.0
var ladder_detach := 0.0
var coyote_remaining := 0.0
var jump_buffer := 0.0
var double_jump_available := true
var selected_reagent := 0
var available_reagents := 1
var resetting := false
var reset_reason := "manual"
var crouching := false
var damage_flash := 0.0
var motion_clock := 0.0
var oxygen_energy := MAX_OXYGEN
var charge_time := 0.0
var charging := false
var skill_cooldown := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_direction := 1.0
var hero_sprite: Sprite2D

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	push_shape.size = Vector2(20, 36)
	floor_snap_length = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hero_sprite = Sprite2D.new()
	hero_sprite.texture = HERO_IDLE_TEXTURE
	hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hero_sprite)
	_update_visuals()

func _physics_process(delta: float) -> void:
	if resetting:
		return
	damage_flash = maxf(0, damage_flash - delta)
	motion_clock += delta
	ladder_detach = maxf(0, ladder_detach - delta)
	acid_cooldown = maxf(0, acid_cooldown - delta)
	gravity_cooldown = maxf(0, gravity_cooldown - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	dash_timer = maxf(0, dash_timer - delta)
	if active_ladder and (not is_instance_valid(active_ladder) or not active_ladder.overlaps_body(self)):
		active_ladder = null
		is_climbing = false
	if Input.is_action_just_pressed("reset_demo"):
		reset_to_spawn()
		return
	for index in range(available_reagents):
		if Input.is_action_just_pressed("slot_%d" % (index + 1)):
			selected_reagent = index
			selection_changed.emit()
	if Input.is_action_just_pressed("next_item"):
		selected_reagent = (selected_reagent + 1) % available_reagents
		selection_changed.emit()
	if Input.is_action_just_pressed("previous_item"):
		selected_reagent = (selected_reagent + available_reagents - 1) % available_reagents
		selection_changed.emit()

	var axis := Input.get_axis("move_left", "move_right")
	var climb_axis := Input.get_axis("move_up", "move_down")
	if not is_zero_approx(axis):
		facing = signf(axis)
	_update_crouch(climb_axis > 0 and active_ladder == null)
	velocity.x = move_toward(velocity.x, axis * (130.0 if crouching else SPEED), (1800.0 if axis else 2200.0) * delta)
	coyote_remaining = 0.12 if is_on_floor() else maxf(0, coyote_remaining - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if is_on_floor():
		double_jump_available = true
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12

	var launched := not is_zero_approx(pending_spring_launch)
	if launched:
		velocity.y = pending_spring_launch
		pending_spring_launch = 0
		active_ladder = null
		is_climbing = false
		coyote_remaining = 0
		double_jump_available = true
		ladder_detach = 0.25
	if not launched and active_ladder and ladder_detach <= 0 and (is_climbing or absf(climb_axis) > 0.01):
		is_climbing = true
		double_jump_available = true
		velocity.y = climb_axis * CLIMB_SPEED
		velocity.x = axis * SPEED * 0.55
		if jump_buffer > 0:
			is_climbing = false
			active_ladder = null
			ladder_detach = 0.25
			velocity.y = JUMP_VELOCITY
			jump_buffer = 0
			jumped.emit()
	else:
		is_climbing = false
		velocity.y = minf(velocity.y + GRAVITY * delta, 700)
		if jump_buffer > 0 and not launched:
			if coyote_remaining > 0 or double_jump_available:
				if coyote_remaining <= 0:
					double_jump_available = false
					velocity.y = -590
				else:
					velocity.y = JUMP_VELOCITY
				coyote_remaining = 0
				jump_buffer = 0
				jumped.emit()
		if Input.is_action_just_released("jump") and velocity.y < -180:
			velocity.y *= 0.55

	if Input.is_action_just_pressed("use_acid") and acid_cooldown <= 0:
		_throw(false)
	if Input.is_action_just_pressed("throw_item") and acid_cooldown <= 0:
		_throw(true)
	if Input.is_action_just_pressed("gravity_skill") and gravity_cooldown <= 0 and available_reagents >= 2:
		gravity_cooldown = 4
		var offset := get_global_mouse_position() - global_position
		gravity_requested.emit(global_position + offset.limit_length(220) if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else global_position)
	_process_oxygen_attacks(delta)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and active_ladder == null and not crouching and not launched:
		dash_direction = facing
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		attack_state_changed.emit("L 冲刺")
	if dash_timer > 0:
		velocity = Vector2(dash_direction * DASH_SPEED, 0)
	move_and_slide()
	if dash_timer > 0 and is_on_wall():
		dash_timer = 0
	_push_weights(axis)
	if global_position.y > 900:
		reset_to_spawn("fall")
	_update_visuals()
	queue_redraw()

func _process_oxygen_attacks(delta: float) -> void:
	if Input.is_action_just_pressed("oxygen_normal"):
		oxygen_projectile_requested.emit(_attack_origin(), Vector2(facing, -0.04), 12.0, "normal")
		attack_state_changed.emit("氧元素普攻：氧气弹")
	if Input.is_action_just_pressed("oxygen_skill2"):
		charging = true
		charge_time = 0
		attack_state_changed.emit("技能 2 蓄力中：松开 I 释放压缩氧核")
	if charging:
		charge_time = minf(MAX_CHARGE_TIME, charge_time + delta)
		charge_changed.emit(charge_time, MAX_CHARGE_TIME)
		# Releasing I while paused must also finish the charge after resuming.
		if not Input.is_action_pressed("oxygen_skill2"):
			var ratio := clampf(charge_time / MAX_CHARGE_TIME, 0.2, 1.0)
			oxygen_projectile_requested.emit(_attack_origin(), Vector2(facing, -0.04), lerpf(22.0, 70.0, ratio), "charged")
			gain_oxygen(12.0 + 18.0 * ratio)
			attack_state_changed.emit("技能 2：压缩氧核 %.0f%%" % (ratio * 100))
			charging = false
			charge_time = 0
			charge_changed.emit(0, MAX_CHARGE_TIME)
	if Input.is_action_just_pressed("oxygen_skill"):
		if skill_cooldown <= 0 and oxygen_energy >= SKILL_COST:
			consume_oxygen(SKILL_COST)
			skill_cooldown = SKILL_COOLDOWN
			oxygen_pulse_requested.emit(global_position + Vector2(118 * facing, -8), 165.0, 34.0, "skill")
			attack_state_changed.emit("技能 1：氧化冲击")
		else:
			attack_state_changed.emit("技能未就绪：需要 25 氧能量并等待冷却")
	if Input.is_action_just_pressed("oxygen_ultimate"):
		if oxygen_energy >= MAX_OXYGEN:
			consume_oxygen(MAX_OXYGEN)
			oxygen_pulse_requested.emit(global_position + Vector2(170 * facing, -12), 330.0, 120.0, "ultimate")
			attack_state_changed.emit("大招：纯氧领域")
		else:
			attack_state_changed.emit("大招未就绪：氧能量需要充满")

func _attack_origin() -> Vector2:
	return global_position + Vector2(30 * facing, -10)

func gain_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy + amount, 0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func consume_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy - amount, 0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func reset_combat() -> void:
	oxygen_energy = MAX_OXYGEN
	charging = false
	charge_time = 0
	skill_cooldown = 0
	dash_timer = 0
	dash_cooldown = 0
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)
	charge_changed.emit(0, MAX_CHARGE_TIME)

func _update_visuals() -> void:
	if not hero_sprite:
		return
	hero_sprite.flip_h = facing < 0
	hero_sprite.scale = Vector2(1, 0.6 if crouching else 1.0)
	hero_sprite.position = Vector2(0, 26 - 24 * hero_sprite.scale.y)
	hero_sprite.modulate = Color(1.8, 1.8, 1.8) if damage_flash > 0 else Color.WHITE

func _throw(aim_at_mouse: bool) -> void:
	acid_cooldown = 0.35
	var reagent: String = REAGENTS[selected_reagent]
	var direction := Vector2(facing, 0.3 if reagent == "ice" else -0.08).normalized()
	if aim_at_mouse:
		var offset := get_global_mouse_position() - global_position
		if offset.length() > 8:
			direction = offset.normalized()
	var origin := global_position + direction * 29 + Vector2(0, -6)
	reagent_requested.emit(origin, direction, reagent)

func _update_crouch(wants_crouch: bool) -> void:
	var collider := get_node("CollisionShape2D") as CollisionShape2D
	if not wants_crouch and crouching:
		# Query only the extra headroom, so the supporting floor is not
		# mistaken for an overhead obstacle when the capsule touches it.
		var test_shape := RectangleShape2D.new()
		test_shape.size = Vector2(32, 20)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = test_shape
		query.transform = global_transform.translated_local(Vector2(0, -16))
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return
	if wants_crouch == crouching:
		return
	crouching = wants_crouch
	(collider.shape as CapsuleShape2D).height = 32 if crouching else 52
	collider.position.y = 10 if crouching else 0

func set_ladder(ladder: Area2D, entered: bool) -> void:
	if entered and ladder_detach <= 0:
		active_ladder = ladder
	elif active_ladder == ladder and not entered:
		active_ladder = null
		is_climbing = false

func spring_launch(launch_velocity: float) -> void:
	active_ladder = null
	is_climbing = false
	pending_spring_launch = launch_velocity

func _push_weights(axis: float) -> void:
	if absf(axis) < 0.01:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = push_shape
	query.transform = Transform2D(0, global_position + Vector2(axis * 26, 5))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := result.get("collider") as PhysicsBody2D
		if body and body.is_in_group("weights") and body.has_method("request_push"):
			body.request_push(axis)
			return

func take_damage(amount: float) -> void:
	if resetting:
		return
	stability = clampf(stability - amount, 0, MAX_STABILITY)
	damage_flash = 0.15
	stability_changed.emit(stability, MAX_STABILITY)
	if stability <= 0:
		reset_to_spawn("stability")

func restore_stability(amount: float) -> void:
	stability = clampf(stability + amount, 0, MAX_STABILITY)
	stability_changed.emit(stability, MAX_STABILITY)

func reset_to_spawn(reason := "manual") -> void:
	if resetting:
		return
	resetting = true
	reset_reason = reason
	global_position = spawn_position
	velocity = Vector2.ZERO
	active_ladder = null
	is_climbing = false
	pending_spring_launch = 0
	ladder_detach = 0.25
	coyote_remaining = 0
	jump_buffer = 0
	double_jump_available = true
	gravity_cooldown = 0
	acid_cooldown = 0
	stability = MAX_STABILITY
	reset_combat()
	_update_crouch(false)
	_update_visuals()
	stability_changed.emit(stability, MAX_STABILITY)
	player_reset.emit()

func _draw() -> void:
	var reagent_tint := [Color("#8ce3b5"), Color("#a2e0fa"), Color("#dfbd7d")]
	draw_circle(Vector2(19 * facing, 5 if crouching else -7), 3, reagent_tint[selected_reagent])
	if is_climbing:
		draw_line(Vector2(-20, 6), Vector2(-20, -12), Color("#83d5ac"), 2)
	if charging:
		var ratio := clampf(charge_time / MAX_CHARGE_TIME, 0, 1)
		draw_arc(Vector2.ZERO, 32 + ratio * 12, -PI * 0.8, PI * 0.8, 24, Color("#ffd76e"), 3)
