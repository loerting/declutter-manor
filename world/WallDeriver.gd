class_name WallDeriver
## Builds a storey's wall list from its rooms, instead of the wall list being typed out beside
## them. Two rectangles that share an edge imply a wall between them, and that wall knows both
## rooms — which is exactly the fact `WallSegment` needs and exactly the fact a human gets wrong.
##
## The garage plan was authored by hand: seven walls, each naming two sides, each an opportunity
## to name the wrong one. At 26 zones that stops being an opportunity and becomes a certainty,
## so the derivation is the authoring tool for the manor.
##
## Rooms must be axis-aligned rectangles here. Non-rectangular zones (an L-shaped landing, the
## pool surround) are authored as several rectangles that touch, which is also what makes their
## shared edges disappear automatically.

const EPS := 0.001
## The thickness every derived wall gets, and the number anything standing against a wall has
## to know to find its face — `FurnitureBuilder` is the second reader.
const DEFAULT_THICKNESS := 0.20

## Every wall implied by `rooms`, with sides correctly assigned. Openings are added afterwards
## with `pierce()`; a derived wall starts solid.
## Exterior zones are ground, not building, so they imply no walls — a driveway does not put a
## wall between itself and the lawn. A fence or a parapet is authored explicitly.
static func derive(all_rooms: Array[RoomDef], thickness := DEFAULT_THICKNESS) -> Array[WallSegment]:
	var rooms: Array[RoomDef] = []
	for room: RoomDef in all_rooms:
		if room.zone != RoomDef.Zone.EXTERIOR:
			rooms.append(room)
	var walls: Array[WallSegment] = []
	walls.append_array(_axis(rooms, true, thickness))
	walls.append_array(_axis(rooms, false, thickness))
	return walls

## `vertical` walls run along Z at a constant X; horizontal ones run along X at a constant Z.
## The two cases are the same algorithm with the coordinates swapped, so they share one body and
## cannot disagree about which side is which.
static func _axis(rooms: Array[RoomDef], vertical: bool, thickness: float) -> Array[WallSegment]:
	# lines[position][.] collects, for each candidate wall line, the rooms lying on each side.
	var lines: Dictionary = {}
	for room: RoomDef in rooms:
		var r := _bounds(room.polygon)
		var lo := r.position.x if vertical else r.position.y
		var hi := r.end.x if vertical else r.end.y
		var span := Vector2(r.position.y, r.end.y) if vertical else Vector2(r.position.x, r.end.x)
		# the room lies on the PLUS side of its low edge and the MINUS side of its high edge
		_note(lines, lo, span, room.id, true)
		_note(lines, hi, span, room.id, false)

	var out: Array[WallSegment] = []
	var positions: Array = lines.keys()
	positions.sort()
	for pos: float in positions:
		var entry: Dictionary = lines[pos]
		var cuts := _cut_points(entry)
		var runs: Array = []
		for i in range(cuts.size() - 1):
			var a: float = cuts[i]
			var b: float = cuts[i + 1]
			if b - a < EPS:
				continue
			var mid := (a + b) * 0.5
			var minus := _room_at(entry["minus"], mid)
			var plus := _room_at(entry["plus"], mid)
			if minus == &"" and plus == &"":
				continue
			# merge with the previous run when both sides are unchanged, so a long shared wall is
			# one segment rather than one per neighbour's corner
			if not runs.is_empty() and runs[-1][2] == minus and runs[-1][3] == plus \
					and absf(runs[-1][1] - a) < EPS:
				runs[-1][1] = b
				continue
			runs.append([a, b, minus, plus])
		for run: Array in runs:
			out.append(_segment(pos, run[0], run[1], run[2], run[3], vertical, thickness))
	return out

## Side A is the side on your right walking a to b. Walking a vertical wall from low Z to high
## Z that is the -X side; walking a horizontal wall from low X to high X it is the +Z side.
## This is the single place that convention is applied, which is why it can only be wrong once.
static func _segment(pos: float, lo: float, hi: float, minus: StringName, plus: StringName,
		vertical: bool, thickness: float) -> WallSegment:
	if vertical:
		return WallSegment.make(Vector2(pos, lo), Vector2(pos, hi), minus, plus,
				[] as Array[Opening], thickness)
	return WallSegment.make(Vector2(lo, pos), Vector2(hi, pos), plus, minus,
			[] as Array[Opening], thickness)

