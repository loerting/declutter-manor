class_name Ledger
extends PanelContainer
## `show_tracker` pressed: the ledger (decision D2 of the HUD plan, 2026-09-16). Along the top, sets complete and
## slots owned, each a fraction behind its sign, and the house put away as a bar. On the left, one floor of the house
## (`LedgerMap`), every room shaded by how much misplaced clutter it holds, and a tab per floor with that floor's
## count. On the right, the selected room and its count, then the sets a filter picks, grouped under the room they
## belong in and in content order, as tiles: a member's picture, the name, its pips (`SetTile`). Under them, the
## detail of the set pointed at: what a member costs, the piece it goes on, how many are still out, and what a click
## does. Clutter in a room and sets that belong in it are different questions, so each carries its own label.
##
## Each figure is written once, where the player acts on it (the author, 2026-09-17: "so much numbers everywhere,
## this is overwhelming"). A tile's pips are its count, a chip's list is its count, and a room's shade is how much it
## holds — the figure itself belongs to the one room, set or item pointed at.
##
## Everything in it is pointed at and clicked with the mouse as well as keyed: a floor's tab, a room on the map, a
## filter's chip, a set's tile (the author, 2026-09-17). Picking a set asks for it to be looked for (`set_picked`):
## its misplaced members are outlined wherever they lie (`WayHome.track`), and the map marks the rooms they lie in.
##
## It opens on the room the player stands in. `step_room` goes through the rooms of the house, floor by floor, and
## `step_floor` to the floor above or below (`Hud` calls both). Unless a set is looked for, never which item is
## misplaced, never where it lies: a room's count, as on the tape.

## A set was picked to be looked for, or to be looked for no longer.
signal set_picked(set_id: StringName)

## Which sets the list shows. `ROOM`: those that belong in the selected room; the rest across the house.
enum Filter { ROOM, ALL, UNDER_WAY, CARRYING, COMPLETE }
const FILTER_KEYS: Array[String] = ["hud.filter_room", "hud.filter_all", "hud.filter_under_way",
		"hud.filter_carrying", "hud.complete"]

## A completed set stays in its place and steps back.
const COMPLETE_ALPHA := 0.45

@onready var _sets_done: Label = %LedgerSetsDone
@onready var _slots: Label = %LedgerSlots
@onready var _put_away: Label = %LedgerPutAway
@onready var _meter: ProgressBar = %LedgerMeter
@onready var _floors: HBoxContainer = %Floors
@onready var _map: LedgerMap = %Map
@onready var _legend: HFlowContainer = %Legend
@onready var _room_name: Label = %LedgerRoomName
@onready var _room_clutter: Label = %LedgerRoomClutter
@onready var _filters: HFlowContainer = %Filters
@onready var _clip: Control = %CardClip
@onready var _cards: VBoxContainer = %Cards
@onready var _room_key_cap: Control = %RoomKeyCap
@onready var _room_key: Label = %RoomKey
@onready var _room_text: Label = %RoomText
@onready var _floor_up_cap: Control = %FloorUpCap
@onready var _floor_up: Label = %FloorUp
@onready var _floor_down_cap: Control = %FloorDownCap
@onready var _floor_down: Label = %FloorDown
@onready var _floor_text: Label = %FloorText
@onready var _detail: Control = %Detail
@onready var _detail_picture: TextureRect = %DetailPicture
@onready var _detail_name: Label = %DetailName
@onready var _detail_home: Label = %DetailHome
@onready var _detail_cost: Label = %DetailCost
@onready var _detail_dots: SetDots = %DetailDots
@onready var _detail_out: Label = %DetailOut
@onready var _detail_action: Control = %DetailAction
@onready var _detail_key: Label = %DetailKey
@onready var _detail_do: Label = %DetailDo

