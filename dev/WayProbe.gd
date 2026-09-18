extends Node3D
## The way home, followed (`docs/ARCHITECTURE.md`, "The way home"), in the real house:
##
##     godot --headless --path . dev/WayProbe.tscn
##
##     way.route    from the middle of every room, carrying a member of every set, walking to wherever the
##                  marker for its home room aims ends in that home room, in at most
##                  `MAX_STEPS` markers; a marker aiming at a flight is followed up or down it
##     way.clear    nothing of the house stands between the eye and where a marker aims: a ray through the
##                  built walls, floors, stairs and railings, the furniture left out, finds nothing. The plan's
##                  walls chose the aim; the built house is what checks it
##     way.outline  in the home room there is no marker, a pin is on the home, and exactly one outline shows:
##                  on the drawer or door the slots are behind, or on the piece that holds them, drawn round
##                  the place the item goes
##     way.through  from another room, on another floor where there is one, the same pin and the same one outline show,
##                  and the outline is drawn through the house
##     way.held     carrying two items bound for two other rooms, the marker is for the one in hand, and follows the
##                  hand to the other; both homes keep their pin
##     way.sought   looking for a set outlines every member that is neither home nor in hand, and nothing else, in
##                  its own kind; the census counts them in the rooms they lie in; looking for it again puts it down;
##                  a set that becomes complete is no longer looked for, and says so
##     way.names    with the guidance set to names only, no marker, no pin and no home outline, anywhere; a set looked
##                  for is still outlined
##
## Exit code is the number of violations.

## A route longer than this many markers is going round in circles; the longest in the manor is 7 rooms.
const MAX_STEPS := 16
## How far off the end of a flight a step up or down it arrives.
const STEP_PAST := 0.6
## A marker aims at a flight's end if it is this close to it.
const FLIGHT_EPS := 0.05
## The ray is cast this far above the higher of the two floors: over a sofa back and a deck railing, under
## a door's head.
const RAY_HEIGHT := 1.25
## The outline is drawn round the place the item goes if that place is this near the outlined meshes.
const OUTLINE_NEAR := 0.3

## Looks timed for `way.time`.
const REFRESH_SAMPLES := 20

var _violations := 0
var _plan: FloorPlan
var _content: Catalogue
var _eye: Node3D
var _way: WayHome
## Every furniture body, which the ray looks past.
var _furniture: Array[RID] = []

func _ready() -> void:
	_plan = ManorPlan.build()
	_content = WorldBuilder.catalogue(_plan)
	add_child(HouseBuilder.build(_plan))
	var items := WorldBuilder.furnish(self, _plan, _content)
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		if not items.is_ancestor_of(body) and _in_furniture(body):
			_furniture.append(body.get_rid())
	_eye = Node3D.new()
	_eye.name = "Eye"
	add_child(_eye)
	_way = WayHome.new()
	_way.initialize(_plan, _content, RoomGraph.new(_plan), _eye, self)
	add_child(_way)
	_way.set_process(false)
	for i in range(3):
		await get_tree().physics_frame
	Inventory.reset(Balance.FINALE_SLOT_COST)
	SetTracker.begin(_content)
	var t0 := Time.get_ticks_msec()
	_check_routes()
	_check_outlines()
	_check_held()
	_measure()
	_check_sought()
	_check_names()
	print("")
	print("WayProbe: %d violation(s) in %d ms" % [_violations, Time.get_ticks_msec() - t0])
	get_tree().quit(_violations)

func _in_furniture(body: Node) -> bool:
	for node: Node in find_children("*", "", true, false):
		var piece := node as FurnitureNode
		if piece != null and piece.is_ancestor_of(body):
			return true
	return false

## One member of the set, in hand, and nothing else.
func _carry(def: ItemDef) -> void:
	for held: ItemDef in Inventory.carried():
		Inventory.release(held)
	Inventory.take(def)

func _middle(room: RoomDef) -> Vector3:
	var c := room.centroid()
	return Vector3(c.x, room.floor_y(_plan.storey_of(room.id).base_y) + Balance.EYE_HEIGHT, c.y)

