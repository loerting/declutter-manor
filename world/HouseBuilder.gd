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
## ceilings below. It also covers a `floor_drop` (the garage slab), which is what the very first
## garage render showed daylight under.
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
const TRIM_SLOT := "painted_wood"
const TRIM_TINT := Color(1.0, 0.99, 0.96)
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
		_build_roof(shell, roof)
	TerrainBuilder.build(shell, plan)
	return root

# --- Rooms -----------------------------------------------------------------------------------

static func _build_room(parent: Node3D, plan: FloorPlan, storey: StoreyDef, room: RoomDef) -> void:
	var holder := Node3D.new()
	holder.name = String(room.id)
	parent.add_child(holder)

	var tucked := _grown(room.polygon)
	var top := room.floor_y(storey.base_y)
	var floor_mat := Mats.of(room.floor_slot, room.floor_tint, 0.65, 1.0, true)
	# A flight that ARRIVES in this room needs a hole in this floor to arrive through.
	var i := 0
	for piece: PackedVector2Array in _minus_stairwells(tucked, plan, room.id, true):
		i += 1
		_surface(holder, Props.prism(piece, top - FLOOR_SLAB, top), [floor_mat], "Floor%d" % i, true)

	var cy := storey.ceiling_y()
	# The light comes before the ceiling, because a room without a ceiling — the attic, under its
	# roof boards — still owns a bulb. The first attic render was lit only by the landing below.
	if room.light_energy > 0.0:
		var lamp := OmniLight3D.new()
		lamp.name = "Light"
		lamp.light_color = room.light_color
		lamp.light_energy = room.light_energy
		lamp.omni_range = room.light_range if room.light_range > 0.0 else room.reach() + LIGHT_MARGIN
		lamp.shadow_enabled = room.light_shadows
		lamp.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		var c := room.centroid()
		lamp.position = Vector3(c.x, cy - room.light_offset, c.y)
		holder.add_child(lamp)

	if not room.has_ceiling:
		return
	var ceil_mat := Mats.of(room.ceiling_slot, Color(1.24, 1.25, 1.26), 0.95, 1.0, true)
	# ...and a flight that LEAVES this room needs the hole in its ceiling.
	i = 0
	for piece: PackedVector2Array in _minus_stairwells(tucked, plan, room.id, false):
		i += 1
		_surface(holder, Props.prism(piece, cy, cy + CEILING_PLANE), [ceil_mat], "Ceiling%d" % i, true)

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
			next.append_array(_cut_rect(piece, stair.footprint()))
		pieces = next
	return pieces

static func _cut_rect(polygon: PackedVector2Array, rect: Rect2) -> Array[PackedVector2Array]:
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
	var b := _bounds(polygon)
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

static func _bounds(polygon: PackedVector2Array) -> Rect2:
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
	var total := height + FOUNDATION
	var centre_y := storey.base_y + (height - FOUNDATION) * 0.5
	var z_ref := centre_y - storey.base_y

	var holes: Array[Rect2] = []
	for o: Opening in wall.openings:
		holes.append(Rect2(o.u0() - length * 0.5, z_ref - o.top(), o.width, o.height))

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
	_surface(holder, mesh, [face_a, face_b, _face_material(plan, storey, rim_room)], "Slab", true)

	for o: Opening in wall.openings:
		_build_opening(holder, wall, o, length, z_ref)

static func _face_material(plan: FloorPlan, storey: StoreyDef, room_id: StringName) -> Material:
	if room_id == &"":
		return Mats.of(plan.siding_slot, plan.siding_tint, 0.85, 1.0, true)
	var room := storey.room(room_id)
	if room == null:
		# Not silently defaulted: a wall naming a room that does not exist is a plan bug, and
		# PlanProbe reports it. The magenta is so it is impossible to miss in a render too.
		push_error("HouseBuilder: wall names unknown room '%s'" % room_id)
		return Props.mat(Color(1, 0, 1))
	return Mats.of(room.wall_slot, Color(1.32, 1.34, 1.36), 0.95, 1.0, true)

static func _side_name(room_id: StringName) -> String:
	return "outside" if room_id == &"" else String(room_id)

# --- Openings ---------------------------------------------------------------------------------