var _content: Catalogue
var _plan: FloorPlan
var _census: ClutterCensus
var _portraits: Portraits
## The set looked for, and the set the pointer or the keyboard is on, or none.
var _tracked: StringName = &""
var _pointed: StringName = &""
## Room id -> the sets that belong in it, in content order. A set's members share one home (`docs/CONTENT.md`).
var _sets_by_room: Dictionary[StringName, Array] = {}
var _counts: Dictionary = {}
var _here: StringName = &""
var _here_at := Vector2.ZERO
var _room: StringName = &""
## Kept between openings: the player picked it.
var _filter := Filter.ROOM
## What the list shows, top to bottom: the set on each card, the card, and each group's room with its heading.
var _card_sets: Array[StringName] = []
var _card_nodes: Array[SetTile] = []
var _heads: Dictionary[StringName, Control] = {}
var _floor_labels: Array[Label] = []
var _detail_shown: StringName = &""
var _filter_labels: Array[Label] = []

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put_away.text = tr("hud.put_away")
	_room_key.text = InputNames.of(&"select_next")
	_room_text.text = tr("hud.room")
	_floor_up.text = InputNames.of(&"ledger_floor_up")
	_floor_down.text = InputNames.of(&"ledger_floor_down")
	_floor_text.text = tr("hud.floor_step")
	_detail_key.text = InputNames.of(&"interact")
	_map.room_clicked.connect(_on_room_clicked)
	_room_key_cap.visible = _room_key.text != ""
	_floor_up_cap.visible = _floor_up.text != ""
	_floor_down_cap.visible = _floor_down.text != ""

## `census` says where the set looked for lies; without one the map marks nothing for it.
func track(content: Catalogue, plan: FloorPlan, census: ClutterCensus = null) -> void:
	_content = content
	_plan = plan
	_census = census
	_map.frame(plan)
	_sets_by_room.clear()
	for s: SetDef in content.sets:
		var members := content.members(s.id)
		if members.is_empty():
			continue
		var piece := content.piece_of(members[0].home)
		if piece == null:
			continue
		if not _sets_by_room.has(piece.room):
			_sets_by_room[piece.room] = []
		_sets_by_room[piece.room].append(s)
	_room = plan.all_rooms()[0].id

func show_pictures(portraits: Portraits) -> void:
	_portraits = portraits
	refresh()

## `counts`: room id -> misplaced items, rooms with none absent (`ClutterCensus`).
func show_counts(counts: Dictionary) -> void:
	_counts = counts
	refresh()

## The room the player stands in, and where in it, in plan metres.
func show_here(room_id: StringName, at: Vector2) -> void:
	var moved_room := room_id != _here
	_here = room_id
	_here_at = at
	if moved_room:
		refresh()
	elif visible:
		_map.move_here(at)

## Shown on the room the player stands in.
func open() -> void:
	if _plan != null and _here != &"":
		_room = _here
	visible = true
	refresh()

func close() -> void:
	visible = false

## The set looked for, shown on its tile, in the detail and on the map.
func show_tracked(set_id: StringName) -> void:
	_tracked = set_id
	refresh()

func tracked() -> StringName:
	return _tracked

## Asks for a set to be looked for, as a click on its tile does; a complete set has nothing left to look for.
func pick(set_id: StringName) -> void:
	if set_id != &"" and not SetTracker.is_complete(set_id):
		set_picked.emit(set_id)

## The set the detail line describes.
func detail_set() -> StringName:
	return _detail_shown

## The keyboard on the first tile, for a player who reaches for the arrows before the mouse.
func focus_first() -> void:
	if not _card_nodes.is_empty():
		_card_nodes[0].grab_focus()

func _on_room_clicked(room_id: StringName) -> void:
	_room = room_id
	refresh()

func _on_pointed(set_id: StringName) -> void:
	_pointed = set_id
	_show_detail()
func show_filter(filter: Filter) -> void:
	_filter = filter
	refresh()

## The next filter (`step` 1) or the one before (-1), round the end.
func step_filter(step: int) -> void:
	show_filter(posmod(_filter + step, Filter.size()) as Filter)

## The next room of the house (`step` 1) or the one before (-1), floor by floor, round the end. While the list
## spans the house, only the rooms it has a group for, so each step brings the next group up.
func step_room(step: int) -> void:
	var rooms := _plan.all_rooms()
	var at := 0
	for i in range(rooms.size()):
		if rooms[i].id == _room:
			at = i
	var listed := _listed_rooms()
	for k in range(1, rooms.size() + 1):
		var room := rooms[posmod(at + step * k, rooms.size())]
		if listed.is_empty() or listed.has(room.id):
			_room = room.id
			break
	refresh()

