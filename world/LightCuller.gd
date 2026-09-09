class_name LightCuller
extends Node
## Burns the bulbs of the room the eye is in and of the rooms it opens onto, and no others.
##
## A shadowed omni light re-renders everything in its range: with every bulb in the manor
## shadowed, `PerfProbe` measured the low tier at 39,704 draw calls. The first answer to that
## was to shadow only the four nearest bulbs and leave the rest burning without shadow maps —
## which is what the author walked into on 2026-09-09: **a light with no shadow map shines
## through walls.** Twenty-two bulbs were lighting rooms they are not in, the set of them
## changed as the player moved, and so the lighting in a room changed as it was entered.
##
## So the rule is the house's, not the camera's. A bulb burns when the eye is in its room or in
## a room that shares a wall or a flight of stairs with it, and every burning bulb casts
## shadows. Nothing burns unshadowed, so nothing lights through a wall, and a bulb that changes
## state is at least two rooms away — behind two walls, where the change cannot be seen.
##
## Wire it with `initialize(plan, lights, camera)`; it takes the plan because adjacency is a
## fact about the floor plan, and it takes the lights because it does not know how to find them
## (rule 5).

## How often the eye's room is looked up again. The player walks 2.8 m/s, so this is 7 cm.
const INTERVAL := 0.025
## Of the bulbs that burn, how many carry a shadow map. Every burning bulb having one is the
## honest arrangement and `PerfProbe` measured it at 18.3 ms a frame against a 16.7 budget, for
## eight shadow maps at once. Three is the room the eye is in and the two nearest rooms it opens
## onto; the rest of the neighbours are fill light through a doorway, which is what they are.
const SHADOWED := 3
## Vertical slack when deciding which storey the eye is on, so standing on a stair nose or a
## step down into the garage does not put the eye in no room at all.
const STOREY_SLACK := 0.4

var _lights: Array[RoomLight] = []
var _camera: Camera3D
## room id -> Array[StringName]: the rooms whose bulbs burn when the eye is in this one.
var _neighbours: Dictionary = {}
## room id -> Array: [RoomDef, StoreyDef], for placing the eye.
var _rooms: Dictionary = {}
var _clock := 0.0
var _current: StringName = &""
## False until the eye has been placed in a room once, which is what tells "outdoors, and the
## house behind me" apart from "the very first frame".
var _placed := false

func initialize(plan: FloorPlan, lights: Array[RoomLight], camera: Camera3D) -> void:
	_lights = lights
	_camera = camera
	_index(plan)
	_apply(_room_at(camera.global_position))

func _ready() -> void:
	assert(_camera != null, "LightCuller: initialize() before adding to the tree")

func _process(delta: float) -> void:
	_clock += delta
	if _clock < INTERVAL:
		return
	_clock = 0.0
	var here := _room_at(_camera.global_position)
	if here == _current and _placed:
		return
	_apply(here)

## Which rooms each room opens onto: everything it shares a wall with, plus everything a flight
## connects it to, plus itself. Derived, so a plan change cannot leave a stale list behind.
func _index(plan: FloorPlan) -> void:
	for storey: StoreyDef in plan.storeys:
		for room: RoomDef in storey.rooms:
			_rooms[room.id] = [room, storey]
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
	var plan_point := Vector2(eye.x, eye.z)
	for id: StringName in _rooms:
		var room: RoomDef = _rooms[id][0]
		var storey: StoreyDef = _rooms[id][1]
		if not room.contains(plan_point):
			continue
		var base := room.floor_y(storey.base_y)
		if eye.y >= base - STOREY_SLACK and eye.y <= storey.ceiling_y() + STOREY_SLACK:
			return id
	return &""

## Burns the bulbs of `here` and its neighbours. Outdoors lights nothing: the sun is the only
## thing lighting the garden, and a bulb seen through a window is the window's business.
func _apply(here: StringName) -> void:
	if here == &"":
		# A threshold, or the garden with the house behind you. Once the eye has been in a room,
		# the house keeps the lighting it had — stepping over a boundary must not change it.
		if _placed:
			return
		# It never has: this is a camera outside the building, which is every exterior gate
		# render. The house lights itself the way it did before there was a culler, and pays
		# nothing for it, because an unshadowed light costs one pass.
		for light: RoomLight in _lights:
			light.visible = true
			light.shadow_enabled = false
		return
	_current = here
	_placed = true
	var on: Array[StringName] = _neighbours.get(here, [] as Array[StringName])
	var burning: Array[RoomLight] = []
	for light: RoomLight in _lights:
		light.visible = on.has(light.room)
		light.shadow_enabled = false
		if light.visible:
			burning.append(light)
	# The eye's own room first, then the nearest of the rooms it opens onto. Ranking only the
	# burning ones is what keeps this stable: the set changes when the eye changes room, not as
	# it walks about inside one.
	var eye := _camera.global_position
	burning.sort_custom(func(a: RoomLight, b: RoomLight) -> bool:
		if (a.room == here) != (b.room == here):
			return a.room == here
		return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	for i in range(mini(SHADOWED, burning.size())):
		burning[i].shadow_enabled = true

## Every RoomLight under a node, for callers that built the house and want its bulbs.
static func collect(root: Node) -> Array[RoomLight]:
	var out: Array[RoomLight] = []
	var light := root as RoomLight
	# a bulb switched off for daylight is not a candidate at all
	if light != null and light.light_energy > 0.0:
		out.append(light)
	for child: Node in root.get_children():
		out.append_array(collect(child))
	return out
