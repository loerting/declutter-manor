class_name HomePins
extends Control
## A pin on every home of a carried item that is in view, through the walls: a dot where the next item goes, and above
## it a disc with the picture of what goes there (`WayHome.Pin`). The outline says which piece; the picture says
## which item, without a word. It draws where it is told (`Hud.guide`), already on screen.

## One pin: the point on screen and the picture of the item that goes there, or null while there is none.
class Tag:
	extends RefCounted
	var at: Vector2
	var picture: Texture2D

@export var stem := 22.0
@export var dot := 4.0
@export var disc := 40.0
@export var ring := 2.5
@export var fill_color := Color(0.13, 0.114, 0.098, 0.9)
@export var ink := Color(0.961, 0.937, 0.894, 1.0)

var _tags: Array[Tag] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func show_tags(tags: Array[Tag]) -> void:
	_tags = tags.duplicate()
	queue_redraw()

func tags() -> Array[Tag]:
	return _tags

func _draw() -> void:
	for tag: Tag in _tags:
		# Kept on screen: a home at the edge of the view still shows what goes there.
		var centre := (tag.at - Vector2(0.0, stem + disc * 0.5)).clamp(Vector2.ONE * disc * 0.5, size - Vector2.ONE * disc * 0.5)
		draw_line(tag.at, centre + Vector2(0.0, disc * 0.5), ink, 1.5, true)
		draw_circle(tag.at, dot, ink, true, -1.0, true)
		draw_circle(centre, disc * 0.5, fill_color, true, -1.0, true)
		if tag.picture != null:
			var inner := (disc * 0.5 - ring) * sqrt(2.0) * 0.98
			draw_texture_rect(tag.picture, Rect2(centre - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false)
		draw_circle(centre, disc * 0.5 - ring * 0.5, ink, false, ring, true)
