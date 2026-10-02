extends SceneTree

const ENVIRONMENT = preload("res://air_gun_environment.gd")
const BALLISTICS = preload("res://air_gun_ballistics.gd")
const PROJECTILE = preload("res://oxygen_projectile.gd")

class Target extends StaticBody2D:
	var hits: Array[float] = []
	func take_oxygen_damage(amount: float, _kind: String) -> void:
		hits.append(amount)

func _initialize() -> void:
	call_deferred("_verify")

func _simulate(preset: int, strength: float, step: float = 1.0 / 60.0) -> RefCounted:
	var air := ENVIRONMENT.new()
	air.apply_preset(preset)
	var state := BALLISTICS.new()
	state.launch(Vector2.RIGHT, strength, air)
	var previous_energy := 1.0
	while state.active:
		state.advance(step)
		if air.wind_mps == Vector2.ZERO:
			assert(state.energy_fraction() <= previous_energy + 0.0001, "Still-air impact energy must decay")
		previous_energy = state.energy_fraction()
	assert(state.age <= BALLISTICS.MAX_FLIGHT_SECONDS + 0.01)
	return state

func _verify() -> void:
	var normal := _simulate(0, 1.0)
	var charged := _simulate(0, 4.0)
	var thin := _simulate(1, 1.0)
	var dense := _simulate(2, 1.0)
	var hot := _simulate(3, 1.0)
	var headwind := _simulate(4, 1.0)
	assert(charged.initial_speed_mps > normal.initial_speed_mps)
	assert(charged.distance_m > normal.distance_m)
	assert(thin.initial_speed_mps > normal.initial_speed_mps and thin.distance_m > normal.distance_m)
	assert(dense.initial_speed_mps < normal.initial_speed_mps and dense.distance_m < normal.distance_m)
	assert(normal.position_m.y > 0.0 and hot.position_m.y < 0.0, "Cold packet sinks; hot packet initially rises")
	assert(headwind.distance_m < normal.distance_m)
	var low_fps := _simulate(0, 1.0, 1.0 / 30.0)
	var high_fps := _simulate(0, 1.0, 1.0 / 120.0)
	assert(absf(low_fps.distance_m - high_fps.distance_m) < 0.02, "Integration must be frame-rate stable")
	var air := ENVIRONMENT.new()
	var warm := BALLISTICS.new()
	air.apply_preset(3)
	warm.launch(Vector2.RIGHT, 1.0, air)
	assert(warm.buoyancy_acceleration() < 0.0)
	warm.advance(0.55)
	assert(warm.buoyancy_acceleration() > 0.0, "Hot oxygen can sink after cooling")
	air.pressure_pa = 0.0
	var vacuum := BALLISTICS.new()
	vacuum.launch(Vector2.RIGHT, 1.0, air)
	assert(not vacuum.active, "Ambient-intake gun needs gas to collect")
	var world := Node2D.new()
	root.add_child(world)
	for facing in [1.0, -1.0]:
		var target := Target.new()
		target.position = Vector2(100.0 * facing, 0.0)
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(2, 60)
		shape_node.shape = shape
		target.add_child(shape_node)
		world.add_child(target)
		var projectile := Area2D.new()
		projectile.set_script(PROJECTILE)
		projectile.direction = Vector2(facing, 0)
		projectile.compression_strength = 4.0
		projectile.attack_kind = "charged"
		projectile.damage = 70.0
		world.add_child(projectile)
		await create_timer(0.12).timeout
		assert(target.hits.size() == 1, "Fast packet must hit a 2 px wall exactly once")
		assert(target.hits[0] > 0.0 and target.hits[0] < 70.0, "Range must reduce impact damage")
		assert(not is_instance_valid(projectile))
		target.queue_free()
		await create_timer(1.15).timeout
		assert(world.get_child_count() == 0, "Explosion and gas cloud must clean up")
	var stray := Area2D.new()
	stray.set_script(PROJECTILE)
	world.add_child(stray)
	await create_timer(0.7).timeout
	assert(not is_instance_valid(stray), "Exhausted shot must dissipate")
	for child in world.get_children():
		assert(not child is AnimatedSprite2D, "Free dissipation must not trigger hit explosion")
	await create_timer(1.15).timeout
	assert(world.get_child_count() == 0)
	print("PASS: compression, density, wind, buoyancy reversal, range/energy, timestep stability, swept collision, dissipation and cleanup")
	quit()
