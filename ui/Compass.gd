class_name Compass
extends Control
## The way home, at the top of the screen: one marker, for the item in hand, at the bearing of the next place on
## the way to its home room (`WayHome`), with that item's picture, how far it is on foot, the room and the floor
## it is on, with an arrow up or down. Straight ahead is the middle; `band_degrees` either side is the band's edge,
## and a marker further round than that waits at the edge it is nearer.
##
## It draws what it is given and decides nothing (`Hud.guide`). The picture stands straight under its bearing, and
## the words under it keep inside the band. One marker, not one per carried item: several crowded each other off
## their bearings (the author, 2026-09-18).

## One marker: its bearing in radians, right of straight ahead positive; the room's name and how far it is;
## floors up (negative: down) and the name of the floor the room is on; and the picture.
class Mark:
	extends RefCounted
	var bearing: float
	var title: String
	var distance: String
	var floors: int
	var floor_name: String
	var picture: Texture2D

@export var band_degrees := 90.0
@export var band_height := 30.0
@export var disc := 44.0
@export var ring := 2.5
## From the band down to the marker's disc.
@export var drop := 6.0
@export var label_gap := 4.0
@export var tick := 7.0
@export var fill_color := Color(0.13, 0.114, 0.098, 0.92)
@export var ink := Color(0.961, 0.937, 0.894, 1.0)
@export var faint := Color(0.961, 0.937, 0.894, 0.35)
## A tick on the band every this many degrees.
@export var tick_degrees := 15.0

@onready var _marks: Control = %Marks

## What is shown, or null.
var _mark: Mark

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_marks.draw.connect(_draw_marks)
	resized.connect(_marks.queue_redraw)

## Shows `mark`, or nothing with null.
func show_mark(mark: Mark) -> void:
	_mark = mark
	_marks.queue_redraw()

func shown() -> Mark:
	return _mark

## How far from the middle towards an edge a bearing is drawn: -1 at the left edge, 1 at the right.
func offset(bearing: float) -> float:
	return clampf(bearing / deg_to_rad(band_degrees), -1.0, 1.0)

## Where on the band a mark's bearing is, in this control's space.
func true_x(mark: Mark) -> float:
	return size.x * 0.5 + offset(mark.bearing) * size.x * 0.5

## Radians right of straight ahead, seen from `eye` looking along its -Z, of a point, on the floor plan.
static func bearing(eye: Transform3D, at: Vector3) -> float:
	var to := Vector2(at.x - eye.origin.x, at.z - eye.origin.z)
	var ahead := Vector2(-eye.basis.z.x, -eye.basis.z.z)
	var right := Vector2(eye.basis.x.x, eye.basis.x.z)
	return atan2(to.dot(right.normalized()), to.dot(ahead.normalized()))

## The marker's picture, in global coordinates, for `dev/HudProbe.gd`.
func disc_rect() -> Rect2:
	return Rect2(global_position + Vector2(_disc_x() - disc * 0.5, band_height + drop), Vector2(disc, disc))

## Where the picture's middle is: under the bearing, and inside the band when the bearing is at its edge.
func _disc_x() -> float:
	return clampf(true_x(_mark), disc * 0.5, size.x - disc * 0.5)

## The distance, room and floor under the marker, in global coordinates, for `dev/HudProbe.gd`.
func words_rect() -> Rect2:
	var words := _words_span()
	return Rect2(global_position + Vector2(words.x, band_height + drop + disc + label_gap),
			Vector2(words.y - words.x, _line() * 3.0))

## The left and right of the words under the marker: under its picture, and inside the band.
func _words_span() -> Vector2:
	var w := maxf(_text_width(_mark.distance), maxf(_text_width(_mark.title),
			_arrowed_width(_mark.floors, _floors_text(_mark))))
	var left := clampf(_disc_x() - w * 0.5, 0.0, size.x - w)
	return Vector2(left, left + w)

func _font() -> Font:
	return get_theme_font(&"font", &"Label")

func _font_size() -> int:
	return get_theme_font_size(&"font_size", &"Label")

func _line() -> float:
	return _font().get_height(_font_size())

func _text_width(text: String) -> float:
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x

## The floor the room is on, beside an arrow up or down; nothing on the player's own floor. The floor's name, not how
## many floors away: "1 floor" with an arrow read as a count to climb, not a place (the author, 2026-09-17).
func _floors_text(mark: Mark) -> String:
	return "" if mark.floors == 0 else mark.floor_name

## `text` after the arrow that says a room `floors` away is up or down, when it is. The arrow is drawn, not typed:
## the HUD's font has no arrows.
func _arrowed_width(floors: int, text: String) -> float:
	if text == "":
		return 0.0
	var arrow := 0.0 if floors == 0 else _line() * 0.7
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x + arrow

func _draw_marks() -> void:
	# The band: a tick every `tick_degrees`, and the middle.
	var steps := int(band_degrees / tick_degrees)
	for k in range(-steps, steps + 1):
		var x := size.x * 0.5 + offset(deg_to_rad(k * tick_degrees)) * size.x * 0.5
		var h := band_height * (0.5 if k == 0 else 0.22)
		_marks.draw_line(Vector2(x, band_height * 0.5 - h * 0.5), Vector2(x, band_height * 0.5 + h * 0.5),
				ink if k == 0 else faint, 2.0 if k == 0 else 1.0, true)
	if _mark == null:
		return
	# A dot on the band, not an arrow: an arrow pointing up read as "one floor up" (the author, 2026-09-17).
	_marks.draw_circle(Vector2(true_x(_mark), band_height), tick * 0.6, ink, true, -1.0, true)
	var centre := Vector2(_disc_x(), band_height + drop + disc * 0.5)
	_marks.draw_circle(centre, disc * 0.5, fill_color, true, -1.0, true)
	if _mark.picture != null:
		var inner := (disc * 0.5 - ring) * sqrt(2.0) * 0.98
		_marks.draw_texture_rect(_mark.picture, Rect2(centre - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false)
	_marks.draw_circle(centre, disc * 0.5 - ring * 0.5, ink, false, ring, true)
	var words := _words_span()
	var mid := (words.x + words.y) * 0.5
	var y := centre.y + disc * 0.5 + label_gap + _font().get_ascent(_font_size())
	_draw_arrowed(0, _mark.distance, mid, y)
	_draw_arrowed(0, _mark.title, mid, y + _line())
	_draw_arrowed(_mark.floors, _floors_text(_mark), mid, y + _line() * 2.0)

## `text` centred on `mid` with its baseline at `y`, after the arrow that says a room `floors` away is up or down.
func _draw_arrowed(floors: int, text: String, mid: float, y: float) -> void:
	if text == "":
		return
	var font := _font()
	var font_size := _font_size()
	var outline_size := 4
	var outline := get_theme_color(&"font_outline_color", &"Label")
	var left := mid - _arrowed_width(floors, text) * 0.5
	if floors != 0:
		var arrow := _line() * 0.45
		var at := y - font.get_ascent(font_size) * 0.4
		var up := floors > 0
		_marks.draw_colored_polygon(PackedVector2Array([
				Vector2(left, at + (arrow * 0.45 if up else -arrow * 0.45)),
				Vector2(left + arrow, at + (arrow * 0.45 if up else -arrow * 0.45)),
				Vector2(left + arrow * 0.5, at + (-arrow * 0.55 if up else arrow * 0.55))]), ink)
		left += _line() * 0.7
	var text_at := Vector2(left, y)
	_marks.draw_string_outline(font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline)
	_marks.draw_string(font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
