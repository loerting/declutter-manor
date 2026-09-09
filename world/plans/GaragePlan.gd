class_name GaragePlan
## The garage and its mudroom — the first thing Phase 1 builds, because it is interior and
## exterior at once and is the cheapest complete test that the plan model is right
## (`docs/HOUSE.md`). It exercises every case the full plan will hit: a wall that is outside on
## one side and a room on the other, a wall that is two different rooms, a garage door, a
## window with a projecting sill, a door between rooms, and a slab that sits below the house.
##
## Plan coordinates are the lot's, so this plan drops into the manor plan unchanged: the house
## footprint is x 4..17, z 6..15.5 and the garage is attached on its east side.
##
## Authored in code rather than as a .tres on purpose. A rectangle knows its own four walls, so
## the wall list is derived rather than typed twice, and a diff of a plan change stays readable.
## Phase 3's authoring tool writes .tres; until it exists, this is the reviewable form.

const GARAGE := Vector4(17.0, 6.0, 23.0, 12.5)   # x0, z0, x1, z1
const MUDROOM := Vector4(13.0, 6.0, 17.0, 12.5)
const DRIVEWAY := Vector4(15.5, 0.5, 23.5, 6.0)

## A garage slab sits a step below the house floor so water runs out rather than in.
const GARAGE_DROP := 0.15
const STOREY_HEIGHT := 2.7

static func build() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.id = &"garage_test"
	plan.lot = Rect2(0, 0, 26, 19)

	var ground := StoreyDef.new()
	ground.id = &"ground"
	ground.base_y = 0.0
	ground.height = STOREY_HEIGHT

	var garage := _rect_room(&"garage", "room.garage", GARAGE)
	garage.zone = RoomDef.Zone.GARAGE
	garage.floor_slot = "concrete"
	garage.wall_slot = "wall_plaster"
	garage.floor_drop = GARAGE_DROP

	var mudroom := _rect_room(&"mudroom", "room.mudroom", MUDROOM)
	mudroom.floor_slot = "floor_wood"

	var driveway := _rect_room(&"driveway", "room.driveway", DRIVEWAY)
	driveway.zone = RoomDef.Zone.EXTERIOR
	driveway.has_ceiling = false
	driveway.floor_slot = "concrete"
	driveway.floor_drop = 0.0

	ground.rooms = [garage, mudroom, driveway]
	ground.walls = _walls()
	plan.storeys = [ground]
	# One gable over both blocks, ridge running east-west, so the driveway looks at an eave and
	# the gable ends close the volume at each end. The full manor breaks this into a main block
	# and a garage wing; the point here is that the roof comes off the same footprint the rooms
	# do, not out of a separate authored shape.
	plan.roofs = [RoofDef.gable(Rect2(MUDROOM.x, MUDROOM.y, GARAGE.z - MUDROOM.x, GARAGE.w - GARAGE.y),
			STOREY_HEIGHT, true)]
	return plan

static func _rect_room(id: StringName, key: String, r: Vector4) -> RoomDef:
	return RoomDef.rect(id, key, r.x, r.y, r.z, r.w)

## Every wall is written as "walking from a to b, side A is on your right". The room named on
## each side is what decides its finish, so a swapped pair is a visible error and PlanProbe
## catches it before a render does.
static func _walls() -> Array[WallSegment]:
	var w: Array[WallSegment] = []

	# Garage, north face: the elevation you see from the driveway.
	w.append(WallSegment.make(Vector2(23, 6), Vector2(17, 6), &"", &"garage",
			[Opening.garage_door(3.0, 4.2, 2.2)] as Array[Opening]))
	# Garage, east face: a high window, above where a workbench will stand.
	w.append(WallSegment.make(Vector2(23, 12.5), Vector2(23, 6), &"", &"garage",
			[Opening.window(3.25, 1.0, 0.9, 1.5)] as Array[Opening]))
	# Garage, south face.
	w.append(WallSegment.make(Vector2(17, 12.5), Vector2(23, 12.5), &"", &"garage",
			[] as Array[Opening]))
	# The shared wall — garage on one side, house on the other, one door through both.
	w.append(WallSegment.make(Vector2(17, 12.5), Vector2(17, 6), &"garage", &"mudroom",
			[Opening.door(3.25)] as Array[Opening]))

	w.append(WallSegment.make(Vector2(17, 6), Vector2(13, 6), &"", &"mudroom",
			[Opening.window(2.0, 1.2, 1.1, 1.0)] as Array[Opening]))
	w.append(WallSegment.make(Vector2(13, 6), Vector2(13, 12.5), &"", &"mudroom",
			[Opening.door(3.25)] as Array[Opening]))
	w.append(WallSegment.make(Vector2(13, 12.5), Vector2(17, 12.5), &"", &"mudroom",
			[Opening.window(2.0, 1.2, 1.1, 1.0)] as Array[Opening]))
	return w
