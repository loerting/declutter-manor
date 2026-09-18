class_name Clearance
## The floor that has to stay clear, as plan polygons: in front of doorways, at both ends of a
## flight, in front of windows for anything taller than the sill. `FurnitureProbe` keeps furniture
## out of it and `ContentImport` keeps item starts out of it, so the two cannot disagree about
## where a doorway is — or about whether a start is inside a piece (`buried`). Dev only: the game
## itself never asks.

## Kept clear in front of every door and archway, on both sides: a body walks through a doorway
## straight, and a thing in that metre is a thing the player walks into.
const DOORWAY_DEPTH := 0.9
## Kept clear beyond both ends of a flight, in the room at each end.
const STAIR_LANDING := 0.9
## A piece whose back is this close to a window's wall stands in front of the window if it is
## taller than the sill.
const WINDOW_REACH := 0.5
## Kept clear in front of every drawer, door and lid on the floor: a drawer's travel and a body
## standing at it.
const FRONT_REACH := 0.75
## Areas below this are touching, not overlapping.
const OVERLAP_AREA := 0.0001
## An item whose shape reaches into anything solid by more than this is inside it.
const ITEM_SKIN := 0.005
## The surface under an item is looked for from this far over its top.
const REST_START := 0.001

## The floor in front of every door, archway and garage door in the walls of `room`, on its side.
static func doorways(plan: FloorPlan, room: RoomDef) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for wall: WallSegment in walls_of(plan, room):
		var inward := wall.normal() * (1.0 if wall.room_a == room.id else -1.0)
		var face := wall.thickness * 0.5
		for o: Opening in wall.openings:
			if o.kind != Opening.Kind.WINDOW:
				out.append(strip(wall, o.u0(), o.u1(), inward * face, inward * (face + DOORWAY_DEPTH)))
	return out

## The floor in front of every window in the walls of `room` whose sill is lower than `height`.
static func windows(plan: FloorPlan, room: RoomDef, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for wall: WallSegment in walls_of(plan, room):
		var inward := wall.normal() * (1.0 if wall.room_a == room.id else -1.0)
		var face := wall.thickness * 0.5
		for o: Opening in wall.openings:
			if o.kind == Opening.Kind.WINDOW and height > o.sill:
				out.append(strip(wall, o.u0(), o.u1(), inward * face, inward * (face + WINDOW_REACH)))
	return out

## Every flight that starts or ends in `room`, with a landing's length added at both ends.
static func stairs(plan: FloorPlan, room: RoomDef) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stair: StairDef in plan.stairs:
		if stair.lower_room != room.id and stair.upper_room != room.id:
			continue
		var along := Vector2(absf(stair.direction.x), absf(stair.direction.y)) * STAIR_LANDING
		out.append(rect_polygon(stair.footprint().grow_individual(along.x, along.y, along.x, along.y)))
	return out

## The open water of every pool cut into `room`: no item starts in it. Not one of `zones`, because the diving
## board stands out over the water on purpose.
static func water(plan: FloorPlan, room: RoomDef) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for pool: PoolDef in plan.pools_in(room.id):
		out.append(rect_polygon(pool.rect))
	return out

## The floor an item at `xform` covers, as a plan polygon: the hull of its bounds' corners.
static func item_footprint(def: ItemDef, xform: Transform3D) -> PackedVector2Array:
	var box := ItemFactory.extent(def)
	var corners := PackedVector2Array()
	for k in range(8):
		var c := xform * box.get_endpoint(k)
		corners.append(Vector2(c.x, c.z))
	return Geometry2D.convex_hull(corners)

## All three, for something of `height` standing in `room`.
static func zones(plan: FloorPlan, room: RoomDef, height: float) -> Array[PackedVector2Array]:
	var out := doorways(plan, room)
	out.append_array(stairs(plan, room))
	out.append_array(windows(plan, room, height))
	return out

## The room's floor inside the wall faces.
static func inner(room: RoomDef) -> Rect2:
	return FurnitureBuilder.bounds(room).grow(-WallDeriver.DEFAULT_THICKNESS * 0.5)

## The floor in front of `container` on `piece`, across its front and `FRONT_REACH` out from the
## piece's footprint, as a plan polygon.
static func front(piece: FurnitureNode, container: ContainerComponent) -> PackedVector2Array:
	var box := piece.global_transform.affine_inverse() * container.handle_bounds()
	var out := PackedVector2Array()
	for local: Vector3 in [Vector3(box.position.x, 0, piece.footprint.y), Vector3(box.end.x, 0, piece.footprint.y),
			Vector3(box.end.x, 0, piece.footprint.y + FRONT_REACH), Vector3(box.position.x, 0, piece.footprint.y + FRONT_REACH)]:
		var p := piece.global_transform * local
		out.append(Vector2(p.x, p.z))
	return out

## The floor a piece covers, as a plan polygon.
static func footprint(piece: FurnitureNode) -> PackedVector2Array:
	var half := piece.footprint.x * 0.5
	var out := PackedVector2Array()
	for local: Vector3 in [Vector3(-half, 0, 0), Vector3(half, 0, 0),
			Vector3(half, 0, piece.footprint.y), Vector3(-half, 0, piece.footprint.y)]:
		var p := piece.global_transform * local
		out.append(Vector2(p.x, p.z))
	return out

static func walls_of(plan: FloorPlan, room: RoomDef) -> Array[WallSegment]:
	var out: Array[WallSegment] = []
	for wall: WallSegment in plan.storey_of(room.id).walls:
		if wall.room_a == room.id or wall.room_b == room.id:
			out.append(wall)
	return out

## The strip of floor beside a stretch of wall from `u0` to `u1`, between two offsets from its line.
static func strip(wall: WallSegment, u0: float, u1: float, near: Vector2, far: Vector2) -> PackedVector2Array:
	return PackedVector2Array([wall.at_u(u0) + near, wall.at_u(u1) + near,
			wall.at_u(u1) + far, wall.at_u(u0) + far])

static func rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])

