class_name Hud
extends CanvasLayer
## Everything the player is told, and when (the HUD plan of 2026-09-16), read at a glance: an item or a set is shown
## by its picture, progress by pips and "3/12", and words are kept for what a picture cannot say (the author,
## 2026-09-17: "way too text based"; `docs/ARCHITECTURE.md`, "Reading the HUD"):
##
## - the room they stand in and how much misplaced clutter it still holds, on a strip of tape;
## - what a click would do, under the crosshair;
## - the item the crosshair is on: its picture, what it costs to carry, the room and piece it belongs on, and how much
##   of its set is home (`ItemCard`);
## - how full their hands are, and which carried item is selected (`CarryBar`);
## - sets complete, slots, the set looked for, and the sets under way as pictures with pips (the tracker);
## - `show_tracker` pressed: the ledger, a map of the house and the sets by the room they belong in (`Ledger`), where
##   a set is picked to be looked for;
## - the way to where the carried items belong: a compass marker to the home room of the one in hand, and a pin on
##   every home in view, through the walls (`Compass`, `HomePins`, from `WayHome`).
##
## Never which item is misplaced, never where it lies, unless the player picks its set to look for (`docs/VISION.md`,
## "Findability"). Nothing here decides anything: it is told (`Interactor.aim_changed`, `EventBus`, `ClutterCensus`,
## `WayHome`).

## Player-facing text states the mechanical fact and nothing else (`CLAUDE.md`, "No AI-slop copy"). A refusal says
## which fact refused: too little room left, more slots than the player owns, or an item already sorted.
const PROMPTS: Dictionary = {
	Interactor.Prompt.NONE: "",
	Interactor.Prompt.TAKE: "hud.take",
	Interactor.Prompt.OPEN: "hud.open",
	Interactor.Prompt.CLOSE: "hud.close",
	Interactor.Prompt.PLACE: "hud.put_away",
	Interactor.Prompt.HANDS_FULL: "hud.hands_full",
	Interactor.Prompt.TOO_BIG: "hud.too_big",
	Interactor.Prompt.AT_HOME: "hud.already_put_away",
}
## The prompts a click on an item gives; the item card shows only for these.
const ITEM_PROMPTS: Array[Interactor.Prompt] = [Interactor.Prompt.TAKE, Interactor.Prompt.HANDS_FULL,
		Interactor.Prompt.TOO_BIG, Interactor.Prompt.AT_HOME]
## The prompts a press acts on: the others say why nothing would happen, and carry no key.
const ACTION_PROMPTS: Array[Interactor.Prompt] = [Interactor.Prompt.TAKE, Interactor.Prompt.OPEN,
		Interactor.Prompt.CLOSE, Interactor.Prompt.PLACE]

## The ledger opened or closed: whoever owns the player holds it still meanwhile (`PlayerController.hold_still`).
signal ledger_toggled(open: bool)

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_line: Control = %Prompt
@onready var _prompt_key_cap: Control = %PromptKeyCap
@onready var _prompt_key: Label = %PromptKey
@onready var _prompt_text: Label = %PromptText
@onready var _card: ItemCard = %Card
@onready var _carry_bar: CarryBar = %CarryBar
@onready var _room_name: Label = %RoomName
@onready var _room_count: Label = %RoomCount
@onready var _room_tidy: Glyph = %RoomTidy
@onready var _room_tag: Control = %RoomTag
@onready var _tracker: Control = %Tracker
@onready var _sets_done: Label = %SetsDone
@onready var _slots: Label = %Slots
@onready var _sought: Control = %Sought
@onready var _sought_picture: TextureRect = %SoughtPicture
@onready var _sought_text: Label = %SoughtText
@onready var _active: VBoxContainer = %Active
@onready var _hint_key: Label = %HintKey
@onready var _hint_text: Label = %HintText
@onready var _ledger: Ledger = %Ledger
@onready var _notice: Control = %Notice
@onready var _notice_text: Label = %NoticeText
@onready var _notice_picture: TextureRect = %NoticePicture
@onready var _compass: Compass = %Compass
@onready var _pins: HomePins = %Pins

