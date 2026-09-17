class_name Hud
extends CanvasLayer
## Everything the player is told, and when (the HUD plan of 2026-09-16):
##
## - the room they stand in and how much misplaced clutter it still holds, on a strip of tape;
## - what a click would do, under the crosshair;
## - the item the crosshair is on: its picture, what it costs to carry, the room and piece it belongs on, and how much
##   of its set is home (`ItemCard`);
## - how full their hands are, and which carried item is selected (`CarryBar`);
## - sets complete, slots, items put away, and the sets under way as pips (the tracker);
## - held `show_tracker`: every set and every room, in place of the tracker;
## - the way to where the carried items belong: a compass marker per home room, and a pin on a home in view
##   (`Compass`, `HomePins`, from `WayHome`).
##
## Never which item is misplaced, never where it lies (`docs/VISION.md`, "Findability"). Nothing here
## decides anything: it is told (`Interactor.aim_changed`, `EventBus`, `ClutterCensus`, `WayHome`).

## Player-facing text states the mechanical fact and nothing else (`CLAUDE.md`, "No AI-slop copy").
const PROMPTS: Dictionary = {
	Interactor.Prompt.NONE: "",
	Interactor.Prompt.TAKE: "hud.take",
	Interactor.Prompt.OPEN: "hud.open",
	Interactor.Prompt.CLOSE: "hud.close",
	Interactor.Prompt.PLACE: "hud.put_away",
	Interactor.Prompt.NO_SLOT: "hud.no_slot",
}
## The prompts a click on an item gives; the item card shows only for these.
const ITEM_PROMPTS: Array[Interactor.Prompt] = [Interactor.Prompt.TAKE, Interactor.Prompt.NO_SLOT]

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_key_cap: Control = %PromptKeyCap
@onready var _prompt_key: Label = %PromptKey
@onready var _prompt_text: Label = %PromptText
@onready var _card: ItemCard = %Card
@onready var _carry_bar: CarryBar = %CarryBar
@onready var _room_name: Label = %RoomName
@onready var _room_count: Label = %RoomCount
@onready var _room_tag: Control = %RoomTag
@onready var _tracker: Control = %Tracker
@onready var _sets_done: Label = %SetsDone
@onready var _sets_of: Label = %SetsOf
@onready var _slots: Label = %Slots
@onready var _slots_word: Label = %SlotsWord
@onready var _put_away: Label = %PutAway
@onready var _meter: ProgressBar = %Meter
@onready var _active: VBoxContainer = %Active
@onready var _hint_key: Label = %HintKey
@onready var _hint_text: Label = %HintText
@onready var _overview: Control = %Overview
@onready var _sets_title: Label = %SetsTitle
@onready var _sets: GridContainer = %Sets
@onready var _rooms_title: Label = %RoomsTitle
@onready var _rooms: GridContainer = %Rooms
@onready var _notice: Control = %Notice
@onready var _notice_text: Label = %NoticeText
@onready var _compass: Compass = %Compass
@onready var _pins: HomePins = %Pins

## Every overview row is this wide and a name that does not fit ends in an ellipsis, so fifty-five sets
## and every room of the house fit the overview's four columns (`dev/HudProbe.gd`).
@export var row_width := 250.0
## The tracker shows at most this many sets under way, the last one to change first.
@export var active_rows := 6
## A completed set stays in its place in the overview, so the list never reshuffles, and steps back.
@export var complete_alpha := 0.45

var _content: Catalogue
var _plan: FloorPlan
## The item pictures, once whoever owns them hands them over (`show_pictures`).
var _portraits: Portraits
## set id -> its overview row: the name, then the count.
var _set_rows: Dictionary = {}
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
var _camera: Camera3D

func _ready() -> void:
	_crosshair.draw.connect(_draw_crosshair)
	EventBus.carried_changed.connect(_on_carried_changed)
	EventBus.carried_selected.connect(_on_carried_selected)
	EventBus.item_picked_up.connect(_on_item_moved)
	EventBus.item_returned.connect(_on_item_moved)
	_sets_title.text = tr("hud.sets")
	_rooms_title.text = tr("hud.rooms")
	_hint_key.text = InputNames.of(&"show_tracker")
	_hint_text.text = tr("hud.overview_hint")
	EventBus.zone_entered.connect(_on_zone_entered)
	_room_tag.visible = false
	_show_aim(Interactor.Prompt.NONE, null)
	_on_carried_changed(Inventory.used(), Inventory.capacity)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action(&"show_tracker") and not event.is_echo():
		show_overview(event.is_pressed())

