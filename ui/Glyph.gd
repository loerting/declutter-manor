class_name Glyph
extends Control
## A small drawn sign beside a number or a word: it lets the number stand without the sentence round it. Always
## next to a label or a picture that says the same, never alone: almost no icon is understood on its own
## (Nielsen Norman Group, "Icon Usability"). Drawn, not typed: the HUD's font has none of these.
##
## As tall as the text of the label it sits beside, so it grows with the text.

enum Shape {
	## A set complete.
	TICK,
	## A carry slot, the same square as the carry bar's cells.
	SLOT,
	## Where an item belongs.
	HOUSE,
	## The set looked for.
	EYE,
	## A floor above or below.
	UP,
	DOWN,
}

@export var shape := Shape.TICK
## Repainted when it changes: a glyph that warns turns with the number beside it (`ItemCard`).
@export var color := Color(0.961, 0.937, 0.894, 1.0):
	set(value):
		color = value
		queue_redraw()
## The label size the glyph matches; 0 takes the theme's.
@export var font_size := 0

static func make(glyph_shape: Shape, glyph_color := Color(0.961, 0.937, 0.894, 1.0), size_of_text := 0) -> Glyph:
	var g := Glyph.new()
	g.shape = glyph_shape
	g.color = glyph_color
	g.font_size = size_of_text
	return g

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _get_minimum_size() -> Vector2:
	var side := _side()
	return Vector2(side, side)

func _side() -> float:
	var pixels := font_size if font_size > 0 else get_theme_font_size(&"font_size", &"Label")
	return roundf(pixels * 0.9)

func _draw() -> void:
	var s := _side()
	var w := maxf(1.5, s * 0.11)
	var c := Vector2(s, s) * 0.5 + (size - Vector2(s, s)) * 0.5
	var o := c - Vector2(s, s) * 0.5
	match shape:
		Shape.TICK:
			draw_polyline(PackedVector2Array([o + Vector2(0.14, 0.52) * s, o + Vector2(0.4, 0.78) * s,
					o + Vector2(0.88, 0.24) * s]), color, w * 1.3, true)
		Shape.SLOT:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(color, 0.0)
			box.border_color = color
			box.set_border_width_all(int(maxf(1.0, roundf(w))))
			box.set_corner_radius_all(int(s * 0.14))
			draw_style_box(box, Rect2(o + Vector2(0.12, 0.12) * s, Vector2(0.76, 0.76) * s))
		Shape.HOUSE:
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 0.08) * s, o + Vector2(0.94, 0.48) * s,
					o + Vector2(0.06, 0.48) * s]), color)
			draw_rect(Rect2(o + Vector2(0.2, 0.46) * s, Vector2(0.6, 0.44) * s), color)
			draw_rect(Rect2(o + Vector2(0.42, 0.62) * s, Vector2(0.16, 0.28) * s), Color(0.0, 0.0, 0.0, 0.55))
		Shape.EYE:
			var lid := PackedVector2Array()
			for k in range(17):
				var t := float(k) / 16.0
				lid.append(o + Vector2(0.06 + 0.88 * t, 0.5 - 0.3 * sin(t * PI)) * s)
			for k in range(1, 16):
				var t := 1.0 - float(k) / 16.0
				lid.append(o + Vector2(0.06 + 0.88 * t, 0.5 + 0.3 * sin(t * PI)) * s)
			lid.append(lid[0])
			draw_polyline(lid, color, w, true)
			draw_circle(c, s * 0.15, color, true, -1.0, true)
		Shape.UP, Shape.DOWN:
			var sign := -1.0 if shape == Shape.UP else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, 0.36 * sign) * s, c + Vector2(0.36, -0.08 * sign) * s,
					c + Vector2(-0.36, -0.08 * sign) * s]), color)
			# The shaft on the far side of the head's base from its tip.
			var shaft_top := 0.06 if shape == Shape.UP else -0.42
			draw_rect(Rect2(c + Vector2(-0.12, shaft_top) * s, Vector2(0.24, 0.36) * s), color)
