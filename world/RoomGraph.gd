class_name RoomGraph
extends RefCounted
## The house as the player walks it: every room's middle, and the metres between rooms that are joined
## through a doorway, up a flight, or across open ground between two exterior zones. Built from the plan
## alone, so the pacing model and the HUD's way home read the same routes (`dev/PacingProbe.gd`).

## Two exterior zones are walked between across open ground, with no doorway between them.
const OUTDOORS_STEP := 1.0

var _plan: FloorPlan
## Room id -> room id -> metres between their middles, through a doorway or a flight.
var _links: Dictionary[StringName, Dictionary] = {}
var _middle: Dictionary[StringName, Vector3] = {}
## Room pair -> metres: asked for once per leg of every trip, and the answer never changes.
var _hops: Dictionary[String, float] = {}

func _init(plan: FloorPlan) -> void:
	_plan = plan
	for room: RoomDef in plan.all_rooms():
		var storey := plan.storey_of(room.id)
		var centre := room.centroid()
		_middle[room.id] = Vector3(centre.x, room.floor_y(storey.base_y), centre.y)
		_links[room.id] = {}
	for storey: StoreyDef in plan.storeys:
		for wall: WallSegment in storey.walls:
			for opening: Opening in wall.openings:
				if opening.kind == Opening.Kind.WINDOW:
					continue
				var along := (wall.b - wall.a).normalized()
				_join(wall.room_a, wall.room_b, wall.a + along * opening.at)
	for stair: StairDef in plan.stairs:
		var foot := stair.foot + stair.direction * stair.run * 0.5
		_link(stair.lower_room, stair.upper_room, _reach(stair.lower_room, foot) + _reach(stair.upper_room, foot)
				+ stair.run)
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
	var best: Dictionary[StringName, float] = {from: 0.0}
	var settled: Dictionary[StringName, bool] = {}
	while true:
		var next := &""
		for room: StringName in best:
			if not settled.has(room) and (next == &"" or best[room] < best[next]):
				next = room
		if next == &"":
			return INF
		if next == to:
			return best[to]
		settled[next] = true
		for other: StringName in _links[next]:
			var through: float = best[next] + _links[next][other]
			if not best.has(other) or through < best[other]:
				best[other] = through
	return INF

## A doorway between two rooms, or between a room and whatever is outside it: a door in an exterior wall
## leads to the zone on its far side if there is one, and onto the ground otherwise, from where every
## exterior zone is walked to across the open.
func _join(room_a: StringName, room_b: StringName, at: Vector2) -> void:
	if room_a != &"" and room_b != &"":
		_link(room_a, room_b, _reach(room_a, at) + _reach(room_b, at))
		return
	var inside := room_a if room_a != &"" else room_b
	if inside == &"":
		return
	for room: RoomDef in _plan.all_rooms():
		if room.zone != RoomDef.Zone.EXTERIOR:
			continue
		if room.contains(at) or _reach(room.id, at) < Balance.DOOR_CLEARANCE * 4.0:
			_link(inside, room.id, _reach(inside, at) + _reach(room.id, at))

func _link(a: StringName, b: StringName, metres: float) -> void:
	if a == &"" or b == &"" or a == b or not _links.has(a) or not _links.has(b):
		return
	if not _links[a].has(b) or metres < float(_links[a][b]):
		_links[a][b] = metres
		_links[b][a] = metres

## From a room's middle to a plan point, on the floor: the two legs a doorway link is made of.
func _reach(room: StringName, at: Vector2) -> float:
	return Vector2(_middle[room].x - at.x, _middle[room].z - at.y).length()