## Everything here is built in the wall slab's local space: x along the wall from its centre,
## y across the thickness (+ toward side A), z downward from mid-height.
static func _build_opening(holder: Node3D, wall: WallSegment, o: Opening, length: float, z_ref: float) -> void:
	var cx := o.at - length * 0.5
	var cz := z_ref - (o.bottom() + o.height * 0.5)
	var half_t := wall.thickness * 0.5

	if o.kind == Opening.Kind.GARAGE_DOOR:
		_build_garage_door(holder, o, cx, cz, half_t)
		return

	if o.glazed:
		var glass := Props.mat(Color(0.82, 0.90, 0.95, 0.14), 0.05)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.metallic = 0.3
		holder.add_child(Props.mi(Props.box(Vector3(o.width, 0.006, o.height)), glass, Vector3(cx, 0.0, cz)))

	if not o.trimmed:
		return
	var trim := Mats.of(TRIM_SLOT, TRIM_TINT, 0.7)
	var sides: Array[float] = [1.0, -1.0]
	for side: float in sides:
		# Casing stands PROUD of the wall, as real casing does. Sitting it flush made its outer
		# face coplanar with the wall's, which z-fought into a ragged dark fringe along the
		# garage door head.
		var y := side * (half_t + TRIM_DEPTH * 0.5 - TRIM_PROUD)
		var w := o.width + TRIM_WIDTH * 2.0
		holder.add_child(Props.mi(Props.box(Vector3(TRIM_WIDTH, TRIM_DEPTH, o.height)), trim,
				Vector3(cx - o.width * 0.5 - TRIM_WIDTH * 0.5, y, cz)))
		holder.add_child(Props.mi(Props.box(Vector3(TRIM_WIDTH, TRIM_DEPTH, o.height)), trim,
				Vector3(cx + o.width * 0.5 + TRIM_WIDTH * 0.5, y, cz)))
		holder.add_child(Props.mi(Props.box(Vector3(w, TRIM_DEPTH, TRIM_WIDTH)), trim,
				Vector3(cx, y, cz - o.height * 0.5 - TRIM_WIDTH * 0.5)))
		if o.kind != Opening.Kind.WINDOW:
			continue
		# Sill board: only a window has one, and it projects, which is what stops a window
		# reading as a rectangle painted on the wall.
		holder.add_child(Props.mi(Props.box(Vector3(w, TRIM_DEPTH * 2.6, TRIM_WIDTH * 1.6)), trim,
				Vector3(cx, y - side * TRIM_DEPTH * 0.8, cz + o.height * 0.5 + TRIM_WIDTH * 0.8)))

static func _build_garage_door(holder: Node3D, o: Opening, cx: float, cz: float, half_t: float) -> void:
	var leaf_h := (o.height - GARAGE_LEAF_GAP * float(GARAGE_LEAVES - 1)) / float(GARAGE_LEAVES)
	var panel := Mats.of(TRIM_SLOT, GARAGE_DOOR_TINT, 0.8)
	var top_z := cz - o.height * 0.5
	for i in range(GARAGE_LEAVES):
		var z := top_z + leaf_h * 0.5 + float(i) * (leaf_h + GARAGE_LEAF_GAP)
		holder.add_child(Props.mi(Props.box(Vector3(o.width - 0.02, 0.055, leaf_h)), panel,
				Vector3(cx, -(half_t - 0.075), z)))

# --- Plumbing ---------------------------------------------------------------------------------

static func _surface(parent: Node3D, mesh: ArrayMesh, materials: Array, node_name: String,
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
static func _build_roof(parent: Node3D, roof: RoofDef) -> void:
	var holder := Node3D.new()
	holder.name = "Roof"
	parent.add_child(holder)
	var tiles := Mats.of(roof.slot, Color(0.92, 0.90, 0.90), 0.95, 1.0, true)
	var boards := Mats.of(roof.underside_slot, roof.underside_tint, 0.9, 1.0, true)
	var fascia := Mats.of(roof.fascia_slot, TRIM_TINT, 0.75)
	var gable := Mats.of(roof.gable_slot, roof.gable_tint, 0.85, 1.0, true)

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
	_surface(holder, Props.slab_poly(north, roof.thickness, Vector3.UP, true), roof_mats, "SlopeA", true)
	_surface(holder, Props.slab_poly(south, roof.thickness, Vector3.UP, true), roof_mats, "SlopeB", true)

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
		_surface(holder, Props.slab_poly(tri, roof.wall_thickness, _uv(along_x, 1.0, 0.0, 0.0)),
				[gable], "Gable", true)

	# Fascia along both eaves: the board that closes the tile edge. A roof without one reads as
	# a sheet of card laid on the walls.
	for v: float in [v0, v1] as Array[float]:
		var a := _uv(along_x, u0, low, v)
		var b := _uv(along_x, u1, low, v)
		var mid := (a + b) * 0.5 + Vector3(0.0, -0.09, 0.0)
		var size := _uv(along_x, u1 - u0, 0.18, 0.05) if along_x else _uv(along_x, u1 - u0, 0.18, 0.05)
		holder.add_child(Props.mi(Props.box(Vector3(absf(size.x), 0.18, absf(size.z))), fascia, mid))

## Maps an (along-ridge, height, across-ridge) triple into world space for either ridge
## direction, so the roof is written once instead of twice.
static func _uv(along_x: bool, u: float, y: float, v: float) -> Vector3:
	return Vector3(u, y, v) if along_x else Vector3(v, y, u)

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
	var y0 := plan.find_room(stair.lower_room).floor_y(lower_storey.base_y)
	var y1 := plan.find_room(stair.upper_room).floor_y(upper_storey.base_y)
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
	_surface(holder, mesh, [Mats.of(stair.tread_slot, Color.WHITE, 0.7, 1.0, true)], "Flight", true)