## The floor above (`step` 1) or below (-1), round the end: on the player's room if it is on it, else on its
## first room.
func step_floor(step: int) -> void:
	var storeys := _plan.storeys
	var at := storeys.find(_plan.storey_of(_room))
	for k in range(1, storeys.size() + 1):
		var storey := storeys[posmod(at + step * k, storeys.size())]
		if storey.rooms.is_empty():
			continue
		_room = _here if storey.room(_here) != null else storey.rooms[0].id
		break
	refresh()

func selected_room() -> StringName:
	return _room

func filter() -> Filter:
	return _filter

## The sets on the cards, top to bottom.
func card_sets() -> Array[StringName]:
	return _card_sets.duplicate()

func cards() -> Array[SetTile]:
	return _card_nodes.duplicate()

## The rooms the list has a group for, top to bottom, each with its heading.
func groups() -> Dictionary[StringName, Control]:
	return _heads.duplicate()

## Where the list is shown; what does not fit is cut off at its bottom.
func card_list() -> Control:
	return _clip

func map() -> LedgerMap:
	return _map

## The label on each floor's tab, top floor first.
func floor_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for label: Label in _floor_labels:
		out.append(label.text)
	return out

## The label on each filter's chip, in `Filter` order.
func filter_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for label: Label in _filter_labels:
		out.append(label.text)
	return out

## What the selected room holds: its misplaced count, or tidy.
func room_clutter() -> String:
	return _room_clutter.text

## Everything shown again, from what it was last told. Nothing to do while it is not up.
func refresh() -> void:
	if not visible or _content == null:
		return
	_show_totals()
	var storey := _plan.storey_of(_room)
	_show_floors(storey)
	var homes: Dictionary[StringName, bool] = {}
	for def: ItemDef in Inventory.carried():
		var piece := _content.piece_of(def.home)
		if piece != null:
			homes[piece.room] = true
	var sought: Dictionary = {}
	if _tracked != &"" and _census != null:
		sought = _census.rooms_of(_tracked)
	_map.show_floor(storey, _counts, _room, homes, _here, _here_at, sought)
	_show_legend()
	var room := _plan.find_room(_room)
	_room_name.text = tr(room.name_key)
	var left := int(_counts.get(_room, 0))
	_room_clutter.text = tr("hud.tidy") if left == 0 else tr("hud.misplaced") % NumberFormatter.count(left)
	_show_filters()
	_show_list()
	_show_detail()

## Two figures and a bar: the sets complete of all of them, the slots owned of the last piece's cost, and how much of
## the house is put away, which is a length rather than a third pair of numbers to read (the author, 2026-09-17).
## What each shade, the ring, the dot and the badge stand for. The shades' bands are the floor shown's, so it is
## rebuilt with the map rather than once.
func _show_legend() -> void:
	_clear(_legend)
	var keys: Array[Array] = [[LedgerMap.Key.FEW, tr("hud.range") % [NumberFormatter.count(1),
			NumberFormatter.count(_map.few_max())]],
			[LedgerMap.Key.SOME, tr("hud.range") % [NumberFormatter.count(_map.few_max() + 1),
			NumberFormatter.count(_map.some_max())]],
			[LedgerMap.Key.MANY, tr("hud.or_more") % NumberFormatter.count(_map.some_max() + 1)],
			[LedgerMap.Key.TIDY, tr("hud.tidy")], [LedgerMap.Key.HOME, tr("hud.carried_home")],
			[LedgerMap.Key.HERE, tr("hud.you_are_here")], [LedgerMap.Key.SOUGHT, tr("hud.sought_here")]]
	for entry: Array in keys:
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override(&"separation", 6)
		item.add_child(_map.swatch(entry[0]))
		var label := Label.new()
		label.theme_type_variation = &"Dim"
		label.text = entry[1]
		item.add_child(label)
		_legend.add_child(item)

func _show_totals() -> void:
	var members := SetProgress.member_count(_content)
	_sets_done.text = NumberFormatter.fraction(SetProgress.complete_count(_content), _content.sets.size())
	_slots.text = NumberFormatter.fraction(Inventory.capacity, Balance.FINALE_SLOT_COST)
	_meter.max_value = maxi(members, 1)
	_meter.value = SetTracker.home_count()

