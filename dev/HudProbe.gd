extends Node
## The HUD at shipping volume: every set of `docs/CONTENT.md`, every room of the manor holding something,
## hands loaded, and an item under the crosshair — at every screen size the game supports (`docs/PACING.md`:
## 1080p and Steam Deck; 720p as the floor; 1440p above), and again with every string 40% longer, because
## German is. Headless, it checks the layout; with `--screenshot` it saves what one screen shows, over
## `--backdrop` if one is given.
##
##     godot --headless --path . dev/HudProbe.tscn
##     godot --path . dev/HudProbe.tscn -- --screenshot=/abs/out.png [--backdrop=/abs/game.png] [--ledger [--filter=<0-4>]]
##             [--track] [--long] [--size=1600x900]
##
##     hud.fits      the room tag, tracker, item card, carry bar, prompt, notice, compass and ledger end inside
##                   the screen
##     hud.clear     none of those meet each other, but the notice and the compass, which take turns at the top;
##                   the ledger meets neither the notice nor the carry bar
##     hud.short     the tracker holds `active_rows` sets under way, the last one changed first, and no
##                   complete set; a set looked for takes the row above them, with how many are still out, and
##                   leaves the rows below
##     hud.ledger    one press of the key shows the ledger on the player's room in place of the tracker and the room
##                   tag, hides the crosshair, prompt, item card and pins under it and asks for the player to be held
##                   still; the next press, or Escape, brings all back; the wheel steps the room and is handled before
##                   the player's input, and the floor steps on the arrows, on W/S and on the page keys, each pressed
##                   as a key; every floor's tab counts its misplaced items; the map rings the rooms a carried item
##                   belongs in
##     ledger.click  a click, sent through the screen like a mouse's, on a floor's tab shows that floor, on a room of
##                   the map selects it, on a filter's chip picks the filter, and on a set's tile asks for that set to
##                   be looked for; the map holds the room the pointer is over, which is the one room that carries its
##                   figure; pointing at a tile puts it in the detail line, which offers to look for it or to stop;
##                   the tile of the set looked for says so; a complete set is not asked for
##     ledger.map    on every floor, the map draws each room of that storey once, in the plan's order, from its
##                   polygon, at one scale that keeps its shape, inside the map; the building's footprint, grown by
##                   the floor's own outdoor zones, spans the map's width or height
##     ledger.sets   stepping through every room of the house shows, for each, the sets that belong in it in
##                   content order under one group for the room, and nothing else: all of them, each once; the
##                   room's misplaced count; every card inside the list without scrolling and clear of the others,
##                   the ledger inside the screen
##     ledger.filter a number key or the pad's shoulder picks a filter, handled before the player's input; each chip
##                   carries its name alone, and its list holds the sets grouped by home room, in plan and content
##                   order, under a heading that names the room and counts nothing; stepping the room goes from group
##                   to group and starts the list at its group; a complete set says its slot
##     hud.here      the room the player stands in is shown with its count
##     hud.card      the item under the crosshair shows its name, slot cost, home room and piece, and its
##                   set's progress; nothing when the prompt is not about an item
##     hud.prompt    a click that would do nothing says which fact refused it — the hands are too full for this item,
##                   the item is bigger than the hands are, or it is sorted already — in words of its own, with no key
##                   to press and the card still up
##     hud.readable  no label with text on screen is squeezed below the width of its text or, for one that may
##                   end in an ellipsis, below `SQUEEZE_FLOOR`: a label shrunk to nothing reads as missing
##     hud.bar       the carry bar counts slots used of capacity, draws one block per carried item covering
##                   its cost, outlines the selected one and names it, and never grows past its width;
##                   at the start of a run, one slot and one item, the item's name is not cut off and the tracker's
##                   head carries the two figures behind their signs; it shows the keys that drop and throw
##     hud.place     the prompt to put away names the selected item, and follows the selection
##     hud.compass   the way-home marker, ahead, to either side and behind, stays inside the compass with its
##                   words, and its picture stands under its bearing, or at the edge for one behind
##
## The window scales the HUD (`display/window/stretch`, canvas items, expand); a SubViewport does not, so
## each screen is laid out at the size the window would give it and rendered at its physical size.

const HUD := preload("res://ui/Hud.tscn")
const SCREENS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080),
		Vector2i(2560, 1440)]
const SHOT_SCREEN := Vector2i(1600, 900)
const SET_COUNT := Balance.TARGET_SET_COUNT
const MEMBERS := 12
## Sets under way in the probe: more than the tracker shows, so its cap is what is checked.
const UNDER_WAY := 9
## The sets of `docs/CONTENT.md`, in its order. Untranslated, so `tr` returns them as is.
const SET_NAMES: Array[String] = ["Board game", "Laundry basket", "Paint can", "Light bulb box",
	"Screwdriver", "Wrench", "Suitcase", "Holiday decoration box", "Sleeping bag", "Car keys",
	"Umbrella", "Winter coat", "Laptop", "Ring binder", "Television", "TV remote", "Game controller",
	"Sofa cushion", "Throw blanket", "Book", "Picture frame", "Dinner plate", "Spoon", "Mug",
	"Drinking glass", "Toaster", "Sneakers", "School backpack", "Dog leash", "Dog toy", "Hand towel",
	"Kids' bicycle", "Bike helmet", "Empty soda can", "Bath towel", "Bed pillow", "Phone charger",
	"Clothes hanger", "Dress shoes", "Perfume bottle", "Toy car", "Stuffed animal", "School book",
	"Dumbbell", "Rubber duck", "Toilet paper roll", "Shampoo bottle", "Photo album", "Garden gnome",
	"Grill tool", "Deck chair cushion", "Pool noodle", "Swim goggles", "Garden hose", "Watering can",
	"Table tennis equipment"]
