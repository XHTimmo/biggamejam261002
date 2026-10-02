extends RefCounted

const PIXELS_PER_METRE := 48.0
var environment: Resource
var element := "iron"
var position_m := Vector2.ZERO
var velocity_mps := Vector2.ZERO
var initial_speed_mps := 0.0
var distance_m := 0.0
var age := 0.0
var active := true

func launch(direction: Vector2, strength: float, air: Resource) -> void:
	environment = air
	# Fixed launcher energy; carbon rounds are lighter than iron rounds.
	initial_speed_mps = (18.0 if element == "carbon" else 16.0) * sqrt(strength)
	velocity_mps = direction.normalized() * initial_speed_mps

func energy_fraction() -> float:
	return clampf(velocity_mps.length_squared() / maxf(0.001, initial_speed_mps * initial_speed_mps), 0, 1)

func advance(delta: float) -> void:
	var remaining := delta
	while remaining > 0.000001 and active:
		var step := minf(remaining, 1.0 / 120.0)
		var before := velocity_mps
		velocity_mps.y += 9.81 * step
		var relative: Vector2 = velocity_mps - environment.wind_mps
		var drag: float = (0.045 if element == "carbon" else 0.012) * environment.air_density() / 1.204
		velocity_mps = environment.wind_mps + relative / (1 + drag * relative.length() * step)
		var displacement := (before + velocity_mps) * (0.5 * step)
		position_m += displacement
		distance_m += displacement.length()
		age += step
		remaining -= step
		active = age < 3.0