## Every set and every room in place of the tracker, or the tracker back. The compass steps aside for it.
func show_overview(on: bool) -> void:
	_overview.visible = on
	_tracker.visible = not on
	_show_compass()

func _process(_delta: float) -> void:
	if _way != null:
		_show_way()

## Connected by whoever owns both, so the HUD never reaches for the player (rule 4).
func watch(interactor: Interactor) -> void:
	interactor.aim_changed.connect(_show_aim)
	_show_aim(interactor.prompt(), interactor.target())

## The sets come from the content and the rooms from the plan; the counts come from `SetTracker` and the
## census. Connected by whoever owns all of them, for the same reason as `watch`.
func track(content: Catalogue, plan: FloorPlan, census: ClutterCensus) -> void:
	_content = content
	_plan = plan
	for s: SetDef in content.sets:
		_set_rows[s.id] = _row(_sets, tr(s.name_key))
		_show_set(s.id)
		if _is_under_way(s.id):
			_under_way.append(s.id)
	_show_tracker()
	EventBus.set_progressed.connect(_on_set_progressed)
	EventBus.set_completed.connect(_on_set_completed)
	census.counts_changed.connect(_on_counts_changed)
	_on_counts_changed(census.counts())

## The item card and the carry bar show pictures from `portraits`, and are redrawn once they are rendered.
func show_pictures(portraits: Portraits) -> void:
	_portraits = portraits
	portraits.rendered.connect(_on_pictures_rendered)
	_on_pictures_rendered()

## The compass and the pins show the way home `way` finds, seen from `camera`. Connected by whoever owns
## both, for the same reason as `watch`.
func guide(way: WayHome, camera: Camera3D) -> void:
	_way = way
	_camera = camera
	_show_way()

func _on_pictures_rendered() -> void:
	_show_load()
	_show_card()

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
	_prompt_key.text = InputNames.of(&"interact")
	# Nothing to press when there is no room for the item: the words say why.
	_prompt_key_cap.visible = key != "" and prompt != Interactor.Prompt.NO_SLOT
	_crosshair.queue_redraw()
	_show_card()

func _show_card() -> void:
	var shown := _target != null and _content != null and ITEM_PROMPTS.has(_prompt)
	_card.visible = shown
	if shown:
		_card.show_item(_target, _content, _plan, _carried_of(_target.set_id), _picture(_target))

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

func _carried_of(set_id: StringName) -> int:
	var n := 0
	for def: ItemDef in Inventory.carried():
		if def.set_id == set_id and set_id != &"":
			n += 1
	return n

# --- The tracker -----------------------------------------------------------------------------------

func _is_under_way(set_id: StringName) -> bool:
	return not SetTracker.is_complete(set_id) and (SetTracker.placed(set_id) > 0 or _carried_of(set_id) > 0)

## The set moves to the top of the sets under way, or leaves them.
func _touch(set_id: StringName) -> void:
	_under_way.erase(set_id)
	if _is_under_way(set_id):
		_under_way.push_front(set_id)

func _show_tracker() -> void:
	if _content == null:
		return
	var done := 0
	var members := 0
	for s: SetDef in _content.sets:
		members += SetTracker.total(s.id)
		if SetTracker.is_complete(s.id):
			done += 1
	_sets_done.text = NumberFormatter.count(done)
	_sets_of.text = tr("hud.sets_of") % NumberFormatter.count(_content.sets.size())
	_slots.text = NumberFormatter.count(Inventory.capacity)
	_slots_word.text = tr("hud.slot_word") if Inventory.capacity == 1 else tr("hud.slots_word")
	var home := SetTracker.home_count()
	_put_away.text = tr("hud.put_away_of") % NumberFormatter.of_total(home, members)
	_meter.max_value = maxi(members, 1)
	_meter.value = home
	for child: Node in _active.get_children():
		_active.remove_child(child)
		child.queue_free()
	for set_id: StringName in _under_way.slice(0, active_rows):
		_active.add_child(_set_line(set_id))