## The most sets that belong in one room of the content, the living room's; the probe's first room gets as many.
const MOST_IN_ONE_ROOM := 7
## The longest home name of the content, on every probe home.
const HOME_NAME := "cupboard over the coffee maker"
## Way-home markers, one at a time: title, bearing in radians, floors, the floor's name, metres. Ahead, near the
## right edge, behind, and at the very edge of the band.
const COMPASS_MARKS: Array[Array] = [["Kitchen", 0.05, 0, "storey.ground", 4.0],
	["Master bedroom", 1.2, 1, "storey.upper", 23.0], ["Workshop", -2.6, -1, "storey.basement", 31.0],
	["Attic", -PI * 0.5, 2, "storey.attic", 40.0]]
## Slot costs of the load carried at the finale's capacity: the widest the bar gets.
const FULL_LOAD: Array[int] = [8, 8, 8, 8, 8, 4, 4, 2, 2, 1, 1]
## The narrowest a label that may end in an ellipsis can be and still say something.
const SQUEEZE_FLOOR := 48.0
## German runs about this much longer than English.
const LONGER := 0.4

var _violations := 0
## The interactor standing in for the player's, on the HUD being checked. Never in the tree: only its
## signal is used, and it is freed with the screen.
var _aim: Interactor

func _ready() -> void:
	assert(SET_NAMES.size() == SET_COUNT, "HudProbe: one name per set")
	var shot := ""
	var backdrop := ""
	var ledger := false
	var long := false
	var track := false
	var filter := Ledger.Filter.ROOM
	var shot_screen := SHOT_SCREEN
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--backdrop="):
			backdrop = arg.trim_prefix("--backdrop=")
		elif arg == "--ledger":
			ledger = true
		elif arg.begins_with("--filter="):
			filter = int(arg.trim_prefix("--filter=")) as Ledger.Filter
		elif arg == "--track":
			track = true
		elif arg == "--long":
			long = true
		elif arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			shot_screen = Vector2i(int(wh[0]), int(wh[1]))
	var plan := ManorPlan.build()
	var content := _content(plan)
	for longer: bool in [false, true]:
		_pseudo(longer)
		for screen: Vector2i in SCREENS:
			await _check(screen, content, plan, "long " if longer else "")
	_pseudo(long)
	if shot != "":
		await _shoot(shot, backdrop, ledger, filter, track, shot_screen, content, plan)
	print("HudProbe: %d violation(s)" % _violations)
	get_tree().quit(1 if _violations > 0 else 0)

## Every translated string 40% longer, with accents, in brackets: Godot's own pseudolocalization.
func _pseudo(on: bool) -> void:
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", LONGER if on else 0.0)
	TranslationServer.pseudolocalization_enabled = on
	TranslationServer.reload_pseudolocalization()

func _check(screen: Vector2i, content: Catalogue, plan: FloorPlan, pass_tag: String) -> void:
	var view := _screen(screen)
	var hud := await _hud(view, content, plan, Balance.FINALE_SLOT_COST, FULL_LOAD)
	var logical := view.size_2d_override
	var tag := "%s%dx%d" % [pass_tag, screen.x, screen.y]
	var whole := Rect2(Vector2.ZERO, Vector2(logical))

	var parts: Dictionary[String, Rect2] = {}
	# The notice is up, so the compass has stepped aside; it is laid out against the rest once the notice goes.
	var compass_shown := (hud.get_node("%Compass") as Control).is_visible_in_tree()
	for part: String in ["%RoomTag", "%Tracker", "%Card", "%CarryBar", "%Prompt", "%Notice", "%Compass"]:
		var control := hud.get_node(part) as Control
		if part == "%Notice" and control.is_visible_in_tree():
			parts[part] = control.get_global_rect()
			control.visible = false
			hud.show_mark(_mark(COMPASS_MARKS[1]))
		elif control.is_visible_in_tree():
			parts[part] = control.get_global_rect()
	(hud.get_node("%Notice") as Control).visible = true
	hud.show_mark(_mark(COMPASS_MARKS[1]))
	_ok("hud.fits", parts.size() == 7 and not compass_shown, "%s: shown %s, the compass beside the notice: %s" % [
			tag, parts.keys(), compass_shown])
	for part: String in parts:
		_ok("hud.fits", whole.encloses(parts[part]), "%s: %s %s outside %s" % [tag, part, parts[part], whole])
	var names := parts.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			# One place, never both at once (`hud.fits`).
			if [names[i], names[j]] == ["%Notice", "%Compass"]:
				continue
			_ok("hud.clear", not parts[names[i]].intersects(parts[names[j]]),
					"%s: %s %s meets %s %s" % [tag, names[i], parts[names[i]], names[j], parts[names[j]]])

	var short := hud.get_node("%Active")
	var shown := hud.tracker_sets()
	_ok("hud.short", short.get_child_count() == hud.active_rows and shown.size() == hud.active_rows
			and shown[0] == content.sets[UNDER_WAY + 1].id and not shown.has(content.sets[0].id),
			"%s: tracker %s" % [tag, shown])
	# Looking for the set at the top of the rows lifts it above them, with its members still out.
	var sought := content.sets[UNDER_WAY + 1].id
	hud.show_tracked(sought)
	var sought_line := hud.get_node("%Sought") as Control
	var out := SetProgress.out_in_house(sought)
	_ok("hud.short", sought_line.is_visible_in_tree() and not hud.tracker_sets().has(sought)
			and (hud.get_node("%SoughtText") as Label).text == tr("hud.to_find") % NumberFormatter.count(out)
			and hud.ledger().tracked() == sought,
			"%s: looking for %s, sought line %s '%s', rows %s" % [tag, sought, sought_line.is_visible_in_tree(),
			(hud.get_node("%SoughtText") as Label).text, hud.tracker_sets()])
	parts["%Tracker"] = (hud.get_node("%Tracker") as Control).get_global_rect()
	_ok("hud.fits", whole.encloses(parts["%Tracker"]), "%s: tracker with a set looked for %s outside %s" % [tag,
			parts["%Tracker"], whole])
	for part: String in parts:
		if part != "%Tracker":
			_ok("hud.clear", not parts[part].intersects(parts["%Tracker"]), "%s: tracker with a set looked for meets %s" % [
					tag, part])
	hud.show_tracked(&"")
	var room := plan.all_rooms()[0]
	_ok("hud.here", (hud.get_node("%RoomName") as Label).text == tr(room.name_key)
			and (hud.get_node("%RoomCount") as Label).text.contains(str(MEMBERS)),
			"%s: here '%s' '%s'" % [tag, (hud.get_node("%RoomName") as Label).text,
			(hud.get_node("%RoomCount") as Label).text])

	_check_card(hud, content, plan, tag)
	_check_compass(hud, tag)
	_check_bar(hud, tag, logical)
	_check_readable(hud, tag)
	_check_place(hud, tag)
	await _check_start(hud, content, tag)

	await _check_ledger(view, hud, content, plan, tag, whole)
	print("  %s (laid out at %dx%d) %s" % [tag, logical.x, logical.y, parts])
	_release(view)

