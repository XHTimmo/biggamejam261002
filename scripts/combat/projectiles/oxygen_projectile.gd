extends Area2D

const NORMAL_TEXTURE = preload("res://assets/chemistry_bullets/oxygen_v2/oxygen_normal_strip.png")
const CHARGED_TEXTURE = preload("res://assets/chemistry_bullets/oxygen_v2/oxygen_charged_strip.png")
const IMPACT_TEXTURE = preload("res://assets/chemistry_bullets/oxygen_v2/oxygen_impact_strip.png")
const CHARGED_IMPACT_TEXTURE = preload("res://assets/chemistry_bullets/oxygen_v2/oxygen_charged_impact_strip.png")
const FLIGHT_FRAMES := 8
const FLIGHT_FPS := 16.0
const EXPLOSION_FPS := 24.0
const BALLISTICS = preload("res://scripts/combat/ballistics/air_gun_ballistics.gd")
const ENVIRONMENT = preload("res://scripts/combat/ballistics/air_gun_environment.gd")
const GAS_CLOUD = preload("res://scripts/combat/projectiles/oxygen_gas_cloud.gd")

var direction := Vector2.RIGHT
var damage := 12.0
var attack_kind := "normal"
var compression_strength := 1.0
var environment: Resource = ENVIRONMENT.new()
var ballistics: RefCounted
var launch_position := Vector2.ZERO
var animation_time := 0.0
var sprite: Sprite2D
var impacted := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	ballistics = BALLISTICS.new()
	ballistics.launch(direction, compression_strength, environment)
	launch_position = global_position
	sprite = Sprite2D.new()
	sprite.texture = CHARGED_TEXTURE if attack_kind == "charged" else NORMAL_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = FLIGHT_FRAMES
	sprite.flip_h = direction.x < 0.0
	# Align the molecular core with the collision center, leaving vapor behind it.
	sprite.position.x = (7.0 if attack_kind == "charged" else 5.0) * (-1.0 if direction.x >= 0.0 else 1.0)
	add_child(sprite)
	if not ballistics.active:
		queue_free()

func _physics_process(delta: float) -> void:
	if impacted:
		return
	ballistics.advance(delta)
	var next_position: Vector2 = launch_position + ballistics.position_m * BALLISTICS.PIXELS_PER_METRE
	# Sweep the center segment so faster charged shots cannot skip thin walls.
	var excluded: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("player"):
		if player is CollisionObject2D:
			excluded.append(player.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(global_position, next_position, collision_mask, excluded)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if ballistics.active and not hit.is_empty() and _can_hit(hit.collider):
		global_position = hit.position
		_on_body_entered(hit.collider)
		return
	global_position = next_position
	animation_time += delta
	sprite.frame = int(animation_time * FLIGHT_FPS) % FLIGHT_FRAMES
	# Loss of cohesion dims the packet before it breaks into a spreading cloud.
	sprite.modulate.a = lerpf(0.3, 1.0, ballistics.energy_fraction())
	if not ballistics.active:
		_spawn_gas_cloud()
		queue_free()

func _can_hit(body: Node2D) -> bool:
	return body.has_method("take_oxygen_damage") or (body is StaticBody2D and not body.is_in_group("player"))

func _on_body_entered(body: Node2D) -> void:
	if impacted:
		return
	if not ballistics.active:
		return
	if body.has_method("take_oxygen_damage"):
		impacted = true
		# At close range the gas packet still delivers its calibrated muzzle
		# energy. Further shots lose damage as coherence and speed decay.
		var close_target: bool = body.is_in_group("oxygen_targets") and ballistics.distance_m < 3.0
		var impact_damage: float = damage if close_target else damage * ballistics.energy_fraction()
		body.take_oxygen_damage(impact_damage, attack_kind)
		_spawn_impact()
		queue_free()
	elif body is StaticBody2D and not body.is_in_group("player"):
		impacted = true
		_spawn_impact()
		queue_free()

func _spawn_impact() -> void:
	var effect := AnimatedSprite2D.new()
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.z_index = 2
	var is_charged := attack_kind == "charged"
	var cell_size := 64 if is_charged else 48
	var frame_count := 12 if is_charged else 10
	var atlas := CHARGED_IMPACT_TEXTURE if is_charged else IMPACT_TEXTURE
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", EXPLOSION_FPS)
	for frame in range(frame_count):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(frame * cell_size, 0, cell_size, cell_size)
		frames.add_frame("default", texture)
	effect.sprite_frames = frames
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.animation_finished.connect(effect.queue_free)
	effect.play()
	_spawn_gas_cloud()

func _spawn_gas_cloud() -> void:
	var cloud := Node2D.new()
	cloud.set_script(GAS_CLOUD)
	cloud.environment = environment
	cloud.gas_temperature_k = ballistics.gas_temperature_k
	cloud.concentration = minf(0.65, ballistics.coherence)
	cloud.velocity_mps = ballistics.velocity_mps * 0.04
	cloud.charged = attack_kind == "charged"
	get_parent().add_child(cloud)
	cloud.global_position = global_position
