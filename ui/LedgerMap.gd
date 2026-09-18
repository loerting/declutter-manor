class_name LedgerMap
extends Control
## One floor of the house as the ledger shows it: every room of the storey drawn from its `FloorPlan` polygon, so the
## map cannot disagree with the house. A room is shaded by how many misplaced items it still holds, and the legend
## says what each shade counts, so the shade is never a signal the player cannot read; a tidy room carries a tick, and
## the room under the pointer carries its figure. Its name is written where it fits, a ring marks where a carried item
## belongs, a dot marks where the player stands, and the selected room is outlined — its count stands beside its name
## on the other side of the ledger. While a set is looked for, a room holding its misplaced members gets an amber
## badge with how many. A room is clicked to select it (`room_clicked`).
##
## A storey is fitted into the building's footprint across every storey, grown by any of its own rooms outside it (the
## ground floor's garden), so the floors inside the building share one frame and a room above another is drawn over
## it, while no floor is shrunk by a garden it does not have. It draws what it is given and decides nothing (`Ledger`).

enum Shade { TIDY, FEW, SOME, MANY }
## What the legend explains: a shade, the ring, the dot and the badge.
enum Key { FEW, SOME, MANY, TIDY, HOME, HERE, SOUGHT }

signal room_clicked(room_id: StringName)

@export var margin := 10.0
@export var name_size := 15
@export var shade_colors: Array[Color] = [Color(0.961, 0.937, 0.894, 0.06), Color(0.95, 0.72, 0.42, 0.22),
		Color(0.95, 0.66, 0.36, 0.42), Color(0.95, 0.58, 0.3, 0.66)]
@export var ink := Color(0.961, 0.937, 0.894, 1.0)
@export var wall := Color(0.961, 0.937, 0.894, 0.55)
## Outdoors has no walls: its edge is drawn fainter.
@export var edge := Color(0.961, 0.937, 0.894, 0.2)
@export var selected_width := 3.0
@export var ring_radius := 15.0
@export var here_radius := 5.0
@export var badge_radius := 11.0
@export var hover := Color(0.961, 0.937, 0.894, 0.12)

var _storey: StoreyDef
var _counts: Dictionary = {}
var _selected: StringName = &""
var _homes: Dictionary[StringName, bool] = {}
var _here: StringName = &""
var _here_at := Vector2.ZERO
## Room id -> members of the set looked for lying in it.
var _sought: Dictionary = {}
var _hovered: StringName = &""
## The most misplaced items a room of the floor shown can hold and still be shaded `FEW`, and `SOME`. They are
## scaled to the busiest room of that floor: three fixed thresholds painted every room of a fresh house the same
## darkest shade, which is a map that says nothing when the player needs it most (2026-09-17). The legend says what
## band each shade stands for, so a scaled shade is still a shade the player can read.
var _few_max := 2
var _some_max := 5
## The building's extent across every storey, outdoor zones left out; and the shown storey's frame.
var _footprint := Rect2()
var _bounds := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

## The room under the pointer is taken from where the pointer is, every frame the map is up, rather than from the
## motion events a control is sent: a control is only sent motion while a button is held (Godot 4.7), so a room lit
## by a pressed button alone would be a room lit by dragging. It also follows a map redrawn under a still pointer.
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var at := get_local_mouse_position()
	_hover(room_under(at) if Rect2(Vector2.ZERO, size).has_point(at) else &"")

## The footprint every storey of `plan` is fitted into.
func frame(plan: FloorPlan) -> void:
	var first := true
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR:
			continue
		for p: Vector2 in room.polygon:
			_footprint = Rect2(p, Vector2.ZERO) if first else _footprint.expand(p)
			first = false
	queue_redraw()

## `counts`: room id -> misplaced items, rooms with none absent (`ClutterCensus`). `homes`: the rooms a carried item
## belongs in. `here_at` is where the player stands in `here`, in plan metres. `sought`: room id -> members of the set
## looked for lying there.
func show_floor(storey: StoreyDef, counts: Dictionary, selected: StringName, homes: Dictionary[StringName, bool],
		here: StringName, here_at: Vector2, sought: Dictionary = {}) -> void:
	_sought = sought
	_storey = storey
	_bounds = _footprint
	for room: RoomDef in storey.rooms:
		for p: Vector2 in room.polygon:
			_bounds = _bounds.expand(p)
	_counts = counts
	var most := 0
	for room: RoomDef in storey.rooms:
		most = maxi(most, int(counts.get(room.id, 0)))
	_few_max = maxi(1, ceili(most / 3.0))
	_some_max = maxi(_few_max + 1, ceili(most * 2.0 / 3.0))
	_selected = selected
	_homes = homes
	_here = here
	_here_at = here_at
	queue_redraw()

