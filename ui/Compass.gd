class_name Compass
extends Control
## The way home, at the top of the screen: one marker per room a carried item belongs in, at the bearing of
## the next place on the way there (`WayHome`), with that item's picture, the room, how far it is on foot and
## how many floors up or down. Straight ahead is the middle; `band_degrees` either side is the band's edge,
## and a marker further round than that waits at the edge it is nearer.
##
## It draws what it is given and decides nothing (`Hud.guide`). Markers that would meet are moved apart,
## and a tick on the band keeps each one's true bearing; when they do not all fit, the nearest ones are shown.

## One marker: its bearing in radians, right of straight ahead positive; the room and distance; floors up
## (negative: down); the picture; and how far, which decides who is shown when not all fit.
class Mark:
	extends RefCounted
	var bearing: float
	var title: String
	var floors: int
	var picture: Texture2D
	var metres: float

@export var band_degrees := 90.0
@export var band_height := 30.0
@export var disc := 44.0
@export var ring := 2.5
## Between two markers side by side.
@export var gap := 20.0
## From the band down to a marker's disc.
@export var drop := 6.0
@export var label_gap := 4.0
@export var tick := 7.0
@export var fill_color := Color(0.13, 0.114, 0.098, 0.92)
@export var ink := Color(0.961, 0.937, 0.894, 1.0)
@export var faint := Color(0.961, 0.937, 0.894, 0.35)
## A tick on the band every this many degrees.
@export var tick_degrees := 15.0

@onready var _marks: Control = %Marks

## What is shown, nearest first, and where each marker's middle is, in this control's space.
var _shown: Array[Mark] = []
var _centres: Array[float] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_marks.draw.connect(_draw_marks)
	resized.connect(_layout)

func show_marks(marks: Array[Mark]) -> void:
	_shown = marks.duplicate()
	_shown.sort_custom(func(a: Mark, b: Mark) -> bool: return a.metres < b.metres)
	_layout()

## How far from the middle towards an edge a bearing is drawn: -1 at the left edge, 1 at the right.
func offset(bearing: float) -> float:
	return clampf(bearing / deg_to_rad(band_degrees), -1.0, 1.0)

## Radians right of straight ahead, seen from `eye` looking along its -Z, of a point, on the floor plan.
static func bearing(eye: Transform3D, at: Vector3) -> float:
	var to := Vector2(at.x - eye.origin.x, at.z - eye.origin.z)
	var ahead := Vector2(-eye.basis.z.x, -eye.basis.z.z)
	var right := Vector2(eye.basis.x.x, eye.basis.x.z)
	return atan2(to.dot(right.normalized()), to.dot(ahead.normalized()))

## Every shown marker's disc and text, in global coordinates, for `dev/HudProbe.gd`.
func marker_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(_shown.size()):
		var w := _width(_shown[i])
		out.append(Rect2(global_position + Vector2(_centres[i] - w * 0.5, band_height + drop),
				Vector2(w, disc + label_gap + _line() * 2.0)))
	return out

func shown_count() -> int:
	return _shown.size()

## The marks shown, left to right.
func shown() -> Array[Mark]:
	return _shown

func _layout() -> void:
	# The nearest first, while they fit side by side.
	var room := size.x
	var kept: Array[Mark] = []
	for mark: Mark in _shown:
		var w := _width(mark) + gap
		if w > room:
			break
		room -= w
		kept.append(mark)
	_shown = kept
	# Left to right, each at its bearing, then pushed apart and back inside.
	var order: Array[int] = []
	for i in range(_shown.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _shown[a].bearing < _shown[b].bearing)
	var sorted: Array[Mark] = []
	for i: int in order:
		sorted.append(_shown[i])
	_shown = sorted
	_centres.clear()
	for mark: Mark in _shown:
		var half := _width(mark) * 0.5
		_centres.append(clampf(size.x * 0.5 + offset(mark.bearing) * size.x * 0.5, half, size.x - half))
	for i in range(1, _shown.size()):
		_centres[i] = maxf(_centres[i], _centres[i - 1] + (_width(_shown[i - 1]) + _width(_shown[i])) * 0.5 + gap)
	for i in range(_shown.size() - 1, -1, -1):
		var limit := size.x - _width(_shown[i]) * 0.5
		if i < _shown.size() - 1:
			limit = minf(limit, _centres[i + 1] - (_width(_shown[i + 1]) + _width(_shown[i])) * 0.5 - gap)
		_centres[i] = minf(_centres[i], limit)
	_marks.queue_redraw()