static func _note(lines: Dictionary, pos: float, span: Vector2, id: StringName, plus: bool) -> void:
	var key := snappedf(pos, EPS)
	if not lines.has(key):
		lines[key] = {"minus": [], "plus": []}
	lines[key]["plus" if plus else "minus"].append([span.x, span.y, id])

static func _cut_points(entry: Dictionary) -> PackedFloat32Array:
	var vals := PackedFloat32Array()
	for side: String in ["minus", "plus"]:
		for s: Array in entry[side]:
			vals.append(s[0])
			vals.append(s[1])
	vals.sort()
	var out := PackedFloat32Array()
	for v: float in vals:
		if out.is_empty() or absf(v - out[out.size() - 1]) > EPS:
			out.append(v)
	return out

static func _room_at(spans: Array, at: float) -> StringName:
	for s: Array in spans:
		if at > s[0] + EPS and at < s[1] - EPS:
			return s[2]
	return &""

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		r = r.expand(p)
	return r

# --- Authoring on top of a derived list -------------------------------------------------------

## Compass directions in plan space, for naming which face of a room an opening goes in.
## North is -Z, matching the rest of the project.
const NORTH := Vector2(0, -1)
const SOUTH := Vector2(0, 1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)

## Puts an opening in the wall between two rooms, positioned by a fraction along that wall so
## the plan never restates coordinates the rooms already fix.
##
## Every pierce fails loudly when it matches nothing. A plan that silently builds a house with
## no door in it is a far more expensive bug than a plan that refuses to build.
static func pierce_between(walls: Array[WallSegment], room_a: StringName, room_b: StringName,
		opening: Opening, at_fraction := 0.5) -> void:
	var wall := between(walls, room_a, room_b)
	if wall == null:
		push_error("WallDeriver: no wall between '%s' and '%s'" % [room_a, room_b])
		return
	_add(wall, opening, at_fraction)

## Puts an opening in the outside wall of `room` that faces the given direction. Naming the
## compass point rather than the room pair is what disambiguates a room with four outside walls,
## all of which are "between this room and outdoors".
static func pierce_exterior(walls: Array[WallSegment], room: StringName, facing: Vector2,
		opening: Opening, at_fraction := 0.5) -> void:
	var wall := facing_wall(walls, room, facing)
	if wall == null:
		push_error("WallDeriver: '%s' has no outside wall facing %s" % [room, facing])
		return
	_add(wall, opening, at_fraction)

static func _add(wall: WallSegment, opening: Opening, at_fraction: float) -> void:
	opening.at = wall.length() * at_fraction
	wall.openings.append(opening)

## The longest wall between two rooms — longest because a pair can share more than one segment
## once a third room interrupts them, and a door belongs in the main run.
static func between(walls: Array[WallSegment], room_a: StringName, room_b: StringName) -> WallSegment:
	var best: WallSegment = null
	for wall: WallSegment in walls:
		var matches := (wall.room_a == room_a and wall.room_b == room_b) \
				or (wall.room_a == room_b and wall.room_b == room_a)
		if matches and (best == null or wall.length() > best.length()):
			best = wall
	return best

## The longest outside wall of `room` whose outward direction points the given way.
static func facing_wall(walls: Array[WallSegment], room: StringName, facing: Vector2) -> WallSegment:
	var best: WallSegment = null
	for wall: WallSegment in exterior_walls(walls, room):
		# the outward direction is the wall normal, flipped when the room is the side-A room
		var outward := wall.normal() if wall.room_b == room else -wall.normal()
		if outward.dot(facing) < 0.9:
			continue
		if best == null or wall.length() > best.length():
			best = wall
	return best

## Every wall between a room and outdoors, longest first, so a plan can say "a window on this
## room's longest outside wall" instead of naming coordinates.
static func exterior_walls(walls: Array[WallSegment], room: StringName) -> Array[WallSegment]:
	var out: Array[WallSegment] = []
	for wall: WallSegment in walls:
		if (wall.room_a == room and wall.room_b == &"") or (wall.room_b == room and wall.room_a == &""):
			out.append(wall)
	out.sort_custom(func(x: WallSegment, y: WallSegment) -> bool: return x.length() > y.length())
	return out