## One set under way: its name and count, and a pip per member under them.
func _set_line(set_id: StringName) -> VBoxContainer:
	var line := VBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 3)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = tr(_content.find_set(set_id).name_key)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var count := Label.new()
	count.theme_type_variation = &"Dim"
	count.text = NumberFormatter.of_total(SetTracker.placed(set_id), SetTracker.total(set_id))
	head.add_child(title)
	head.add_child(count)
	var dots := SetDots.new()
	dots.show_progress(SetTracker.placed(set_id), _carried_of(set_id), SetTracker.total(set_id))
	line.add_child(head)
	line.add_child(dots)
	return line

func _on_set_progressed(set_id: StringName, _placed: int, _total: int) -> void:
	if not _set_rows.has(set_id):
		return
	_show_set(set_id)
	_touch(set_id)
	_show_tracker()
	_show_card()

func _on_set_completed(set_id: StringName) -> void:
	var s := _content.find_set(set_id)
	if s == null:
		return
	_notice_text.text = tr("hud.set_completed") % [tr(s.name_key), NumberFormatter.slots(Balance.SLOTS_PER_COMPLETED_SET)]
	_notice.visible = true
	_show_compass()
	# A second set finishing inside the first one's notice gets its full time on screen.
	_notice_serial += 1
	var serial := _notice_serial
	await get_tree().create_timer(Balance.SET_NOTICE_SECONDS).timeout
	if serial == _notice_serial:
		_notice.visible = false
		_show_compass()

# --- The overview ----------------------------------------------------------------------------------

func _row(list: Container, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.x = row_width
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)
	row.add_child(count)
	list.add_child(row)
	return row

static func _count_of(row: HBoxContainer) -> Label:
	return row.get_child(1) as Label

func _show_set(set_id: StringName) -> void:
	var row: HBoxContainer = _set_rows[set_id]
	var complete := SetTracker.is_complete(set_id)
	_count_of(row).text = tr("hud.complete") if complete \
			else NumberFormatter.of_total(SetTracker.placed(set_id), SetTracker.total(set_id))
	row.modulate.a = complete_alpha if complete else 1.0

## Rooms in plan order, so the list does not reshuffle as counts change; a room with nothing misplaced
## left in it leaves the list.
func _on_counts_changed(counts: Dictionary) -> void:
	for child: Node in _rooms.get_children():
		_rooms.remove_child(child)
		child.queue_free()
	for room: RoomDef in _plan.all_rooms():
		if counts.has(room.id):
			_count_of(_row(_rooms, tr(room.name_key))).text = NumberFormatter.count(int(counts[room.id]))
	_rooms_title.visible = not counts.is_empty()
	_counts = counts
	_show_here()

# --- The way home ---------------------------------------------------------------------------------

## Redrawn every frame: the marks move as the head turns, not only when the way changes.
func _show_way() -> void:
	var eye := _camera.global_transform
	var marks: Array[Compass.Mark] = []
	for way: WayHome.Way in _way.ways():
		var mark := Compass.Mark.new()
		mark.bearing = Compass.bearing(eye, way.aim)
		mark.title = tr("hud.pair") % [tr(_plan.find_room(way.room).name_key),
				tr("hud.metres") % NumberFormatter.count(roundi(way.metres))]
		mark.floors = way.floors
		mark.picture = _picture(way.def)
		mark.metres = way.metres
		marks.append(mark)
	show_marks(marks)
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
		tag.text = tr("hud.pair") % [tr(pin.def.name_key), tr(_content.find_group(pin.group).name_key)]
		tags.append(tag)
	_pins.show_tags(tags)

## The compass shows these marks.
func show_marks(marks: Array[Compass.Mark]) -> void:
	_compass.show_marks(marks)
	_show_compass()

## The top of the screen holds one thing at a time: the compass steps aside for a notice and for the overview,
## and is not there while it has nothing to show.
func _show_compass() -> void:
	_compass.visible = _compass.shown_count() > 0 and not _overview.visible and not _notice.visible

# --- The room --------------------------------------------------------------------------------------

func _on_zone_entered(room_id: StringName) -> void:
	_room = room_id
	_show_here()

func _show_here() -> void:
	var room: RoomDef = null
	if _plan != null and _room != &"":
		room = _plan.find_room(_room)
	_room_tag.visible = room != null
	if room == null:
		return
	_room_name.text = tr(room.name_key)
	var left := int(_counts.get(_room, 0))
	_room_count.text = tr("hud.tidy") if left == 0 else tr("hud.misplaced_here") % NumberFormatter.count(left)
