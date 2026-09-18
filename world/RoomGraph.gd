class_name RoomGraph
extends RefCounted
## The house as the player walks it: every room's middle, and the metres between rooms that are joined
## through a doorway, up a flight, or across open ground between two exterior zones. Built from the plan
## alone, so the pacing model and the HUD's way home read the same routes (`dev/PacingProbe.gd`).
##
## Every link also knows where it is crossed (`waypoints`): the middle of its doorway, both ends of its
## flight, or, between two exterior zones, a way round the outside of the house past its corners. The
## metres a link costs do not change with that; the pacing model was measured on them.

## A place on the way: a point on a floor, and the storey it is on, since a point on the landing is not
## seen from the hall below it.
class Waypoint:
	extends RefCounted
	var at: Vector3
	var storey: StoreyDef

	func _init(point: Vector3, on: StoreyDef) -> void:
		at = point
		storey = on

## Where to look along a route and how far it is from the eye (`sight`).
class Sight:
	extends RefCounted
	var at: Vector3
	var metres := 0.0

## Two exterior zones are walked between across open ground, with no doorway between them.
const OUTDOORS_STEP := 1.0
## Halvings `sight` takes to find how far along a leg the eye still sees: a 6 m leg to 19 cm.
const SIGHT_STEPS := 5

var _plan: FloorPlan
## Room id -> room id -> metres between their middles, through a doorway or a flight.
var _links: Dictionary[StringName, Dictionary] = {}
var _middle: Dictionary[StringName, Vector3] = {}
## Room pair -> metres: asked for once per leg of every trip, and the answer never changes.
var _hops: Dictionary[String, float] = {}
## Room id -> room id -> the plan points a link is crossed at, walking from the first room: a doorway's middle,
## a flight's near end then its far end. Between two exterior zones it is worked out when first asked (`_around`).
var _via: Dictionary[StringName, Dictionary] = {}
## Exterior zone pairs whose way round the house has been worked out.
var _walked_round: Dictionary[String, bool] = {}
## Room pair -> its waypoints, once asked for.
var _ways: Dictionary[String, Array] = {}
## Storey -> what a line on its floor may not cross, worked out once: every wall face as a pair of ends, the wall
## it is a face of and how far that face is off the wall's line; then every flight's edges as pairs of ends,
## with whether each is the end it is walked onto from.
var _faces: Dictionary[StoreyDef, PackedVector2Array] = {}
var _face_walls: Dictionary[StoreyDef, Array] = {}
var _face_offsets: Dictionary[StoreyDef, PackedVector2Array] = {}
var _flight_edges: Dictionary[StoreyDef, PackedVector2Array] = {}
var _flight_open: Dictionary[StoreyDef, Array] = {}

func _init(plan: FloorPlan) -> void:
	_plan = plan
	for storey: StoreyDef in plan.storeys:
		_index_obstacles(storey)
	for room: RoomDef in plan.all_rooms():
		var storey := plan.storey_of(room.id)
		var centre := room.centroid()
		_middle[room.id] = Vector3(centre.x, room.floor_y(storey.base_y), centre.y)
		_links[room.id] = {}
		_via[room.id] = {}
	for storey: StoreyDef in plan.storeys:
		for wall: WallSegment in storey.walls:
			for opening: Opening in wall.openings:
				if not passable(opening):
					continue
				_join(wall.room_a, wall.room_b, wall.at_u(opening.at), wall.normal())
	for stair: StairDef in plan.stairs:
		var foot := stair.foot + stair.direction * stair.run * 0.5
		var before := _point(stair.lower_room, _approach(stair.lower_room, stair.foot, -stair.direction))
		var lower := _point(stair.lower_room, stair.foot)
		var upper := _point(stair.upper_room, stair.head())
		var after := _point(stair.upper_room, _approach(stair.upper_room, stair.head(), stair.direction))
		_link(stair.lower_room, stair.upper_room, _reach(stair.lower_room, foot) + _reach(stair.upper_room, foot)
				+ stair.run, [before, lower, upper, after], [after, upper, lower, before])
	var outside: Array[RoomDef] = []
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR:
			outside.append(room)
	for i in range(outside.size()):
		for j in range(i + 1, outside.size()):
			_link(outside[i].id, outside[j].id,
					_middle[outside[i].id].distance_to(_middle[outside[j].id]) * OUTDOORS_STEP)

