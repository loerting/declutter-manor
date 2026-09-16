class_name SetDots
extends Control
## A set's members as pips, in three states that differ in shape as well as colour: a filled disc is at
## home, a bright ring is in the player's hands, a faint small ring is still out in the house.

## The largest set has 15 members (`docs/CONTENT.md`), so one row always holds a set.
@export var pip := 9.0
@export var gap := 4.0
@export var home_color := Color(0.961, 0.937, 0.894)
@export var carried_color := Color(1.0, 0.945, 0.812)
@export var missing_color := Color(0.961, 0.937, 0.894, 0.38)

var _home := 0
var _carried := 0
var _total := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_progress(home: int, carried: int, total: int) -> void:
	_home = home
	_carried = carried
	_total = total
	update_minimum_size()
	queue_redraw()

func home() -> int:
	return _home

func carried() -> int:
	return _carried

func _get_minimum_size() -> Vector2:
	return Vector2(_total * pip + maxi(_total - 1, 0) * gap, pip)

func _draw() -> void:
	var r := pip * 0.5
	for i: int in _total:
		var centre := Vector2(r + i * (pip + gap), size.y * 0.5)
		if i < _home:
			draw_circle(centre, r, home_color)
		elif i < _home + _carried:
			draw_circle(centre, r + 1.5, Color(carried_color, 0.22))
			draw_arc(centre, r - 1.0, 0.0, TAU, 20, carried_color, 2.0, true)
		else:
			draw_arc(centre, r - 2.0, 0.0, TAU, 16, missing_color, 1.2, true)
