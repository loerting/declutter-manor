extends Node3D
## Finds z-fighting before the player does.
##
##     godot --headless --path . dev/SeamProbe.tscn
##
## Two surfaces that face the same way, lie in the same plane to within a fraction of a
## millimetre and overlap in that plane will flicker against each other as the camera moves.
## **A render cannot prove their absence**: the artifact is a motion artifact, and a still from
## one camera position is clean exactly as often as it is not. That is not a hypothesis — a
## doorway seam was called fixed on the strength of a still on 2026-09-09 and the author walked
## into it again on the next pass. So this is geometry, not pixels: every triangle in the built
## world is bucketed by its plane, and any two from different meshes that share a plane and
## overlap inside it are reported with the gap between them and the area they share.
##
## Exit code is the number of overlapping pairs, like the other probes.
##
## Most coplanar pairs in a house are buried. A floor slab is tucked 80 mm into the wall that
## stands on it, so its top face and the wall's inner face share a plane inside the wall assembly,
## where no camera will ever reach them: 96 such pairs and 30 m2 of them, swamping the handful
## that are actually in view. So each pair is also asked what is on either side of it. A face with
## solid material against both of its sides cannot be seen fighting and is reported as a note; one
## with open air on either side is a VIOLATION and counts towards the exit code.
##
## The side test is the parity of a ray cast straight up, counted per mesh: an odd number of
## crossings means the point is inside that mesh's solid. It is only as good as its assumption,
## which is that every generator returns a closed solid — true of everything that goes through
## `Props.prism`, and the reason `dev/Diag.gd` exists.
##
## It asks once per overlapping triangle pair and stops at the first point that can be seen, rather
## than once per pair, because a seam is rarely all one thing. Put the deck bug back and the strip
## it shares with the floors behind it is 160 mm wide under three rooms; only `entry_hall` has a
## door onto the deck, so only there is the strip cut through by a threshold and in view. Asked at
## one point per pair it reported whichever of the two that point happened to land in; asked per
## triangle it reports `entry_hall` and leaves the other two buried, which is the truth.

## Two faces closer than this, where they overlap, fight. Measured on 2026-09-15 at the player's field
## of view (GTX 1080, Vulkan, Forward+): a front quad subdivided 9x9 over a diamond behind it, at 2, 15
## and 30 m, square on and at 70 and 85 degrees. Coplanar fought everywhere; 0.05 mm fought from 15 m,
## 0.1 mm at 15-30 m, 0.2 mm only at 30 m and 70 degrees, and 0.3 mm and more never. This is
## 0.5 mm so that a depth buffer with less precision than that one still loses nothing. It was 4 mm,
## a guess, and at 4 mm every cushion lying on a seat and every book lying on a shelf was a seam.
const GAP := 0.0005
## How parallel two faces must be to count as the same plane, as a dot product. 0.9995 is under
## two degrees, which is as far as two surfaces can diverge and still fight over a short run.
const PARALLEL := 0.9995
## Overlap smaller than this in either in-plane direction is two surfaces meeting at an edge,
## which is what a butt joint is and what every skirting board in the house does.
const TOUCH := 0.002
## Below this a triangle has no area to fight over and its normal is noise.
const DEGENERATE := 1e-9
## How much further apart than GAP two faces' offsets may be and still be measured where they overlap.
## Only faces that are not exactly parallel need it, and it is the reach the probe had when GAP was 4 mm,
## so it finds every pair it found then.
const DRIFT := 0.0035
## Plane buckets are this wide, so a pair within GAP + DRIFT is either in the same bucket or the next.
const BUCKET := GAP + DRIFT
## How far off the plane the visibility test steps to ask what is there. It has to clear GAP, because a
## point in the sliver between two fighting faces is inside neither and would read as open air,
## and it has to stay inside the thinnest thing a seam can be buried in. The thinnest is
## `HouseBuilder.SLAB_TUCK` at 80 mm, so 10 mm is clear at both ends.
const PROBE := 0.01
## How many samples the step out from the plane is taken in. One jump is not enough: `_inside`
## asks whether a point is in solid material, and a single 10 mm probe walks straight THROUGH the
## 26 mm ceiling plane the attic's wall feet are buried in and lands in the room below, which is
## how four buried corners were reported as exposed.
const SAMPLES := 5
## The visibility test's ray runs straight up, so a point lying exactly on a shared triangle edge would
## cross it twice or not at all. The point is nudged by this first: far below anything the house is
## modelled to, and off every grid the plan is laid out on.
const NUDGE := Vector3(0.00037, 0.0, 0.00061)
## Side of the column the visibility test looks triangles up in, in metres. Only triangles whose footprint
## covers the point can be crossed by a vertical ray through it.
const CELL := 1.0
## Surfaces you can see through are not material for the purpose of hiding a seam: the tread that
## sat in the pool's water plane was under 140 mm of water and perfectly visible. They are left out
## of the solid test entirely, which is the conservative direction — it can only over-report.
const SEE_THROUGH := ["Water", "Glass"]

