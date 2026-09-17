class_name TerrainBuilder
## The ground the house sits in. Grass is laid as the border rectangles left over around the
## building footprint rather than as a lawn with a hole cut in it: a polygon with a hole cannot
## be triangulated directly, and four rectangles are exact, cheap and always valid.
##
## Paved exterior zones (driveway, deck, pool surround) are their own rooms in the plan and are
## built by HouseBuilder as ordinary floor slabs sitting just above the grass.
##
## A pool is the one thing that takes ground away rather than covering it: its footprint is cut
## out of the grass here with the same rectangle decomposition the stairwells use, because a
## basin under an unbroken lawn is a basin nobody can see into.

## The lot is where the game happens; the ground has to keep going past it or every exterior
## view ends in a hard rectangle floating against the sky. Nothing outside the lot is reachable
## — walls and the plan bound the player, not the edge of the grass.
const SURROUND := 45.0
const GRASS_DEPTH := 0.4
## Grass sits a hair below the paving so the two never fight for the same pixel.
const GRASS_TOP := -0.02
## Macro variation. The lawn texture tiles every 1.4 m; over a 116 m square that repeat is the
## whole reason a big flat lawn reads as a billiard table. The mesh carries a second, much
## slower variation on a 14 m lattice — dry patches and shade, the scale a real lawn varies at.
const MACRO_LATTICE := 14.0
const MACRO_CELL := 4.0
const MACRO_RANGE := 0.16

static func build(parent: Node3D, plan: FloorPlan) -> void:
	var holder := Node3D.new()
	holder.name = "Terrain"
	parent.add_child(holder)
	var grass := Mats.of(plan.ground_slot, Color(0.92, 1.0, 0.88), 1.0, 1.0, true, false, true)

	var built := _building_bounds(plan)
	var lot := plan.lot.grow(SURROUND)
	var strips: Array[Rect2] = []
	if built.size == Vector2.ZERO:
		strips.append(lot)
	else:
		strips.append(Rect2(lot.position.x, lot.position.y, lot.size.x, built.position.y - lot.position.y))
		strips.append(Rect2(lot.position.x, built.end.y, lot.size.x, lot.end.y - built.end.y))
		strips.append(Rect2(lot.position.x, built.position.y, built.position.x - lot.position.x, built.size.y))
		strips.append(Rect2(built.end.x, built.position.y, lot.end.x - built.end.x, built.size.y))
		strips.append_array(_gap_rects(plan, built))

	var i := 0
	for strip: Rect2 in strips:
		i += 1
		if strip.size.x < 0.01 or strip.size.y < 0.01:
			continue
		var pieces: Array[PackedVector2Array] = [PackedVector2Array([strip.position,
				Vector2(strip.end.x, strip.position.y), strip.end,
				Vector2(strip.position.x, strip.end.y)])]
		for pool: PoolDef in plan.pools:
			if not strip.encloses(pool.lawn_hole()) and not strip.intersects(pool.lawn_hole()):
				continue
			var next: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				next.append_array(HouseBuilder.cut_rect(piece, pool.lawn_hole()))
			pieces = next
		var j := 0
		for poly: PackedVector2Array in pieces:
			j += 1
			var mi := MeshInstance3D.new()
			mi.name = "Grass%d_%d" % [i, j]
			# Every piece is a rectangle — the strips are, and cutting a rectangle out of one
			# leaves rectangles — so the tinted slab covers each exactly. Anything else would
			# be a plan the decomposition does not produce, and gets the plain solid.
			mi.mesh = Props.ground_slab(HouseBuilder.bounds(poly), GRASS_TOP - GRASS_DEPTH,
					GRASS_TOP, MACRO_CELL, _tint) if poly.size() == 4 \
					else Props.prism(poly, GRASS_TOP - GRASS_DEPTH, GRASS_TOP)
			mi.set_surface_override_material(0, grass)
			holder.add_child(mi)
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mi.mesh.create_trimesh_shape()
			body.add_child(shape)
			holder.add_child(body)
			HouseBuilder.backing(holder, poly, GRASS_TOP - GRASS_DEPTH, GRASS_TOP, "Grass%d_%dBacking" % [i, j])

