extends Node
## The HUD at shipping volume: every set of `docs/CONTENT.md`, every room of the manor holding something,
## hands loaded, and an item under the crosshair — at every screen size the game supports (`docs/PACING.md`:
## 1080p and Steam Deck; 720p as the floor; 1440p above), and again with every string 40% longer, because
## German is. Headless, it checks the layout; with `--screenshot` it saves what one screen shows, over
## `--backdrop` if one is given.
##
##     godot --headless --path . dev/HudProbe.tscn
##     godot --path . dev/HudProbe.tscn -- --screenshot=/abs/out.png [--backdrop=/abs/game.png] [--overview]
##             [--long] [--size=1600x900]
##
##     hud.rows      every set and every room with a count has a row in the overview
##     hud.fits      the room tag, tracker, item card, carry bar, prompt, notice, compass and overview end inside
##                   the screen
##     hud.clear     none of those meet each other, but the notice and the compass, which take turns at the top;
##                   the overview meets neither the notice, the carry bar nor the room tag
##     hud.short     the tracker holds `active_rows` sets under way, the last one changed first, and no
##                   complete set
##     hud.overview  holding the key shows the overview in place of the tracker, and letting go brings the
##                   tracker back
##     hud.here      the room the player stands in is shown with its count
##     hud.card      the item under the crosshair shows its name, slot cost, home room and piece, and its
##                   set's progress; with no room for it, how many slots are free; nothing when the prompt
##                   is not about an item
##     hud.readable  no label with text on screen is squeezed below the width of its text or, for one that may
##                   end in an ellipsis, below `SQUEEZE_FLOOR`: a label shrunk to nothing reads as missing
##     hud.bar       the carry bar counts slots used of capacity, draws one block per carried item covering
##                   its cost, outlines the selected one and names it, and never grows past its width;
##                   at the start of a run, one slot and one item, the item's name is not cut off
##                   and the slot count is singular; it shows the keys that drop and throw
##     hud.place     the prompt to put away names the selected item, and follows the selection
##     hud.compass   the way-home markers stay inside the compass and never meet, the nearest is among those
##                   shown, and left to right they keep the order of their bearings
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
	"Grill tool", "Deck chair cushion", "Pool noodle", "Swim goggles", "Garden hose", "Watering can"]
## The longest home name of the content, on every probe home.
const HOME_NAME := "cupboard over the coffee maker"
## Way-home markers: title, bearing in radians, floors, metres. The first is the nearest; two nearly share a
## bearing, one is behind the player.
const COMPASS_MARKS: Array[Array] = [["Kitchen · 4 m", 0.05, 0, 4.0], ["Master bedroom · 23 m", 1.2, 1, 23.0],
	["Workshop · 31 m", -2.6, -1, 31.0], ["Attic · 40 m", 0.0, 2, 40.0]]
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
	var overview := false
	var long := false
	var shot_screen := SHOT_SCREEN
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--backdrop="):
			backdrop = arg.trim_prefix("--backdrop=")
		elif arg == "--overview":
			overview = true
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
		await _shoot(shot, backdrop, overview, shot_screen, content, plan)
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
			hud.show_marks(_marks())
		elif control.is_visible_in_tree():
			parts[part] = control.get_global_rect()
	(hud.get_node("%Notice") as Control).visible = true
	hud.show_marks(_marks())
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
	var shown: Array[String] = []
	for row: Node in short.get_children():
		shown.append((row.find_children("*", "Label", true, false)[0] as Label).text)
	_ok("hud.short", short.get_child_count() == hud.active_rows and shown[0] == tr(SET_NAMES[UNDER_WAY + 1])
			and not shown.has(tr(SET_NAMES[0])), "%s: tracker %s" % [tag, shown])
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

	hud.show_overview(true)
	await get_tree().process_frame
	var tracker_shown := (hud.get_node("%Tracker") as Control).is_visible_in_tree()
	var overview := (hud.get_node("%Overview") as Control).get_global_rect()
	var rows := hud.get_node("%Sets").get_child_count()
	var room_rows := hud.get_node("%Rooms").get_child_count()
	_ok("hud.rows", rows == SET_COUNT and room_rows == plan.all_rooms().size(),
			"%s: %d set rows, %d room rows" % [tag, rows, room_rows])
	_ok("hud.fits", whole.encloses(overview), "%s: overview %s" % [tag, overview])
	for other: String in ["%Notice", "%CarryBar", "%RoomTag"]:
		var r := (hud.get_node(other) as Control).get_global_rect()
		_ok("hud.clear", not overview.intersects(r), "%s: overview %s meets %s %s" % [tag, overview, other, r])
	hud.show_overview(false)
	await get_tree().process_frame
	_ok("hud.overview", InputMap.has_action(&"show_tracker") and not tracker_shown
			and (hud.get_node("%Tracker") as Control).is_visible_in_tree()
			and not (hud.get_node("%Overview") as Control).is_visible_in_tree(),
			"%s: tracker shown under the overview: %s" % [tag, tracker_shown])
	print("  %s (laid out at %dx%d) %s, overview %s" % [tag, logical.x, logical.y, parts, overview])
	_release(view)

