extends SceneTree

const ENVIRONMENT = preload("res://scripts/combat/ballistics/air_gun_environment.gd")
const BALLISTICS = preload("res://scripts/combat/ballistics/air_gun_ballistics.gd")
const OUTPUT := "res://assets/chemistry_bullets/oxygen_v2/air_gun_data.js"

func _initialize() -> void:
	var presets: Array = []
	for index in range(ENVIRONMENT.PRESETS.size()):
		var air := ENVIRONMENT.new()
		air.apply_preset(index)
		var shots: Array = []
		for level in range(6):
			var strength := 1.0 + level * 0.6
			var state := BALLISTICS.new()
			state.launch(Vector2.RIGHT, strength, air)
			var points: Array = []
			while state.active:
				points.append(_sample(state))
				state.advance(1.0 / 60.0)
			points.append(_sample(state))
			shots.append({"strength": strength, "speed": state.initial_speed_mps, "range": state.position_m.x, "duration": state.age, "points": points})
			if level == 0 or level == 5:
				print("%s / strength %.1f: %.2f m/s, %.2f m range, %.3f s, height %.2f cm" % [ENVIRONMENT.PRESETS[index].name, strength, state.initial_speed_mps, state.position_m.x, state.age, -state.position_m.y * 100.0])
		presets.append({"name": ENVIRONMENT.PRESETS[index].name, "density": air.air_density(), "temperature": air.temperature_k - 273.15, "gas_temperature": air.oxygen_temperature() - 273.15, "wind": air.wind_mps.x, "shots": shots})
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string("window.AIR_GUN_DATA = " + JSON.stringify({"presets": presets, "energy_cutoff": BALLISTICS.ENERGY_CUTOFF, "pixels_per_metre": BALLISTICS.PIXELS_PER_METRE}) + ";\n")
	quit()

func _sample(state: RefCounted) -> Array:
	return [snappedf(state.age, 0.0001), snappedf(state.position_m.x, 0.0001), snappedf(-state.position_m.y * 100.0, 0.001), snappedf(state.velocity_mps.length(), 0.001), snappedf(state.energy_fraction() * 100.0, 0.01), snappedf(state.gas_temperature_k - 273.15, 0.01)]