func _check_ledger(view: SubViewport, hud: Hud, content: Catalogue, plan: FloorPlan, tag: String, whole: Rect2) -> void:
	var ledger := hud.ledger()
	var rooms := plan.all_rooms()
	var covered: Array[String] = ["%Crosshair", "%Prompt", "%Card", "%Pins"]
	_aim.aim_changed.emit(Interactor.Prompt.TAKE, content.members(content.sets[2].id)[0])
	for part: String in covered:
		_ok("hud.ledger", (hud.get_node(part) as Control).is_visible_in_tree(), "%s: %s not up before the ledger" % [tag, part])
	var held: Array[bool] = []
	hud.ledger_toggled.connect(func(open: bool) -> void: held.append(open))
	var opened := _press(view, &"show_tracker")
	await get_tree().process_frame
	_ok("hud.ledger", opened and held == [true], "%s: one press opened %s, handled %s, held still %s" % [tag,
			ledger.is_visible_in_tree(), opened, held])
	_ok("hud.ledger", ledger.is_visible_in_tree() and not (hud.get_node("%Tracker") as Control).is_visible_in_tree()
			and not (hud.get_node("%RoomTag") as Control).is_visible_in_tree()
			and not (hud.get_node("%Compass") as Control).is_visible_in_tree()
			and ledger.selected_room() == rooms[0].id and ledger.filter() == Ledger.Filter.ROOM,
			"%s: ledger shown %s on '%s'" % [tag, ledger.is_visible_in_tree(), ledger.selected_room()])
	for part: String in covered:
		_ok("hud.ledger", not (hud.get_node(part) as Control).is_visible_in_tree(),
				"%s: %s shows under the ledger's glass" % [tag, part])
	for other: String in ["%Notice", "%CarryBar"]:
		var r := (hud.get_node(other) as Control).get_global_rect()
		_ok("hud.clear", not ledger.get_global_rect().intersects(r),
				"%s: ledger %s meets %s %s" % [tag, ledger.get_global_rect(), other, r])
	_check_readable(hud, tag)
	# The wheel picks a room while the ledger is up, and is handled before the player's input would change the hands.
	var wheel_taken := _press(view, &"select_next")
	var wheeled := ledger.selected_room()
	var floor_taken := _press(view, &"ledger_floor_up")
	var up := plan.storeys[plan.storeys.find(plan.storey_of(rooms[1].id)) + 1]
	_ok("hud.ledger", wheeled == rooms[1].id and wheel_taken and floor_taken and ledger.selected_room() == up.rooms[0].id,
			"%s: the wheel went to '%s' (handled %s), the floor key to '%s' (handled %s)" % [tag, wheeled, wheel_taken,
			ledger.selected_room(), floor_taken])
	# The floor also steps on the keys the player walks with, so the page keys are not the only way (the author,
	# 2026-09-17). Each is pressed as a key, which is what proves the binding.
	for keys: Array in [[KEY_UP, KEY_DOWN], [KEY_W, KEY_S], [KEY_PAGEUP, KEY_PAGEDOWN]]:
		var before := plan.storey_of(ledger.selected_room())
		_press_key(view, keys[0])
		await get_tree().process_frame
		var stepped := plan.storey_of(ledger.selected_room())
		_press_key(view, keys[1])
		await get_tree().process_frame
		_ok("hud.ledger", stepped != before and plan.storey_of(ledger.selected_room()) == before,
				"%s: %s took the floor from '%s' to '%s' and back to '%s'" % [tag, OS.get_keycode_string(keys[0]),
				before.id, stepped.id, plan.storey_of(ledger.selected_room()).id])
	var homes: Dictionary[StringName, bool] = {}
	for def: ItemDef in Inventory.carried():
		homes[content.piece_of(def.home).room] = true
	_ok("hud.ledger", ledger.map().homes() == homes, "%s: rings on %s for homes %s" % [tag, ledger.map().homes(), homes])
	var tabs := ledger.floor_texts()
	for storey: StoreyDef in plan.storeys:
		var left := 0
		for room: RoomDef in storey.rooms:
			left += _probe_count(plan, room.id)
		var tab := tabs[plan.storeys.size() - 1 - plan.storeys.find(storey)]
		_ok("hud.ledger", tab == tr("hud.pair") % [tr(storey.name_key), NumberFormatter.count(left)],
				"%s: tab '%s' for %s with %d misplaced" % [tag, tab, storey.id, left])

	ledger.step_room(-1)
	while ledger.selected_room() != rooms[0].id:
		ledger.step_room(-1)
	var seen: Array[StringName] = []
	for room: RoomDef in rooms:
		await get_tree().process_frame
		_ok("ledger.sets", ledger.selected_room() == room.id, "%s: stepped to '%s', not '%s'" % [tag,
				ledger.selected_room(), room.id])
		var expected: Array[StringName] = []
		for s: SetDef in content.sets:
			if _home_room(content, s) == room.id:
				expected.append(s.id)
		_ok("ledger.sets", ledger.card_sets() == expected and ledger.groups().keys() == [room.id],
				"%s: %s shows %s under %s, belongs %s" % [tag, room.id, ledger.card_sets(), ledger.groups().keys(), expected])
		seen.append_array(ledger.card_sets())
		var left := _probe_count(plan, room.id)
		_ok("ledger.sets", ledger.room_clutter() == (tr("hud.tidy") if left == 0
				else tr("hud.misplaced") % NumberFormatter.count(left)),
				"%s: %s with %d misplaced says '%s'" % [tag, room.id, left, ledger.room_clutter()])
		var area := ledger.get_global_rect()
		_ok("ledger.sets", whole.encloses(area), "%s: at %s the ledger %s leaves the screen" % [tag, room.id, area])
		# One room's sets fit without scrolling.
		var list := ledger.card_list().get_global_rect()
		var cards := ledger.cards()
		for i in range(cards.size()):
			var card := cards[i].get_global_rect()
			_ok("ledger.sets", area.encloses(list) and list.grow(0.5).encloses(card),
					"%s: %s card %d %s outside the list %s" % [tag, room.id, i, card, list])
			for j in range(i):
				_ok("ledger.sets", not cards[j].get_global_rect().intersects(card),
						"%s: %s card %d meets card %d" % [tag, room.id, i, j])
		_check_map(ledger.map(), plan, plan.storey_of(room.id), tag)
		ledger.step_room(1)
	var unique: Dictionary[StringName, bool] = {}
	for id: StringName in seen:
		unique[id] = true
	_ok("ledger.sets", seen.size() == content.sets.size() and unique.size() == content.sets.size(),
			"%s: %d cards over the house for %d sets, %d distinct" % [tag, seen.size(), content.sets.size(), unique.size()])
	await _check_filters(view, ledger, content, plan, tag)
	await _check_clicks(view, hud, content, plan, tag)

	var closed := _press(view, &"show_tracker")
	await get_tree().process_frame
	_ok("hud.ledger", closed and held == [true, false] and not ledger.is_visible_in_tree(),
			"%s: the second press closed %s, handled %s, held still %s" % [tag, not ledger.is_visible_in_tree(), closed, held])
	hud.show_ledger(true)
	var escaped := _press(view, &"ui_cancel")
	await get_tree().process_frame
	_ok("hud.ledger", escaped and not ledger.is_visible_in_tree(), "%s: Escape closed %s, handled %s" % [tag,
			not ledger.is_visible_in_tree(), escaped])
	_ok("hud.ledger", InputMap.has_action(&"show_tracker") and not ledger.is_visible_in_tree()
			and (hud.get_node("%Tracker") as Control).is_visible_in_tree()
			and (hud.get_node("%RoomTag") as Control).is_visible_in_tree(),
			"%s: tracker and room tag not back after the ledger" % tag)
	for part: String in covered:
		_ok("hud.ledger", (hud.get_node(part) as Control).is_visible_in_tree(), "%s: %s not back after the ledger" % [tag, part])