func _home_room(def: ItemDef) -> StringName:
	return _content.piece_of(def.home).room

func _check_routes() -> void:
	var walked := 0
	var longest := 0
	for s: SetDef in _content.sets:
		var def := _content.members(s.id)[0]
		_carry(def)
		var home := _home_room(def)
		for room: RoomDef in _plan.all_rooms():
			if room.id == home:
				continue
			walked += 1
			var steps := _follow(room, def, home)
			longest = maxi(longest, steps)
	print("  way.route: %d routes followed, the longest %d markers" % [walked, longest])

## Walks from the room's middle to wherever the markers lead; the number of markers followed.
func _follow(from: RoomDef, def: ItemDef, home: StringName) -> int:
	_eye.global_position = _middle(from)
	var trail := PackedStringArray([String(from.id)])
	for steps in range(MAX_STEPS + 1):
		_way.refresh()
		if _way.room() == home:
			return steps
		if steps == MAX_STEPS:
			break
		var way := _way_to(home)
		if way == null:
			_fail("way.route", "'%s' from %s: no marker for %s after %s" % [def.id, from.id, home, trail])
			return steps
		_ok("way.clear", _seen(_eye.global_position, way.aim),
				"'%s' from %s: from %s in %s the marker aims through the house at %s" % [
				def.id, from.id, _eye.global_position, _way.room(), way.aim])
		_eye.global_position = _step(_eye.global_position, way.aim)
		trail.append(String(_way.room()))
	_fail("way.route", "'%s' from %s never reached %s: %s" % [def.id, from.id, home, trail])
	return MAX_STEPS

func _way_to(home: StringName) -> WayHome.Way:
	var way := _way.way()
	return way if way != null and way.room == home else null

## Where following a marker gets to: up or down the flight whose end it aims at, or onto the place it aims at —
## in front of a doorway, past it, round a corner.
func _step(from: Vector3, aim: Vector3) -> Vector3:
	for stair: StairDef in _plan.stairs:
		var lower := _plan.find_room(stair.lower_room).floor_y(_plan.storey_of(stair.lower_room).base_y)
		var upper := _plan.find_room(stair.upper_room).floor_y(_plan.storey_of(stair.upper_room).base_y)
		var foot := Vector3(stair.foot.x, lower, stair.foot.y)
		var head := Vector3(stair.head().x, upper, stair.head().y)
		var along := Vector3(stair.direction.x, 0.0, stair.direction.y)
		if aim.distance_to(foot) < FLIGHT_EPS:
			return head + along * STEP_PAST + Vector3.UP * Balance.EYE_HEIGHT
		if aim.distance_to(head) < FLIGHT_EPS:
			return foot - along * STEP_PAST + Vector3.UP * Balance.EYE_HEIGHT
	return Vector3(aim.x, aim.y + Balance.EYE_HEIGHT, aim.z)

func _seen(eye: Vector3, aim: Vector3) -> bool:
	var height := maxf(eye.y - Balance.EYE_HEIGHT, aim.y) + RAY_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(Vector3(eye.x, height, eye.z), Vector3(aim.x, height, aim.z),
			Layers.body_mask())
	query.exclude = _furniture
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		print("    hit %s at %s" % [(hit["collider"] as Node).get_path(), hit["position"]])
	return hit.is_empty()

