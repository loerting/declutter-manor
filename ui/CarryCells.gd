class_name CarryCells
extends Control
## The player's hands as cells, one per slot. A carried item covers as many cells as it costs, in the
## order it was taken, with its picture on it, so what is using the room is visible at a glance; the selected one, the one
## `drop_item` lets go of, is outlined.
##
## The bar never grows past `max_width`. Once the slots stop fitting at `cell`, the cells narrow into
## proportional segments, and below `detail_width` the gaps close to a hairline — at the finale's 56
## slots the bar is a gauge, not a row of boxes.

@export var cell := 44.0
@export var gap := 5.0
@export var hairline := 2.0
@export var max_width := 620.0
@export var detail_width := 20.0
@export var empty_color := Color(0.961, 0.937, 0.894, 0.3)
@export var fill_color := Color(0.13, 0.114, 0.098, 0.92)
@export var edge_color := Color(0.961, 0.937, 0.894, 0.55)
@export var selected_color := Color(0.961, 0.937, 0.894, 1.0)
@export var corner := 5.0
## The slot cost printed in a cell's corner, once a cell is wide enough to hold it.
@export var cost_font_size := 13
## How far a picture stays inside its block's edge.
@export var picture_inset := 3.0

## Slot costs of the carried items, in the order they were taken.
var _costs: Array[int] = []
var _capacity := 1
## Which of them is outlined, or -1.
var _selected := -1
## Their pictures, null where there is none.
var _pictures: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func show_load(costs: Array[int], capacity: int, selected := -1, pictures: Array[Texture2D] = []) -> void:
	assert(pictures.is_empty() or pictures.size() == costs.size(), "CarryCells: one picture per carried item")
	_costs = costs.duplicate()
	_pictures = pictures.duplicate()
	_selected = selected
	_capacity = maxi(capacity, 1)
	update_minimum_size()
	queue_redraw()

## The width of one cell and of the gap after it, at this capacity.
func pitch() -> Vector2:
	var fitted := (max_width - gap * (_capacity - 1)) / _capacity
	if fitted >= cell:
		return Vector2(cell, gap)
	if fitted >= detail_width:
		return Vector2(fitted, gap)
	return Vector2((max_width - hairline * (_capacity - 1)) / _capacity, hairline)

## Each carried item's rectangle, in the order taken.
func blocks() -> Array[Rect2]:
	var p := pitch()
	var out: Array[Rect2] = []
	var at := 0
	for cost: int in _costs:
		out.append(Rect2(at * (p.x + p.y), 0.0, cost * p.x + (cost - 1) * p.y, cell))
		at += cost
	return out

## Where carried item `k`'s picture is drawn: a square in the middle of its block, or an empty rectangle
## when it has none or the block is too narrow to show one.
func picture_rect(k: int) -> Rect2:
	var r := blocks()[k]
	if k >= _pictures.size() or _pictures[k] == null or r.size.x < cell * 0.6:
		return Rect2()
	var side := minf(r.size.x, r.size.y) - picture_inset * 2.0
	return Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))

func _get_minimum_size() -> Vector2:
	var p := pitch()
	return Vector2(_capacity * p.x + (_capacity - 1) * p.y, cell)

func _draw() -> void:
	var p := pitch()
	var used := 0
	for cost: int in _costs:
		used += cost
	var radius := minf(corner, p.x * 0.3)
	for i: int in range(used, _capacity):
		_box(Rect2(i * (p.x + p.y), 0.0, p.x, cell), Color(0, 0, 0, 0), empty_color, radius, 1.0)
	var all := blocks()
	var font := get_theme_font(&"font", &"Label")
	for k: int in all.size():
		var r := all[k]
		_box(r, fill_color, edge_color, radius, 1.0)
		var picture := picture_rect(k)
		if picture.has_area():
			draw_texture_rect(_pictures[k], picture, false)
		# One cell is one slot without saying so; a number over a picture says it again.
		if r.size.x >= cell * 0.6 and (_costs[k] > 1 or not picture.has_area()):
			var text := NumberFormatter.count(_costs[k])
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_font_size).x
			draw_string(font, r.end - Vector2(w + 5.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_font_size, edge_color)
	if _selected >= 0 and _selected < all.size():
		_box(all[_selected].grow(3.0), Color(0, 0, 0, 0), selected_color, radius + 2.0, 2.0)

func _box(r: Rect2, fill: Color, edge: Color, radius: float, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, r)