## A tab per floor, top floor first, each with its misplaced items; the shown floor's tab is lifted.
func _show_floors(shown: StoreyDef) -> void:
	_clear(_floors)
	_floor_labels.clear()
	for i in range(_plan.storeys.size() - 1, -1, -1):
		var storey := _plan.storeys[i]
		var left := 0
		for room: RoomDef in storey.rooms:
			left += int(_counts.get(room.id, 0))
		var label := _chip(_floors, storey == shown, "", _on_floor_clicked.bind(storey))
		label.text = tr("hud.pair") % [tr(storey.name_key), NumberFormatter.count(left)]
		_floor_labels.append(label)

## A chip per filter with the key that picks it; the one in use is lifted. What each one holds is the list under it,
## counted there rather than on five chips at once.
func _show_filters() -> void:
	_clear(_filters)
	_filter_labels.clear()
	for f: int in Filter.size():
		var label := _chip(_filters, f == _filter, InputNames.of(StringName("select_%d" % (f + 1))),
				show_filter.bind(f as Filter))
		label.text = tr(FILTER_KEYS[f])
		_filter_labels.append(label)

func _on_floor_clicked(storey: StoreyDef) -> void:
	if storey.rooms.is_empty():
		return
	_room = _here if storey.room(_here) != null else storey.rooms[0].id
	refresh()

## A lifted or plain chip in `row`, with a key cap when `key` names one, that calls `clicked` when clicked; its label
## is returned for the text.
func _chip(row: Container, lifted: bool, key: String, clicked: Callable) -> Label:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.gui_input.connect(_on_chip_input.bind(clicked))
	chip.theme_type_variation = &"ChipOn" if lifted else &"Chip"
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 6)
	if key != "":
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cap.theme_type_variation = &"Key"
		var key_label := Label.new()
		key_label.theme_type_variation = &"KeyLabel"
		key_label.text = key
		cap.add_child(key_label)
		line.add_child(cap)
	var label := Label.new()
	label.theme_type_variation = &"Strong" if lifted else &"Dim"
	line.add_child(label)
	chip.add_child(line)
	row.add_child(chip)
	return label

func _on_chip_input(event: InputEvent, clicked: Callable) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.call()

## The sets `filter` shows, in content order.
func _matching(filter: Filter) -> Array[SetDef]:
	var out: Array[SetDef] = []
	if filter == Filter.ROOM:
		out.assign(_sets_by_room.get(_room, []))
		return out
	for s: SetDef in _content.sets:
		if _passes(filter, s):
			out.append(s)
	return out

static func _passes(filter: Filter, s: SetDef) -> bool:
	match filter:
		Filter.UNDER_WAY:
			return SetProgress.is_under_way(s.id)
		Filter.CARRYING:
			return SetProgress.carried(s.id) > 0
		Filter.COMPLETE:
			return SetTracker.is_complete(s.id)
	return true

## The rooms a list that spans the house has a group for; none while it shows one room.
func _listed_rooms() -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	if _filter == Filter.ROOM:
		return out
	for room_id: StringName in _sets_by_room:
		for s: SetDef in _sets_by_room[room_id]:
			if _passes(_filter, s):
				out[room_id] = true
	return out

## A group per room in plan order, headed "Belongs in" the room, and under it the sets' tiles, as many to a row as fit.
## The heading counts nothing: the tiles under it are the count. While the list shows one room, that room has a group
## even with no sets. While it spans the house, it starts at the selected room's group, or the next one in the house,
## round the end, so stepping the room pages through it; what does not fit is cut off at the bottom.
func _show_list() -> void:
	var focused := get_viewport().gui_get_focus_owner() as SetTile
	var refocus: StringName = focused.set_id if focused != null else &""
	_clear(_cards)
	_card_sets.clear()
	_card_nodes.clear()
	_heads.clear()
	for room_id: StringName in _list_rooms():
		var room := _plan.find_room(room_id)
		var sets: Array = _sets_by_room.get(room_id, [])
		var shown: Array[SetDef] = []
		for s: SetDef in sets:
			if _filter == Filter.ROOM or _passes(_filter, s):
				shown.append(s)
		_heads[room_id] = _head(room, room_id == _room)
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override(&"h_separation", 8)
		flow.add_theme_constant_override(&"v_separation", 8)
		_cards.add_child(flow)
		for s: SetDef in shown:
			var tile := _tile(s)
			flow.add_child(tile)
			_card_sets.append(s.id)
			_card_nodes.append(tile)
			if s.id == refocus:
				tile.grab_focus.call_deferred()
			elif s.id == _pointed and focused == null:
				tile.show_pointed(true)
	_chain_focus()

