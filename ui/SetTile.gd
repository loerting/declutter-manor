class_name SetTile
extends PanelContainer
## One set in the ledger, read at a glance: a member's picture, the set's name, and a pip per member, filled for the
## ones at home. A tick in the corner once it is complete, an eye while it is looked for. The pips are the count, so
## the tile carries no figure of its own (the author, 2026-09-17: a wall of numbers is a wall). How many are still
## out, what a member costs and where it goes are the ledger's detail line, for the set pointed at.
##
## It can be pointed at (the mouse, or keyboard focus) and picked (a click, or the accept key), and says so; the
## ledger decides what picking does (`Ledger.set_picked`).

signal pointed(set_id: StringName)
signal picked(set_id: StringName)

@export var picture_size := 56.0
@export var tile_width := 168.0
## Small enough that a set of 15 fits the tile's width.
@export var pip := 7.0
@export var pip_gap := 3.0

var set_id: StringName = &""

var _sought := false
var _pointed := false

## A member's `picture` (or null while there is none), the set's `title`, how many are `home` and `carried` of
## `total`, and whether it is `complete` and `sought`.
func show_set(id: StringName, picture: Texture2D, title: String, home: int, carried: int, total: int, complete: bool,
		sought: bool) -> void:
	set_id = id
	_sought = sought
	custom_minimum_size = Vector2(tile_width, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 6)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(picture_size, picture_size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = picture
	top.add_child(image)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var signs := VBoxContainer.new()
	signs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if complete:
		signs.add_child(Glyph.make(Glyph.Shape.TICK))
	if sought:
		signs.add_child(Glyph.make(Glyph.Shape.EYE, Outline.COLORS[Outline.Kind.SOUGHT]))
	top.add_child(signs)
	rows.add_child(top)
	var name_label := Label.new()
	name_label.theme_type_variation = &"Strong"
	name_label.text = title
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rows.add_child(name_label)
	var progress := HBoxContainer.new()
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_constant_override(&"separation", 8)
	var dots := SetDots.new()
	dots.pip = pip
	dots.gap = pip_gap
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.show_progress(home, carried, total)
	progress.add_child(dots)
	rows.add_child(progress)
	add_child(rows)
	modulate.a = Ledger.COMPLETE_ALPHA if complete and not sought else 1.0
	mouse_entered.connect(_point.bind(true))
	mouse_exited.connect(_point.bind(false))
	focus_entered.connect(_point.bind(true))
	focus_exited.connect(_point.bind(false))
	_restyle()

## Pointed at from outside: a tile rebuilt under a resting pointer keeps its look.
func show_pointed(on: bool) -> void:
	_pointed = on
	_restyle()

func sought() -> bool:
	return _sought

func _point(on: bool) -> void:
	_pointed = on or has_focus()
	_restyle()
	if on:
		pointed.emit(set_id)

func _restyle() -> void:
	theme_type_variation = &"TileSought" if _sought else (&"TileHover" if _pointed else &"Tile")

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var accepted := event.is_action_pressed(&"ui_accept") and not event.is_echo()
	if accepted or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		picked.emit(set_id)