func _marks() -> Array[Compass.Mark]:
	var marks: Array[Compass.Mark] = []
	for row: Array in COMPASS_MARKS:
		var mark := Compass.Mark.new()
		mark.title = tr(row[0])
		mark.bearing = row[1]
		mark.floors = row[2]
		mark.metres = row[3]
		marks.append(mark)
	return marks

func _check_compass(hud: Hud, tag: String) -> void:
	(hud.get_node("%Notice") as Control).visible = false
	hud.show_marks(_marks())
	var compass := hud.get_node("%Compass") as Compass
	var area := compass.get_global_rect()
	var rects := compass.marker_rects()
	_ok("hud.compass", rects.size() >= 2, "%s: %d of %d markers shown" % [tag, rects.size(), COMPASS_MARKS.size()])
	for i in range(rects.size()):
		_ok("hud.compass", area.encloses(rects[i]), "%s: marker %s outside the compass %s" % [tag, rects[i], area])
		for j in range(i + 1, rects.size()):
			_ok("hud.compass", not rects[i].intersects(rects[j]) and rects[i].position.x < rects[j].position.x,
					"%s: marker %s meets or is right of marker %s" % [tag, rects[i], rects[j]])
	var titles: Array[String] = []
	for mark: Compass.Mark in compass.shown():
		titles.append(mark.title)
	_ok("hud.compass", titles.has(tr(COMPASS_MARKS[0][0])), "%s: the nearest is not among %s" % [tag, titles])
	_ok("hud.compass", compass.is_visible_in_tree(), "%s: no compass once the notice is gone" % tag)
	(hud.get_node("%Notice") as Control).visible = true
	hud.show_marks(_marks())

## The item under the crosshair is a member of the second set under way, which the player also carries.
func _check_card(hud: Hud, content: Catalogue, plan: FloorPlan, tag: String) -> void:
	var card := hud.get_node("%Card") as ItemCard
	var def := content.members(content.sets[2].id)[0]
	var piece := content.piece_of(def.home)
	var room := tr(plan.find_room(piece.room).name_key)
	var total := content.members(def.set_id).size()
	_ok("hud.card", card.visible and card.name_text() == tr(def.name_key)
			and card.cost_text() == NumberFormatter.slots(def.slot_cost)
			and card.home_text().contains(room) and card.home_text().contains(tr(HOME_NAME))
			and card.count_text().contains(NumberFormatter.of_total(total - 1, total)),
			"%s: card '%s' '%s' '%s' '%s'" % [tag, card.name_text(), card.cost_text(), card.home_text(), card.count_text()])
	var heavy := content.members(content.sets[3].id)[0]
	heavy.slot_cost = Balance.SLOT_COST_TIERS.back()
	_aim.aim_changed.emit(Interactor.Prompt.NO_SLOT, heavy)
	_ok("hud.card", card.visible and card.cost_text().contains(NumberFormatter.slots(heavy.slot_cost))
			and card.cost_text().contains(tr("hud.free") % NumberFormatter.count(Inventory.free_slots())),
			"%s: no room, card cost '%s'" % [tag, card.cost_text()])
	heavy.slot_cost = 1
	_aim.aim_changed.emit(Interactor.Prompt.OPEN, def)
	_ok("hud.card", not card.visible, "%s: card shown for a container prompt" % tag)
	_aim.aim_changed.emit(Interactor.Prompt.TAKE, def)

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
	var slots_word := (hud.get_node("%SlotsWord") as Label).text
	_ok("hud.bar", back.size.x + 1.0 >= wide and slots_word == tr("hud.slot_word"),
			"%s: start of a run, '%s' is %.0f px wide for %.0f px of text; slots word '%s'" % [tag, back.text,
			back.size.x, wide, slots_word])

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
	_ok("hud.bar", bar.used_text() == NumberFormatter.slots_of(used, Inventory.capacity)
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

func _shoot(path: String, backdrop: String, overview: bool, screen: Vector2i, content: Catalogue,
		plan: FloorPlan) -> void:
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
	hud.show_overview(overview)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
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
	hud.show_marks(_marks())
	# After the placements: the census recounts the empty house once they settle.
	await get_tree().process_frame
	var counts: Dictionary = {}
	for room: RoomDef in plan.all_rooms():
		counts[room.id] = MEMBERS
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

## Every set with one home on a piece in a room of the plan, rooms taken in turn, each home named like the
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
		piece.room = rooms[i % rooms.size()].id
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