## The keyboard walks the tiles left and right, in the order they are listed and round the end: a flow container's
## own neighbours stop at the end of a row, and up and down are the floor (`Hud._input`).
func _chain_focus() -> void:
	for i in range(_card_nodes.size()):
		var before := _card_nodes[posmod(i - 1, _card_nodes.size())].get_path()
		var after := _card_nodes[posmod(i + 1, _card_nodes.size())].get_path()
		_card_nodes[i].focus_neighbor_left = before
		_card_nodes[i].focus_previous = before
		_card_nodes[i].focus_neighbor_right = after
		_card_nodes[i].focus_next = after

## The rooms the list has a group for, top to bottom.
func _list_rooms() -> Array[StringName]:
	var out: Array[StringName] = []
	if _filter == Filter.ROOM:
		out.append(_room)
		return out
	var listed := _listed_rooms()
	var rooms := _plan.all_rooms()
	var at := rooms.find(_plan.find_room(_room))
	var start := -1
	for k in range(rooms.size()):
		if listed.has(rooms[posmod(at + k, rooms.size())].id):
			start = posmod(at + k, rooms.size())
			break
	if start < 0:
		return out
	for i in range(start, rooms.size()):
		if listed.has(rooms[i].id):
			out.append(rooms[i].id)
	return out

func _head(room: RoomDef, selected: bool) -> Control:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.theme_type_variation = &"Strong" if selected else &"Dim"
	title.text = tr("hud.belongs_in") % tr(room.name_key)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	_cards.add_child(head)
	return head

## One set's tile, pointed at and picked through the ledger.
func _tile(s: SetDef) -> SetTile:
	var first := _content.members(s.id)[0]
	var tile := SetTile.new()
	tile.show_set(s.id, null if _portraits == null else _portraits.of(first), tr(s.name_key), SetTracker.placed(s.id),
			SetProgress.carried(s.id), SetTracker.total(s.id), SetTracker.is_complete(s.id), s.id == _tracked)
	tile.pointed.connect(_on_pointed)
	tile.picked.connect(pick)
	return tile

## The set pointed at, or else the set looked for, or else the first one listed: its picture and name; what a
## member costs, the room and the piece it goes on; its pips, how many are still out, and what a click does: look for
## it, or stop. The pips say how many are home, so only the number the player acts on is written. Nothing while the
## list is empty.
func _show_detail() -> void:
	var set_id: StringName = &""
	for candidate: StringName in [_pointed, _tracked]:
		if set_id == &"" and _card_sets.has(candidate):
			set_id = candidate
	if set_id == &"" and not _card_sets.is_empty():
		set_id = _card_sets[0]
	_detail_shown = set_id
	_detail.modulate.a = 0.0 if set_id == &"" else 1.0
	if set_id == &"":
		return
	var members := _content.members(set_id)
	var first := members[0]
	_detail_picture.texture = null if _portraits == null else _portraits.of(first)
	_detail_name.text = tr(_content.find_set(set_id).name_key)
	_detail_home.text = HomeName.of(first.home, _content, _plan)
	var least := first.slot_cost
	var most := first.slot_cost
	for def: ItemDef in members:
		least = mini(least, def.slot_cost)
		most = maxi(most, def.slot_cost)
	# Beside the slot sign, the word "slots" would be the sign written out.
	var cost := NumberFormatter.count(least) if least == most \
			else tr("hud.range") % [NumberFormatter.count(least), NumberFormatter.count(most)]
	_detail_cost.text = tr("hud.each") % cost if members.size() > 1 else cost
	var done := SetTracker.is_complete(set_id)
	_detail_dots.show_progress(SetTracker.placed(set_id), SetProgress.carried(set_id), SetTracker.total(set_id))
	var out := SetProgress.out_in_house(set_id)
	_detail_out.text = tr("hud.bonus") % NumberFormatter.slots(Balance.SLOTS_PER_COMPLETED_SET) if done \
			else (tr("hud.to_find") % NumberFormatter.count(out) if out > 0 else "")
	_detail_action.visible = not done
	_detail_do.text = tr("hud.stop_looking") if set_id == _tracked else tr("hud.look_for")

static func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
