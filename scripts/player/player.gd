extends CharacterBody2D

const HERO_IDLE_TEXTURE = preload("res://assets/character/hero_idle_01.png")
const HERO_IDLE_STRIP_TEXTURE = preload("res://assets/character/hero_idle_strip.png")
const HERO_WALK_STRIP_TEXTURE = preload("res://assets/character/hero_walk_strip.png")
const HERO_RUN_STRIP_TEXTURE = preload("res://assets/character/hero_run_strip.png")
const HERO_JUMP_STRIP_TEXTURE = preload("res://assets/character/hero_jump_strip.png")
const HERO_ATTACK_STRIP_TEXTURE = preload("res://assets/character/hero_attack_strip.png")
const HERO_CROUCH_STRIP_TEXTURE = preload("res://assets/character/hero_crouch_strip.png")
const HERO_CLIMB_STRIP_TEXTURE = preload("res://assets/character/hero_climb_strip.png")
const ELEMENT_WEAPON = preload("res://scripts/combat/weapons/element_weapon.gd")
const ELEMENTS = preload("res://scripts/shared/element_catalog.gd")
const HERO_DISPLAY_SCALE := 2.0
const WEAPON_DISPLAY_SCALE := 0.75
const WEAPON_ANCHOR_X := 12.0
const WEAPON_ANCHOR_Y := -10.0
const IDLE_FRAME_COUNT := 4
const MOTION_FRAME_COUNT := 6
const JUMP_FRAME_COUNT := 9
const ATTACK_FRAME_COUNT := 8
const CROUCH_FRAME_COUNT := 4
const CLIMB_FRAME_COUNT := 6
const IDLE_FRAME_DURATION := 0.17
const WALK_FRAME_DURATION := 0.12
const RUN_FRAME_DURATION := 0.08
const ATTACK_FRAME_DURATION := 0.06
const CROUCH_FRAME_DURATION := 0.18
const CLIMB_FRAME_DURATION := 0.12
const LANDING_FRAME_DURATION := 0.12
const JUMP_MODE_ROLL := 0
const JUMP_MODE_JET := 1
const ROLL_ROTATIONS_PER_SECOND := 2.2

signal stability_changed(value: float, maximum: float)
signal player_reset
signal jumped
signal selection_changed
signal element_projectile_requested(origin: Vector2, direction: Vector2, damage: float, attack_kind: String, element: String)
signal oxygen_pulse_requested(origin: Vector2, radius: float, damage: float, attack_kind: String)
signal oxygen_energy_changed(value: float, maximum: float)
signal charge_changed(value: float, maximum: float)
signal attack_state_changed(message: String)
signal dash_started
signal weapon_fired(element: String, attack_kind: String)
signal reload_finished(element: String)

const SPEED := 300.0
const SPRINT_SPEED := 440.0
const JUMP_VELOCITY := -620.0
const MAX_STABILITY := 100.0
const GRAVITY := 1500.0
const CLIMB_SPEED := 210.0
const MAX_OXYGEN := 100.0
const SKILL_COST := 25.0
const SKILL_COOLDOWN := 4.0
const MAX_CHARGE_TIME := 1.4
const DASH_SPEED := 900.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.8

var stability := MAX_STABILITY
var spawn_position := Vector2.ZERO
var facing := 1.0
var active_ladder: Area2D
var is_climbing := false
var push_shape := RectangleShape2D.new()
var pending_spring_launch := 0.0
var ladder_detach := 0.0
var coyote_remaining := 0.0
var jump_buffer := 0.0
var air_spray_available := true
var air_spray_timer := 0.0
var selected_element := 1 # Start with oxygen; all four elements are always available.
var magazine_ammo: Array[int] = [12, 12, 6, 6]
var reload_remaining: Array[float] = [0.0, 0.0, 0.0, 0.0]
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
var weapon_visual: Node2D
var animation_time := 0.0
var sprinting := false
var attack_animation_time := 0.0
var attack_animation_active := false
var airborne := false
var jump_anticipation_time := 0.0
var landing_animation_time := 0.0
var last_compression_strength := 1.0
var airborne_jump_mode := JUMP_MODE_ROLL
var roll_animation_time := 0.0
var world_bounds := Rect2()
var world_bounds_enabled := false
var world_bounds_margin := Vector2(18.0, 26.0)

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	push_shape.size = Vector2(20, 36)
	floor_snap_length = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hero_sprite = Sprite2D.new()
	hero_sprite.texture = HERO_IDLE_STRIP_TEXTURE
	hero_sprite.hframes = IDLE_FRAME_COUNT
	hero_sprite.frame = 0
	hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hero_sprite)
	weapon_visual = ELEMENT_WEAPON.new()
	weapon_visual.position = Vector2(WEAPON_ANCHOR_X, WEAPON_ANCHOR_Y * HERO_DISPLAY_SCALE)
	weapon_visual.scale = Vector2(WEAPON_DISPLAY_SCALE, WEAPON_DISPLAY_SCALE)
	weapon_visual.z_index = 1
	add_child(weapon_visual)
	_update_visuals()