## The tracker shows at most this many sets under way, the last one to change first.
@export var active_rows := 6
## A set's picture in the tracker's rows.
@export var row_picture := 36.0

var _content: Catalogue
var _plan: FloorPlan
## The item pictures, once whoever owns them hands them over (`show_pictures`).
var _portraits: Portraits
## Sets with some but not all members home or in hand, the last one to change first.
var _under_way: Array[StringName] = []
## The room the player last stood in, and the census's latest counts.
var _room: StringName = &""
var _counts: Dictionary = {}
var _notice_serial := 0
var _prompt: Interactor.Prompt = Interactor.Prompt.NONE
var _target: ItemDef
## The way home and the eye it is seen from, once whoever owns them hands them over (`guide`).
var _way: WayHome
## Home room -> the direction in the house its compass mark points, eased towards the aim (`_show_way`).
var _headings: Dictionary[StringName, float] = {}
var _camera: Camera3D
## The set looked for (`WayHome.tracked_changed`), or none.
var _tracked: StringName = &""

func _ready() -> void:
	_crosshair.draw.connect(_draw_crosshair)
	EventBus.carried_changed.connect(_on_carried_changed)
	EventBus.carried_selected.connect(_on_carried_selected)
	EventBus.item_picked_up.connect(_on_item_moved)
	EventBus.item_returned.connect(_on_item_moved)
	_hint_key.text = InputNames.of(&"show_tracker")
	_hint_text.text = tr("hud.ledger_hint")
	EventBus.zone_entered.connect(_on_zone_entered)
	_room_tag.visible = false
	_show_aim(Interactor.Prompt.NONE, null)
	_on_carried_changed(Inventory.used(), Inventory.capacity)

## One press opens the ledger and the next closes it (the author, 2026-09-17: holding it was a chore).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"show_tracker") and not event.is_echo():
		get_viewport().set_input_as_handled()
		show_ledger(not _ledger.visible)

## While the ledger is up, the keys that pick a carried item pick a filter and a room instead: it is before the
## player's own input, so the hands do not change under it. The pad's shoulders pick the filter, so they are asked
## first; the wheel shares their actions and picks the room. The floor is stepped by the keys the player already
## walks with — the arrows and W/S as well as the page keys (`project.godot`, `ledger_floor_up`).
func _input(event: InputEvent) -> void:
	if not _ledger.visible or event.is_echo():
		return
	# Before the GUI: a focused tile would take Tab to move the focus, and Escape is the player's way out.
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"show_tracker"):
		get_viewport().set_input_as_handled()
		show_ledger(false)
		return
	# Left and right walk the tiles; the first press gives the keyboard to the first tile. Up and down are the
	# floor, wherever the focus is (the author, 2026-09-17), so they are never spent on moving it.
	if get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed(&"ui_right")
			or event.is_action_pressed(&"ui_left")):
		get_viewport().set_input_as_handled()
		_ledger.focus_first()
		return
	for k: int in Ledger.Filter.size():
		if event.is_action_pressed(StringName("select_%d" % (k + 1))):
			get_viewport().set_input_as_handled()
			_ledger.show_filter(k as Ledger.Filter)
			return
	var filter := 0
	if event.is_action_pressed(&"ledger_filter_next"):
		filter = 1
	elif event.is_action_pressed(&"ledger_filter_previous"):
		filter = -1
	if filter != 0:
		get_viewport().set_input_as_handled()
		_ledger.step_filter(filter)
		return
	var room := 0
	if event.is_action_pressed(&"select_next") or event.is_action_pressed(&"ledger_room_next"):
		room = 1
	elif event.is_action_pressed(&"select_previous") or event.is_action_pressed(&"ledger_room_previous"):
		room = -1
	var storey := 0
	if event.is_action_pressed(&"ledger_floor_up"):
		storey = 1
	elif event.is_action_pressed(&"ledger_floor_down"):
		storey = -1
	if room == 0 and storey == 0:
		return
	get_viewport().set_input_as_handled()
	if room != 0:
		_ledger.step_room(room)
	else:
		_ledger.step_floor(storey)

