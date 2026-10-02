extends Node2D

const BALLISTICS = preload("res://air_gun_ballistics.gd")
const PALETTE = preload("res://assets/palette.gd")

var molar_mass_ratio := BALLISTICS.OXYGEN_TO_AIR_MOLAR_MASS
var tint := Color("#8aceda")
var environment: Resource
var gas_temperature_k := 293.15
var concentration := 0.4
var velocity_mps := Vector2.ZERO
var elapsed := 0.0
var duration := 1.0
var charged := false

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	gas_temperature_k = environment.temperature_k + (gas_temperature_k - environment.temperature_k) * exp(-2.0 * delta)
	concentration *= exp(-2.5 * delta)
	var ratio: float = 1.0 + concentration * (molar_mass_ratio * environment.temperature_k / gas_temperature_k - 1.0)
	velocity_mps.y += BALLISTICS.GRAVITY_MPS2 * (ratio - 1.0) / ratio * delta
	velocity_mps = environment.wind_mps + (velocity_mps - environment.wind_mps) * exp(-2.5 * delta)
	position += velocity_mps * BALLISTICS.PIXELS_PER_METRE * delta
	queue_redraw()

func _draw() -> void:
	var progress := elapsed / duration
	var radius := (14.0 if charged else 9.0) + progress * 13.0
	var color: Color = tint
	color.a = (1.0 - progress) * 0.65
	for particle in range(8):
		var angle := float(particle) * TAU / 8.0 + 0.2
		var center := (Vector2(cos(angle), sin(angle)) * radius).round()
		var size := 2.0 if progress < 0.65 else 1.0
		draw_rect(Rect2(center - Vector2.ONE * size, Vector2.ONE * size * 2.0), color)