## Metres from `a` to `b` on foot: inside one room, straight; otherwise to the middle of its room, through
## the doorways and flights between the two rooms, and out to the point at the other end.
func walk(a: Vector3, b: Vector3) -> float:
	var from := _plan.room_at(a, ProgressSave.ROOM_SLACK)
	var to := _plan.room_at(b, ProgressSave.ROOM_SLACK)
	if from == null or to == null:
		return a.distance_to(b)
	if from.id == to.id:
		return a.distance_to(b)
	return a.distance_to(_middle[from.id]) + between(from.id, to.id) + _middle[to.id].distance_to(b)

## Metres between two rooms' middles along the shortest route, or INF when nothing joins them.
func between(from: StringName, to: StringName) -> float:
	var key := "%s|%s" % [from, to]
	if _hops.has(key):
		return _hops[key]
	var metres := _dijkstra(from, to)
	_hops[key] = metres
	_hops["%s|%s" % [to, from]] = metres
	return metres

func _dijkstra(from: StringName, to: StringName) -> float:
	var path := _path(from, to)
	if path.is_empty():
		return INF
	var metres := 0.0
	for i in range(path.size() - 1):
		metres += float(_links[path[i]][path[i + 1]])
	return metres

## The rooms walked through from `from` to `to`, both included, along the shortest route; empty when nothing
## joins them.
func route(from: StringName, to: StringName) -> Array[StringName]:
	return _path(from, to)

## Where to walk, in order, from anywhere in `from` to the room `to`: every link on the route, crossed. Empty
## in `to` itself or when nothing joins them.
func waypoints(from: StringName, to: StringName) -> Array[Waypoint]:
	var key := "%s|%s" % [from, to]
	var out: Array[Waypoint] = []
	if _ways.has(key):
		out.assign(_ways[key])
		return out
	var path := _path(from, to)
	for i in range(path.size() - 1):
		out.append_array(_crossing(path[i], path[i + 1]))
	_ways[key] = out
	return out

func _path(from: StringName, to: StringName) -> Array[StringName]:
	var none: Array[StringName] = []
	if not _links.has(from) or not _links.has(to):
		return none
	var best: Dictionary[StringName, float] = {from: 0.0}
	var came: Dictionary[StringName, StringName] = {}
	var settled: Dictionary[StringName, bool] = {}
	while true:
		var next := &""
		for room: StringName in best:
			if not settled.has(room) and (next == &"" or best[room] < best[next]):
				next = room
		if next == &"":
			return none
		if next == to:
			break
		settled[next] = true
		for other: StringName in _links[next]:
			var through: float = best[next] + _links[next][other]
			if not best.has(other) or through < best[other]:
				best[other] = through
				came[other] = next
	var path: Array[StringName] = [to]
	while path[0] != from:
		path.push_front(came[path[0]])
	return path

func _crossing(a: StringName, b: StringName) -> Array[Waypoint]:
	var key := "%s|%s" % [a, b]
	if (_via[a][b] as Array).is_empty() and not _walked_round.has(key):
		_walked_round[key] = true
		_via[a][b] = _around(a, b)
	var out: Array[Waypoint] = []
	out.assign(_via[a][b])
	return out

# --- Where to look ---------------------------------------------------------------------------------