## The ledger in place of the tracker and the room tag, on the room the player stands in, or both back. The compass
## steps aside for it; the crosshair, its prompt, the item card and the pins go, rather than blur under its glass.
func show_ledger(on: bool) -> void:
	if on == _ledger.visible:
		return
	if on:
		_show_position()
		_ledger.open()
	else:
		_ledger.close()
	_tracker.visible = not on
	_crosshair.visible = not on
	_prompt_line.visible = not on
	_pins.visible = not on
	_show_card()
	_show_here()
	_show_compass()
	ledger_toggled.emit(on)

func ledger() -> Ledger:
	return _ledger

func _process(delta: float) -> void:
	if _way != null:
		_show_way(delta)
	if _ledger.visible:
		_show_position()

## Connected by whoever owns both, so the HUD never reaches for the player (rule 4).
func watch(interactor: Interactor) -> void:
	interactor.aim_changed.connect(_show_aim)
	_show_aim(interactor.prompt(), interactor.target())

## The sets come from the content and the rooms from the plan; the counts come from `SetTracker` and the
## census. Connected by whoever owns all of them, for the same reason as `watch`.
func track(content: Catalogue, plan: FloorPlan, census: ClutterCensus) -> void:
	_content = content
	_plan = plan
	_ledger.track(content, plan, census)
	_ledger.set_picked.connect(_on_set_picked)
	for s: SetDef in content.sets:
		if SetProgress.is_under_way(s.id):
			_under_way.append(s.id)
	_show_tracker()
	EventBus.set_progressed.connect(_on_set_progressed)
	EventBus.set_completed.connect(_on_set_completed)
	census.counts_changed.connect(_on_counts_changed)
	_on_counts_changed(census.counts())

## The item card and the carry bar show pictures from `portraits`, and are redrawn once they are rendered.
func show_pictures(portraits: Portraits) -> void:
	_portraits = portraits
	_ledger.show_pictures(portraits)
	portraits.rendered.connect(_on_pictures_rendered)
	_on_pictures_rendered()

## The compass and the pins show the way home `way` finds, seen from `camera`. Connected by whoever owns
## both, for the same reason as `watch`.
func guide(way: WayHome, camera: Camera3D) -> void:
	_way = way
	_camera = camera
	way.tracked_changed.connect(show_tracked)
	_show_way(0.0)

## A set picked in the ledger is looked for, or no longer if it already was.
func _on_set_picked(set_id: StringName) -> void:
	if _way != null:
		_way.track(set_id)

## The set looked for, in the tracker's top row and on its tile in the ledger; `&""` for none.
func show_tracked(set_id: StringName) -> void:
	_tracked = set_id
	_ledger.show_tracked(set_id)
	_show_tracker()

## The set looked for, or none.
func tracked() -> StringName:
	return _tracked

func _on_pictures_rendered() -> void:
	_show_load()
	_show_card()
	# The tracker's rows are pictures and pips. A row built before its picture was rendered stayed a row of pips
	# with nothing to name it (seen in a render, 2026-09-17).
	_show_tracker()
	_ledger.refresh()

func _picture(def: ItemDef) -> Texture2D:
	return null if _portraits == null else _portraits.of(def)

# --- The crosshair and the item card ---------------------------------------------------------------

## What a click would do and the item it would do it to, if it is one.
func _show_aim(prompt: Interactor.Prompt, target: ItemDef) -> void:
	_prompt = prompt
	_target = target
	var key: String = PROMPTS.get(prompt, "")
	_prompt_text.text = "" if key == "" else tr(key)
	# Pointing at a group may have selected another item than the one in hand a moment ago: the prompt names it.
	var selected := Inventory.selected()
	if prompt == Interactor.Prompt.PLACE and selected >= 0:
		_prompt_text.text = tr("hud.pair") % [tr(key), tr(Inventory.carried()[selected].name_key)]
	# A refusal carries the numbers that explain it: what the item costs, and what the hands hold at all.
	if target != null and prompt == Interactor.Prompt.HANDS_FULL:
		_prompt_text.text = tr(key) % NumberFormatter.slots(target.slot_cost)
	elif target != null and prompt == Interactor.Prompt.TOO_BIG:
		_prompt_text.text = tr(key) % [NumberFormatter.slots(target.slot_cost),
				NumberFormatter.slots(Inventory.capacity)]
	_prompt_key.text = InputNames.of(&"interact")
	# Nothing to press when the click would do nothing: the words say why instead.
	_prompt_key_cap.visible = ACTION_PROMPTS.has(prompt)
	_crosshair.queue_redraw()
	_show_card()