var _pairs := 0
var _exposed := 0
## Every triangle in the world, filed by the ground cells its footprint covers, for the ray test.
var _grid := {}
var _plan: FloorPlan

func _ready() -> void:
	var plan := ManorPlan.build()
	_plan = plan
	var house := HouseBuilder.build(plan)
	add_child(house)
	WorldBuilder.furnish(self, plan)
	print("=== manor (hash %s) ===" % plan.plan_hash())
	_scan(self)
	print("")
	print("SeamProbe: %d exposed, %d buried, %d coplanar overlap(s)" % [
			_exposed, _pairs - _exposed, _pairs])
	get_tree().quit(_exposed)

## Every triangle in the tree, in world space, filed under the plane it lies in. The key is the
## quantized normal and the quantized distance along it, so two triangles that could fight are
## necessarily in the same bucket or in one of its two neighbours along the distance axis.
func _scan(root: Node3D) -> void:
	var buckets := {}
	var count := 0
	for mi: MeshInstance3D in _meshes(root):
		var xform := mi.global_transform
		var path := String(root.get_path_to(mi))
		var solid := not SEE_THROUGH.has(mi.name)
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# An unindexed surface has a null in the index slot rather than an empty array.
			var index := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				index = arrays[Mesh.ARRAY_INDEX]
			var tris := index.size() / 3 if index.size() > 0 else verts.size() / 3
			for t in range(tris):
				var a: Vector3
				var b: Vector3
				var c: Vector3
				if index.size() > 0:
					a = xform * verts[index[t * 3]]
					b = xform * verts[index[t * 3 + 1]]
					c = xform * verts[index[t * 3 + 2]]
				else:
					a = xform * verts[t * 3]
					b = xform * verts[t * 3 + 1]
					c = xform * verts[t * 3 + 2]
				var cross := (b - a).cross(c - a)
				if cross.length_squared() < DEGENERATE:
					continue
				var n := cross.normalized()
				var d := n.dot(a)
				var key := _key(n, d)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append([path, n, d, a, b, c])
				count += 1
				if solid:
					_file(path, a, b, c)
	print("  %d triangles in %d plane buckets, %d ground cells" % [count, buckets.size(),
			_grid.size()])
	_compare(buckets)

## Bucket key: the normal to a thousandth and the plane offset to one GAP. A face and its twin
## a hair in front of it land in the same bucket or in the one after it.
func _key(n: Vector3, d: float, step := 0) -> String:
	return "%d,%d,%d,%d" % [roundi(n.x * 1000.0), roundi(n.y * 1000.0), roundi(n.z * 1000.0),
			floori(d / BUCKET) + step]