## Where someone whose eye is at `eye` on `storey` looks to follow `points` to `end`, and how far that is on foot:
## the last of the points in plain sight before the route changes floor, or on a flight the far end of it; when
## none is in sight, the first corner of the way round whatever stands between — a flight in the hall — towards
## the first of them. What is looked at is the furthest place
## along the route in plain sight: past the last point in sight, as far along the leg to the next one as is still
## in sight, so the place slides along the route as the eye moves instead of jumping from one point to the next
## (the author, 2026-09-17: the compass jumped while walking straight on). The metres run from the eye to that
## place and on along the route, so they fall as the player walks it; measured through each room's middle, they
## rose from 8 to 9 walking towards the kids' room door.
func sight(storey: StoreyDef, eye_at: Vector3, points: Array[Waypoint], end: Vector3) -> Sight:
	var eye := Vector2(eye_at.x, eye_at.z)
	var out := Sight.new()
	var level := 0
	while level < points.size() and points[level].storey == storey:
		level += 1
	var next := 0
	if level < points.size() and level > 0 and _on_flight(storey, eye_at):
		out.at = points[level].at
		next = level + 1
	else:
		var seen := -1
		# From the far end back, so the first in sight is the answer.
		for i in range(level - 1, -1, -1):
			if clear(storey, eye, Vector2(points[i].at.x, points[i].at.z)):
				seen = i
				break
		if seen < 0:
			var first := points[0]
			var round := _round(storey, eye, Vector2(first.at.x, first.at.z))
			out.at = first.at if round == Vector2.INF else Vector3(round.x, first.at.y, round.y)
			next = 1 if round == Vector2.INF else 0
		else:
			out.at = points[seen].at
			next = seen + 1
			if next < level:
				out.at = _along(storey, eye, points[seen].at, points[next].at)
	out.metres = eye.distance_to(Vector2(out.at.x, out.at.z))
	var from := out.at
	for i in range(next, points.size()):
		out.metres += from.distance_to(points[i].at)
		from = points[i].at
	out.metres += from.distance_to(end)
	return out

## The furthest place from `a` towards `b` that `eye` sees, `a` itself in sight: halved in on `SIGHT_STEPS` times,
## then `WAY_JAMB` back towards `a`, so the line to it does not graze whatever ends the view (the attic ladder's
## guard, `WayProbe`, 2026-09-17).
func _along(storey: StoreyDef, eye: Vector2, a: Vector3, b: Vector3) -> Vector3:
	var lo := 0.0
	var hi := 1.0
	for i in range(SIGHT_STEPS):
		var mid := (lo + hi) * 0.5
		var p := a.lerp(b, mid)
		if clear(storey, eye, Vector2(p.x, p.z)):
			lo = mid
		else:
			hi = mid
	return a.lerp(b, maxf(lo - Balance.WAY_JAMB / maxf(a.distance_to(b), Balance.WAY_JAMB), 0.0))

## Whether an eye at `eye` stands on a flight that starts or ends on `storey`: over its treads, or `WAY_JAMB` off
## either end, and as high over the treads under it as a standing or crouching eye is, give or take a step. By
## its plan alone, an eye beside the basement flight or under its top end was on it, and the marker aimed up the
## flight through its guard (`WayProbe`, 2026-09-17).
func _on_flight(storey: StoreyDef, eye: Vector3) -> bool:
	for stair: StairDef in _plan.stairs:
		if _plan.storey_of(stair.lower_room) != storey and _plan.storey_of(stair.upper_room) != storey:
			continue
		var from_foot := Vector2(eye.x, eye.z) - stair.foot
		var along := from_foot.dot(stair.direction)
		var across := absf(from_foot.dot(Vector2(-stair.direction.y, stair.direction.x)))
		if along < -Balance.WAY_JAMB or along > stair.run + Balance.WAY_JAMB or across > stair.width * 0.5:
			continue
		var lower := _plan.find_room(stair.lower_room).floor_y(_plan.storey_of(stair.lower_room).base_y)
		var upper := _plan.find_room(stair.upper_room).floor_y(_plan.storey_of(stair.upper_room).base_y)
		var above := eye.y - lerpf(lower, upper, clampf(along / stair.run, 0.0, 1.0))
		if above >= Balance.CROUCH_EYE_HEIGHT - Balance.STEP_HEIGHT and above <= Balance.EYE_HEIGHT + Balance.STEP_HEIGHT:
			return true
	return false