func _check_outlines() -> void:
	for s: SetDef in _content.sets:
		var def := _content.members(s.id)[0]
		_carry(def)
		var home := _home_room(def)
		_eye.global_position = _middle(_plan.find_room(home))
		_way.refresh()
		var slots := ProgressSave.find_slots(self, def.home)
		var pinned := false
		for pin: WayHome.Pin in _way.pins():
			pinned = pinned or pin.group == def.home
		var shown := _way.shown_outlines()
		var outline := _way.outline_of(def.home)
		_ok("way.outline", _way_to(home) == null and pinned and shown.size() == 1 and outline != null
				and shown[0] == outline and not outline.hulls().is_empty(),
				"'%s' in %s: marker %s, pinned %s, %d outlines shown, its own %s" % [
				def.id, home, _way_to(home) != null, pinned, shown.size(), outline])
		if outline == null or outline.hulls().is_empty():
			continue
		var target := outline.target
		var holds := (slots.container() != null and target == slots.container().mover()) \
				or (target is FurnitureNode and (target as FurnitureNode).def.id == _content.piece_of(def.home).id
				and target.is_ancestor_of(slots))
		var bounds := AABB()
		for i in range(outline.hulls().size()):
			var hull := outline.hulls()[i]
			var box := hull.global_transform * hull.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		var at := slots.global_position
		_ok("way.outline", holds and bounds.grow(OUTLINE_NEAR).has_point(at),
				"'%s': outlined %s (holds the slots: %s), %s round %s" % [def.id, target.name, holds, bounds, at])
		var away := _away_from(home)
		_eye.global_position = _middle(away)
		_way.refresh()
		pinned = false
		for pin: WayHome.Pin in _way.pins():
			pinned = pinned or pin.group == def.home
		var through := outline.hulls()[0].material_override as ShaderMaterial
		_ok("way.through", pinned and _way.shown_outlines() == [outline] and through != null
				and through.shader == Outline.THROUGH and outline.hulls()[0].material_overlay != null,
				"'%s' from %s: pinned %s, outlines %s, drawn through the house %s" % [def.id, away.id, pinned,
				_way.shown_outlines(), through != null and through.shader == Outline.THROUGH])

## A room away from `home`: on another floor where there is one, else the first other room.
func _away_from(home: StringName) -> RoomDef:
	var home_storey := _plan.storey_of(home)
	var fallback: RoomDef = null
	for room: RoomDef in _plan.all_rooms():
		if room.id == home:
			continue
		if _plan.storey_of(room.id) != home_storey:
			return room
		if fallback == null:
			fallback = room
	return fallback

## The first set with at least three members: one taken in hand, one put home, the rest left where they lie.
func _check_sought() -> void:
	for held: ItemDef in Inventory.carried():
		Inventory.release(held)
	var census := ClutterCensus.new()
	census.initialize(self, _plan)
	add_child(census)
	var s: SetDef = null
	for candidate: SetDef in _content.sets:
		if s == null and _content.members(candidate.id).size() >= 3:
			s = candidate
	var nodes: Array[ItemNode] = []
	for item: ItemNode in ProgressSave.items_in(self):
		if item.def.set_id == s.id:
			nodes.append(item)
	nodes[0].set_carried(true)
	EventBus.item_placed.emit(nodes[1].def.id, nodes[1].def.home)
	var changes: Array[StringName] = []
	var on_change := func(id: StringName) -> void: changes.append(id)
	_way.tracked_changed.connect(on_change)
	_way.track(s.id)
	var expected: Array[ItemNode] = nodes.slice(2)
	var outlined: Array[Node3D] = []
	for outline: Outline in _way.shown_outlines():
		if outline.kind == Outline.Kind.SOUGHT:
			outlined.append(outline.target)
	var rooms: Dictionary = {}
	for item: ItemNode in expected:
		var room := _plan.room_at(item.global_position, ProgressSave.ROOM_SLACK)
		if room != null:
			rooms[room.id] = int(rooms.get(room.id, 0)) + 1
	var same := outlined.size() == expected.size()
	for item: ItemNode in expected:
		same = same and outlined.has(item) and _way.outline_on(item).hulls().size() > 0
	_ok("way.sought", _way.tracked() == s.id and same and census.rooms_of(s.id) == rooms,
			"'%s' looked for: outlined %d of %d expected, rooms %s, census %s" % [s.id, outlined.size(), expected.size(),
			rooms, census.rooms_of(s.id)])
	_way.track(s.id)
	var any := 0
	for outline: Outline in _way.shown_outlines():
		any += 1 if outline.kind == Outline.Kind.SOUGHT else 0
	_ok("way.sought", _way.tracked() == &"" and any == 0, "'%s' looked for again: tracked '%s', %d outlines" % [s.id,
			_way.tracked(), any])
	_way.track(s.id)
	for item: ItemNode in nodes:
		EventBus.item_placed.emit(item.def.id, item.def.home)
	_way.refresh()
	_ok("way.sought", _way.tracked() == &"" and changes == [s.id, &"", s.id, &""],
			"'%s' completed: tracked '%s', told %s" % [s.id, _way.tracked(), changes])
	_way.tracked_changed.disconnect(on_change)
	nodes[0].set_carried(false)
	SetTracker.begin(_content)
	# Looked for again for the names check: the player's own request stands with the guidance off.
	_way.track(s.id)

