extends Resource

const AIR_GAS_CONSTANT := 287.05
const STANDARD_PRESSURE := 101325.0
const STANDARD_TEMPERATURE := 293.15
const REFERENCE_DENSITY := STANDARD_PRESSURE / (AIR_GAS_CONSTANT * STANDARD_TEMPERATURE)
const PRESETS := [
	{"name": "海平面 · 20°C", "pressure": 101325.0, "temperature": 293.15, "gas_offset": -8.0, "wind": 0.0},
	{"name": "高海拔 · 稀薄空气", "pressure": 75000.0, "temperature": 293.15, "gas_offset": -8.0, "wind": 0.0},
	{"name": "冷空气 · −10°C", "pressure": 101325.0, "temperature": 263.15, "gas_offset": -8.0, "wind": 0.0},
	{"name": "热氧弹 · 90°C", "pressure": 101325.0, "temperature": 293.15, "gas_offset": 70.0, "wind": 0.0},
	{"name": "向左气流 · 4m/s", "pressure": 101325.0, "temperature": 293.15, "gas_offset": -8.0, "wind": -4.0}
]

@export var pressure_pa := STANDARD_PRESSURE
@export var temperature_k := STANDARD_TEMPERATURE
@export var wind_mps := Vector2.ZERO
@export var oxygen_temperature_offset_k := -8.0

func air_density() -> float:
	return maxf(0.0, pressure_pa) / (AIR_GAS_CONSTANT * maxf(180.0, temperature_k))

func oxygen_temperature() -> float:
	return maxf(180.0, temperature_k + oxygen_temperature_offset_k)

func apply_preset(index: int) -> void:
	var preset: Dictionary = PRESETS[clampi(index, 0, PRESETS.size() - 1)]
	pressure_pa = preset.pressure
	temperature_k = preset.temperature
	oxygen_temperature_offset_k = preset.gas_offset
	wind_mps = Vector2(preset.wind, 0.0)