func _physics_process(delta: float) -> void:
	if resetting:
		return
	damage_flash = maxf(0, damage_flash - delta)
	motion_clock += delta
	air_spray_timer = maxf(0, air_spray_timer - delta)
	ladder_detach = maxf(0, ladder_detach - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	dash_timer = maxf(0, dash_timer - delta)
	if active_ladder and (not is_instance_valid(active_ladder) or absf(global_position.x - active_ladder.global_position.x) > 30.0 or not active_ladder.overlaps_body(self)):
		active_ladder = null
		is_climbing = false
	if Input.is_action_just_pressed("reset_demo"):
		reset_to_spawn()
		return
	_advance_reload(delta)
	if Input.is_action_just_pressed("previous_element"):
		select_element(selected_element - 1)
	if Input.is_action_just_pressed("next_element"):
		select_element(selected_element + 1)

	var axis := Input.get_axis("move_left", "move_right")
	var climb_axis := Input.get_axis("move_up", "move_down")
	if not is_zero_approx(axis):
		facing = signf(axis)
	_update_crouch(climb_axis > 0 and active_ladder == null)
	sprinting = Input.is_action_pressed("sprint") and is_on_floor() and absf(axis) > 0.01 and not crouching
	var move_speed := SPRINT_SPEED if sprinting else (130.0 if crouching else SPEED)
	velocity.x = move_toward(velocity.x, axis * move_speed, (1800.0 if axis else 2200.0) * delta)
	coyote_remaining = 0.12 if is_on_floor() else maxf(0, coyote_remaining - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if is_on_floor():
		air_spray_available = true
		air_spray_timer = 0.0
		airborne_jump_mode = JUMP_MODE_ROLL
		roll_animation_time = 0.0
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
		jump_anticipation_time = 0.08

	var launched := not is_zero_approx(pending_spring_launch)
	if launched:
		velocity.y = pending_spring_launch
		pending_spring_launch = 0
		active_ladder = null
		is_climbing = false
		coyote_remaining = 0
		air_spray_available = true
		air_spray_timer = 0.0
		ladder_detach = 0.25
	# Horizontal input intentionally breaks the ladder attachment and lets
	# gravity take over on the same frame.
	if is_climbing and active_ladder and absf(axis) > 0.01:
		is_climbing = false
		active_ladder = null
		velocity.y = 0.0
		ladder_detach = 0.25
	if not launched and active_ladder and ladder_detach <= 0 and (is_climbing or climb_axis < -0.01):
		is_climbing = true
		air_spray_available = true
		air_spray_timer = 0.0
		# Keep the character centered on the ladder rails while climbing.
		global_position.x = active_ladder.global_position.x
		velocity.x = 0.0
		velocity.y = climb_axis * CLIMB_SPEED
		# Horizontal input cannot pull the character off the ladder rails.
		velocity.x = 0.0
		if jump_buffer > 0:
			is_climbing = false
			active_ladder = null
			ladder_detach = 0.25
			velocity.y = JUMP_VELOCITY
			airborne_jump_mode = JUMP_MODE_ROLL
			roll_animation_time = 0.0
			jump_buffer = 0
			jumped.emit()
	else:
		is_climbing = false
		velocity.y = minf(velocity.y + GRAVITY * delta, 700)
		if jump_buffer > 0 and not launched:
			if coyote_remaining > 0 or air_spray_available:
				if coyote_remaining <= 0:
					air_spray_available = false
					air_spray_timer = 0.22
					velocity.y = -590
					airborne_jump_mode = JUMP_MODE_JET
					attack_state_changed.emit("空中喷气：二段助推")
				else:
					velocity.y = JUMP_VELOCITY
					airborne_jump_mode = JUMP_MODE_ROLL
					roll_animation_time = 0.0
				coyote_remaining = 0
				jump_buffer = 0
				jumped.emit()
		if Input.is_action_just_released("jump") and velocity.y < -180:
			velocity.y *= 0.55

	_process_element_attacks(delta)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and active_ladder == null and not crouching and not launched:
		dash_direction = facing
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		dash_started.emit()
		attack_state_changed.emit("L 冲刺")
	if dash_timer > 0:
		velocity = Vector2(dash_direction * DASH_SPEED, 0)
	move_and_slide()
	if dash_timer > 0 and is_on_wall():
		dash_timer = 0
	_constrain_world_bounds()
	_push_weights(axis)
	if global_position.y > 900:
		reset_to_spawn("fall")
	_update_visuals()
	_update_hero_animation(delta)
	queue_redraw()

func set_world_bounds(bounds: Rect2, margin := Vector2(18.0, 26.0)) -> void:
	world_bounds = bounds
	world_bounds_margin = margin
	world_bounds_enabled = bounds.size.x > 0.0 and bounds.size.y > 0.0

func _constrain_world_bounds() -> void:
	if not world_bounds_enabled:
		return
	var minimum := world_bounds.position + world_bounds_margin
	var maximum := world_bounds.end - world_bounds_margin
	var constrained := Vector2(
		clampf(global_position.x, minimum.x, maximum.x),
		global_position.y
	)
	if not is_equal_approx(constrained.x, global_position.x):
		global_position.x = constrained.x
		velocity.x = 0.0
		dash_timer = 0.0
	if constrained.y < minimum.y:
		global_position.y = minimum.y
		velocity.y = maxf(velocity.y, 0.0)
	elif global_position.y > maximum.y:
		reset_to_spawn("fall")

func is_reloading() -> bool:
	return reload_remaining[selected_element] > 0.0

func magazine_capacity() -> int:
	return ELEMENTS.MAGAZINE_CAPACITY[selected_element]

func _advance_reload(delta: float) -> void:
	# Stowed magazines keep their progress; only the held weapon reloads.
	if not is_reloading():
		return
	reload_remaining[selected_element] = maxf(0.0, reload_remaining[selected_element] - delta)
	if not is_reloading():
		magazine_ammo[selected_element] = magazine_capacity()
		weapon_visual.set_reload_progress(-1.0)
		attack_state_changed.emit(ELEMENTS.NAMES[selected_element] + "换弹完成")
		reload_finished.emit(ELEMENTS.IDS[selected_element])

func _start_reload() -> void:
	if is_reloading():
		return
	reload_remaining[selected_element] = ELEMENTS.RELOAD_SECONDS[selected_element]
	charging = false
	charge_time = 0.0
	charge_changed.emit(0, MAX_CHARGE_TIME)
	weapon_visual.set_reload_progress(0.0)
	attack_state_changed.emit("%s自动换弹 · %.1f 秒" % [ELEMENTS.NAMES[selected_element], reload_remaining[selected_element]])

func _prepare_shot(count: int) -> bool:
	if is_reloading():
		return false
	if magazine_ammo[selected_element] < count:
		_start_reload()
		return false
	return true

func _finish_shot() -> void:
	if magazine_ammo[selected_element] == 0:
		_start_reload()

func _process_element_attacks(delta: float) -> void:
	if is_reloading():
		return
	if Input.is_action_just_pressed("oxygen_normal") and _prepare_shot(1):
		magazine_ammo[selected_element] -= 1
		_start_attack_animation()
		last_compression_strength = 1.0
		_fire_element("normal", ELEMENTS.NORMAL_DAMAGE[selected_element])
		attack_state_changed.emit(ELEMENTS.NAMES[selected_element] + "元素普攻：" + ELEMENTS.NORMAL_NAMES[selected_element])
		_finish_shot()
	if Input.is_action_just_pressed("oxygen_skill2") and _prepare_shot(1):
		charging = true
		charge_time = 0
		_start_attack_animation()
		attack_state_changed.emit("蓄力中：松开 I 释放" + ELEMENTS.CHARGED_NAMES[selected_element])
	if charging:
		charge_time = minf(MAX_CHARGE_TIME, charge_time + delta)
		charge_changed.emit(charge_time, MAX_CHARGE_TIME)
		# Releasing I while paused must also finish the charge after resuming.
		if not Input.is_action_pressed("oxygen_skill2"):
			var ratio := clampf(charge_time / MAX_CHARGE_TIME, 0.2, 1.0)
			charging = false
			charge_time = 0
			charge_changed.emit(0, MAX_CHARGE_TIME)
			if _prepare_shot(1):
				magazine_ammo[selected_element] -= 1
				last_compression_strength = 1.0 + 3.0 * ratio
				_fire_element("charged", lerpf(ELEMENTS.NORMAL_DAMAGE[selected_element], ELEMENTS.CHARGED_DAMAGE[selected_element], ratio))
				gain_oxygen(12.0 + 18.0 * ratio)
				attack_state_changed.emit("%s %.0f%%" % [ELEMENTS.CHARGED_NAMES[selected_element], ratio * 100])
				_start_attack_animation()
				_finish_shot()
	if Input.is_action_just_pressed("oxygen_skill"):
		if skill_cooldown <= 0 and oxygen_energy >= SKILL_COST:
			var cost := 1 if selected_element == 1 else 3
			if _prepare_shot(cost):
				# Commit the whole volley before emitting any projectiles or spending energy.
				magazine_ammo[selected_element] -= cost
				_start_attack_animation()
				consume_oxygen(SKILL_COST)
				skill_cooldown = SKILL_COOLDOWN
				if selected_element == 1:
					oxygen_pulse_requested.emit(global_position + Vector2(118 * facing, -8), 165.0, 34.0, "skill")
					weapon_fired.emit("oxygen", "charged")
				else:
					_fire_fan(3, false)
				attack_state_changed.emit("U：" + ELEMENTS.NAMES[selected_element] + "元素技能")
				_finish_shot()
		else:
			attack_state_changed.emit("技能未就绪：需要 25 元素能量并等待冷却")
	if Input.is_action_just_pressed("oxygen_ultimate"):
		if oxygen_energy >= MAX_OXYGEN:
			var cost := 1 if selected_element == 1 else 5
			if _prepare_shot(cost):
				magazine_ammo[selected_element] -= cost
				_start_attack_animation()
				consume_oxygen(MAX_OXYGEN)
				if selected_element == 1:
					oxygen_pulse_requested.emit(global_position + Vector2(170 * facing, -12), 330.0, 120.0, "ultimate")
					weapon_fired.emit("oxygen", "charged")
				else:
					_fire_fan(5, true)
				attack_state_changed.emit("O：" + ELEMENTS.NAMES[selected_element] + "元素爆发")
				_finish_shot()
		else:
			attack_state_changed.emit("大招未就绪：元素能量需要充满")

func select_element(index: int) -> void:
	selected_element = posmod(index, ELEMENTS.IDS.size())
	# Never release ammunition from an element that was charged before switching.
	charging = false
	charge_time = 0.0
	last_compression_strength = 1.0
	charge_changed.emit(0, MAX_CHARGE_TIME)
	weapon_visual.set_element(ELEMENTS.IDS[selected_element])
	_update_hero_animation(0.0)
	selection_changed.emit()
	attack_state_changed.emit(ELEMENTS.NAMES[selected_element] + " · " + ELEMENTS.WEAPONS[selected_element])
	queue_redraw()

func _fire_element(kind: String, amount: float, angle := 0.0, play_sound := true) -> void:
	# Update the hand transform before sampling the muzzle on a turn-and-fire frame.
	_update_hero_animation(0.0)
	weapon_visual.fire()
	element_projectile_requested.emit(_attack_origin(), Vector2(facing, -0.04).normalized().rotated(angle), amount, kind, ELEMENTS.IDS[selected_element])
	if play_sound:
		weapon_fired.emit(ELEMENTS.IDS[selected_element], kind)

func _fire_fan(count: int, charged: bool) -> void:
	last_compression_strength = 4.0 if charged else 1.0
	for index in range(count):
		var angle := (index - (count - 1) * 0.5) * 0.10
		_fire_element("charged" if charged else "normal", ELEMENTS.CHARGED_DAMAGE[selected_element] if charged else ELEMENTS.NORMAL_DAMAGE[selected_element], angle, false)
	weapon_fired.emit(ELEMENTS.IDS[selected_element], "charged" if charged else "normal")

func _attack_origin() -> Vector2:
	return weapon_visual.to_global(weapon_visual.muzzle)

func _update_hero_animation(delta: float) -> void:
	if not hero_sprite:
		return
	# The roll is a visual-only transform. Clear it first so landing, climbing,
	# attacks, and crouching always return the character to an upright pose.
	hero_sprite.rotation = 0.0
	hero_sprite.flip_h = false if is_climbing else facing < 0
	if weapon_visual:
		weapon_visual.visible = not is_climbing
		var crouch_ratio := hero_sprite.scale.y / HERO_DISPLAY_SCALE
		weapon_visual.position = Vector2(WEAPON_ANCHOR_X * facing, WEAPON_ANCHOR_Y * hero_sprite.scale.y)
		weapon_visual.scale = Vector2(WEAPON_DISPLAY_SCALE * facing, WEAPON_DISPLAY_SCALE * crouch_ratio)
		weapon_visual.set("charge_ratio", charge_time / MAX_CHARGE_TIME if charging else 0.0)
		weapon_visual.set_reload_progress(1.0 - reload_remaining[selected_element] / ELEMENTS.RELOAD_SECONDS[selected_element] if is_reloading() else -1.0)
		weapon_visual.queue_redraw()
	if charging:
		_set_hero_animation_texture(HERO_ATTACK_STRIP_TEXTURE, ATTACK_FRAME_COUNT)
		hero_sprite.frame = 1 + mini(2, int(floor(clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0) * 3.0)))
		return
	if attack_animation_active:
		_set_hero_animation_texture(HERO_ATTACK_STRIP_TEXTURE, ATTACK_FRAME_COUNT)
		attack_animation_time += delta
		var attack_frame := int(floor(attack_animation_time / ATTACK_FRAME_DURATION))
		if attack_frame < ATTACK_FRAME_COUNT:
			hero_sprite.frame = attack_frame
			return
		attack_animation_active = false
		attack_animation_time = 0.0
	if is_climbing:
		_set_hero_animation_texture(HERO_CLIMB_STRIP_TEXTURE, CLIMB_FRAME_COUNT)
		animation_time += delta
		hero_sprite.frame = int(floor(animation_time / CLIMB_FRAME_DURATION)) % CLIMB_FRAME_COUNT
		return
	if crouching and is_on_floor():
		_set_hero_animation_texture(HERO_CROUCH_STRIP_TEXTURE, CROUCH_FRAME_COUNT)
		animation_time += delta
		hero_sprite.frame = int(floor(animation_time / CROUCH_FRAME_DURATION)) % CROUCH_FRAME_COUNT
		return
	if not is_on_floor():
		_set_hero_animation_texture(HERO_JUMP_STRIP_TEXTURE, JUMP_FRAME_COUNT)
		if airborne_jump_mode == JUMP_MODE_ROLL:
			# One full body roll every ~0.45 s keeps the first jump readable while
			# still giving the player a clear mid-air action pose.
			roll_animation_time += delta
			hero_sprite.rotation = fposmod(roll_animation_time * TAU * ROLL_ROTATIONS_PER_SECOND, TAU)
			hero_sprite.frame = 4 if velocity.y < 100 else 7
		else:
			# The second jump keeps the authored jet-assisted jump frames intact.
			hero_sprite.frame = 1 if velocity.y < -220 else 4 if velocity.y < 100 else 7
		return
	if absf(velocity.x) > 8.0 and dash_timer <= 0.0:
		_set_hero_animation_texture(HERO_RUN_STRIP_TEXTURE if sprinting else HERO_WALK_STRIP_TEXTURE, MOTION_FRAME_COUNT)
		animation_time += delta
		hero_sprite.frame = int(floor(animation_time / (RUN_FRAME_DURATION if sprinting else WALK_FRAME_DURATION))) % MOTION_FRAME_COUNT
	else:
		# Keep the authored 32×48 idle frame as the stable standing pose;
		# movement, jump and attack states use the multi-frame strips above.
		_set_hero_animation_texture(HERO_IDLE_STRIP_TEXTURE, IDLE_FRAME_COUNT)
		animation_time += delta
		hero_sprite.frame = int(floor(animation_time / IDLE_FRAME_DURATION)) % IDLE_FRAME_COUNT

func _set_hero_animation_texture(texture: Texture2D, frame_count: int) -> void:
	if hero_sprite.texture == texture and hero_sprite.hframes == frame_count:
		return
	hero_sprite.texture = texture
	hero_sprite.hframes = frame_count
	hero_sprite.frame = 0

func _start_attack_animation() -> void:
	attack_animation_active = true
	attack_animation_time = 0.0

func gain_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy + amount, 0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func consume_oxygen(amount: float) -> void:
	oxygen_energy = clampf(oxygen_energy - amount, 0, MAX_OXYGEN)
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)

