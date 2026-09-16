extends FurnitureGenerator
## A planted bed against a wall: timber edging along the front and both ends, a bed of bark mulch inside it, a row
## of clipped box shrubs along the back and clumps of flowering perennials along the front, with room left
## between the clumps for the things that live in the bed.
##
##     width     float    along the wall, metres, default 5.1
##     depth     float    out from the wall, metres, default 0.85
##     places    int      the clear places along the front, default 3
##
## Anchors:
##
##     bed    on the mulch at the leftmost clear place; the others are PLACE_STEP to the right

const DEFAULT_WIDTH := 5.1
const DEFAULT_DEPTH := 0.85
const DEFAULT_PLACES := 3
const PLACE_STEP := 1.2
const EDGING := Vector2(0.04, 0.16)
const MULCH_TOP := 0.12
## Box shrubs: roughly one per this much width, their radius, how far off the wall their middles stand, and the
## tufts that give each its lumpy outline.
const SHRUB_PITCH := 1.25
const SHRUB := 0.3
const SHRUB_Z := 0.4
const TUFTS := 34
const TUFT := 0.24
const TUFT_SIZES: Array[float] = [0.85, 1.0, 1.15]
const SHRUB_SQUASH := 0.82
## Perennial clumps: how far out their middles stand, the mound's half size, flower heads on each and their radius.
const CLUMP_Z := 0.66
const MOUND := Vector3(0.15, 0.09, 0.12)
const FLOWERS := 11
const FLOWER := 0.024
## No clump stands nearer a clear place than this, and clumps stand about this far apart.
const CLEAR := 0.32
const CLUMP_PITCH := 0.42
const SEED := 4417

const TIMBER := Color(0.46, 0.36, 0.26)
const MULCH := Color(0.42, 0.3, 0.22)
const BOX_GREEN := Color(0.2, 0.32, 0.15)
const LEAF_GREEN := Color(0.3, 0.48, 0.22)
const BLOOMS: Array[Color] = [Color(0.56, 0.34, 0.72), Color(0.95, 0.94, 0.9), Color(0.95, 0.78, 0.2), Color(0.86, 0.36, 0.5)]

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var depth := Params.number(def.params, "depth", DEFAULT_DEPTH)
	var places := maxi(Params.integer(def.params, "places", DEFAULT_PLACES), 1)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, depth))
	var hx := width * 0.5
	var edging: Array = [[Props.rounded_box(Vector3(width, EDGING.y, EDGING.x), 0.006, 2, 8),
			Transform3D(Basis.IDENTITY, Vector3(0, EDGING.y * 0.5, depth - EDGING.x * 0.5))]]
	for side: float in [-1.0, 1.0]:
		edging.append([Props.rounded_box(Vector3(EDGING.x, EDGING.y, depth - EDGING.x), 0.006, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(side * (hx - EDGING.x * 0.5), EDGING.y * 0.5, (depth - EDGING.x) * 0.5))])
	piece.add_child(Props.mi(Props.bake(edging), Mats.of("oak", TIMBER, 0.9)))
	piece.add_child(Props.mi(Props.box(Vector3(width - EDGING.x * 2.0, MULCH_TOP, depth - EDGING.x)), Mats.of("soil", MULCH, 1.0),
			Vector3(0, MULCH_TOP * 0.5, (depth - EDGING.x) * 0.5)))

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Every tuft, mound and flower head is one of a few meshes built here once and baked in place many times:
	# built one by one, the front bed's hundreds of little ellipsoids took a quarter of a second (2026-09-15).
	var core := Props.ellipsoid(Vector3(SHRUB, SHRUB * SHRUB_SQUASH, SHRUB), 8, 14)
	var tufts: Array[ArrayMesh] = []
	for size: float in TUFT_SIZES:
		tufts.append(Props.ellipsoid(Vector3.ONE * SHRUB * TUFT * size, 5, 8))
	var mound := Props.ellipsoid(MOUND, 7, 12)
	var flower := Props.ellipsoid(Vector3.ONE * FLOWER, 5, 8)
	var box_green: Array = []
	var shrubs := maxi(roundi(width / SHRUB_PITCH), 1)
	for k in range(shrubs):
		var x := -hx + width * (float(k) + 0.5) / float(shrubs)
		_shrub(box_green, Vector3(x, MULCH_TOP + SHRUB * SHRUB_SQUASH * 0.7, SHRUB_Z), rng, core, tufts)
	piece.add_child(Props.mi(Props.bake(box_green), Props.mat(BOX_GREEN, 0.8)))

	var first := -PLACE_STEP * float(places - 1) * 0.5
	var leaves: Array = []
	var blooms: Array[Array] = []
	for i in range(BLOOMS.size()):
		blooms.append([])
	# Clear of the end edging by more than a seam: the first mound, laid against it, shared its plane.
	var x := -hx + EDGING.x + MOUND.x + Props.PROUD * 3.0
	var n := 0
	while x < hx - EDGING.x - MOUND.x:
		var near := false
		for p in range(places):
			near = near or absf(x - (first + PLACE_STEP * float(p))) < CLEAR
		if not near:
			_clump(leaves, blooms[n % BLOOMS.size()], Vector3(x, MULCH_TOP, minf(CLUMP_Z, depth - EDGING.x - MOUND.z)), rng, mound, flower)
			n += 1
		x += CLUMP_PITCH
	piece.add_child(Props.mi(Props.bake(leaves), Props.mat(LEAF_GREEN, 0.75)))
	for i in range(BLOOMS.size()):
		if not blooms[i].is_empty():
			piece.add_child(Props.mi(Props.bake(blooms[i]), Props.mat(BLOOMS[i], 0.7)))

	piece.add_anchor(&"bed", Transform3D(Basis.IDENTITY, Vector3(first, MULCH_TOP, minf(CLUMP_Z, depth - EDGING.x - MOUND.z))), piece)
	piece.add_box(Vector3(width, EDGING.y, depth), Vector3(0, EDGING.y * 0.5, depth * 0.5))
	return piece

## A clipped box shrub: a squashed core with tufts round its upper part.
static func _shrub(out: Array, at: Vector3, rng: RandomNumberGenerator, core: ArrayMesh, tufts: Array[ArrayMesh]) -> void:
	var half := Vector3(SHRUB, SHRUB * SHRUB_SQUASH, SHRUB)
	out.append([core, Transform3D(Basis.IDENTITY, at)])
	for k in range(TUFTS):
		var a := TAU * (float(k) + rng.randf()) / float(TUFTS)
		var up := rng.randf_range(-0.1, 0.95)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		out.append([tufts[rng.randi_range(0, tufts.size() - 1)], Transform3D(Basis.IDENTITY, at + dir * half * 0.9)])

## A perennial: a leafy mound with flower heads over its top.
static func _clump(leaves: Array, blooms: Array, at: Vector3, rng: RandomNumberGenerator, mound: ArrayMesh, flower: ArrayMesh) -> void:
	leaves.append([mound, Transform3D(Basis.IDENTITY, at + Vector3(0, MOUND.y * 0.55, 0))])
	for k in range(FLOWERS):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.8
		var p := Vector3(cos(a) * MOUND.x * r, 0.0, sin(a) * MOUND.z * r)
		p.y = MOUND.y * 0.55 + MOUND.y * sqrt(maxf(1.0 - r * r, 0.0)) + FLOWER * 0.3
		blooms.append([flower, Transform3D(Basis.IDENTITY, at + p)])
