class_name RoomLayers
## Which render layer each room is drawn on, and therefore which bulbs can light it.
##
## An omni light with no shadow map lights everything in its range, walls or not. The house has
## ~25 bulbs and cannot afford a shadow map for each (`docs/PACING.md`: 39,704 draw calls), so
## the first answer was to switch bulbs on and off around the player — and the author walked
## into the consequence twice: the hall rendered from one spot was bright with the eye in the hall
## and dim with the eye one step into the living room, because a different set of bulbs was
## shining through its walls (`dev/HouseView.gd --eye`, 2026-09-13, 61% of pixels changed).
##
## So nothing switches. Every bulb burns all the time, without a shadow map, and its
## `light_cull_mask` only contains its own room's layer: a bulb cannot light a room it is not
## in, whatever is between them. Two rooms may share a layer only when neither bulb can reach
## the other room at all, which is a greedy colouring of "bulb range touches room box" — the
## house needs far fewer layers than it has rooms.
##
## A wall is drawn on both its rooms' layers. That is correct rather than a leak: each face of it
## looks into one room, and a bulb on the other side sees that face from behind, which lights
## nothing.

## Anything any bulb may light: items, which move between rooms and are too small for the stray
## light through a wall to read as anything but brightness.
const SHARED := 1
const FIRST_ROOM := 2
const LAST_ROOM := 19
## The outside of the house — terrain, paving, the roof's top — which only the sun lights. The
## first rear render had three bulbs' pools of light on the lawn under the house.
const OUTDOOR := 20

## room id -> render layer (1-based, as the editor numbers them).
static func derive(plan: FloorPlan) -> Dictionary:
	var rooms: Array[RoomDef] = []
	var boxes: Dictionary = {}
	for storey: StoreyDef in plan.storeys:
		for room: RoomDef in storey.rooms:
			if room.zone == RoomDef.Zone.EXTERIOR:
				continue
			rooms.append(room)
			boxes[room.id] = _box(storey, room)
	var clash: Dictionary = {}
	for room: RoomDef in rooms:
		clash[room.id] = [] as Array[StringName]
	# A flight, its rails and its guards are drawn on both rooms it joins, so they stand in both
	# rooms' way: a bulb under the hall that reaches the foot of the stair must not share a layer
	# with the landing either (`dev/PlanProbe.gd`, light.leak, the utility bulb and the balusters).
	var flights: Array = []
	for stair: StairDef in plan.stairs:
		var lower := plan.storey_of(stair.lower_room)
		var upper := plan.storey_of(stair.upper_room)
		if lower == null or upper == null:
			continue
		var r := stair.footprint().grow(HouseBuilder.OPEN_PROBE)
		var y0 := plan.find_room(stair.lower_room).floor_y(lower.base_y)
		flights.append([AABB(Vector3(r.position.x, y0, r.position.y),
				Vector3(r.size.x, upper.ceiling_y() - y0, r.size.y)), stair.lower_room, stair.upper_room])
	for a: RoomDef in rooms:
		if a.light_energy <= 0.0:
			continue
		var storey := plan.storey_of(a.id)
		var at := HouseBuilder.bulb_position(storey, a)
		var reach := HouseBuilder.bulb_range(a)
		var reached: Array[StringName] = []
		for b: RoomDef in rooms:
			if b != a and _touches(boxes[b.id], at, reach):
				reached.append(b.id)
		for flight: Array in flights:
			if not _touches(flight[0], at, reach):
				continue
			for id: StringName in [flight[1], flight[2]] as Array[StringName]:
				if id != a.id and clash.has(id) and not reached.has(id):
					reached.append(id)
		for id: StringName in reached:
			(clash[a.id] as Array[StringName]).append(id)
			(clash[id] as Array[StringName]).append(a.id)
	# Most constrained first, which is what keeps a greedy colouring close to the fewest colours.
	rooms.sort_custom(func(x: RoomDef, y: RoomDef) -> bool:
		return (clash[x.id] as Array).size() > (clash[y.id] as Array).size())
	var out: Dictionary = {}
	for room: RoomDef in rooms:
		var layer := FIRST_ROOM
		while _taken(out, clash[room.id], layer):
			layer += 1
		assert(layer <= LAST_ROOM, "RoomLayers: '%s' needs layer %d; there are %d" % [
				room.id, layer, LAST_ROOM - FIRST_ROOM + 1])
		out[room.id] = layer
	return out

## The mask for a room id, or for the outside when the id is empty or an exterior zone.
static func mask(layers: Dictionary, room_id: StringName) -> int:
	if not layers.has(room_id):
		return bit(OUTDOOR)
	return bit(layers[room_id])

static func bit(layer: int) -> int:
	return 1 << (layer - 1)

## Puts every drawable under `node` on `layer_mask`, and makes every bulb among them light only
## that mask and the shared layer.
static func stamp(node: Node, layer_mask: int) -> void:
	var light := node as RoomLight
	if light != null:
		light.light_cull_mask = layer_mask | bit(SHARED)
	var drawn := node as GeometryInstance3D
	if drawn != null:
		drawn.layers = layer_mask
	for child: Node in node.get_children():
		stamp(child, layer_mask)

## `stamp` for the children `parent` gained since it had `from` of them — how a builder that adds
## straight into a shared parent says "whatever that call just built".
static func stamp_since(parent: Node, from: int, layer_mask: int) -> void:
	for i in range(from, parent.get_child_count()):
		stamp(parent.get_child(i), layer_mask)

static func _box(storey: StoreyDef, room: RoomDef) -> AABB:
	var r := Rect2(room.polygon[0], Vector2.ZERO)
	for p: Vector2 in room.polygon:
		r = r.expand(p)
	# Out to the middle of its walls and through its floor and ceiling slabs, because that is
	# where the geometry drawn on its layer actually stands: the wall footings of the storey
	# above are in this room's ceiling slab.
	r = r.grow(WallDeriver.DEFAULT_THICKNESS)
	var y0 := room.floor_y(storey.base_y) - storey.slab_thickness
	return AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, storey.ceiling_y() + storey.slab_thickness - y0, r.size.y))

static func _touches(box: AABB, at: Vector3, reach: float) -> bool:
	var nearest := at.clamp(box.position, box.end)
	return nearest.distance_to(at) < reach

static func _taken(out: Dictionary, clashes: Array[StringName], layer: int) -> bool:
	for other: StringName in clashes:
		if out.get(other, -1) == layer:
			return true
	return false