func _show_card() -> void:
	var shown := _target != null and _content != null and ITEM_PROMPTS.has(_prompt) and not _ledger.visible
	_card.visible = shown
	if shown:
		_card.show_item(_target, _content, _plan, SetProgress.carried(_target.set_id), _picture(_target))

## A dot, not a reticle: this is a game about looking at things, and a shooter's cross reads as a weapon.
## It brightens when the crosshair is on something a click would act on.
func _draw_crosshair() -> void:
	var centre := _crosshair.size * 0.5
	var lit := _prompt_text.text != ""
	_crosshair.draw_circle(centre, 4.5, Color(0, 0, 0, 0.35))
	_crosshair.draw_circle(centre, 3.0, Color(1, 1, 1, 0.95 if lit else 0.55))

# --- Hands -----------------------------------------------------------------------------------------

func _on_carried_changed(_used: int, _capacity: int) -> void:
	_show_load()
	_show_tracker()
	_show_card()
	_ledger.refresh()

func _on_carried_selected(_index: int) -> void:
	_show_load()
	_show_aim(_prompt, _target)

func _show_load() -> void:
	var carried := Inventory.carried()
	var pictures: Array[Texture2D] = []
	for def: ItemDef in carried:
		pictures.append(_picture(def))
	_carry_bar.show_load(carried, Inventory.capacity, Inventory.selected(), pictures)

## Taking a member in hand, or putting it back, is the set changing as far as the player is concerned.
func _on_item_moved(item_id: StringName) -> void:
	if _content == null:
		return
	var def := _content.find_item(item_id)
	if def != null and def.set_id != &"":
		_touch(def.set_id)
		_show_tracker()
		_ledger.refresh()

# --- The tracker -----------------------------------------------------------------------------------

## The set moves to the top of the sets under way, or leaves them.
func _touch(set_id: StringName) -> void:
	_under_way.erase(set_id)
	if SetProgress.is_under_way(set_id):
		_under_way.push_front(set_id)

func _show_tracker() -> void:
	if _content == null:
		return
	_sets_done.text = NumberFormatter.fraction(SetProgress.complete_count(_content), _content.sets.size())
	_slots.text = NumberFormatter.count(Inventory.capacity)
	var sought := tracked()
	_sought.visible = sought != &""
	if sought != &"":
		_sought_picture.texture = _picture(_content.members(sought)[0])
		_sought_text.text = tr("hud.to_find") % NumberFormatter.count(SetProgress.out_in_house(sought))
	for child: Node in _active.get_children():
		_active.remove_child(child)
		child.queue_free()
	for set_id: StringName in _under_way.filter(func(id: StringName) -> bool: return id != sought).slice(0, active_rows):
		_active.add_child(_set_line(set_id))