func _check_held() -> void:
	var here := _plan.all_rooms()[0]
	var bound: Array[ItemDef] = []
	var rooms: Array[StringName] = []
	for s: SetDef in _content.sets:
		var def := _content.members(s.id)[0]
		var home := _home_room(def)
		if home != here.id and not rooms.has(home):
			bound.append(def)
			rooms.append(home)
		if bound.size() == 2:
			break
	Inventory.reset(Balance.FINALE_SLOT_COST * 2)
	Inventory.take(bound[0])
	Inventory.take(bound[1])
	_eye.global_position = _middle(here)
	for i: int in [1, 0]:
		Inventory.select(i)
		_way.refresh()
		var way := _way.way()
		_ok("way.held", way != null and way.def == bound[i] and way.room == rooms[i],
				"in %s holding '%s' of two: the marker is for %s" % [
				here.id, bound[i].id, "nothing" if way == null else "'%s' in %s" % [way.def.id, way.room]])
		var pinned: Array[StringName] = []
		for pin: WayHome.Pin in _way.pins():
			pinned.append(pin.def.id)
		_ok("way.held", pinned.has(bound[0].id) and pinned.has(bound[1].id),
				"in %s holding '%s' of two: pins only for %s" % [here.id, bound[i].id, pinned])
	Inventory.reset(Balance.FINALE_SLOT_COST)

## One look with a member of every set in hand, from the attic, the far end of the house.
func _measure() -> void:
	for held: ItemDef in Inventory.carried():
		Inventory.release(held)
	Inventory.reset(Balance.FINALE_SLOT_COST * 8)
	for s: SetDef in _content.sets:
		Inventory.take(_content.members(s.id)[0])
	_eye.global_position = _middle(_plan.find_room(&"attic"))
	var worst := 0
	var total := 0
	for i in range(REFRESH_SAMPLES):
		var t0 := Time.get_ticks_usec()
		_way.refresh()
		var spent := Time.get_ticks_usec() - t0
		worst = maxi(worst, spent)
		total += spent
	print("  way.time: %d carried, %d pins: a look takes %.2f ms, at worst %.2f ms" % [
			Inventory.carried().size(), _way.pins().size(), total / 1000.0 / REFRESH_SAMPLES, worst / 1000.0])
	for held: ItemDef in Inventory.carried():
		Inventory.release(held)
	Inventory.reset(Balance.FINALE_SLOT_COST)

func _check_names() -> void:
	_way.guidance = WayHome.Guidance.NAMES
	var any := 0
	for s: SetDef in _content.sets:
		var def := _content.members(s.id)[0]
		_carry(def)
		for room: RoomDef in [_plan.all_rooms()[0], _plan.find_room(_home_room(def))] as Array[RoomDef]:
			_eye.global_position = _middle(room)
			_way.refresh()
			any += (0 if _way.way() == null else 1) + _way.pins().size()
			for outline: Outline in _way.shown_outlines():
				any += 1 if outline.kind == Outline.Kind.HOME else 0
	var sought := 0
	for outline: Outline in _way.shown_outlines():
		sought += 1 if outline.kind == Outline.Kind.SOUGHT else 0
	_ok("way.names", any == 0 and sought > 0, "names only: %d markers, pins and home outlines shown; %d of the set looked for"
			% [any, sought])
	_way.track(_way.tracked())
	_way.guidance = WayHome.Guidance.FULL

func _ok(label: String, condition: bool, detail: String) -> void:
	if not condition:
		_fail(label, detail)

func _fail(label: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [label, detail])