static func overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var area := 0.0
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		var sum := 0.0
		for i in range(poly.size()):
			sum += poly[i].cross(poly[(i + 1) % poly.size()])
		area += absf(sum) * 0.5
	return area

## True when `polygon` overlaps any of `zones`.
static func blocked(polygon: PackedVector2Array, zone_list: Array[PackedVector2Array]) -> bool:
	for zone: PackedVector2Array in zone_list:
		if overlap(polygon, zone) > OVERLAP_AREA:
			return true
	return false

## How far an item whose solid has `points` (world space) stands over what is drawn under it: the least, over its
## points, of the height of the point over the first surface a ray finds straight down from just over the item's
## top. Negative is sunk: that surface passes through the item above the point. 0 is resting on it; INF is
## nothing within `look` under it. Looked for from just over the item and not from higher, so the seat of a bench
## over a towel on its shelf is not taken for something the towel has sunk into (2026-09-17). A ray from inside a
## piece does not find its top face from behind, so a sunk point cannot be found looking up from it.
static func standing(space: PhysicsDirectSpaceState3D, points: PackedVector3Array, look: float) -> float:
	var top := -INF
	for p: Vector3 in points:
		top = maxf(top, p.y)
	var gap := INF
	for p: Vector3 in points:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, top + REST_START, p.z),
				p - Vector3.UP * look, Layers.drawn_mask()))
		if not hit.is_empty():
			gap = minf(gap, p.y - (hit["position"] as Vector3).y)
	return gap

## True when an item at `xform` is inside something drawn in `space`: a point of its hull is under the top face
## of something by more than `ITEM_SKIN` (`standing`). Measured on the hull, not a box: a box shrunk by a skin
## still reaches through the curve of a car's bonnet or a pillow it lies on.
static func buried(space: PhysicsDirectSpaceState3D, def: ItemDef, xform: Transform3D) -> bool:
	return standing(space, xform * ItemFactory.hull(def).points, ITEM_SKIN) < -ITEM_SKIN