## The rooms ringed, for `dev/HudProbe.gd`.
func homes() -> Dictionary[StringName, bool]:
	return _homes.duplicate()

## The rooms badged for the set looked for, for `dev/HudProbe.gd`.
func sought() -> Dictionary:
	return _sought.duplicate()

## The room under the pointer, the one whose count is written, or none.
func hovered() -> StringName:
	return _hovered

## The room of the shown floor under a point in this control's space, or none.
func room_under(at: Vector2) -> StringName:
	# The last drawn is on top, as a porch is over the garden.
	var rooms := _rooms()
	for i in range(rooms.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(at, _polygon(rooms[i])):
			return rooms[i].id
	return &""

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var room := room_under(click.position)
		if room != &"":
			accept_event()
			room_clicked.emit(room)

func _hover(room_id: StringName) -> void:
	if room_id == _hovered:
		return
	_hovered = room_id
	mouse_default_cursor_shape = Control.CURSOR_ARROW if room_id == &"" else Control.CURSOR_POINTING_HAND
	queue_redraw()

## The player moved inside the same room.
func move_here(at: Vector2) -> void:
	_here_at = at
	queue_redraw()

## The bands of the floor shown, for the legend.
func few_max() -> int:
	return _few_max

func some_max() -> int:
	return _some_max

func shade_of(count: int) -> Shade:
	if count <= 0:
		return Shade.TIDY
	if count <= _few_max:
		return Shade.FEW
	return Shade.SOME if count <= _some_max else Shade.MANY

## Plan metres to this control's space.
func to_map(p: Vector2) -> Vector2:
	var scale := _scale()
	var inner := size - Vector2(margin, margin) * 2.0
	var offset := Vector2(margin, margin) + (inner - _bounds.size * scale) * 0.5
	return offset + (p - _bounds.position) * scale

## Every room drawn, by id, as its polygon in this control's space, in the order drawn; for `dev/HudProbe.gd`.
func drawn() -> Dictionary[StringName, PackedVector2Array]:
	var out: Dictionary[StringName, PackedVector2Array] = {}
	for room: RoomDef in _rooms():
		out[room.id] = _polygon(room)
	return out

## The rooms drawn: the shown storey's.
func _rooms() -> Array[RoomDef]:
	var out: Array[RoomDef] = []
	if _storey != null:
		out = _storey.rooms
	return out

func _scale() -> float:
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return 1.0
	var inner := size - Vector2(margin, margin) * 2.0
	return maxf(minf(inner.x / _bounds.size.x, inner.y / _bounds.size.y), 0.0)

func _polygon(room: RoomDef) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in room.polygon:
		out.append(to_map(p))
	return out

## Where a room's count goes: its middle, or the middle of its widest part when the middle is outside it.
func _label_at(room: RoomDef) -> Vector2:
	var box := Rect2(room.polygon[0], Vector2.ZERO)
	for p: Vector2 in room.polygon:
		box = box.expand(p)
	for candidate: Vector2 in [box.get_center(), room.centroid()]:
		if room.contains(candidate):
			return to_map(candidate)
	var triangles := Geometry2D.triangulate_polygon(room.polygon)
	var best := Vector2.ZERO
	var area := -1.0
	for t in range(0, triangles.size(), 3):
		var a := room.polygon[triangles[t]]
		var b := room.polygon[triangles[t + 1]]
		var c := room.polygon[triangles[t + 2]]
		var this_area := absf((b - a).cross(c - a))
		if this_area > area:
			area = this_area
			best = (a + b + c) / 3.0
	return to_map(best)

func _draw() -> void:
	if _storey == null:
		return
	var font := get_theme_font(&"font", &"Label")
	var bold := get_theme_font(&"font", &"Strong")
	var count_size := get_theme_font_size(&"font_size", &"Label")
	var outline := get_theme_color(&"font_outline_color", &"Label")
	for room: RoomDef in _rooms():
		var poly := _polygon(room)
		var count := int(_counts.get(room.id, 0))
		draw_colored_polygon(poly, shade_colors[shade_of(count)])
		if room.id == _hovered:
			draw_colored_polygon(poly, hover)
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, edge if room.zone == RoomDef.Zone.EXTERIOR else wall, 1.5, true)
	# Under the labels, so a count stays readable wherever the player stands.
	if _storey.room(_here) != null:
		var dot := to_map(_here_at)
		draw_circle(dot, here_radius + 2.0, outline)
		draw_circle(dot, here_radius, ink)
	for room: RoomDef in _rooms():
		var count := int(_counts.get(room.id, 0))
		var at := _label_at(room)
		var box := Rect2(_polygon(room)[0], Vector2.ZERO)
		for p: Vector2 in _polygon(room):
			box = box.expand(p)
		# A tidy room is ticked and the room pointed at carries its figure; every other room says how much it
		# holds by its shade, which the legend decodes. Thirteen rooms are thirteen numbers to read otherwise,
		# and the player only ever acts on one of them (the author, 2026-09-17).
		var marked := count <= 0 or room.id == _hovered
		var title := tr(room.name_key)
		var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var line := font.get_height(count_size)
		var room_for_title := box.size.y >= (line * 2.4 + ring_radius if marked else line * 1.2)
		if title_w + 8.0 <= box.size.x and room_for_title:
			var above := at.y - line * 0.5 - 4.0 if marked else at.y + font.get_ascent(name_size) * 0.5
			var title_at := Vector2(at.x - title_w * 0.5, above)
			draw_string_outline(font, title_at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 3, outline)
			draw_string(font, title_at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(ink, 0.8))
			if marked:
				at.y += line * 0.45
		if count <= 0:
			var s := 6.0
			draw_polyline(PackedVector2Array([at + Vector2(-s, 0.0), at + Vector2(-s * 0.3, s * 0.7),
					at + Vector2(s, -s * 0.8)]), ink, 2.0, true)
		elif room.id == _hovered:
			var text := NumberFormatter.count(count)
			var w := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size).x
			var base := Vector2(at.x - w * 0.5, at.y + bold.get_ascent(count_size) * 0.5 - 1.0)
			draw_string_outline(bold, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, 4, outline)
			draw_string(bold, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, ink)
		if _homes.has(room.id):
			draw_arc(at, ring_radius, 0.0, TAU, 32, ink, 2.0, true)
		var sought := int(_sought.get(room.id, 0))
		if sought > 0:
			var badge := at + Vector2(ring_radius + badge_radius * 0.6, -ring_radius * 0.8)
			draw_circle(badge, badge_radius + 1.5, outline)
			draw_circle(badge, badge_radius, Outline.COLORS[Outline.Kind.SOUGHT])
			var text := NumberFormatter.count(sought)
			var small := name_size
			var tw := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			draw_string(bold, badge + Vector2(-tw * 0.5, bold.get_ascent(small) * 0.5 - 1.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(0.1, 0.08, 0.05))
	var selected := _storey.room(_selected)
	if selected != null:
		var closed := _polygon(selected)
		closed.append(closed[0])
		draw_polyline(closed, ink, selected_width, true)

## A key for the legend, drawn the way the map draws it.
func swatch(key: Key) -> Control:
	var patch := Control.new()
	patch.custom_minimum_size = Vector2(18, 18)
	patch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.draw.connect(_draw_key.bind(patch, key))
	return patch

func _draw_key(patch: Control, key: Key) -> void:
	var r := Rect2(Vector2.ZERO, patch.size)
	if key == Key.HOME:
		patch.draw_arc(r.get_center(), r.size.y * 0.42, 0.0, TAU, 24, ink, 2.0, true)
		return
	if key == Key.HERE:
		patch.draw_circle(r.get_center(), here_radius, ink)
		return
	if key == Key.SOUGHT:
		patch.draw_circle(r.get_center(), r.size.y * 0.45, Outline.COLORS[Outline.Kind.SOUGHT])
		return
	var shade: Shade = {Key.FEW: Shade.FEW, Key.SOME: Shade.SOME, Key.MANY: Shade.MANY, Key.TIDY: Shade.TIDY}[key]
	patch.draw_rect(r, shade_colors[shade])
	patch.draw_rect(r, wall, false, 1.0)