## Presses the key with this physical keycode on the screen, as a keyboard sends it: what is checked is the
## binding, which an action event would step over.
func _press_key(view: SubViewport, physical: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = physical
		key.pressed = pressed
		view.push_input(key, true)

## Presses `action` on the screen; true when the HUD handled it, so `_unhandled_input` (the player's) never sees it.
func _press(view: SubViewport, action: StringName) -> bool:
	var key := InputEventAction.new()
	key.action = action
	key.pressed = true
	view.push_input(key)
	return view.is_input_handled()

static func _home_room(content: Catalogue, s: SetDef) -> StringName:
	return content.piece_of(content.members(s.id)[0].home).room

## Each filter, picked by its number key or stepped to by the pad's shoulder, leaves the hands alone, counts its sets
## on its chip, and lists them in groups by the room they belong in, rooms in plan order from the selected room's
## group on, and sets in content order. Stepping the room goes from group to group, and the list starts at its group.
## A complete set's card says the slot it granted.
func _check_filters(view: SubViewport, ledger: Ledger, content: Catalogue, plan: FloorPlan, tag: String) -> void:
	var number_taken := _press(view, &"select_2")
	_ok("ledger.filter", ledger.filter() == Ledger.Filter.ALL and number_taken,
			"%s: the second number key gave filter %d, handled %s" % [tag, ledger.filter(), number_taken])
	var shoulder_taken := _press(view, &"ledger_filter_next")
	_ok("ledger.filter", ledger.filter() == Ledger.Filter.UNDER_WAY and shoulder_taken,
			"%s: the shoulder gave filter %d, handled %s" % [tag, ledger.filter(), shoulder_taken])
	var rooms := plan.all_rooms()
	for f: int in [Ledger.Filter.ALL, Ledger.Filter.UNDER_WAY, Ledger.Filter.CARRYING, Ledger.Filter.COMPLETE]:
		ledger.show_filter(f as Ledger.Filter)
		var listed: Array[StringName] = []
		var matching := 0
		for room: RoomDef in rooms:
			for s: SetDef in content.sets:
				if _home_room(content, s) == room.id and _in_filter(f as Ledger.Filter, s):
					matching += 1
					if not listed.has(room.id):
						listed.append(room.id)
		# The list starts at the selected room's group, or the next one in the house, round the end.
		var at := rooms.find(plan.find_room(ledger.selected_room()))
		var start := -1
		for k in range(rooms.size()):
			if start < 0 and listed.has(rooms[posmod(at + k, rooms.size())].id):
				start = posmod(at + k, rooms.size())
		var groups: Array[StringName] = []
		var expected: Array[StringName] = []
		for i in range(maxi(start, 0), rooms.size() if start >= 0 else 0):
			if not listed.has(rooms[i].id):
				continue
			groups.append(rooms[i].id)
			for s: SetDef in content.sets:
				if _home_room(content, s) == rooms[i].id and _in_filter(f as Ledger.Filter, s):
					expected.append(s.id)
		_ok("ledger.filter", ledger.card_sets() == expected and ledger.groups().keys() == groups
				and ledger.filter_texts()[f] == tr(Ledger.FILTER_KEYS[f]),
				"%s: filter %d on '%s' shows %s under %s, chip '%s'; expected %s under %s" % [tag, f,
				ledger.selected_room(), ledger.card_sets(), ledger.groups().keys(), ledger.filter_texts()[f], expected, groups])
		for room_id: StringName in listed:
			ledger.step_room(1)
			await get_tree().process_frame
			var keys := ledger.groups().keys()
			var head := ledger.groups().get(ledger.selected_room(), null) as Control
			var list := ledger.card_list().get_global_rect().grow(0.5)
			_ok("ledger.filter", listed.has(ledger.selected_room()) and not keys.is_empty()
					and keys[0] == ledger.selected_room() and head != null and list.encloses(head.get_global_rect()),
					"%s: filter %d stepped to '%s', list starts %s at %s in %s" % [tag, f, ledger.selected_room(), keys,
					null if head == null else head.get_global_rect(), list])
			if head != null:
				# The heading names the room the sets belong in and counts nothing: the tiles under it are the count.
				var title := head.get_child(0) as Label
				var wanted := tr("hud.belongs_in") % tr(plan.find_room(ledger.selected_room()).name_key)
				_ok("ledger.filter", head.get_child_count() == 1 and title.text == wanted,
						"%s: filter %d heads '%s' with %d labels, the first '%s', expected '%s'" % [tag, f,
						ledger.selected_room(), head.get_child_count(), title.text, wanted])
	var bonus := tr("hud.bonus") % NumberFormatter.slots(Balance.SLOTS_PER_COMPLETED_SET)
	var said := (ledger.get_node("%DetailOut") as Label).text
	_ok("ledger.filter", ledger.filter() == Ledger.Filter.COMPLETE and ledger.detail_set() == ledger.card_sets()[0]
			and said == bonus and not (ledger.get_node("%DetailAction") as Control).visible,
			"%s: the complete set's detail says '%s', not '%s'" % [tag, said, bonus])
	ledger.show_filter(Ledger.Filter.ROOM)

## A left click at the middle of `control`, pressed and let go, sent through the screen the way the window sends one.
func _click(view: SubViewport, control: Control, at := Vector2(-1, -1)) -> void:
	var where := control.get_global_rect().get_center() if at.x < 0.0 else at
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = where
		click.global_position = where
		view.push_input(click, true)

## The mouse moved onto `control`.
func _point_at(view: SubViewport, control: Control) -> void:
	var move := InputEventMouseMotion.new()
	move.position = control.get_global_rect().get_center()
	move.global_position = move.position
	view.push_input(move, true)

## Tabs, rooms, chips and tiles, clicked. A set picked is looked for through the HUD only when a `WayHome` answers; here
## the ledger's own signal is what is checked, and the HUD is told the answer as `WayHome` would tell it.
func _check_clicks(view: SubViewport, hud: Hud, content: Catalogue, plan: FloorPlan, tag: String) -> void:
	var ledger := hud.ledger()
	ledger.show_filter(Ledger.Filter.ROOM)
	var rooms := plan.all_rooms()
	while ledger.selected_room() != rooms[0].id:
		ledger.step_room(1)
	await get_tree().process_frame
	# The floor with the most rooms, so there is a room on it to click other than the one selected; its tab is the
	# tabs' own order, the top floor first.
	var storey := plan.storeys[0]
	for candidate: StoreyDef in plan.storeys:
		if candidate.rooms.size() > storey.rooms.size():
			storey = candidate
	_click(view, ledger.get_node("%Floors").get_child(plan.storeys.size() - 1 - plan.storeys.find(storey)) as Control)
	await get_tree().process_frame
	_ok("ledger.click", plan.storey_of(ledger.selected_room()) == storey, "%s: the tab of '%s' showed '%s'" % [tag,
			storey.id, ledger.selected_room()])
	var map := ledger.map()
	# The last room of the floor whose middle is inside it, other than the one selected.
	var target: RoomDef = null
	for room: RoomDef in storey.rooms:
		if room.contains(room.centroid()) and room.id != ledger.selected_room():
			target = room
	var at := map.get_global_transform() * map.to_map(target.centroid())
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	view.push_input(move, true)
	await get_tree().process_frame
	_ok("ledger.click", map.hovered() == target.id, "%s: the pointer over %s has the map on '%s'" % [tag, target.id,
			map.hovered()])
	_click(view, map, at)
	await get_tree().process_frame
	_ok("ledger.click", ledger.selected_room() == target.id, "%s: clicked %s on the map at %s, selected '%s'" % [tag,
			target.id, at, ledger.selected_room()])
	_click(view, ledger.get_node("%Filters").get_child(Ledger.Filter.ALL) as Control)
	await get_tree().process_frame
	_ok("ledger.click", ledger.filter() == Ledger.Filter.ALL, "%s: clicking the second chip gave filter %d" % [tag, ledger.filter()])
	ledger.show_filter(Ledger.Filter.UNDER_WAY)
	await get_tree().process_frame
	var picked: Array[StringName] = []
	var on_pick := func(id: StringName) -> void: picked.append(id)
	ledger.set_picked.connect(on_pick)
	var tiles := ledger.cards()
	# Not the first: with nothing pointed at, the detail line falls back to it, and a check that cannot tell the two
	# apart proves nothing.
	var tile: SetTile = tiles[1] if tiles.size() > 1 else tiles[0]
	_point_at(view, tile)
	await get_tree().process_frame
	var offered := (ledger.get_node("%DetailDo") as Label).text
	_click(view, tile)
	await get_tree().process_frame
	_ok("ledger.click", picked == [tile.set_id] and ledger.detail_set() == tile.set_id and offered == tr("hud.look_for"),
			"%s: pointed at and clicked %s: asked for %s, detail on '%s' offering '%s'" % [tag, tile.set_id, picked,
			ledger.detail_set(), offered])
	# The list is rebuilt around the set looked for, so the tile is found again by its set: the old node is gone.
	var sought := tile.set_id
	hud.show_tracked(sought)
	await get_tree().process_frame
	for card: SetTile in ledger.cards():
		if card.set_id == sought:
			tile = card
	_ok("ledger.click", tile.sought() and (ledger.get_node("%DetailDo") as Label).text == tr("hud.stop_looking"),
			"%s: looked for, the tile says %s and the detail offers '%s'" % [tag, tile.sought(),
			(ledger.get_node("%DetailDo") as Label).text])
	hud.show_tracked(&"")
	ledger.show_filter(Ledger.Filter.COMPLETE)
	await get_tree().process_frame
	picked.clear()
	_click(view, ledger.cards()[0])
	await get_tree().process_frame
	_ok("ledger.click", picked.is_empty(), "%s: a complete set was asked for: %s" % [tag, picked])
	ledger.set_picked.disconnect(on_pick)
	ledger.show_filter(Ledger.Filter.ROOM)

static func _in_filter(filter: Ledger.Filter, s: SetDef) -> bool:
	match filter:
		Ledger.Filter.UNDER_WAY:
			return not SetTracker.is_complete(s.id) and (SetTracker.placed(s.id) > 0 or _carried(s.id) > 0)
		Ledger.Filter.CARRYING:
			return _carried(s.id) > 0
		Ledger.Filter.COMPLETE:
			return SetTracker.is_complete(s.id)
	return true

static func _carried(set_id: StringName) -> int:
	var n := 0
	for def: ItemDef in Inventory.carried():
		if def.set_id == set_id:
			n += 1
	return n

## The map draws the storey's rooms, one for one, each the plan's polygon at one scale, inside the map; and the
## building's footprint, grown by the storey's own rooms, spans the map across its width or its height.
func _check_map(map: LedgerMap, plan: FloorPlan, storey: StoreyDef, tag: String) -> void:
	var drawn := map.drawn()
	var ids: Array[StringName] = []
	for room: RoomDef in storey.rooms:
		ids.append(room.id)
	_ok("ledger.map", drawn.keys() == ids, "%s: %s draws %s, has %s" % [tag, storey.id, drawn.keys(), ids])
	var inside := Rect2(Vector2.ZERO, map.size).grow(0.5)
	var scale := -1.0
	for room: RoomDef in storey.rooms:
		var poly: PackedVector2Array = drawn.get(room.id, PackedVector2Array())
		var shaped := poly.size() == room.polygon.size()
		for k in range(mini(poly.size(), room.polygon.size())):
			shaped = shaped and inside.has_point(poly[k])
			if k == 0:
				continue
			var plan_step := room.polygon[k] - room.polygon[0]
			var map_step := poly[k] - poly[0]
			if scale < 0.0 and plan_step.length() > 0.1:
				scale = map_step.length() / plan_step.length()
			shaped = shaped and map_step.is_equal_approx(plan_step * scale)
		_ok("ledger.map", shaped and scale > 0.0, "%s: %s drawn %s from %s" % [tag, room.id, poly, room.polygon])
	var frame := Rect2()
	var first := true
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR and not storey.rooms.has(room):
			continue
		for p: Vector2 in room.polygon:
			frame = Rect2(p, Vector2.ZERO) if first else frame.expand(p)
			first = false
	var span := map.to_map(frame.end) - map.to_map(frame.position)
	var inner := map.size - Vector2(map.margin, map.margin) * 2.0
	_ok("ledger.map", absf(span.x - inner.x) < 1.0 or absf(span.y - inner.y) < 1.0,
			"%s: %s frame %s spans %s of %s" % [tag, storey.id, frame, span, inner])

## The misplaced items the probe puts in a room: the first room holds `MEMBERS`, the rest a spread from none to
## many, so every shade is on the map.
static func _probe_count(plan: FloorPlan, room_id: StringName) -> int:
	var i := plan.all_rooms().find(plan.find_room(room_id))
	return MEMBERS if i == 0 else i % 8

func _mark(row: Array) -> Compass.Mark:
	var mark := Compass.Mark.new()
	mark.title = tr(row[0])
	mark.bearing = row[1]
	mark.floors = row[2]
	mark.floor_name = tr(row[3])
	mark.distance = tr("hud.metres") % NumberFormatter.count(roundi(row[4]))
	return mark

func _check_compass(hud: Hud, tag: String) -> void:
	(hud.get_node("%Notice") as Control).visible = false
	var compass := hud.get_node("%Compass") as Compass
	var area := compass.get_global_rect()
	for row: Array in COMPASS_MARKS:
		var mark := _mark(row)
		hud.show_mark(mark)
		var disc := compass.disc_rect()
		var words := compass.words_rect()
		_ok("hud.compass", area.encloses(disc) and area.encloses(words),
				"%s: '%s' at %s and its words at %s outside the compass %s" % [tag, mark.title, disc, words, area])
		# The picture under its bearing, with no line back to it (the author, 2026-09-18); behind, at the edge.
		var off := absf(disc.get_center().x - compass.global_position.x - compass.true_x(mark))
		_ok("hud.compass", off <= (compass.disc * 0.5 if absf(compass.offset(mark.bearing)) == 1.0 else 1.0),
				"%s: '%s' stands %.0f px off its bearing" % [tag, mark.title, off])
		_ok("hud.compass", compass.is_visible_in_tree(), "%s: no compass once the notice is gone" % tag)
	(hud.get_node("%Notice") as Control).visible = true
	hud.show_mark(_mark(COMPASS_MARKS[1]))

## The item under the crosshair is a member of the second set under way, which the player also carries.
func _check_card(hud: Hud, content: Catalogue, plan: FloorPlan, tag: String) -> void:
	var card := hud.get_node("%Card") as ItemCard
	var def := content.members(content.sets[2].id)[0]
	var piece := content.piece_of(def.home)
	var room := tr(plan.find_room(piece.room).name_key)
	var total := content.members(def.set_id).size()
	_ok("hud.card", card.visible and card.name_text() == tr(def.name_key)
			and card.cost_text() == NumberFormatter.count(def.slot_cost)
			and card.home_text().contains(room) and card.home_text().contains(tr(HOME_NAME))
			and card.count_text() == NumberFormatter.fraction(total - 1, total),
			"%s: card '%s' '%s' '%s' '%s'" % [tag, card.name_text(), card.cost_text(), card.home_text(), card.count_text()])
	var heavy := content.members(content.sets[3].id)[0]
	heavy.slot_cost = Balance.SLOT_COST_TIERS.back()
	_aim.aim_changed.emit(Interactor.Prompt.TOO_BIG, heavy)
	_ok("hud.card", card.visible and card.cost_text() == NumberFormatter.count(heavy.slot_cost),
			"%s: no room, card cost '%s'" % [tag, card.cost_text()])
	_check_refused(hud, heavy, tag)
	heavy.slot_cost = 1
	_aim.aim_changed.emit(Interactor.Prompt.OPEN, def)
	_ok("hud.card", not card.visible, "%s: card shown for a container prompt" % tag)
	_aim.aim_changed.emit(Interactor.Prompt.TAKE, def)

## A click that would do nothing says which fact refused it — the hands are too full for this item, the item is
## bigger than the hands are, or it is sorted already — and offers no key to press (the author, 2026-09-17: "no
## slots free" is wrong when slots are free). The card stays up for all three: it is still what is being looked at.
func _check_refused(hud: Hud, heavy: ItemDef, tag: String) -> void:
	var text := hud.get_node("%PromptText") as Label
	var cap := hud.get_node("%PromptKeyCap") as Control
	var card := hud.get_node("%Card") as Control
	var said: Array[String] = []
	var refusals: Array[Interactor.Prompt] = [Interactor.Prompt.TOO_BIG, Interactor.Prompt.HANDS_FULL,
			Interactor.Prompt.AT_HOME]
	var wanted: Array[String] = [tr("hud.too_big") % [NumberFormatter.slots(heavy.slot_cost),
			NumberFormatter.slots(Inventory.capacity)],
			tr("hud.hands_full") % NumberFormatter.slots(heavy.slot_cost), tr("hud.already_put_away")]
	for k: int in refusals.size():
		_aim.aim_changed.emit(refusals[k], heavy)
		said.append(text.text)
		_ok("hud.prompt", text.text == wanted[k] and not cap.is_visible_in_tree() and card.is_visible_in_tree(),
				"%s: refusal %d says '%s' (expected '%s'), key shown %s, card shown %s" % [tag, refusals[k], text.text,
				wanted[k], cap.is_visible_in_tree(), card.is_visible_in_tree()])
	_ok("hud.prompt", said[0] != said[1], "%s: a full pair of hands and an item too big both say '%s'" % [tag, said[0]])
	_aim.aim_changed.emit(Interactor.Prompt.TAKE, heavy)
	_ok("hud.prompt", text.text == tr("hud.take") and cap.is_visible_in_tree(),
			"%s: taking says '%s', key shown %s" % [tag, text.text, cap.is_visible_in_tree()])

## The first minutes: one slot, one item with the longest set name in hand.
func _check_start(hud: Hud, content: Catalogue, tag: String) -> void:
	for def: ItemDef in Inventory.carried():
		Inventory.release(def)
	Inventory.reset(Balance.START_SLOTS)
	var longest := content.sets[0]
	for s: SetDef in content.sets:
		if tr(s.name_key).length() > tr(longest.name_key).length():
			longest = s
	var def := content.members(longest.id)[MEMBERS - 1]
	Inventory.take(def)
	await get_tree().process_frame
	var bar := hud.get_node("%CarryBar") as CarryBar
	var back := bar.selected_label()
	var wide := back.get_theme_font(&"font").get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			back.get_theme_font_size(&"font_size")).x
	var slots := (hud.get_node("%Slots") as Label).text
	var sets := (hud.get_node("%SetsDone") as Label).text
	_ok("hud.bar", back.size.x + 1.0 >= wide and slots == NumberFormatter.count(Balance.START_SLOTS)
			and sets == NumberFormatter.fraction(SetProgress.complete_count(content), content.sets.size()),
			"%s: start of a run, '%s' is %.0f px wide for %.0f px of text; head '%s' '%s'" % [tag, back.text,
			back.size.x, wide, sets, slots])

