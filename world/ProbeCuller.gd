class_name ProbeCuller
extends Node
## Keeps the reflection probes of the room the eye is in, and of the rooms it opens onto, and
## hides the rest.
##
## Twenty-six probes blending at once measured +4.6 ms a frame on the high tier
## (`dev/PerfProbe.tscn`, 2026-09-10), and a probe only affects what stands inside its own box,
## so one two rooms away changes nothing the eye can see.
##
## This used to be `LightCuller` and switched the bulbs the same way. That was the "lighting
## changes every time I enter a room" the author reported (2026-09-09, and again 2026-09-13):
## unshadowed bulbs shine through walls, so which bulbs were on decided how bright the room you
## were standing in was. Bulbs no longer switch at all — `RoomLayers` stops them lighting other
## rooms instead — and this only touches probes.
##
## Wire it with `initialize(plan, probes, camera)`; it takes the plan because adjacency is a fact
## about the floor plan, and it takes the probes because it does not know how to find them
## (rule 5).
##
## It is also the one place that knows which room the eye is in, so it announces a change of room
## (`EventBus.zone_entered`); the HUD shows that room's count.

## How often the eye's room is looked up again. The player walks 2.8 m/s, so this is 7 cm.
const INTERVAL := 0.025
## Vertical slack when deciding which storey the eye is on, so standing on a stair nose or a
## step down into the garage does not put the eye in no room at all.
const STOREY_SLACK := 0.4

var _probes: Array[RoomProbe] = []
var _camera: Camera3D
## room id -> Array[StringName]: the rooms whose probes stay on when the eye is in this one.
var _neighbours: Dictionary = {}
var _plan: FloorPlan
var _clock := 0.0
var _current: StringName = &""
## False until the eye has been placed in a room once, which is what tells "outdoors, and the
## house behind me" apart from "the very first frame".
var _placed := false
## The room last announced. Announced from `_process`, so whatever is added to the tree after this
## in the same frame hears the first room too.
var _announced: StringName = &""

func initialize(plan: FloorPlan, probes: Array[RoomProbe], camera: Camera3D) -> void:
	_probes = probes
	_camera = camera
	_plan = plan
	_index(plan)
	_apply(_room_at(camera.global_position))

func _ready() -> void:
	assert(_camera != null, "ProbeCuller: initialize() before adding to the tree")

func _process(delta: float) -> void:
	_clock += delta
	if _clock < INTERVAL:
		return
	_clock = 0.0
	var here := _room_at(_camera.global_position)
	if here != _current or not _placed:
		_apply(here)
	if _current == _announced:
		return
	if _announced != &"":
		EventBus.zone_exited.emit(_announced)
	_announced = _current
	EventBus.zone_entered.emit(_current)

## Which rooms each room opens onto: everything it shares a wall with, plus everything a flight
## connects it to, plus itself. Derived, so a plan change cannot leave a stale list behind.
func _index(plan: FloorPlan) -> void:
	for storey: StoreyDef in plan.storeys:
		for room: RoomDef in storey.rooms:
			_neighbours[room.id] = [room.id] as Array[StringName]
		for wall: WallSegment in storey.walls:
			if wall.room_a == &"" or wall.room_b == &"":
				continue
			_link(wall.room_a, wall.room_b)
	for stair: StairDef in plan.stairs:
		_link(stair.lower_room, stair.upper_room)

func _link(a: StringName, b: StringName) -> void:
	for pair: Array in [[a, b], [b, a]] as Array[Array]:
		var list: Array[StringName] = _neighbours.get(pair[0], [] as Array[StringName])
		if not list.has(pair[1]):
			list.append(pair[1])
		_neighbours[pair[0]] = list

## The room the eye is in, or `&""` when it is outdoors or in a stairwell between two.
func _room_at(eye: Vector3) -> StringName:
	var room := _plan.room_at(eye, STOREY_SLACK)
	return room.id if room != null else &""

func _apply(here: StringName) -> void:
	if here == &"":
		# A threshold, or the garden with the house behind you. Once the eye has been in a room,
		# the house keeps what it had — stepping over a boundary must not change it.
		if _placed:
			return
		# It never has: this is a camera outside the building, which sees into the house through
		# its windows and is not a frame anyone plays through.
		for probe: RoomProbe in _probes:
			probe.visible = true
		return
	_current = here
	_placed = true
	var on: Array[StringName] = _neighbours.get(here, [] as Array[StringName])
	for probe: RoomProbe in _probes:
		probe.visible = on.has(probe.room)

## Every RoomProbe under a node.
static func collect(root: Node) -> Array[RoomProbe]:
	var out: Array[RoomProbe] = []
	var probe := root as RoomProbe
	if probe != null:
		out.append(probe)
	for child: Node in root.get_children():
		out.append_array(collect(child))
	return out
