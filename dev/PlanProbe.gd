extends SceneTree
## Consistency probe for a FloorPlan. It is the gate for Phase 1 alongside the renders, and it
## exists because a plan bug is invisible until it is expensive: a wall whose sides are swapped
## renders plaster on the garden elevation, and a missing wall is a room you can walk out of.
##
##     godot --headless --path . --script res://dev/PlanProbe.gd
##
## Exit code is the number of violations, so it can be scripted. Every check states what it
## proves, not what it looked at.

const EPS := 0.005

var _violations := 0

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _init() -> void:
	_check_plan("garage", GaragePlan.build())
	_check_plan("manor", ManorPlan.build())
	print("")
	print("PlanProbe: %d violation(s)" % _violations)
	quit(_violations)

func _check_plan(label: String, plan: FloorPlan) -> void:
	print("=== %s (hash %s) ===" % [label, plan.plan_hash()])
	if plan.plan_hash() != plan.plan_hash():
		_fail("hash", "plan_hash is not stable within a single run")
	for storey: StoreyDef in plan.storeys:
		_check_rooms(storey)
		_check_walls(plan, storey)
		_check_enclosure(storey)
	_check_stairs(plan)
	_check_reachability(plan)
	print("  rooms=%d walls=%d openings=%d" % [
			plan.all_rooms().size(), _wall_count(plan), _opening_count(plan)])

func _wall_count(plan: FloorPlan) -> int:
	var n := 0
	for s: StoreyDef in plan.storeys:
		n += s.walls.size()
	return n

func _opening_count(plan: FloorPlan) -> int:
	var n := 0
	for s: StoreyDef in plan.storeys:
		for w: WallSegment in s.walls:
			n += w.openings.size()
	return n

# --- Rooms ------------------------------------------------------------------------------------

func _check_rooms(storey: StoreyDef) -> void:
	var seen: Dictionary = {}
	for room: RoomDef in storey.rooms:
		if seen.has(room.id):
			_fail("room.id", "'%s' is used twice on storey '%s'" % [room.id, storey.id])
		seen[room.id] = true
		if room.polygon.size() < 3:
			_fail("room.polygon", "'%s' has %d points" % [room.id, room.polygon.size()])
		if room.area() < 1.0:
			_fail("room.area", "'%s' is %.2f m2" % [room.id, room.area()])
	# No two rooms may overlap, or an item could be authored into two zones at once and the
	# per-room clutter counts in docs/VISION.md would double-count it.
	for i in range(storey.rooms.size()):
		for j in range(i + 1, storey.rooms.size()):
			var a := storey.rooms[i]
			var b := storey.rooms[j]
			if absf(a.floor_y(storey.base_y) - b.floor_y(storey.base_y)) > 1.0:
				continue
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(a.polygon, b.polygon):
				var overlap := _poly_area(piece)
				if overlap > 0.05:
					_fail("room.overlap", "'%s' and '%s' share %.2f m2" % [a.id, b.id, overlap])

func _poly_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5

# --- Walls ------------------------------------------------------------------------------------

func _check_walls(plan: FloorPlan, storey: StoreyDef) -> void:
	for wall: WallSegment in storey.walls:
		var where := "wall %s->%s" % [wall.a, wall.b]
		if wall.length() < 0.05:
			_fail("wall.length", "%s is %.3f m" % [where, wall.length()])
			continue
		if wall.room_a == &"" and wall.room_b == &"":
			_fail("wall.sides", "%s is outdoors on both sides — it belongs to no room" % where)
		for side: StringName in [wall.room_a, wall.room_b]:
			if side != &"" and storey.room(side) == null:
				_fail("wall.room", "%s names room '%s', which does not exist" % [where, side])

		# Side A is defined as the side on your right walking a->b. If the room named there is
		# actually on the other side, the finishes come out swapped — plaster outdoors, siding
		# in the living room. This is the check that makes that impossible to ship.
		var n := wall.normal()
		var mid := wall.midpoint()
		for pair: Array in [[wall.room_a, 1.0], [wall.room_b, -1.0]]:
			var room_id: StringName = pair[0]
			if room_id == &"":
				continue
			var room := storey.room(room_id)
			if room == null:
				continue
			var to_room := room.centroid() - mid
			if to_room.dot(n) * float(pair[1]) <= 0.0:
				_fail("wall.side_order", "%s puts '%s' on the wrong side" % [where, room_id])

		var height := wall.height_override if wall.height_override > 0.0 else storey.height
		var spans: Array = []
		for o: Opening in wall.openings:
			if o.u0() < -EPS or o.u1() > wall.length() + EPS:
				_fail("opening.bounds", "%s: opening spans %.2f..%.2f of a %.2f m wall" % [
						where, o.u0(), o.u1(), wall.length()])
			if o.top() > height - EPS:
				_fail("opening.head", "%s: opening reaches %.2f m in a %.2f m storey" % [
						where, o.top(), height])
			if o.bottom() < -EPS:
				_fail("opening.sill", "%s: opening starts %.2f m below the floor" % [where, o.bottom()])
			if o.width < 0.3 or o.height < 0.3:
				_fail("opening.size", "%s: %.2f x %.2f m opening" % [where, o.width, o.height])
			for s: Array in spans:
				if o.u0() < s[1] - EPS and o.u1() > s[0] + EPS:
					_fail("opening.overlap", "%s: two openings overlap near u=%.2f" % [where, o.at])
			spans.append([o.u0(), o.u1()])

		var lot := plan.lot.grow(EPS)
		if not lot.has_point(wall.a) or not lot.has_point(wall.b):
			_fail("wall.lot", "%s leaves the lot %s" % [where, plan.lot])