## Lawn colour at a world point: value noise on `MACRO_LATTICE`, smoothed, as a multiplier on
## the grass albedo. A pure function of world position, so two pieces meeting at a seam agree
## on the colour of the grass along it.
static func _tint(x: float, z: float) -> Color:
	var u := x / MACRO_LATTICE
	var v := z / MACRO_LATTICE
	var ix := int(floor(u))
	var iz := int(floor(v))
	var fx := smoothstep(0.0, 1.0, u - float(ix))
	var fz := smoothstep(0.0, 1.0, v - float(iz))
	var n := lerpf(lerpf(_lattice(ix, iz), _lattice(ix + 1, iz), fx),
			lerpf(_lattice(ix, iz + 1), _lattice(ix + 1, iz + 1), fx), fz)
	var k := 1.0 + (n - 0.5) * 2.0 * MACRO_RANGE
	# the bright patches are the dry ones, so they lose a little green as they gain value
	return Color(k, k * (1.0 - (k - 1.0) * 0.6), k * 0.99)

## Deterministic 0..1 value at a lattice point. Integer hash rather than a seeded RNG: the
## lawn has to look the same in every session and in every render, including the aerial the
## gate is judged on.
static func _lattice(ix: int, iz: int) -> float:
	var h := ix * 374761393 + iz * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0

## The ground inside the building's bounding rectangle that no room stands on. The footprint is
## not its bounding box: the manor is an L and the garage arm stops four metres short of the
## rear wall, so a 6 x 4 m notch behind the house was covered by neither a room nor a border
## strip and had no ground at all — the pool view looked out at a void where the lawn should
## meet the house (2026-09-10). The notch is found by cutting the bounding rectangle on the
## grid of every room edge, keeping the cells no room covers and merging each row back into
## runs: exact, always rectangles, and a handful of meshes rather than a cell each.
static func _gap_rects(plan: FloorPlan, built: Rect2) -> Array[Rect2]:
	var foot: Array[Rect2] = []
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR:
			continue
		foot.append(HouseBuilder.bounds(room.polygon))
	var xs := _edges(built.position.x, built.end.x, foot, true)
	var zs := _edges(built.position.y, built.end.y, foot, false)
	var out: Array[Rect2] = []
	for iz: int in zs.size() - 1:
		var run := Rect2()
		var open := false
		for ix: int in xs.size() - 1:
			var cell := Rect2(xs[ix], zs[iz], xs[ix + 1] - xs[ix], zs[iz + 1] - zs[iz])
			var covered := false
			for f: Rect2 in foot:
				if f.has_point(cell.get_center()):
					covered = true
					break
			if covered:
				if open:
					out.append(run)
					open = false
				continue
			run = cell if not open else run.merge(cell)
			open = true
		if open:
			out.append(run)
	return out

## The sorted, deduplicated cut lines between `lo` and `hi` on one axis: the bounds themselves
## plus every room edge strictly inside them.
static func _edges(lo: float, hi: float, foot: Array[Rect2], on_x: bool) -> PackedFloat32Array:
	var vals: Array[float] = [lo, hi]
	for f: Rect2 in foot:
		var pair: Array[float] = []
		if on_x:
			pair.append(f.position.x)
			pair.append(f.end.x)
		else:
			pair.append(f.position.y)
			pair.append(f.end.y)
		for v: float in pair:
			if v > lo + 0.005 and v < hi - 0.005:
				vals.append(v)
	vals.sort()
	var out := PackedFloat32Array()
	for v: float in vals:
		if out.is_empty() or v - out[out.size() - 1] > 0.005:
			out.append(v)
	return out

## Plan-space rectangle the building occupies. Exterior zones are ground, not building, so
## they do not push the grass back.
static func _building_bounds(plan: FloorPlan) -> Rect2:
	var out := Rect2()
	var first := true
	for room: RoomDef in plan.all_rooms():
		if room.zone == RoomDef.Zone.EXTERIOR:
			continue
		var r := Rect2(room.polygon[0], Vector2.ZERO)
		for p: Vector2 in room.polygon:
			r = r.expand(p)
		out = r if first else out.merge(r)
		first = false
	return out