func _check_readable(hud: Hud, tag: String) -> void:
	for node: Node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_visible_in_tree() or label.text == "":
			continue
		var font := label.get_theme_font(&"font")
		var wide := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size(&"font_size")).x
		var floor_width := wide if label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
				and label.autowrap_mode == TextServer.AUTOWRAP_OFF else minf(wide, SQUEEZE_FLOOR)
		_ok("hud.readable", label.size.x + 1.0 >= floor_width,
				"%s: '%s' (%s) is %.0f px wide for %.0f px of text" % [tag, label.text, label.name, label.size.x, wide])

func _check_bar(hud: Hud, tag: String, logical: Vector2i) -> void:
	var bar := hud.get_node("%CarryBar") as CarryBar
	var used := 0
	for cost: int in FULL_LOAD:
		used += cost
	var blocks := bar.cells().blocks()
	var last := blocks.back() as Rect2
	var covered := true
	var p := bar.cells().pitch()
	for k: int in blocks.size():
		covered = covered and is_equal_approx(blocks[k].size.x, FULL_LOAD[k] * p.x + (FULL_LOAD[k] - 1) * p.y)
	var carried := Inventory.carried()
	_ok("hud.bar", bar.used_text() == NumberFormatter.fraction(used, Inventory.capacity)
			and blocks.size() == FULL_LOAD.size() and covered
			and bar.selected_text().contains(tr(carried.back().name_key))
			and last.end.x <= bar.cells().get_rect().size.x + 0.5
			and bar.cells().get_rect().size.x <= bar.cells().max_width + 0.5,
			"%s: '%s', %d blocks, covered %s, back '%s', cells %s" % [tag, bar.used_text(), blocks.size(), covered,
			bar.selected_text(), bar.cells().get_rect()])
	_ok("hud.bar", bar.key_texts() == PackedStringArray([InputNames.of(&"drop_item"), InputNames.of(&"throw_item")]),
			"%s: the bar's keys are %s" % [tag, bar.key_texts()])
	# Another item selected: the bar names that one, not the last one taken.
	Inventory.select(0)
	_ok("hud.bar", bar.selected_text().contains(tr(carried[0].name_key))
			and not bar.selected_text().contains(tr(carried.back().name_key)),
			"%s: with the first item selected the bar says '%s'" % [tag, bar.selected_text()])
	Inventory.select(carried.size() - 1)

