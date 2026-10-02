extends RefCounted

# A calibrated gas-packet approximation, not a rigid pellet or a CFD solver.
const ENVIRONMENT = preload("res://scripts/combat/ballistics/air_gun_environment.gd")
const PIXELS_PER_METRE := 48.0
const GRAVITY_MPS2 := 9.81
const OXYGEN_TO_AIR_MOLAR_MASS := 31.998 / 28.965
const BASE_SPEED_MPS := 20.0
const DRAG_PER_METRE := 0.10
const MIXING_PER_SECOND := 0.65
const THERMAL_RELAXATION := 2.0
const ENERGY_CUTOFF := 0.12
const MAX_FLIGHT_SECONDS := 2.5
const STEP_SECONDS := 1.0 / 120.0

var molar_mass_ratio := OXYGEN_TO_AIR_MOLAR_MASS
var mixing_per_second := MIXING_PER_SECOND
var environment: Resource = ENVIRONMENT.new()
var compression_strength := 1.0
var position_m := Vector2.ZERO
var velocity_mps := Vector2.ZERO
var gas_temperature_k := 293.15
var initial_speed_mps := 0.0
var coherence := 1.0
var age := 0.0
var distance_m := 0.0
var active := true

func launch(shot_direction: Vector2, strength: float, air: Resource) -> void:
	environment = air
	compression_strength = clampf(strength, 1.0, 4.0)
	gas_temperature_k = environment.oxygen_temperature()
	# Fixed intake volume and stored-energy scale: denser gas has more mass.
	var relative_packet_density: float = environment.air_density() / ENVIRONMENT.REFERENCE_DENSITY * environment.temperature_k / gas_temperature_k * molar_mass_ratio / OXYGEN_TO_AIR_MOLAR_MASS
	initial_speed_mps = BASE_SPEED_MPS * sqrt(compression_strength / maxf(0.05, relative_packet_density))
	velocity_mps = shot_direction.normalized() * initial_speed_mps
	position_m = Vector2.ZERO
	age = 0.0
	distance_m = 0.0
	coherence = 1.0
	active = environment.air_density() >= ENVIRONMENT.REFERENCE_DENSITY * 0.05

func density_ratio() -> float:
	var pure_ratio: float = molar_mass_ratio * environment.temperature_k / gas_temperature_k
	return 1.0 + coherence * (pure_ratio - 1.0)

func buoyancy_acceleration() -> float:
	var ratio := density_ratio()
	# Godot Y points down; include displaced air instead of full pellet gravity.
	return GRAVITY_MPS2 * (ratio - 1.0) / maxf(0.2, ratio)

func energy_fraction() -> float:
	return clampf(coherence * velocity_mps.length_squared() / maxf(0.001, initial_speed_mps * initial_speed_mps), 0.0, 1.0)

func advance(delta: float) -> void:
	var remaining := maxf(0.0, delta)
	while remaining > 0.000001 and active:
		var step := minf(STEP_SECONDS, remaining)
		var before := velocity_mps
		gas_temperature_k = environment.temperature_k + (gas_temperature_k - environment.temperature_k) * exp(-THERMAL_RELAXATION * step)
		velocity_mps.y += buoyancy_acceleration() * step
		var relative: Vector2 = velocity_mps - environment.wind_mps
		var expansion := 1.0 + 0.25 * age
		var drag: float = DRAG_PER_METRE * environment.air_density() / ENVIRONMENT.REFERENCE_DENSITY * expansion * expansion / pow(compression_strength, 0.25)
		velocity_mps = environment.wind_mps + relative / (1.0 + drag * relative.length() * step)
		var displacement := (before + velocity_mps) * (0.5 * step)
		position_m += displacement
		distance_m += displacement.length()
		coherence *= exp(-mixing_per_second / sqrt(compression_strength) * step)
		age += step
		remaining -= step
		active = energy_fraction() > ENERGY_CUTOFF and coherence > 0.3 and age < MAX_FLIGHT_SECONDS
