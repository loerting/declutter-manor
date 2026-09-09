class_name HouseBuilder
## Walks a FloorPlan once and emits the whole building: interior surfaces, the exterior shell,
## collision and occluders. **No geometry for the house is authored anywhere else.**
##
## The invariant this file exists to enforce: a wall is ONE mesh with two faces and a rim, cut
## by ONE list of openings. There is no separate interior wall and exterior wall that could
## disagree, so a window seen from the garden is necessarily the window seen from the room.
##
## Plan coordinates are metres; plan (x, y) is world (x, ·, y) and north is -Z.

## Structural depth of a floor slab: the storey slab minus the ceiling plane hung under it, so
## the two meet and a stairwell shows one clean edge instead of a dark slot between them.
const FLOOR_SLAB := 0.33
## Ceilings are a thin plane hung under the slab above, not the underside of that slab, so a
## room's ceiling finish never has to agree with the floor finish of the room over it.
const CEILING_PLANE := 0.02
## Walls run this far below the storey's finished floor: exactly one slab, so an upper storey's
## walls land on the head of the walls beneath and the siding runs unbroken. Less than a slab
## left a bright 3 cm seam around the house at first-floor level; more would hang through the
## ceilings below. It also covers a `floor_drop` up to one slab deep (the garage), which is what
## the very first garage render showed daylight under.
const FOUNDATION := 0.35
## Floor and ceiling planes are grown by this much so they run into the walls instead of
## stopping at the centre line and leaving a seam at every junction. It must stay **below half
## the thinnest wall**, or a room's floor pokes out through the far face of its own wall and
## into the neighbour — which is how a 2 cm strip of the mudroom's oak floor ended up standing
## proud of the garage slab.
const SLAB_TUCK := 0.08
const SEAM_OVERLAP := 0.01
## Added to a room's far-corner distance when its light range is fitted automatically.
const LIGHT_MARGIN := 0.6
## Bulbs in a room with a window are scaled by this while the sun is up. The first manor renders
## had every window glowing warm at noon, which is the single strongest "architectural model"
## tell there is. Off entirely left the kitchen, with one small east window, a cave at noon; 0.4 keeps
## the room warm without the window glowing. 0 hides the node entirely.
const DAYLIT_BULB := 0.4

# --- Grade, plinth and steps -------------------------------------------------------------------

## World Y of the ground the house stands on. Finished floors sit above it (the plan says how
## far); paved exterior zones sit on it.
const GRADE := 0.0
## The concrete band between the turf and the siding, above and below grade. Siding that runs
## straight into the grass puts the house on the lawn like a box on a table.
const PLINTH_TOP := 0.30
const PLINTH_DEPTH := 0.35
const PLINTH_PROUD := 0.025
const PLINTH_SLOT := "concrete"
const PLINTH_TINT := Color(0.66, 0.65, 0.62)
## Outside steps: the tallest riser allowed and the going. A door whose floor is above the
## ground outside it gets a flight from these, sized to the rise it actually has.
const STEP_RISER_MAX := 0.17
const STEP_GOING := 0.30
## Steps are wider than their door by this on each side.
const STEP_SIDE := 0.30
const STEP_BURY := 0.30
## A garage door gets an apron ramp instead of steps: a car cannot take a step.
const RAMP_RUN := 1.0

# --- Trim ----------------------------------------------------------------------------------------

const TRIM_SLOT := "painted_wood"
const TRIM_TINT := Color(1.0, 0.99, 0.96)

## Roof edge. The ridge cap is the run of tiles laid over the joint where the two slopes meet:
## without it the ridge is a mitred seam no real roof has. The gutter is a channel with two
## sides and a floor rather than a solid bar, because the aerial view looks straight into it.
const RIDGE_CAP_HALF := 0.17
const RIDGE_CAP_RISE := 0.06
const GUTTER_WIDTH := 0.12
const GUTTER_DEPTH := 0.10
const GUTTER_WALL := 0.014
const DOWNSPOUT_R := 0.038
## The door reads as a door because it contrasts with the wall around it, not because of its
## panel lines alone.
const GARAGE_DOOR_TINT := Color(1.06, 1.04, 0.99)
const TRIM_DEPTH := 0.03
## How far the casing is let into the wall face; the rest of TRIM_DEPTH stands out from it.
const TRIM_PROUD := 0.005
const TRIM_WIDTH := 0.055
## A sectional garage door reads as a door because of its panel lines, so it is built as
## separate leaves with real gaps rather than as one slab with a texture.
const GARAGE_LEAVES := 4
const GARAGE_LEAF_GAP := 0.012
## Skirting along every interior wall foot. It is the cheapest thing that stops a wall meeting a
## floor at a razor edge, and it hides every floor seam at the wall line.
const SKIRT_HEIGHT := 0.10
const SKIRT_DEPTH := 0.015
## A window is a frame with glass in it, not a hole with glass in it. The frame sits at the
## wall's mid-plane inside the reveal; anything wider than a pane gets mullions, anything tall
## enough gets a meeting rail, which is what reads as a sash from the street.
const FRAME_WIDTH := 0.06
const FRAME_DEPTH := 0.10
const MULLION_WIDTH := 0.045
const MULLION_DEPTH := 0.07
const PANE_MAX_WIDTH := 0.70
const MEETING_RAIL_MIN_HEIGHT := 1.1
const GLASS_THICKNESS := 0.006

# --- Fixtures and rails ----------------------------------------------------------------------------

## A flush ceiling light: a disc against the ceiling and a frosted dome under it, so a lit room
## has something at the hotspot on its ceiling. The bulb sits just below the dome.
const FIXTURE_RADIUS := 0.11
const FIXTURE_DISC := 0.03
const FIXTURE_EMISSION := 1.6
## Balustrades: the guard height, the baluster section and spacing, the newel section and the
## handrail section (width across, height). Flights narrower than LADDER_WIDTH are ladders and
## get no rail.
const RAIL_HEIGHT := 0.9
const BALUSTER := 0.025
const BALUSTER_SPACING := 0.13
const NEWEL := 0.08
const NEWEL_OVER := 0.08
const HANDRAIL := Vector2(0.06, 0.045)
const LADDER_WIDTH := 0.8
## How far outside a flight's edge, or a well's edge, to look for floor. Floor there means the
## side is open and needs a rail; no floor means a wall, which is its own guard.
const OPEN_PROBE := 0.3
const GUARD_INSET := 0.05

