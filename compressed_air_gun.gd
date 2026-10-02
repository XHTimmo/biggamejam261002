extends Node2D

const PALETTE = preload("res://assets/palette.gd")
var charge_ratio := 0.0

func _draw() -> void:
	# Pixel barrel, oxygen canister, grip and a visible compression gauge.
	draw_rect(Rect2(-9, -6, 10, 13), PALETTE.COLORS[1])
	draw_rect(Rect2(-7, -4, 6, 9), PALETTE.COLORS[15])
	draw_rect(Rect2(-6, -3, 3, 6), PALETTE.COLORS[17])
	draw_rect(Rect2(-1, -4, 18, 9), PALETTE.COLORS[1])
	draw_rect(Rect2(1, -3, 14, 6), PALETTE.COLORS[4])
	draw_rect(Rect2(3, -2, 7, 2), PALETTE.COLORS[17])
	draw_rect(Rect2(3, 4, 5, 7), PALETTE.COLORS[1])
	draw_rect(Rect2(4, 5, 3, 5), PALETTE.COLORS[20])
	draw_rect(Rect2(14, -3, 18, 6), PALETTE.COLORS[1])
	draw_rect(Rect2(15, -2, 15, 4), PALETTE.COLORS[5])
	draw_rect(Rect2(16, -2, 12, 1), PALETTE.COLORS[6])
	draw_rect(Rect2(29, -3, 3, 6), PALETTE.COLORS[15])
	draw_rect(Rect2(30, -1, 2, 2), PALETTE.COLORS[19])
	draw_rect(Rect2(1, -6, 12, 2), PALETTE.COLORS[1])
	draw_rect(Rect2(2, -5, 2 + roundi(charge_ratio * 9.0), 1), PALETTE.COLORS[22])