func _compare(buckets: Dictionary) -> void:
	# Reported per pair of nodes rather than per pair of triangles: one floor lying on another
	# is thousands of triangle pairs and one bug, and a list of thousands is a list nobody reads.
	var found := {}
	for key: String in buckets:
		var here: Array = buckets[key]
		for i in range(here.size()):
			var a: Array = here[i]
			# The same bucket, and the next one along the offset axis. The previous one is not
			# searched because it searched this one already.
			var others: Array = here.slice(i + 1)
			var next: String = _key(a[1], a[2], 1)
			if buckets.has(next):
				others += buckets[next] as Array
			for b: Array in others:
				if a[0] == b[0]:
					continue   # one mesh's own faces: a solid's two sides are not a seam
				if a[1].dot(b[1]) < PARALLEL:
					continue
				# A first cut on the planes' offsets, which is exact only for faces that are exactly
				# parallel: two faces a degree apart differ in offset by metres or by nothing, depending
				# on how far from the origin they are.
				if absf(a[2] - b[2]) > GAP + DRIFT:
					continue
				var over := _overlap(a, b)
				if over.is_empty():
					continue
				# The gap that fights is the one where they overlap.
				var gap: float = absf((b[1] as Vector3).dot(over[2]) - b[2])
				if gap > GAP:
					continue
				var pair: String = "%s | %s" % [a[0], b[0]] if a[0] < b[0] else "%s | %s" % [b[0], a[0]]
				var slot := _slot(found, pair, a[1], a[2])
				if not found.has(slot):
					found[slot] = [0.0, 0.0, gap, a[1], a[2], false, Vector3.ZERO, pair]
				# Area accumulates over the triangles of a pair and the widest strip is kept:
				# a seam is one bug however many triangles it is made of, and its size is the
				# whole of it, not the biggest single triangle overlap.
				found[slot][0] += over[0]
				found[slot][1] = maxf(found[slot][1], over[1])
				if found[slot][5]:
					continue   # already known to be in view; nothing left to learn about it
				# A face is seen from the side its cross product points away from — Godot's front
				# faces are clockwise, so the cross product points into the solid (`dev/Diag.gd`
				# proves it for every generator). Both faces of a pair share that normal to within
				# PARALLEL, so there is exactly one side either could be seen from.
				if _visible_from(over[2], a[1]):
					found[slot][5] = true
					found[slot][6] = over[2]
	var names := found.keys()
	names.sort_custom(func(x: String, y: String) -> bool: return found[x][0] > found[y][0])
	for slot: String in names:
		_pairs += 1
		# The plane is printed with the pair because "which two nodes" is only half of a seam:
		# the fix depends entirely on whether it is two floors, two wall faces or a reveal.
		var n: Vector3 = found[slot][3]
		var buried: bool = not found[slot][5]
		if not buried:
			_exposed += 1
		print("  %s [seam.%s] %8.4f m2, %5.1f mm wide, %.1f mm apart, n=(%.2f %.2f %.2f) d=%.3f: %s"
				% ["NOTE     " if buried else "VIOLATION", "buried" if buried else "coplanar",
				found[slot][0], found[slot][1] * 1000.0, found[slot][2] * 1000.0,
				n.x, n.y, n.z, found[slot][4], found[slot][7]])
		if not buried:
			var at: Vector3 = found[slot][6]
			print("            seen from (%.2f %.2f %.2f)" % [at.x, at.y, at.z])

## The dictionary key for one seam: the two nodes AND the plane they meet in. Two nodes can fight
## in more than one plane at once — a plinth that laps its neighbour at a building corner shares
## its top face with it in view and its buried underside out of view — and keying on the node pair
## alone summed the area of both against whichever plane was found first, which is how a 30 mm
## corner lap came to be reported as 0.34 m2. The adjacent d-buckets are tried first so a seam
## whose two faces straddle a bucket edge stays one entry.
func _slot(found: Dictionary, pair: String, n: Vector3, d: float) -> String:
	for step: int in [0, -1, 1]:
		var key := "%s @%s" % [pair, _key(n, d, step)]
		if found.has(key):
			return key
	return "%s @%s" % [pair, _key(n, d, 0)]