## The first corner on the shortest way from `eye` to `to` past the flights on this storey, each corner pushed
## `Balance.WAY_ROUND` off them; INF when there is none.
func _round(storey: StoreyDef, eye: Vector2, to: Vector2) -> Vector2:
	var nodes: Array[Vector2] = [eye]
	for stair: StairDef in _plan.stairs:
		if _plan.storey_of(stair.lower_room) != storey and _plan.storey_of(stair.upper_room) != storey:
			continue
		var rect := stair.footprint()
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)] as Array[Vector2]:
			var out := corner + (corner - rect.get_center()).sign() * Balance.WAY_ROUND
			if _plan.room_at(Vector3(out.x, storey.base_y + 1.0, out.y), ProbeCuller.STOREY_SLACK) != null:
				nodes.append(out)
	nodes.append(to)
	var last := nodes.size() - 1
	var best: Array[float] = []
	best.resize(nodes.size())
	best.fill(INF)
	best[0] = 0.0
	var came: Array[int] = []
	came.resize(nodes.size())
	came.fill(-1)
	var settled: Array[bool] = []
	settled.resize(nodes.size())
	settled.fill(false)
	while true:
		var next := -1
		for i in range(nodes.size()):
			if not settled[i] and best[i] < INF and (next < 0 or best[i] < best[next]):
				next = i
		if next < 0 or next == last:
			break
		settled[next] = true
		for i in range(nodes.size()):
			if settled[i] or not clear(storey, nodes[next], nodes[i]):
				continue
			var through := best[next] + nodes[next].distance_to(nodes[i])
			if through < best[i]:
				best[i] = through
				came[i] = next
	if came[last] < 0:
		return Vector2.INF
	var at := last
	while came[at] > 0:
		at = came[at]
	return nodes[at]

# --- In plain sight --------------------------------------------------------------------------------

## Whether a person walks through it. A garage door is built shut (`HouseBuilder`), so it is a wall.
static func passable(opening: Opening) -> bool:
	return opening.kind == Opening.Kind.DOOR or opening.kind == Opening.Kind.ARCH

## Whether a straight line on one storey's floor meets nothing built: no wall face, except through a doorway
## or an arch with `Balance.WAY_JAMB` to spare at either side, and no flight or stairwell, except across the
## end it is walked onto from. `through_doors` false shuts every doorway, for a way round the outside.
func clear(storey: StoreyDef, p: Vector2, q: Vector2, through_doors := true) -> bool:
	var faces := _faces[storey]
	var walls: Array = _face_walls[storey]
	var offsets := _face_offsets[storey]
	for i in range(0, faces.size(), 2):
		var hit: Variant = Geometry2D.segment_intersects_segment(p, q, faces[i], faces[i + 1])
		if hit == null:
			continue
		var wall: WallSegment = walls[i / 2]
		if not through_doors or not _in_doorway(wall, (hit as Vector2 - offsets[i / 2] - wall.a).dot(wall.dir())):
			return false
	var edges := _flight_edges[storey]
	var open: Array = _flight_open[storey]
	for i in range(0, edges.size(), 2):
		if not open[i / 2] and Geometry2D.segment_intersects_segment(p, q, edges[i], edges[i + 1]) != null:
			return false
	return true

static func _in_doorway(wall: WallSegment, u: float) -> bool:
	for opening: Opening in wall.openings:
		if passable(opening) and u >= opening.u0() + Balance.WAY_JAMB and u <= opening.u1() - Balance.WAY_JAMB:
			return true
	return false

func _index_obstacles(storey: StoreyDef) -> void:
	var faces := PackedVector2Array()
	var walls: Array[WallSegment] = []
	var offsets := PackedVector2Array()
	for wall: WallSegment in storey.walls:
		var half := wall.normal() * wall.thickness * 0.5
		for face: Vector2 in [half, -half] as Array[Vector2]:
			faces.append_array([wall.a + face, wall.b + face])
			walls.append(wall)
			offsets.append(face)
	_faces[storey] = faces
	_face_walls[storey] = walls
	_face_offsets[storey] = offsets
	var edges := PackedVector2Array()
	var open: Array[bool] = []
	for stair: StairDef in _plan.stairs:
		for from_below: bool in [true, false] as Array[bool]:
			var room := stair.lower_room if from_below else stair.upper_room
			if _plan.storey_of(room) != storey:
				continue
			_flight(stair, from_below, edges, open)
	_flight_edges[storey] = edges
	_flight_open[storey] = open