## Put away names the item it puts away, and follows the selection while the prompt stays the same.
func _check_place(hud: Hud, tag: String) -> void:
	var prompt := hud.get_node("%PromptText") as Label
	var carried := Inventory.carried()
	_aim.aim_changed.emit(Interactor.Prompt.PLACE, null)
	_ok("hud.place", prompt.text == tr("hud.pair") % [tr("hud.put_away"), tr(carried.back().name_key)],
			"%s: putting away the last item taken, the prompt says '%s'" % [tag, prompt.text])
	Inventory.select(0)
	_ok("hud.place", prompt.text == tr("hud.pair") % [tr("hud.put_away"), tr(carried[0].name_key)],
			"%s: with the first item selected, the prompt to put away says '%s'" % [tag, prompt.text])
	Inventory.select(carried.size() - 1)
	_aim.aim_changed.emit(Interactor.Prompt.NONE, null)

func _shoot(path: String, backdrop: String, ledger: bool, filter: Ledger.Filter, track: bool, screen: Vector2i,
		content: Catalogue, plan: FloorPlan) -> void:
	var view := _screen(screen)
	if backdrop != "":
		var img := Image.load_from_file(backdrop)
		assert(img != null, "HudProbe: cannot read %s" % backdrop)
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(img)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.size = Vector2(view.size_2d_override)
		view.add_child(rect)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# A load early in the run: nine slots, six used, so the cells are drawn at their full size.
	var hud := await _hud(view, content, plan, 9, [2, 1, 1, 2] as Array[int])
	hud.show_ledger(ledger)
	(hud.get_node("%Ledger") as Ledger).show_filter(filter)
	if track:
		hud.show_tracked(content.sets[3].id)
	# A window the compositor is not drawing never posts a frame; forced draws do not wait for it.
	for i in range(4):
		await get_tree().process_frame
		RenderingServer.force_draw()
	var err := view.get_texture().get_image().save_png(path)
	_ok("hud.screenshot", err == OK, error_string(err))
	print("  screenshot -> %s" % path)
	_release(view)