func _font() -> Font:
	return get_theme_font(&"font", &"Label")

func _font_size() -> int:
	return get_theme_font_size(&"font_size", &"Label")

func _line() -> float:
	return _font().get_height(_font_size())

func _width(mark: Mark) -> float:
	var font := _font()
	var text := maxf(font.get_string_size(mark.title, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x,
			_floors_width(mark))
	return maxf(disc, text)

func _floors_text(mark: Mark) -> String:
	if mark.floors == 0:
		return ""
	var n := absi(mark.floors)
	return tr("hud.floor") % NumberFormatter.count(n) if n == 1 else tr("hud.floors") % NumberFormatter.count(n)

## The arrow is drawn, not typed: the HUD's font has no arrows.
func _floors_width(mark: Mark) -> float:
	var text := _floors_text(mark)
	if text == "":
		return 0.0
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x + _line() * 0.7

func _draw_marks() -> void:
	var font := _font()
	var font_size := _font_size()
	var outline_size := 4
	var outline := get_theme_color(&"font_outline_color", &"Label")
	# The band: a tick every `tick_degrees`, and the middle.
	var steps := int(band_degrees / tick_degrees)
	for k in range(-steps, steps + 1):
		var x := size.x * 0.5 + offset(deg_to_rad(k * tick_degrees)) * size.x * 0.5
		var h := band_height * (0.5 if k == 0 else 0.22)
		_marks.draw_line(Vector2(x, band_height * 0.5 - h * 0.5), Vector2(x, band_height * 0.5 + h * 0.5),
				ink if k == 0 else faint, 2.0 if k == 0 else 1.0, true)
	for i in range(_shown.size()):
		var mark := _shown[i]
		var true_x := size.x * 0.5 + offset(mark.bearing) * size.x * 0.5
		_marks.draw_colored_polygon(PackedVector2Array([Vector2(true_x - tick, band_height),
				Vector2(true_x + tick, band_height), Vector2(true_x, band_height - tick)]), ink)
		var centre := Vector2(_centres[i], band_height + drop + disc * 0.5)
		# A marker moved aside keeps a line to its bearing.
		if absf(centre.x - true_x) > ring:
			_marks.draw_line(Vector2(true_x, band_height), Vector2(centre.x, centre.y - disc * 0.5), faint, 1.5, true)
		_marks.draw_circle(centre, disc * 0.5, fill_color, true, -1.0, true)
		if mark.picture != null:
			var inner := (disc * 0.5 - ring) * sqrt(2.0) * 0.98
			_marks.draw_texture_rect(mark.picture, Rect2(centre - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false)
		_marks.draw_circle(centre, disc * 0.5 - ring * 0.5, ink, false, ring, true)
		var y := centre.y + disc * 0.5 + label_gap + font.get_ascent(font_size)
		var title_w := font.get_string_size(mark.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2(_centres[i] - title_w * 0.5, y)
		_marks.draw_string_outline(font, at, mark.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline)
		_marks.draw_string(font, at, mark.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		var floors := _floors_text(mark)
		if floors == "":
			continue
		y += _line()
		var w := _floors_width(mark)
		var arrow := _line() * 0.45
		var left := _centres[i] - w * 0.5
		var mid := y - font.get_ascent(font_size) * 0.4
		var up := mark.floors > 0
		_marks.draw_colored_polygon(PackedVector2Array([
				Vector2(left, mid + (arrow * 0.45 if up else -arrow * 0.45)),
				Vector2(left + arrow, mid + (arrow * 0.45 if up else -arrow * 0.45)),
				Vector2(left + arrow * 0.5, mid + (-arrow * 0.55 if up else arrow * 0.55))]), ink)
		var text_at := Vector2(left + _line() * 0.7, y)
		_marks.draw_string_outline(font, text_at, floors, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline)
		_marks.draw_string(font, text_at, floors, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