## Seen from its lower floor, a flight is in the way where its treads are below `Balance.WAY_HEADROOM`, and is
## walked onto across its foot; beyond that it passes overhead. Seen from its upper floor it is a railed
## hole, walked onto across its head.
func _flight(stair: StairDef, from_below: bool, edges: PackedVector2Array, open: Array[bool]) -> void:
	var across := Vector2(-stair.direction.y, stair.direction.x) * stair.width * 0.5
	var rise := _plan.storey_of(stair.upper_room).base_y - _plan.storey_of(stair.lower_room).base_y
	var start := stair.foot
	var end := stair.head()
	if from_below:
		end = stair.foot + stair.direction * stair.run * clampf(Balance.WAY_HEADROOM / maxf(rise, 0.01), 0.0, 1.0)
	var open_edge := stair.foot if from_below else stair.head()
	var corners: Array[Vector2] = [start + across, end + across, end - across, start - across]
	for i in range(4):
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		edges.append_array([a, b])
		open.append(((a + b) * 0.5).is_equal_approx(open_edge))

## From one exterior zone into another without going through the house: from the edge of `a` nearest `b`,
## past whichever outside corners of the house are in the way, into `b`. The shortest such line among the
## corners, each pushed `Balance.WAY_CORNER_OUT` off the house on both axes.
func _around(a: StringName, b: StringName) -> Array[Waypoint]:
	var zone_a := _plan.find_room(a)
	var zone_b := _plan.find_room(b)
	var storey := _plan.storey_of(a)
	var start := _inside(zone_a, _nearest_on(zone_a, zone_b.centroid()))
	var end := _inside(zone_b, _nearest_on(zone_b, start))
	var points: Array[Vector2] = [start]
	points.append_array(_corners(storey))
	points.append(end)
	# Dijkstra over the corners, joined where one sees the next with every wall shut.
	var last := points.size() - 1
	var best: Array[float] = []
	best.resize(points.size())
	best.fill(INF)
	best[0] = 0.0
	var came: Array[int] = []
	came.resize(points.size())
	came.fill(-1)
	var settled: Array[bool] = []
	settled.resize(points.size())
	settled.fill(false)
	while true:
		var next := -1
		for i in range(points.size()):
			if not settled[i] and best[i] < INF and (next < 0 or best[i] < best[next]):
				next = i
		if next < 0 or next == last:
			break
		settled[next] = true
		for i in range(points.size()):
			if settled[i] or not clear(storey, points[next], points[i], false):
				continue
			var through := best[next] + points[next].distance_to(points[i])
			if through < best[i]:
				best[i] = through
				came[i] = next
	var out: Array[Waypoint] = []
	if came[last] < 0:
		out.append(_point(b, end))
		return out
	var at := last
	while at >= 0:
		out.push_front(Waypoint.new(Vector3(points[at].x, 0.0, points[at].y), storey))
		at = came[at]
	for w: Waypoint in out:
		w.at.y = zone_a.floor_y(storey.base_y)
	return out

## Every outside corner of a storey's shell, pushed off it diagonally, and outside every room that is not
## an exterior zone.
func _corners(storey: StoreyDef) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var push := Balance.WAY_CORNER_OUT
	for wall: WallSegment in storey.walls:
		if not wall.is_exterior():
			continue
		for end: Vector2 in [wall.a, wall.b] as Array[Vector2]:
			for side: Vector2 in [Vector2(push, push), Vector2(push, -push), Vector2(-push, push),
					Vector2(-push, -push)] as Array[Vector2]:
				var p := end + side
				if not _built_over(storey, p) and not out.has(p):
					out.append(p)
	return out

func _built_over(storey: StoreyDef, p: Vector2) -> bool:
	for room: RoomDef in storey.rooms:
		if room.zone != RoomDef.Zone.EXTERIOR and room.contains(p):
			return true
	return false