func reset_combat() -> void:
	magazine_ammo.assign(ELEMENTS.MAGAZINE_CAPACITY)
	reload_remaining.fill(0.0)
	if weapon_visual:
		weapon_visual.set_reload_progress(-1.0)
	oxygen_energy = MAX_OXYGEN
	charging = false
	charge_time = 0
	skill_cooldown = 0
	dash_timer = 0
	dash_cooldown = 0
	last_compression_strength = 1.0
	attack_animation_active = false
	attack_animation_time = 0.0
	oxygen_energy_changed.emit(oxygen_energy, MAX_OXYGEN)
	charge_changed.emit(0, MAX_CHARGE_TIME)

func _update_visuals() -> void:
	if not hero_sprite:
		return
	hero_sprite.flip_h = false if is_climbing else facing < 0
	var visual_scale_y := HERO_DISPLAY_SCALE * (0.6 if crouching else 1.0)
	hero_sprite.scale = Vector2(HERO_DISPLAY_SCALE, visual_scale_y)
	# The 48px source frame has a 24px half-height; keep its feet on the
	# capsule's bottom edge (y = 26) at both standing and crouching heights.
	hero_sprite.position = Vector2(0, 26 - 24 * visual_scale_y)
	hero_sprite.modulate = Color(1.8, 1.8, 1.8) if damage_flash > 0 else Color.WHITE

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
		velocity.x = 0.0
		global_position.x = ladder.global_position.x
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
	air_spray_available = true
	air_spray_timer = 0.0
	airborne_jump_mode = JUMP_MODE_ROLL
	roll_animation_time = 0.0
	if hero_sprite:
		hero_sprite.rotation = 0.0
	stability = MAX_STABILITY
	reset_combat()
	_update_crouch(false)
	_update_visuals()
	stability_changed.emit(stability, MAX_STABILITY)
	player_reset.emit()

