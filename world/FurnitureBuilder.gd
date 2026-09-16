class_name FurnitureBuilder
## The furniture, from content. `HouseBuilder` builds the shell; this stands every piece a
## location's `Catalogue` lists in the room it names, and hangs the place-slot groups it carries.
##
## Where a piece stands is derived from the plan, never typed: a `FurnitureDef` says which wall of
## which room and how far along it, so moving the room moves the furniture with it.

##
## `pieces` are the generated pieces of `content.furniture` in its order (`Generation.run`).
static func build(plan: FloorPlan, content: Catalogue, pieces: Array[FurnitureNode]) -> Node3D:
	assert(pieces.size() == content.furniture.size(), "FurnitureBuilder: pieces are not the catalogue's")
	var root := Node3D.new()
	root.name = "Furniture"
	var layers := RoomLayers.derive(plan)
	for i in range(pieces.size()):
		var def := content.furniture[i]
		var piece := pieces[i]
		if piece == null:
			continue
		var room := plan.find_room(def.room)
		if room == null:
			push_error("FurnitureBuilder: '%s' stands in no room '%s'" % [def.id, def.room])
			piece.free()
			continue
		piece.transform = placement(plan, def, piece.footprint)
		hang_slots(piece)
		# On its room's render layer, so that room's bulb lights it and no other does.
		RoomLayers.stamp(piece, RoomLayers.mask(layers, room.id))
		root.add_child(piece)
	return root

## Where a piece of that footprint stands, in world space: its back `out` metres off the face of
## the wall its def names, facing into the room.
static func placement(plan: FloorPlan, def: FurnitureDef, footprint: Vector2) -> Transform3D:
	var room := plan.find_room(def.room)
	assert(room != null, "FurnitureBuilder: '%s' stands in no room '%s'" % [def.id, def.room])
	var inner := bounds(room).grow(-WallDeriver.DEFAULT_THICKNESS * 0.5)
	var inward := inward_of(def.wall)
	# Along the wall runs east for a north or south wall and south for an east or west one, from
	# the corner the wall starts at.
	var run := Vector2(absf(inward.y), absf(inward.x))
	var start := Vector2(inner.end.x if inward.x < 0.0 else inner.position.x,
			inner.end.y if inward.y < 0.0 else inner.position.y)
	var length := inner.size.x if run.x > 0.0 else inner.size.y
	var middle := 0.0
	match def.align:
		FurnitureDef.Align.START:
			middle = def.along + footprint.x * 0.5
		FurnitureDef.Align.END:
			middle = length - def.along - footprint.x * 0.5
		_:
			middle = length * 0.5 + def.along
	var back := start + run * middle + inward * def.out
	# Local +Z onto `inward`: a rotation about Y by θ takes +Z to (sin θ, 0, cos θ).
	var yaw := atan2(inward.x, inward.y) + deg_to_rad(def.turn_degrees)
	var y := room.floor_y(plan.storey_of(room.id).base_y)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(back.x, y, back.y))

## The plan direction from a wall into its room. North is -Z.
static func inward_of(wall: FurnitureDef.Wall) -> Vector2:
	match wall:
		FurnitureDef.Wall.NORTH:
			return Vector2(0, 1)
		FurnitureDef.Wall.SOUTH:
			return Vector2(0, -1)
		FurnitureDef.Wall.WEST:
			return Vector2(1, 0)
	return Vector2(-1, 0)

static func bounds(room: RoomDef) -> Rect2:
	var r := Rect2(room.polygon[0], Vector2.ZERO)
	for p: Vector2 in room.polygon:
		r = r.expand(p)
	return r

## Each group under the anchor it names, holding the container that anchor belongs to — a group
## that requires an open container has to be able to ask one whether it is open.
static func hang_slots(piece: FurnitureNode) -> void:
	for group: PlaceSlotGroup in piece.def.slots:
		var at := piece.anchor(group.anchor)
		if at == null:
			push_error("FurnitureBuilder: '%s' has no anchor '%s' for group '%s'"
					% [piece.def.id, group.anchor, group.id])
			continue
		var slots := PlaceSlots.new()
		slots.initialize(group, piece.container_for(group.anchor))
		at.add_child(slots)