static func build(plan: FloorPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "House"
	for storey: StoreyDef in plan.storeys:
		var node := Node3D.new()
		node.name = String(storey.id)
		root.add_child(node)
		for room: RoomDef in storey.rooms:
			_build_room(node, plan, storey, room)
		for wall: WallSegment in storey.walls:
			_build_wall(node, plan, storey, wall)
	var stairs := Node3D.new()
	stairs.name = "Stairs"
	root.add_child(stairs)
	for stair: StairDef in plan.stairs:
		_build_stair(stairs, plan, stair)
	var shell := Node3D.new()
	shell.name = "Shell"
	root.add_child(shell)
	for roof: RoofDef in plan.roofs:
		_build_roof(shell, plan, roof)
	TerrainBuilder.build(shell, plan)
	return root

# --- Rooms -----------------------------------------------------------------------------------

static func _build_room(parent: Node3D, plan: FloorPlan, storey: StoreyDef, room: RoomDef) -> void:
	var holder := Node3D.new()
	holder.name = String(room.id)
	parent.add_child(holder)

	var tucked := _grown(room.polygon)
	var top := room.floor_y(storey.base_y)
	var floor_mat := Mats.of(room.floor_slot, room.floor_tint, 0.65, room.floor_scale, true)
	var deck := plan.deck_for(room.id)
	if deck != null:
		# A deck has no slab: boards on a beam on posts, all of it built from this same polygon.
		ExteriorBuilder.build_deck(holder, plan, storey, room, deck)
	else:
		# A flight that ARRIVES in this room needs a hole in this floor to arrive through, and a
		# pool needs one for the same reason: you have to be able to get into it.
		var pieces := _minus_stairwells(tucked, plan, room.id, true)
		for pool: PoolDef in plan.pools_in(room.id):
			var left: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				left.append_array(cut_rect(piece, pool.hole()))
			pieces = left
		var i := 0
		for piece: PackedVector2Array in pieces:
			i += 1
			surface(holder, Props.prism(piece, top - FLOOR_SLAB, top), [floor_mat], "Floor%d" % i, true)
	for pool: PoolDef in plan.pools_in(room.id):
		ExteriorBuilder.build_pool(holder, storey, room, pool)

	var cy := storey.ceiling_y()
	# The light comes before the ceiling, because a room without a ceiling — the attic, under its
	# roof boards — still owns a bulb. The first attic render was lit only by the landing below.
	if room.light_energy > 0.0:
		var lit := not _daylit(storey, room)
		var lamp := OmniLight3D.new()
		lamp.name = "Light"
		lamp.light_color = room.light_color
		lamp.light_energy = room.light_energy * (1.0 if lit else DAYLIT_BULB)
		lamp.visible = lamp.light_energy > 0.0
		lamp.omni_range = room.light_range if room.light_range > 0.0 else room.reach() + LIGHT_MARGIN
		lamp.shadow_enabled = room.light_shadows
		lamp.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		var c := room.centroid()
		lamp.position = Vector3(c.x, cy - room.light_offset, c.y)
		holder.add_child(lamp)
		if room.has_ceiling:
			_build_fixture(holder, Vector3(c.x, cy, c.y), room, lamp.visible)

	if not room.has_ceiling:
		return
	var ceil_mat := Mats.of(room.ceiling_slot, Color(1.24, 1.25, 1.26), 0.95, 1.0, true)
	# ...and a flight that LEAVES this room needs the hole in its ceiling.
	var c_i := 0
	for piece: PackedVector2Array in _minus_stairwells(tucked, plan, room.id, false):
		c_i += 1
		surface(holder, Props.prism(piece, cy, cy + CEILING_PLANE), [ceil_mat], "Ceiling%d" % c_i, true)

## A room is daylit when any wall around it carries glazing.
static func _daylit(storey: StoreyDef, room: RoomDef) -> bool:
	for wall: WallSegment in storey.walls:
		if wall.room_a != room.id and wall.room_b != room.id:
			continue
		for o: Opening in wall.openings:
			if o.glazed:
				return true
	return false

static func _build_fixture(holder: Node3D, at: Vector3, room: RoomDef, lit: bool) -> void:
	var disc := Props.mi(Props.cyl(FIXTURE_RADIUS + 0.03, FIXTURE_RADIUS + 0.03, FIXTURE_DISC),
			Mats.of(TRIM_SLOT, TRIM_TINT, 0.7), at + Vector3(0.0, -FIXTURE_DISC * 0.5, 0.0))
	disc.name = "FixtureDisc"
	# The bulb sits inside the fixture's light cone, so the fixture must not shadow it: a dome
	# that cast shadows would black out its own ceiling.
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	var frosted := Props.mat(Color(0.97, 0.96, 0.93), 0.35)
	if lit:
		frosted.emission_enabled = true
		frosted.emission = room.light_color
		frosted.emission_energy_multiplier = FIXTURE_EMISSION
	# Upper half of the dome is inside the ceiling plane and the slab above it.
	var dome := Props.mi(Props.sphere(FIXTURE_RADIUS), frosted, at + Vector3(0.0, -FIXTURE_DISC, 0.0))
	dome.name = "FixtureDome"
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(dome)

## The plane of a room with every relevant stairwell removed. A well that touches the room's
## edge is a notch and clips cleanly; a well fully inside is a hole, which a single polygon
## cannot express and a triangulator cannot take, so it becomes the four strips around it.
static func _minus_stairwells(polygon: PackedVector2Array, plan: FloorPlan, room: StringName,
		arriving: bool) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [polygon]
	for stair: StairDef in plan.stairs:
		var hits := stair.upper_room == room if arriving else stair.lower_room == room
		if not hits:
			continue
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(cut_rect(piece, stair.footprint()))
		pieces = next
	return pieces

static func cut_rect(polygon: PackedVector2Array, rect: Rect2) -> Array[PackedVector2Array]:
	var hole := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)])
	var clipped := Geometry2D.clip_polygons(polygon, hole)
	var out: Array[PackedVector2Array] = []
	if clipped.size() == 1:
		out.append(clipped[0])
		return out
	if clipped.is_empty():
		return out
	# outer ring plus an inner ring: a true hole. Only a rectangular room is decomposed; anything
	# else is a plan error worth stopping on rather than quietly floor-less.
	var b := bounds(polygon)
	if polygon.size() != 4 or absf(_area(polygon) - b.get_area()) > 0.01:
		push_error("HouseBuilder: stairwell lies inside a non-rectangular room; author it as rectangles")
		out.append(polygon)
		return out
	var r := rect.intersection(b)
	# The end strips reach a hair past the well so the side strips' end faces sit inside them.
	# Butted exactly, the side strip's 2 cm end face is coplanar with the end strip's and gets
	# drawn — a bright line straight across the ceiling of every room with a stairwell.
	for strip: Rect2 in [
			Rect2(b.position.x, b.position.y, b.size.x, r.position.y - b.position.y + SEAM_OVERLAP),
			Rect2(b.position.x, r.end.y - SEAM_OVERLAP, b.size.x, b.end.y - r.end.y + SEAM_OVERLAP),
			Rect2(b.position.x, r.position.y, r.position.x - b.position.x, r.size.y),
			Rect2(r.end.x, r.position.y, b.end.x - r.end.x, r.size.y)] as Array[Rect2]:
		if strip.size.x > 0.005 and strip.size.y > 0.005:
			out.append(PackedVector2Array([strip.position, Vector2(strip.end.x, strip.position.y),
					strip.end, Vector2(strip.position.x, strip.end.y)]))
	return out