func _draw() -> void:
	draw_circle(Vector2(19 * facing, 5 if crouching else -7), 3, ELEMENTS.TINTS[selected_element])
	if dash_timer > 0.0:
		var dash_ratio := dash_timer / DASH_DURATION
		for trail in range(3):
			var length := 26.0 + float(trail) * 13.0
			var alpha := (0.72 - float(trail) * 0.18) * dash_ratio
			draw_line(Vector2(-facing * 12.0, -8.0 + trail * 8.0), Vector2(-facing * length, -8.0 + trail * 8.0), Color("#9AF5E5", alpha), 3.0)
		draw_arc(Vector2.ZERO, 27.0 + (1.0 - dash_ratio) * 9.0, 0.0, TAU, 18, Color("#D8FFFF", 0.75 * dash_ratio), 2.0)
	if is_climbing:
		draw_line(Vector2(-20, 6), Vector2(-20, -12), Color("#83d5ac"), 2)
	if charging:
		var ratio := clampf(charge_time / MAX_CHARGE_TIME, 0, 1)
		draw_arc(Vector2.ZERO, 32 + ratio * 12, -PI * 0.8, PI * 0.8, 24, Color("#ffd76e"), 3)
	if air_spray_timer > 0:
		var spray_ratio := air_spray_timer / 0.22
		var spray_color := Color("#b7f2e6", 0.5 + spray_ratio * 0.5)
		var spray_length := 34 + (1.0 - spray_ratio) * 8
		draw_line(Vector2(-7, 22), Vector2(-10, spray_length), spray_color, 3)
		draw_line(Vector2(7, 22), Vector2(10, spray_length), spray_color, 3)
		draw_circle(Vector2(-10, spray_length), 3, spray_color)
		draw_circle(Vector2(10, spray_length), 3, spray_color)
