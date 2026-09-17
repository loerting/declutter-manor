class_name HomePins
extends Control
## In the room a carried item belongs in, a pin on its home while the home is in view: a dot where the next
## item goes, and above it the item and the piece, "Mug · wall cupboard" (`WayHome.Pin`). It draws where it
## is told (`Hud.guide`), already on screen.

## One pin: the point on screen and what it says.
class Tag:
	extends RefCounted
	var at: Vector2
	var text: String

@export var stem := 26.0
@export var dot := 4.0
@export var padding := Vector2(9, 4)
@export var corner := 6.0
@export var fill_color := Color(0.13, 0.114, 0.098, 0.88)
@export var ink := Color(0.961, 0.937, 0.894, 1.0)

var _tags: Array[Tag] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_tags(tags: Array[Tag]) -> void:
	_tags = tags.duplicate()
	queue_redraw()

func tags() -> Array[Tag]:
	return _tags

func _draw() -> void:
	var font := get_theme_font(&"font", &"Label")
	var font_size := get_theme_font_size(&"font_size", &"Label")
	for tag: Tag in _tags:
		var text_size := font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Rect2(tag.at + Vector2(-text_size.x * 0.5 - padding.x, -stem - text_size.y - padding.y * 2.0),
				text_size + padding * 2.0)
		# Kept on screen: a home at the edge of the view still says what it is.
		box.position = box.position.clamp(Vector2.ZERO, size - box.size)
		draw_line(tag.at, Vector2(tag.at.x, box.end.y), ink, 1.5, true)
		draw_circle(tag.at, dot, ink, true, -1.0, true)
		var style := StyleBoxFlat.new()
		style.bg_color = fill_color
		style.set_corner_radius_all(int(corner))
		style.border_color = ink
		style.set_border_width_all(1)
		draw_style_box(style, box)
		draw_string(font, box.position + Vector2(padding.x, padding.y + font.get_ascent(font_size)), tag.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