## One set under way: a member's picture and a pip per member, filled for the ones at home. The picture names the
## set and the pips count it; the ledger and the item card say its name and its figures (the author, 2026-09-17:
## a number beside a picture of the same thing is a number to read for nothing).
func _set_line(set_id: StringName) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 10)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(row_picture, row_picture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = _picture(_content.members(set_id)[0])
	line.add_child(picture)
	var dots := SetDots.new()
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.show_progress(SetTracker.placed(set_id), SetProgress.carried(set_id), SetTracker.total(set_id))
	line.add_child(dots)
	return line

## The sets in the tracker's rows, top to bottom.
func tracker_sets() -> Array[StringName]:
	var out: Array[StringName] = []
	var sought := tracked()
	for set_id: StringName in _under_way.filter(func(id: StringName) -> bool: return id != sought).slice(0, active_rows):
		out.append(set_id)
	return out

func _on_set_progressed(set_id: StringName, _placed: int, _total: int) -> void:
	if _content == null or _content.find_set(set_id) == null:
		return
	_touch(set_id)
	_show_tracker()
	_show_card()
	_ledger.refresh()

func _on_set_completed(set_id: StringName) -> void:
	var s := _content.find_set(set_id)
	if s == null:
		return
	_notice_text.text = tr("hud.set_completed") % [tr(s.name_key), NumberFormatter.slots(Balance.SLOTS_PER_COMPLETED_SET)]
	_notice_picture.texture = _picture(_content.members(set_id)[0])
	_notice.visible = true
	_show_compass()
	# A second set finishing inside the first one's notice gets its full time on screen.
	_notice_serial += 1
	var serial := _notice_serial
	await get_tree().create_timer(Balance.SET_NOTICE_SECONDS).timeout
	if serial == _notice_serial:
		_notice.visible = false
		_show_compass()

func _on_counts_changed(counts: Dictionary) -> void:
	_counts = counts
	_ledger.show_counts(counts)
	_show_here()

# --- The way home ---------------------------------------------------------------------------------

## Redrawn every frame: the marks move as the head turns, not only when the way changes. Where a mark points
## turns towards a new aim over `Balance.WAY_TURN_RATE` rather than in one frame; the head's own turning is never
## eased, because what is eased is the direction in the house and the bearing is taken from it every frame.
func _show_way(delta: float) -> void:
	var eye := _camera.global_transform
	var mark: Compass.Mark = null
	var headings: Dictionary[StringName, float] = {}
	var way := _way.way()
	if way != null:
		var heading := atan2(way.aim.x - eye.origin.x, way.aim.z - eye.origin.z)
		if _headings.has(way.room):
			heading = lerp_angle(_headings[way.room], heading, 1.0 - exp(-Balance.WAY_TURN_RATE * delta))
		headings[way.room] = heading
		mark = Compass.Mark.new()
		mark.bearing = Compass.bearing(eye, eye.origin + Vector3(sin(heading), 0.0, cos(heading)))
		mark.distance = tr("hud.metres") % NumberFormatter.count(roundi(way.metres))
		mark.title = tr(_plan.find_room(way.room).name_key)
		mark.floors = way.floors
		mark.floor_name = tr(way.storey.name_key)
		mark.picture = _picture(way.def)
	_headings = headings
	show_mark(mark)
	var tags: Array[HomePins.Tag] = []
	var view := _pins.get_viewport_rect()
	for pin: WayHome.Pin in _way.pins():
		if _camera.is_position_behind(pin.at):
			continue
		var at := _camera.unproject_position(pin.at)
		if not view.has_point(at):
			continue
		var tag := HomePins.Tag.new()
		tag.at = at
		tag.picture = _picture(pin.def)
		tags.append(tag)
	_pins.show_tags(tags)

## The compass shows this mark, or nothing with null.
func show_mark(mark: Compass.Mark) -> void:
	_compass.show_mark(mark)
	_show_compass()

## The top of the screen holds one thing at a time: the compass steps aside for a notice and for the ledger,
## and is not there while it has nothing to show.
func _show_compass() -> void:
	_compass.visible = _compass.shown() != null and not _ledger.visible and not _notice.visible

# --- The room --------------------------------------------------------------------------------------

func _on_zone_entered(room_id: StringName) -> void:
	_room = room_id
	_show_position()
	_show_here()

## Where the player stands, for the ledger's map: the eye, or the middle of the room before there is one.
func _show_position() -> void:
	if _plan == null or _room == &"":
		return
	var at := _plan.find_room(_room).centroid() if _camera == null \
			else Vector2(_camera.global_position.x, _camera.global_position.z)
	_ledger.show_here(_room, at)

func _show_here() -> void:
	var room: RoomDef = null
	if _plan != null and _room != &"":
		room = _plan.find_room(_room)
	_room_tag.visible = room != null and not _ledger.visible
	if room == null:
		return
	_room_name.text = tr(room.name_key)
	var left := int(_counts.get(_room, 0))
	_room_tidy.visible = left == 0
	_room_count.text = tr("hud.tidy") if left == 0 else tr("hud.misplaced") % NumberFormatter.count(left)
