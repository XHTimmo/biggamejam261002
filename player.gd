extends CharacterBody2D

signal stability_changed(value: float, maximum: float)
signal acid_requested(origin: Vector2, direction: Vector2)
signal reagent_requested(origin: Vector2, direction: Vector2, reagent: String)
signal gravity_requested(target: Vector2)
signal player_reset
signal jumped
signal selection_changed

const SPEED := 300.0
const JUMP_VELOCITY := -620.0
const MAX_STABILITY := 100.0
const GRAVITY := 1500.0
const CLIMB_SPEED := 210.0
const REAGENTS := ["acid", "ice", "iron"]

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

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	push_shape.size = Vector2(20, 36)
	floor_snap_length = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	if resetting:
		return
	damage_flash = maxf(0, damage_flash - delta)
	motion_clock += delta
	ladder_detach = maxf(0, ladder_detach - delta)
	acid_cooldown = maxf(0, acid_cooldown - delta)
	gravity_cooldown = maxf(0, gravity_cooldown - delta)
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
	move_and_slide()
	_push_weights(axis)
	if global_position.y > 900:
		reset_to_spawn("fall")
	queue_redraw()

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
		var test_shape := CapsuleShape2D.new()
		test_shape.radius = 16
		test_shape.height = 52
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = test_shape
		query.transform = global_transform
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
	stability_changed.emit(stability, MAX_STABILITY)
	player_reset.emit()

func _draw() -> void:
	var offset := 14.0 if crouching else 0.0
	draw_set_transform(Vector2(0, offset), 0, Vector2.ONE)
	var tint := Color("#ffffff") if damage_flash > 0 else Color("#edc591")
	draw_rect(Rect2(-16, -26, 32, 40 - offset), tint)
	draw_rect(Rect2(-18, -31, 36, 12), Color("#e8efe3"))
	draw_rect(Rect2(-11, -27, 22, 7), Color("#344e5c"))
	draw_rect(Rect2(-11, -24, 7, 2), Color("#83c6d0"))
	var stride := sin(motion_clock * 16) * 3 if is_on_floor() and absf(velocity.x) > 10 else 0.0
	draw_rect(Rect2(-14, 14 - offset + stride, 11, 12), Color("#56729d"))
	draw_rect(Rect2(3, 14 - offset - stride, 11, 12), Color("#56729d"))
	draw_rect(Rect2(-18, -12, 6, 24 - offset), Color("#647778"))
	var reagent_tint := [Color("#8ce3b5"), Color("#a2e0fa"), Color("#dfbd7d")]
	draw_circle(Vector2(13 * facing, -7), 4, reagent_tint[selected_reagent])
	if is_climbing:
		draw_line(Vector2(-14, -2), Vector2(-22, -13), tint, 5)
		draw_line(Vector2(14, -2), Vector2(22, -13), tint, 5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
