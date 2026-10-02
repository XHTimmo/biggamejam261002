extends StaticBody2D

const GROUND_TILE_TEXTURE = preload("res://assets/environment/tech_ground_tile.png")
const PLATFORM_TILE_TEXTURE = preload("res://assets/environment/tech_floating_platform_tile.png")

@export var size := Vector2(160, 24)
@export var tint := Color("#2e4953")

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size / 2, size)
	var tile_texture: Texture2D = PLATFORM_TILE_TEXTURE if size.y <= 28 else GROUND_TILE_TEXTURE
	draw_texture_rect(tile_texture, rect, true)
	if tint != Color("#2e4953"):
		var tint_overlay := tint
		tint_overlay.a = 0.22
		draw_rect(rect, tint_overlay)
	draw_line(rect.position, rect.position + Vector2(size.x, 0), Color("#9AF5E5"), 2)
	if size.y >= 20:
		for x in range(int(-size.x / 2) + 8, int(size.x / 2), 40):
			draw_rect(Rect2(x, -size.y / 2 + 7, 22, 2), Color("#2D9AA0"))
		draw_line(Vector2(-size.x / 2, size.y / 2), size / 2, Color("#142238"), 2)