## A HUD tracking the given content, with every room of the plan holding items, the player in the first of
## them, one set complete and `UNDER_WAY` more a member short of it or started, `load` carried at
## `capacity`, and a member of the third set under the crosshair — the widest state the HUD shows.
func _hud(view: SubViewport, content: Catalogue, plan: FloorPlan, capacity: int, load: Array[int]) -> Hud:
	SetTracker.begin(content)
	var hud := HUD.instantiate() as Hud
	view.add_child(hud)
	var census := ClutterCensus.new()
	var nothing := Node.new()
	view.add_child(nothing)
	census.initialize(nothing, plan)
	view.add_child(census)
	hud.track(content, plan, census)
	_aim = Interactor.new()
	hud.watch(_aim)
	for s: SetDef in content.sets.slice(0, UNDER_WAY + 2):
		var members := content.members(s.id)
		for def: ItemDef in members.slice(0, members.size() - (0 if s == content.sets[0] else 1)):
			EventBus.item_placed.emit(def.id, def.home)
	# After the placements, which grant the complete set's slot.
	Inventory.reset(capacity)
	# The load comes from the sets after those, one item per cost, so no set under way changes order.
	var spare := content.sets.slice(UNDER_WAY + 2)
	for k: int in load.size():
		var def := content.members(spare[k].id)[MEMBERS - 1]
		def.slot_cost = load[k]
		Inventory.take(def)
	EventBus.zone_entered.emit(plan.all_rooms()[0].id)
	# A set grants once per run, so the notice is raised by hand for every screen after the first.
	EventBus.set_completed.emit(content.sets[0].id)
	_aim.aim_changed.emit(Interactor.Prompt.TAKE, content.members(content.sets[2].id)[0])
	hud.show_mark(_mark(COMPASS_MARKS[1]))
	# After the placements: the census recounts the empty house once they settle.
	await get_tree().process_frame
	var counts: Dictionary = {}
	for room: RoomDef in plan.all_rooms():
		if _probe_count(plan, room.id) > 0:
			counts[room.id] = _probe_count(plan, room.id)
	census.counts_changed.emit(counts)
	await get_tree().process_frame
	await get_tree().process_frame
	return hud