# --- Enclosure --------------------------------------------------------------------------------

## A room is enclosed when the walls naming it add up to its own perimeter. A missing wall, a
## wall that stops short, or a wall accidentally naming the wrong room all show up here as a
## length that does not match — which is cheaper to read than hunting a gap in a render.
func _check_enclosure(storey: StoreyDef) -> void:
	for room: RoomDef in storey.rooms:
		if room.zone == RoomDef.Zone.EXTERIOR:
			continue
		var walled := 0.0
		for wall: WallSegment in storey.walls:
			if wall.room_a == room.id or wall.room_b == room.id:
				walled += wall.length()
		var perimeter := 0.0
		for i in range(room.polygon.size()):
			perimeter += room.polygon[i].distance_to(room.polygon[(i + 1) % room.polygon.size()])
		if absf(walled - perimeter) > 0.05:
			_fail("room.enclosure", "'%s' has %.2f m of wall around a %.2f m perimeter" % [
					room.id, walled, perimeter])

# --- Stairs -----------------------------------------------------------------------------------

## A flight must start inside the room it leaves and end inside the room it reaches, and those
## rooms must be on different storeys. A stair that arrives in the wrong room is a stair that
## comes up through a bathroom floor.
func _check_stairs(plan: FloorPlan) -> void:
	for stair: StairDef in plan.stairs:
		var where := "stair %s->%s" % [stair.lower_room, stair.upper_room]
		var lower := plan.find_room(stair.lower_room)
		var upper := plan.find_room(stair.upper_room)
		if lower == null or upper == null:
			_fail("stair.rooms", "%s names a room that does not exist" % where)
			continue
		var ls := plan.storey_of(stair.lower_room)
		var us := plan.storey_of(stair.upper_room)
		if ls == us:
			_fail("stair.storeys", "%s connects two rooms on the same storey" % where)
		elif upper.floor_y(us.base_y) <= lower.floor_y(ls.base_y):
			_fail("stair.direction", "%s goes down to its 'upper' room" % where)
		if not lower.contains(stair.foot):
			_fail("stair.foot", "%s starts at %s, outside '%s'" % [where, stair.foot, lower.id])
		if not upper.contains(stair.head()):
			_fail("stair.head", "%s arrives at %s, outside '%s'" % [where, stair.head(), upper.id])
		if absf(stair.direction.x) > EPS and absf(stair.direction.y) > EPS:
			_fail("stair.axis", "%s is not axis-aligned" % where)

# --- Reachability -----------------------------------------------------------------------------

## Every interior room must be walkable from outdoors through real openings and real stairs.
## Windows do not count. A room that is only reachable through a window is a room the player can
## see items in and never collect them from; a storey with no stair is a storey that does not
## exist.
func _check_reachability(plan: FloorPlan) -> void:
	var adj: Dictionary = {}
	for room: RoomDef in plan.all_rooms():
		adj[room.id] = [] as Array[StringName]
	adj[&""] = [] as Array[StringName]
	for storey: StoreyDef in plan.storeys:
		for wall: WallSegment in storey.walls:
			var passable := false
			for o: Opening in wall.openings:
				if o.kind != Opening.Kind.WINDOW:
					passable = true
			if not passable or not adj.has(wall.room_a) or not adj.has(wall.room_b):
				continue
			adj[wall.room_a].append(wall.room_b)
			adj[wall.room_b].append(wall.room_a)
	for stair: StairDef in plan.stairs:
		if adj.has(stair.lower_room) and adj.has(stair.upper_room):
			adj[stair.lower_room].append(stair.upper_room)
			adj[stair.upper_room].append(stair.lower_room)

	var seen: Dictionary = {&"": true}
	var queue: Array[StringName] = [&""]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for next: StringName in adj[cur]:
			if seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR:
			continue
		if not seen.has(room.id):
			_fail("room.reachable", "'%s' cannot be walked to from outdoors" % room.id)