static func bounds(polygon: PackedVector2Array) -> Rect2:
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		r = r.expand(p)
	return r

## The room polygon pushed outward so a floor or ceiling plane disappears into the walls.
##
## `offset_polygon` treats a clockwise ring as a hole and shrinks it, and `RoomDef.rect` happens
## to produce clockwise rings — which pulled every slab 12 cm *away* from its walls and left a
## band of roof underside visible above the garage door. Rather than requiring plans to be wound
## a particular way, the result is measured: whichever sign makes the polygon bigger is the one
## that grew it.
static func _grown(polygon: PackedVector2Array) -> PackedVector2Array:
	var before := _area(polygon)
	for delta: float in [SLAB_TUCK, -SLAB_TUCK] as Array[float]:
		# Mitred, so a rectangle stays a four-point rectangle; the default rounds every corner
		# into a chamfer, which then fails the rectangle test in _cut_rect and loses the stairwell.
		var rings := Geometry2D.offset_polygon(polygon, delta, Geometry2D.JOIN_MITER)
		if rings.is_empty():
			continue
		if _area(rings[0]) > before:
			return rings[0]
	return polygon

static func _area(polygon: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(polygon.size()):
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5

# --- Walls -----------------------------------------------------------------------------------

static func _build_wall(parent: Node3D, plan: FloorPlan, storey: StoreyDef, wall: WallSegment) -> void:
	var length := wall.length()
	if length < 1e-3:
		push_error("HouseBuilder: degenerate wall at %s" % wall.a)
		return
	var height := wall.height_override if wall.height_override > 0.0 else storey.height
	# The wall is built from its footing to its head, but every opening is still measured from
	# the finished floor, so `z_ref` is the one place the two datums meet.
	# An outside wall's footing goes the full slab, to meet the head of the wall below. An inside
	# wall that does not stack over a wall stops at the top of the ceiling plane instead: run to
	# the ceiling's underside, its bottom face z-fights with the ceiling and draws itself across
	# it as a pale band — the "diagonal streak" on the kitchen ceiling was the closet walls above.
	var footing := FOUNDATION if wall.is_exterior() else FOUNDATION - CEILING_PLANE
	var total := height + footing
	var centre_y := storey.base_y + (height - footing) * 0.5
	var z_ref := centre_y - storey.base_y
	# ...and that floor is the higher of the two rooms' floors: a door between the kitchen and
	# the dropped garage slab sits at the kitchen floor with a step down, and a garage door sits
	# on the garage slab, not a slab-height above it.
	var z_floor := z_ref - _datum(storey, wall)

	var holes: Array[Rect2] = []
	for o: Opening in wall.openings:
		holes.append(Rect2(o.u0() - length * 0.5, z_floor - o.top(), o.width, o.height))

	# Slab local space: +X along the wall, +Y toward side A, +Z downward. Surface 0 is the
	# side-A face, 1 the side-B face, 2 the rim — including every opening's reveal.
	var mesh := Props.holed_slab(Vector3(length, wall.thickness, total), holes, true)

	var holder := Node3D.new()
	holder.name = "Wall_%s_%s" % [_side_name(wall.room_a), _side_name(wall.room_b)]
	var d := wall.dir()
	var n := wall.normal()
	holder.transform = Transform3D(
		Basis(Vector3(d.x, 0.0, d.y), Vector3(n.x, 0.0, n.y), Vector3(0.0, -1.0, 0.0)),
		Vector3(wall.midpoint().x, centre_y, wall.midpoint().y))
	parent.add_child(holder)

	var face_a := _face_material(plan, storey, wall.room_a)
	var face_b := _face_material(plan, storey, wall.room_b)
	# The rim is what you see standing in a doorway or looking into a window reveal, so it takes
	# the inside finish wherever there is an inside; a garden wall takes the siding.
	var rim_room := wall.room_a if wall.room_a != &"" else wall.room_b
	surface(holder, mesh, [face_a, face_b, _face_material(plan, storey, rim_room)], "Slab", true)

	# Everything on this wall that shares a material is one mesh: the casings, frames, sills and
	# skirting of a wall with three windows were 30 draw calls, and are now one.
	var parts := {"trim": [], "glass": [], "panel": [], "plinth": []}
	for o: Opening in wall.openings:
		_build_opening(holder, plan, storey, wall, o, length, z_ref, z_floor, parts)
	_build_skirting(storey, wall, length, z_ref, parts["trim"])
	_build_plinth(storey, wall, length, centre_y, z_floor, parts["plinth"])
	_emit(holder, parts["trim"], Mats.of(TRIM_SLOT, TRIM_TINT, 0.7), "Trim")
	_emit(holder, parts["panel"], Mats.of(TRIM_SLOT, GARAGE_DOOR_TINT, 0.8), "GarageDoor")
	_emit(holder, parts["plinth"], Mats.of(PLINTH_SLOT, PLINTH_TINT, 1.0, 1.0, true), "Plinth")
	_emit(holder, parts["glass"], _glass(), "Glass")

## The higher finished floor among the rooms a wall names, as an offset from the storey base
## (zero or negative). Openings, skirting and steps are all measured from it.
static func _datum(storey: StoreyDef, wall: WallSegment) -> float:
	var datum := -INF
	for id: StringName in [wall.room_a, wall.room_b] as Array[StringName]:
		var room := storey.room(id)
		if room != null:
			datum = maxf(datum, room.floor_y(storey.base_y) - storey.base_y)
	return 0.0 if datum == -INF else datum

static func _face_material(plan: FloorPlan, storey: StoreyDef, room_id: StringName) -> Material:
	if room_id == &"":
		return Mats.of(plan.siding_slot, plan.siding_tint, 0.85, 1.0, true)
	var room := storey.room(room_id)
	if room == null:
		# Not silently defaulted: a wall naming a room that does not exist is a plan bug, and
		# PlanProbe reports it. The magenta is so it is impossible to miss in a render too.
		push_error("HouseBuilder: wall names unknown room '%s'" % room_id)
		return Props.mat(Color(1, 0, 1))
	return Mats.of(room.wall_slot, Color(1.32, 1.34, 1.36), 0.95, room.wall_scale, true)

static func _side_name(room_id: StringName) -> String:
	return "outside" if room_id == &"" else String(room_id)

static func _glass() -> Material:
	# Real glass is mostly a mirror of the sky from outside and mostly invisible from inside;
	# the Fresnel term does both if the surface is smooth and not metallic. The first version
	# was metallic 0.3 and rough, which made every window a dark grey plate.
	var glass := Props.mat(Color(0.86, 0.92, 0.95, 0.20), 0.02)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return glass

static func _emit(holder: Node3D, parts: Array, material: Material, node_name: String) -> void:
	if parts.is_empty():
		return
	var mi := Props.mi(Props.union(parts), material)
	mi.name = node_name
	holder.add_child(mi)

## Wall-local intervals along X left after removing every opening that reaches the floor,
## widened by `margin` so a board butts against the casing rather than running into it.
static func _floor_runs(wall: WallSegment, length: float, margin: float, floor_only: bool,
		plinth_top_world := INF, storey: StoreyDef = null, z_floor := 0.0, z_ref := 0.0) -> Array[Vector2]:
	var runs: Array[Vector2] = [Vector2(-length * 0.5, length * 0.5)]
	for o: Opening in wall.openings:
		if floor_only and o.kind == Opening.Kind.WINDOW:
			continue
		if not floor_only:
			# a plinth is cut only by openings that come down into it
			var bottom_world := storey.base_y + (z_ref - z_floor) + o.bottom()
			if bottom_world >= plinth_top_world:
				continue
		var m := 0.0 if o.kind == Opening.Kind.ARCH else margin
		var cut := Vector2(o.u0() - m - length * 0.5, o.u1() + m - length * 0.5)
		var next: Array[Vector2] = []
		for r: Vector2 in runs:
			if cut.y <= r.x or cut.x >= r.y:
				next.append(r)
				continue
			if cut.x > r.x:
				next.append(Vector2(r.x, cut.x))
			if cut.y < r.y:
				next.append(Vector2(cut.y, r.y))
		runs = next
	return runs

static func _build_skirting(storey: StoreyDef, wall: WallSegment, length: float, z_ref: float,
		trim: Array) -> void:
	var half_t := wall.thickness * 0.5
	var runs := _floor_runs(wall, length, TRIM_WIDTH, true)
	for side: float in [1.0, -1.0] as Array[float]:
		var room := storey.room(wall.room_a if side > 0.0 else wall.room_b)
		if room == null or room.zone != RoomDef.Zone.INTERIOR:
			continue
		var z_floor := z_ref - (room.floor_y(storey.base_y) - storey.base_y)
		for r: Vector2 in runs:
			if r.y - r.x < 0.02:
				continue
			trim.append(Props.part(Vector3(r.y - r.x, SKIRT_DEPTH, SKIRT_HEIGHT),
					Vector3((r.x + r.y) * 0.5, side * (half_t + SKIRT_DEPTH * 0.5), z_floor - SKIRT_HEIGHT * 0.5)))

## The concrete band at the foot of every outside wall that meets the ground. Runs past both
## ends by the wall's half-thickness plus its own projection, so two bands meet at an outside
## corner instead of leaving a notch of siding between them.
static func _build_plinth(storey: StoreyDef, wall: WallSegment, length: float, centre_y: float,
		z_floor: float, plinth: Array) -> void:
	if not wall.is_exterior():
		return
	var foot := storey.base_y - FOUNDATION
	if foot >= GRADE + PLINTH_TOP or foot < GRADE - 1.0:
		return
	var half_t := wall.thickness * 0.5
	var side := 1.0 if wall.room_a == &"" else -1.0
	var z_top := centre_y - (GRADE + PLINTH_TOP)
	var z_bot := centre_y - (GRADE - PLINTH_DEPTH)
	var z_ref := centre_y - storey.base_y
	var ext := half_t + PLINTH_PROUD
	var runs := _floor_runs(wall, length, 0.0, false, GRADE + PLINTH_TOP, storey, z_floor, z_ref)
	for r: Vector2 in runs:
		var x0 := r.x - (ext if is_equal_approx(r.x, -length * 0.5) else 0.0)
		var x1 := r.y + (ext if is_equal_approx(r.y, length * 0.5) else 0.0)
		plinth.append(Props.part(Vector3(x1 - x0, PLINTH_PROUD + 0.01, z_bot - z_top),
				Vector3((x0 + x1) * 0.5, side * (half_t + PLINTH_PROUD * 0.5 - 0.005), (z_top + z_bot) * 0.5)))

# --- Openings ---------------------------------------------------------------------------------

## Everything here is built in the wall slab's local space: x along the wall from its centre,
## y across the thickness (+ toward side A), z downward from mid-height. `z_floor` is the local
## z of the finished floor the opening is measured from.
static func _build_opening(holder: Node3D, plan: FloorPlan, storey: StoreyDef, wall: WallSegment,
		o: Opening, length: float, z_ref: float, z_floor: float, parts: Dictionary) -> void:
	var cx := o.at - length * 0.5
	var cz := z_floor - (o.bottom() + o.height * 0.5)
	var half_t := wall.thickness * 0.5

	if o.kind == Opening.Kind.GARAGE_DOOR:
		_build_garage_door(o, cx, cz, half_t, parts["panel"])
	if wall.is_exterior() and (o.kind == Opening.Kind.DOOR or o.kind == Opening.Kind.GARAGE_DOOR):
		_build_steps(holder, plan, storey, wall, o, cx, z_ref, z_floor, half_t)
	if o.kind == Opening.Kind.GARAGE_DOOR:
		return

	if o.glazed:
		_build_window_frame(o, cx, cz, parts["trim"])
		parts["glass"].append(Props.part(Vector3(o.width, GLASS_THICKNESS, o.height), Vector3(cx, 0.0, cz)))

	if not o.trimmed:
		return
	var trim: Array = parts["trim"]
	var sides: Array[float] = [1.0, -1.0]
	for side: float in sides:
		# Casing stands PROUD of the wall, as real casing does. Sitting it flush made its outer
		# face coplanar with the wall's, which z-fought into a ragged dark fringe along the
		# garage door head.
		var y := side * (half_t + TRIM_DEPTH * 0.5 - TRIM_PROUD)
		var w := o.width + TRIM_WIDTH * 2.0
		trim.append(Props.part(Vector3(TRIM_WIDTH, TRIM_DEPTH, o.height),
				Vector3(cx - o.width * 0.5 - TRIM_WIDTH * 0.5, y, cz)))
		trim.append(Props.part(Vector3(TRIM_WIDTH, TRIM_DEPTH, o.height),
				Vector3(cx + o.width * 0.5 + TRIM_WIDTH * 0.5, y, cz)))
		trim.append(Props.part(Vector3(w, TRIM_DEPTH, TRIM_WIDTH),
				Vector3(cx, y, cz - o.height * 0.5 - TRIM_WIDTH * 0.5)))
		if o.kind != Opening.Kind.WINDOW:
			continue
		# Sill board: only a window has one, and it projects, which is what stops a window
		# reading as a rectangle painted on the wall.
		trim.append(Props.part(Vector3(w, TRIM_DEPTH * 2.6, TRIM_WIDTH * 1.6),
				Vector3(cx, y - side * TRIM_DEPTH * 0.8, cz + o.height * 0.5 + TRIM_WIDTH * 0.8)))

## Outer frame at the wall's mid-plane, vertical mullions dividing the width into panes no wider
## than PANE_MAX_WIDTH, and a meeting rail across the middle of a tall window.
static func _build_window_frame(o: Opening, cx: float, cz: float, trim: Array) -> void:
	var w := o.width
	var h := o.height
	trim.append(Props.part(Vector3(FRAME_WIDTH, FRAME_DEPTH, h), Vector3(cx - w * 0.5 + FRAME_WIDTH * 0.5, 0.0, cz)))
	trim.append(Props.part(Vector3(FRAME_WIDTH, FRAME_DEPTH, h), Vector3(cx + w * 0.5 - FRAME_WIDTH * 0.5, 0.0, cz)))
	trim.append(Props.part(Vector3(w, FRAME_DEPTH, FRAME_WIDTH), Vector3(cx, 0.0, cz - h * 0.5 + FRAME_WIDTH * 0.5)))
	trim.append(Props.part(Vector3(w, FRAME_DEPTH, FRAME_WIDTH), Vector3(cx, 0.0, cz + h * 0.5 - FRAME_WIDTH * 0.5)))
	var inner_w := w - FRAME_WIDTH * 2.0
	var inner_h := h - FRAME_WIDTH * 2.0
	var panes := maxi(1, int(ceil(inner_w / PANE_MAX_WIDTH)))
	for i in range(1, panes):
		var x := cx - inner_w * 0.5 + inner_w * float(i) / float(panes)
		trim.append(Props.part(Vector3(MULLION_WIDTH, MULLION_DEPTH, inner_h), Vector3(x, 0.0, cz)))
	if h >= MEETING_RAIL_MIN_HEIGHT:
		trim.append(Props.part(Vector3(inner_w, MULLION_DEPTH, MULLION_WIDTH), Vector3(cx, 0.0, cz)))

static func _build_garage_door(o: Opening, cx: float, cz: float, half_t: float, panel: Array) -> void:
	var leaf_h := (o.height - GARAGE_LEAF_GAP * float(GARAGE_LEAVES - 1)) / float(GARAGE_LEAVES)
	var top_z := cz - o.height * 0.5
	for i in range(GARAGE_LEAVES):
		var z := top_z + leaf_h * 0.5 + float(i) * (leaf_h + GARAGE_LEAF_GAP)
		panel.append(Props.part(Vector3(o.width - 0.02, 0.055, leaf_h), Vector3(cx, -(half_t - 0.075), z)))

## Steps (or, for a garage door, a ramp) from the ground outside an exterior door up to its
## floor. The ground is whatever paved zone lies outside the door, else grade; a door that opens
## onto a deck at its own level gets nothing. Built in wall-local space with the flight's `u`
## pointing outward, so one profile serves every wall orientation.
static func _build_steps(holder: Node3D, plan: FloorPlan, storey: StoreyDef, wall: WallSegment,
		o: Opening, cx: float, z_ref: float, z_floor: float, half_t: float) -> void:
	var side := 1.0 if wall.room_a == &"" else -1.0
	var outward := wall.normal() * side
	var outside := wall.at_u(o.at) + outward * (half_t + 0.5)
	var ground := ground_level(plan, storey, outside)
	var floor_world := storey.base_y + (z_ref - z_floor)
	var rise := floor_world - ground
	if rise < 0.05:
		return
	var profile := PackedVector2Array()
	var run := 0.0
	if o.kind == Opening.Kind.GARAGE_DOOR:
		run = RAMP_RUN
		profile.append(Vector2(0.0, 0.0))
		profile.append(Vector2(run, -rise))
	else:
		var n := maxi(1, int(ceil(rise / STEP_RISER_MAX)))
		var r := rise / float(n)
		run = STEP_GOING * float(n)
		profile.append(Vector2(0.0, 0.0))
		for i in range(1, n + 1):
			profile.append(Vector2(STEP_GOING * float(i), -r * float(i - 1)))
			profile.append(Vector2(STEP_GOING * float(i), -r * float(i)))
	profile.append(Vector2(run, -rise - STEP_BURY))
	profile.append(Vector2(0.0, -rise - STEP_BURY))
	var extra := 0.0 if o.kind == Opening.Kind.GARAGE_DOOR else STEP_SIDE
	var mesh := Props.extrude(profile, Vector3(cx, side * half_t, z_floor),
			Vector3(0.0, side, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.RIGHT,
			-o.width * 0.5 - extra, o.width * 0.5 + extra)
	surface(holder, mesh, [Mats.of(PLINTH_SLOT, PLINTH_TINT, 1.0, 1.0, true)],
			"Ramp" if o.kind == Opening.Kind.GARAGE_DOOR else "Steps", true)

## World Y of the ground at a plan point: the paved zone there if any, else grade.
static func ground_level(plan: FloorPlan, storey: StoreyDef, at: Vector2) -> float:
	for room: RoomDef in storey.rooms:
		if room.zone == RoomDef.Zone.EXTERIOR and room.contains(at):
			return room.floor_y(storey.base_y)
	return GRADE

# --- Plumbing ---------------------------------------------------------------------------------

static func surface(parent: Node3D, mesh: ArrayMesh, materials: Array, node_name: String,
		collide: bool) -> void:
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = node_name
	for i in range(mini(materials.size(), mesh.get_surface_count())):
		mi.set_surface_override_material(i, materials[i])
	parent.add_child(mi)
	if not collide:
		return
	# Trimesh collision rather than a box, so an opening is a hole you can walk through for the
	# same reason it is a hole you can see through: there is only one piece of geometry.
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	parent.add_child(body)

# --- Roof ---------------------------------------------------------------------------------------

## The roof is generated from the plan like everything else, so the attic is inside the roof
## volume by construction rather than by an author remembering to keep it there.
static func _build_roof(parent: Node3D, plan: FloorPlan, roof: RoofDef) -> void:
	var holder := Node3D.new()
	holder.name = "Roof"
	parent.add_child(holder)
	var tiles := Mats.of(roof.slot, Color(0.92, 0.90, 0.90), 0.95, 1.0, true)
	# Sawn roof boards are not varnished: on the scan's own roughness the bulb below put two
	# mirror highlights on the underside, the one thing in the attic that read as plastic.
	var boards := Mats.of(roof.underside_slot, roof.underside_tint, 0.88, 0.55, true, true)
	var fascia := Mats.of(roof.fascia_slot, TRIM_TINT, 0.75)
	var gable := Mats.of(plan.siding_slot, plan.siding_tint, 0.85, 1.0, true)

	var fp := roof.footprint
	var oh := roof.overhang
	var drop := tan(deg_to_rad(roof.pitch_deg)) * oh
	# A roof plane is a solid with thickness, and it is the UNDERSIDE that bears on the wall
	# plate — rafters sit on top of the wall, not through it. Without this lift the slab's
	# underside dips below the wall head and comes through the ceiling as a dark wedge along the
	# eave wall, which is exactly what the first garage interior showed.
	var lift := roof.thickness / cos(deg_to_rad(roof.pitch_deg))
	var low := roof.eave_y + lift - drop
	var ridge := roof.ridge_y() + lift

	# Written for a ridge along X and mirrored for a ridge along Z, so the two cases cannot
	# drift apart: `u` is the along-ridge axis and `v` the axis the slopes fall down.
	var along_x := roof.kind == RoofDef.Kind.SHED or roof.ridge_along_x
	var u0 := (fp.position.x if along_x else fp.position.y) - (0.0 if roof.abut_start else oh)
	var u1 := (fp.end.x if along_x else fp.end.y) + (0.0 if roof.abut_end else oh)
	var v0 := (fp.position.y if along_x else fp.position.x) - oh
	var v1 := (fp.end.y if along_x else fp.end.x) + oh
	var vm := (v0 + v1) * 0.5

	var north := PackedVector3Array([_uv(along_x, u0, low, v0), _uv(along_x, u1, low, v0),
			_uv(along_x, u1, ridge, vm), _uv(along_x, u0, ridge, vm)])
	var south := PackedVector3Array([_uv(along_x, u0, ridge, vm), _uv(along_x, u1, ridge, vm),
			_uv(along_x, u1, low, v1), _uv(along_x, u0, low, v1)])
	var roof_mats: Array = [tiles, boards, fascia]
	surface(holder, Props.slab_poly(north, roof.thickness, Vector3.UP, true), roof_mats, "SlopeA", true)
	surface(holder, Props.slab_poly(south, roof.thickness, Vector3.UP, true), roof_mats, "SlopeB", true)

	# The gable ends close the roof volume. Without them you see straight into the attic from
	# the side, which is the single most common way a generated house reads as a set.
	var g0 := (fp.position.x if along_x else fp.position.y)
	var g1 := (fp.end.x if along_x else fp.end.y)
	var gv0 := (fp.position.y if along_x else fp.position.x)
	var gv1 := (fp.end.y if along_x else fp.end.x)
	for u: float in [g0, g1] as Array[float]:
		if (roof.abut_start and is_equal_approx(u, g0)) or (roof.abut_end and is_equal_approx(u, g1)):
			continue
		# The gable continues the wall below it, so it has to sit on the wall's OUTER face, not
		# on the footprint centre line — otherwise the elevation shows a 10 cm step at the wall
		# head where the siding suddenly recedes.
		var out_u := u + (roof.wall_thickness * 0.5 if is_equal_approx(u, g1) else -roof.wall_thickness * 0.5)
		var tri := PackedVector3Array([_uv(along_x, out_u, roof.eave_y, gv0),
				_uv(along_x, out_u, roof.eave_y, gv1), _uv(along_x, out_u, ridge, vm)])
		# the gable fills from the wall head to the ridge, so the lift never opens a slot
		surface(holder, Props.slab_poly(tri, roof.wall_thickness, _uv(along_x, 1.0, 0.0, 0.0)),
				[gable], "Gable", true)

	# The ridge cap: a run of capping tiles over the joint, sitting on the two slopes it covers.
	# Its flat underside is inside the roof solid, which is where a real ridge tile's bed of
	# mortar is, and is never seen.
	var across := Vector3.BACK if along_x else Vector3.RIGHT
	var along := Vector3.RIGHT if along_x else Vector3.BACK
	var cap_foot := ridge - tan(deg_to_rad(roof.pitch_deg)) * RIDGE_CAP_HALF
	var cap_poly := PackedVector2Array([Vector2(vm - RIDGE_CAP_HALF, cap_foot),
			Vector2(vm, ridge + RIDGE_CAP_RISE), Vector2(vm + RIDGE_CAP_HALF, cap_foot)])
	surface(holder, Props.extrude(cap_poly, Vector3.ZERO, across, Vector3.UP, along, u0, u1),
			[tiles], "RidgeCap", false)

	# Fascia along both eaves: the board that closes the tile edge. A roof without one reads as
	# a sheet of card laid on the walls. The gutter hangs off it and the downspout runs from the
	# gutter to the ground, all in one mesh: they share a material and never move apart.
	var edge: Array = []
	var near_u := u0 + 0.4 if not roof.abut_start else u1 - 0.4
	var far_u := u1 - 0.4 if not roof.abut_end else u0 + 0.4
	var spouts: Array[float] = [near_u, far_u]
	var e := 0
	for v: float in [v0, v1] as Array[float]:
		var length := u1 - u0
		var mid := _uv(along_x, (u0 + u1) * 0.5, low - 0.09, v)
		edge.append(Props.part(_size(along_x, length, 0.18, 0.05), mid))
		# outward from the roof, so the gutter hangs clear of the fascia board
		var sgn := -1.0 if is_equal_approx(v, v0) else 1.0
		var g_in := v + sgn * 0.025
		var g_mid := g_in + sgn * GUTTER_WIDTH * 0.5
		var g_top := low - 0.03
		var g_bot := g_top - GUTTER_DEPTH
		edge.append(Props.part(_size(along_x, length, GUTTER_WALL, GUTTER_WIDTH),
				_uv(along_x, (u0 + u1) * 0.5, g_bot + GUTTER_WALL * 0.5, g_mid)))
		for side: float in [g_in, g_in + sgn * GUTTER_WIDTH] as Array[float]:
			edge.append(Props.part(_size(along_x, length, GUTTER_DEPTH, GUTTER_WALL),
					_uv(along_x, (u0 + u1) * 0.5, g_bot + GUTTER_DEPTH * 0.5, side)))
		# The downspout leaves the gutter, elbows back to the wall it runs down, and stops a
		# finger above the ground: a pipe ending in mid-air is the first thing the eye catches.
		var wall_v := (fp.position.y if along_x else fp.position.x) if sgn < 0.0 \
				else (fp.end.y if along_x else fp.end.x)
		var at_wall := wall_v + sgn * (DOWNSPOUT_R + 0.02)
		var su: float = spouts[e]
		edge.append([Props.tube(PackedVector3Array([
				_uv(along_x, su, g_bot + GUTTER_WALL, g_mid),
				_uv(along_x, su, g_bot - 0.18, g_mid),
				_uv(along_x, su, g_bot - 0.45, at_wall),
				_uv(along_x, su, GRADE + 0.07, at_wall)]), DOWNSPOUT_R, 10), Transform3D.IDENTITY])
		e += 1
	surface(holder, Props.with_tangents(Props.union(edge)), [fascia], "Fascia", false)

## Maps an (along-ridge, height, across-ridge) triple into world space for either ridge
## direction, so the roof is written once instead of twice.
static func _uv(along_x: bool, u: float, y: float, v: float) -> Vector3:
	return Vector3(u, y, v) if along_x else Vector3(v, y, u)

## The same mapping for a box size, where every component is a length rather than a coordinate.
static func _size(along_x: bool, along: float, up: float, across: float) -> Vector3:
	return Vector3(absf(along), up, absf(across)) if along_x else Vector3(absf(across), up, absf(along))

# --- Stairs -------------------------------------------------------------------------------------

## One flight as one solid: its side profile — a sawtooth of risers and goings closed along the
## underside — extruded across its width. The rise is read from the storeys, so a flight cannot
## land short of, or above, the floor it serves.
static func _build_stair(parent: Node3D, plan: FloorPlan, stair: StairDef) -> void:
	var lower_storey := plan.storey_of(stair.lower_room)
	var upper_storey := plan.storey_of(stair.upper_room)
	if lower_storey == null or upper_storey == null:
		push_error("HouseBuilder: stair names unknown room ('%s' / '%s')" % [stair.lower_room, stair.upper_room])
		return
	var lower := plan.find_room(stair.lower_room)
	var upper := plan.find_room(stair.upper_room)
	var y0 := lower.floor_y(lower_storey.base_y)
	var y1 := upper.floor_y(upper_storey.base_y)
	var rise := y1 - y0
	var steps := StairDef.step_count(rise)
	var riser := rise / float(steps)
	var going := stair.run / float(steps)

	# profile in (u along the flight, v up), starting at the foot and closing under the flight
	var profile := PackedVector2Array()
	profile.append(Vector2(0.0, 0.0))
	for i in range(steps):
		profile.append(Vector2(going * float(i), riser * float(i + 1)))
		profile.append(Vector2(going * float(i + 1), riser * float(i + 1)))
	# drop down to the upper floor's slab underside so the flight reads as built, not floating
	profile.append(Vector2(stair.run, rise - FLOOR_SLAB))
	profile.append(Vector2(going * 2.0, 0.0))

	var u := Vector3(stair.direction.x, 0.0, stair.direction.y)
	var w := Vector3(-stair.direction.y, 0.0, stair.direction.x)
	var origin := Vector3(stair.foot.x, y0, stair.foot.y)
	var mesh := Props.extrude(profile, origin, u, Vector3.UP, w, -stair.width * 0.5, stair.width * 0.5)
	var holder := Node3D.new()
	holder.name = "Stair_%s_%s" % [stair.lower_room, stair.upper_room]
	parent.add_child(holder)
	surface(holder, mesh, [Mats.of(stair.tread_slot, Color.WHITE, 0.7, 1.0, true)], "Flight", true)

	if stair.width < LADDER_WIDTH:
		return
	var rails := {"post": [], "rail": []}
	var across := Vector2(-stair.direction.y, stair.direction.x)
	# Rake rail on every open side of the flight: a side with floor beyond it is open, a side
	# with a wall beyond it is guarded by the wall.
	for s: float in [1.0, -1.0] as Array[float]:
		var probe := stair.foot + stair.direction * stair.run * 0.5 + across * s * (stair.width * 0.5 + OPEN_PROBE)
		if lower.contains(probe):
			_build_rake_rail(rails, stair, s, y0, riser, going, steps)
	# Guards around the well in the upper floor, on every edge that has floor beyond it. The
	# head edge is where the flight arrives and stays open.
	var well := stair.footprint()
	var d := stair.direction
	var guard_len := stair.run - going
	# foot edge: outward is -direction; side edges: outward is ±across
	var foot_mid := stair.foot - d * OPEN_PROBE
	var y_top := y1
	if upper.contains(foot_mid):
		var a := stair.foot - d * GUARD_INSET - across * (stair.width * 0.5 + GUARD_INSET)
		var b := stair.foot - d * GUARD_INSET + across * (stair.width * 0.5 + GUARD_INSET)
		_build_guard(rails, Vector3(a.x, y_top, a.y), Vector3(b.x, y_top, b.y))
	for s: float in [1.0, -1.0] as Array[float]:
		var mid := well.get_center() + across * s * (stair.width * 0.5 + OPEN_PROBE)
		if not upper.contains(mid):
			continue
		var a := stair.foot + across * s * (stair.width * 0.5 + GUARD_INSET) - d * GUARD_INSET
		var b := a + d * (guard_len + GUARD_INSET)
		_build_guard(rails, Vector3(a.x, y_top, a.y), Vector3(b.x, y_top, b.y))
	_emit(holder, rails["post"], Mats.of(TRIM_SLOT, TRIM_TINT, 0.7), "Balusters")
	_emit(holder, rails["rail"], Mats.of(stair.tread_slot, Color.WHITE, 0.6, 1.0, true), "Handrail")

## Newel at the foot, newel at the head, a raked handrail through the nosings between them and
## two balusters on every tread. Everything stands on the tread it belongs to.
static func _build_rake_rail(rails: Dictionary, stair: StairDef, s: float, y0: float,
		riser: float, going: float, steps: int) -> void:
	var u := Vector3(stair.direction.x, 0.0, stair.direction.y)
	var w := Vector3(-stair.direction.y, 0.0, stair.direction.x)
	var base := Vector3(stair.foot.x, 0.0, stair.foot.y)
	var wo := s * (stair.width * 0.5 - NEWEL * 0.5 - 0.02)
	var at := func(uu: float, y: float) -> Vector3: return base + u * uu + Vector3.UP * y + w * wo
	var top_u := going * float(steps - 1)
	var rail_y := func(uu: float) -> float: return y0 + riser + RAIL_HEIGHT + uu * riser / going
	var y_head: float = rail_y.call(top_u)
	# newels
	var foot_h: float = rail_y.call(0.0) - y0 + NEWEL_OVER
	rails["post"].append(Props.part(Vector3(NEWEL, foot_h, NEWEL), at.call(-NEWEL * 0.5, y0 + foot_h * 0.5)))
	var head_floor := y0 + riser * float(steps)
	var head_h := y_head - head_floor + NEWEL_OVER
	rails["post"].append(Props.part(Vector3(NEWEL, head_h, NEWEL), at.call(top_u + NEWEL * 0.5, head_floor + head_h * 0.5)))
	# raked handrail: a box laid along the line from the foot to the head nosing
	var a: Vector3 = at.call(0.0, rail_y.call(0.0))
	var b: Vector3 = at.call(top_u, y_head)
	var dir := (b - a).normalized()
	var basis := Basis(dir, w.cross(dir), w)
	rails["rail"].append([Props.box(Vector3(a.distance_to(b) + NEWEL, HANDRAIL.y, HANDRAIL.x)),
			Transform3D(basis, (a + b) * 0.5)])
	# balusters, two per tread, the last tread's belong to the head newel
	for i in range(steps - 1):
		var tread := y0 + riser * float(i + 1)
		for f: float in [0.28, 0.72] as Array[float]:
			var uu := going * (float(i) + f)
			var top: float = rail_y.call(uu) - HANDRAIL.y * 0.5
			rails["post"].append(Props.part(Vector3(BALUSTER, top - tread, BALUSTER), at.call(uu, (top + tread) * 0.5)))

## A level guard on a floor between two points: a newel at each end, a handrail, balusters at
## BALUSTER_SPACING between.
static func _build_guard(rails: Dictionary, a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var post_h := RAIL_HEIGHT + NEWEL_OVER
	for p: Vector3 in [a, b] as Array[Vector3]:
		rails["post"].append(Props.part(Vector3(NEWEL, post_h, NEWEL), p + Vector3.UP * post_h * 0.5))
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	rails["rail"].append([Props.box(Vector3(length + NEWEL, HANDRAIL.y, HANDRAIL.x)),
			Transform3D(basis, (a + b) * 0.5 + Vector3.UP * (RAIL_HEIGHT + HANDRAIL.y * 0.5))])
	var count := int(floor((length - NEWEL) / BALUSTER_SPACING))
	var top := RAIL_HEIGHT
	for i in range(1, count + 1):
		var t := float(i) / float(count + 1)
		rails["post"].append(Props.part(Vector3(BALUSTER, top, BALUSTER), a + dir * (length * t) + Vector3.UP * top * 0.5))