## The screen at its physical size, laid out at the size the window's stretch would give the HUD.
func _screen(physical: Vector2i) -> SubViewport:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items"
			and ProjectSettings.get_setting("display/window/stretch/aspect") == "expand",
			"HudProbe: the emulated stretch is canvas_items / expand")
	var scale := minf(physical.x / base.x, physical.y / base.y)
	var view := SubViewport.new()
	view.size = physical
	view.size_2d_override = Vector2i((Vector2(physical) / scale).round())
	view.size_2d_override_stretch = true
	view.transparent_bg = false
	add_child(view)
	return view

func _release(view: SubViewport) -> void:
	_aim.free()
	view.queue_free()
	for def: ItemDef in Inventory.carried():
		Inventory.release(def)

## Every set with one home on a piece in a room of the plan, `MOST_IN_ONE_ROOM` of them in the first room and the
## rest taken in turn by the others, each home named like the
## longest home of the content.
func _content(plan: FloorPlan) -> Catalogue:
	var c := Catalogue.new()
	var rooms := plan.all_rooms()
	for i: int in SET_COUNT:
		var set_id := StringName("probe_set_%02d" % i)
		var home := StringName("probe_home_%02d" % i)
		c.sets.append(SetDef.make(set_id, SET_NAMES[i]))
		var group := PlaceSlotGroup.new()
		group.id = home
		group.name_key = HOME_NAME
		var piece := FurnitureDef.new()
		piece.id = StringName("probe_piece_%02d" % i)
		piece.room = rooms[0].id if i < MOST_IN_ONE_ROOM else rooms[1 + (i - MOST_IN_ONE_ROOM) % (rooms.size() - 1)].id
		piece.slots = [group] as Array[PlaceSlotGroup]
		c.furniture.append(piece)
		for m: int in MEMBERS:
			var def := ItemDef.make(StringName("probe_%02d_%02d" % [i, m]), &"spoon", home, set_id)
			def.name_key = SET_NAMES[i]
			c.items.append(def)
	return c

func _ok(label: String, condition: bool, detail: String) -> void:
	if condition:
		return
	_violations += 1
	print("  VIOLATION %s  %s" % [label, detail])