## Files one triangle under every ground cell its footprint covers.
func _file(path: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var lo := a.min(b).min(c)
	var hi := a.max(b).max(c)
	var tri := [path, a, b, c]
	for ix: int in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for iz: int in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
			var key := "%d,%d" % [ix, iz]
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(tri)

## Whether a camera could ever be at `p`: it is in open air, and that open air is either inside a
## room or outdoors above grade. Solidity alone is not enough. An inside wall runs a full slab down
## past the finished floor, so its underside and the floor's underside share a plane under every
## partition in the basement — 14 pairs and 6 m2 of them, solid above and open below, and the open
## below is a sealed void under the lowest slab that nothing will ever look into. The plan is what
## says where a camera can be, and the plan is the single source of truth for it.
## Whether the seam at `p`, whose faces point away from `n`, can be looked at. The step out from
## the plane is sampled rather than jumped, and the first sample that is solid ends it: you cannot
## see past a surface, however thin it is, and the thinnest one covering a seam in this house is
## the 6 mm of ceiling plane under the attic's wall feet.
func _visible_from(p: Vector3, n: Vector3) -> bool:
	for k in range(1, SAMPLES + 1):
		var at := p - n * (PROBE * float(k) / float(SAMPLES))
		if _inside(at):
			return false
		if _camera_space(at):
			return true
	return false

func _camera_space(p: Vector3) -> bool:
	if _inside(p):
		return false
	var at := Vector2(p.x, p.z)
	for storey: StoreyDef in _plan.storeys:
		for room: RoomDef in storey.rooms:
			if not room.contains(at) or p.y < room.floor_y(storey.base_y):
				continue
			if room.has_ceiling and p.y > storey.ceiling_y():
				continue
			return true
	return p.y > HouseBuilder.GRADE

## Whether `p` is inside solid material. Parity is counted per mesh and not over the world as a
## whole because two solids that overlap in space cancel each other out and the point between them
## would read as open air — which is exactly the case this test exists to catch.
func _inside(p: Vector3) -> bool:
	var at := p + NUDGE
	var key := "%d,%d" % [floori(at.x / CELL), floori(at.z / CELL)]
	if not _grid.has(key):
		return false
	var crossings := {}
	for tri: Array in _grid[key]:
		if Geometry3D.ray_intersects_triangle(at, Vector3.UP, tri[1], tri[2], tri[3]) == null:
			continue
		crossings[tri[0]] = int(crossings.get(tri[0], 0)) + 1
	for path: String in crossings:
		if int(crossings[path]) % 2 == 1:
			return true
	return false

## How much two coplanar triangles share inside their shared plane: the area of the overlap and
## its narrowest width. Both matter and they say different things — a floor lying on a floor is
## a wide strip metres long and crawls in every frame, while a casing let 5 mm into a wall face
## is the same zero gap over a hairline nobody will ever see. Sorting by area is what separates
## them. Both triangles are flattened onto the plane by dropping the axis the normal is most
## aligned with, which is the projection that cannot degenerate.
##
## Returns [area, narrowest width, the centre of the shared polygon in world space]. The point is
## what the side test asks its question at, so it has to be a place the two really do share and
## not, say, the midpoint between two triangle centres.
func _overlap(a: Array, b: Array) -> Array:
	var drop := _dominant(a[1])
	var pa := [_flat(a[3], drop), _flat(a[4], drop), _flat(a[5], drop)]
	var pb := [_flat(b[3], drop), _flat(b[4], drop), _flat(b[5], drop)]
	var least := INF
	for tri: Array in [pa, pb] as Array[Array]:
		for i in range(3):
			var edge: Vector2 = tri[(i + 1) % 3] - tri[i]
			if edge.length_squared() < DEGENERATE:
				continue
			var axis := Vector2(-edge.y, edge.x).normalized()
			var ra := _span(pa, axis)
			var rb := _span(pb, axis)
			var depth := minf(ra.y, rb.y) - maxf(ra.x, rb.x)
			if depth <= TOUCH:
				return []   # a separating axis: they meet at an edge or miss
			least = minf(least, depth)
	if least == INF:
		return []
	var area := 0.0
	var centre := Vector2.ZERO
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(
			PackedVector2Array(pa), PackedVector2Array(pb)):
		var part := absf(_area(poly))
		area += part
		var mid := Vector2.ZERO
		for v: Vector2 in poly:
			mid += v
		centre += mid / float(poly.size()) * part
	if area <= 0.0:
		return []
	return [area, least, _raise(centre / area, drop, a[1], a[2])]

## Puts a point flattened by `_flat` back on its plane. The dropped axis is the one the normal is
## most aligned with, so its component is the largest there is and the division is always safe.
func _raise(flat: Vector2, drop: int, n: Vector3, d: float) -> Vector3:
	match drop:
		0: return Vector3((d - n.y * flat.x - n.z * flat.y) / n.x, flat.x, flat.y)
		1: return Vector3(flat.x, (d - n.x * flat.x - n.z * flat.y) / n.y, flat.y)
		_: return Vector3(flat.x, flat.y, (d - n.x * flat.x - n.y * flat.y) / n.z)
	return Vector3.ZERO

func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5

func _span(tri: Array, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p: Vector2 in tri:
		var v := axis.dot(p)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(lo, hi)

func _dominant(n: Vector3) -> int:
	var an := n.abs()
	if an.x >= an.y and an.x >= an.z:
		return 0
	return 1 if an.y >= an.z else 2

func _flat(v: Vector3, drop: int) -> Vector2:
	match drop:
		0: return Vector2(v.y, v.z)
		1: return Vector2(v.x, v.z)
		_: return Vector2(v.x, v.y)
	return Vector2.ZERO

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := node as MeshInstance3D
	if mi != null and mi.visible:
		out.append(mi)
	for child: Node in node.get_children():
		out += _meshes(child)
	return out