static func _nearest_on(room: RoomDef, to: Vector2) -> Vector2:
	var best := room.polygon[0]
	for i in range(room.polygon.size()):
		var p := Geometry2D.get_closest_point_to_segment(to, room.polygon[i],
				room.polygon[(i + 1) % room.polygon.size()])
		if p.distance_to(to) < best.distance_to(to):
			best = p
	return best

## A point on a zone's edge, moved `Balance.WAY_CORNER_OUT` into it, so a line ending there ends in the zone.
static func _inside(room: RoomDef, edge: Vector2) -> Vector2:
	var into := edge + (room.centroid() - edge).limit_length(Balance.WAY_CORNER_OUT)
	return into if room.contains(into) else edge

## A doorway between two rooms, or between a room and whatever is outside it: a door in an exterior wall
## leads to the zone on its far side if there is one, and onto the ground otherwise, from where every
## exterior zone is walked to across the open. It is crossed from `Balance.WAY_APPROACH` in front of it to as
## far past it, straight through; `towards_a` is the wall's normal, which points into `room_a`.
func _join(room_a: StringName, room_b: StringName, at: Vector2, towards_a: Vector2) -> void:
	var side_a := at + towards_a * Balance.WAY_APPROACH
	var side_b := at - towards_a * Balance.WAY_APPROACH
	if room_a != &"":
		side_a = _approach(room_a, at, towards_a)
	if room_b != &"":
		side_b = _approach(room_b, at, -towards_a)
	if room_a != &"" and room_b != &"":
		_link(room_a, room_b, _reach(room_a, at) + _reach(room_b, at), [_point(room_a, side_a), _point(room_b, side_b)],
				[_point(room_b, side_b), _point(room_a, side_a)])
		return
	var inside := room_a if room_a != &"" else room_b
	if inside == &"":
		return
	var in_front := side_a if room_a != &"" else side_b
	var outside := side_b if room_a != &"" else side_a
	for room: RoomDef in _plan.all_rooms():
		if room.zone != RoomDef.Zone.EXTERIOR:
			continue
		if room.contains(at) or _reach(room.id, at) < Balance.DOOR_CLEARANCE * 4.0:
			_link(inside, room.id, _reach(inside, at) + _reach(room.id, at),
					[_point(inside, in_front), _point(room.id, outside)], [_point(room.id, outside), _point(inside, in_front)])

## `from_a` and `from_b` are where the link is crossed walking from each end; none for two exterior zones,
## whose way round the house is only worked out if a route takes it.
func _link(a: StringName, b: StringName, metres: float, from_a: Array[Waypoint] = [],
		from_b: Array[Waypoint] = []) -> void:
	if a == &"" or b == &"" or a == b or not _links.has(a) or not _links.has(b):
		return
	if not _links[a].has(b) or metres < float(_links[a][b]):
		_links[a][b] = metres
		_links[b][a] = metres
		_via[a][b] = from_a
		_via[b][a] = from_b

## Up to `Balance.WAY_APPROACH` from `at` along `away`, and short of the room's edge by `Balance.WAY_JAMB`,
## so a place to stand in front of a doorway or a flight is in the room: the attic ladder arrives a hand's
## width from the attic's knee wall.
func _approach(room: StringName, at: Vector2, away: Vector2) -> Vector2:
	var def := _plan.find_room(room)
	var reach := Balance.WAY_APPROACH
	while reach > Balance.WAY_JAMB and not def.contains(at + away * (reach + Balance.WAY_JAMB)):
		reach -= Balance.WAY_JAMB * 0.5
	return at + away * reach

## A plan point on the floor of a room.
func _point(room: StringName, at: Vector2) -> Waypoint:
	var def := _plan.find_room(room)
	var storey := _plan.storey_of(room)
	return Waypoint.new(Vector3(at.x, def.floor_y(storey.base_y), at.y), storey)

## From a room's middle to a plan point, on the floor: the two legs a doorway link is made of.
func _reach(room: StringName, at: Vector2) -> float:
	return Vector2(_middle[room].x - at.x, _middle[room].z - at.y).length()
