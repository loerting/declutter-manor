extends ItemGenerator
## A combination wrench lying flat, its length along Z: a ring end at +Z round a twelve-point hole, an open
## jaw at -Z set at fifteen degrees to the shank, and a shank that widens toward the jaw. One forging, cut
## from its outline as one plate.
##
##     size    float    across the flats the wrench fits, metres, default 0.013
##
## The outline has a hole in it, and a polygon with a hole is not one polygon: it is cut along its middle
## into two halves, each an outline with a notch, which share their edge along the cut.

const DEFAULT_SIZE := 0.013
## Proportions of a 13 mm wrench, as shares of the size: length, the ring's outer radius, the jaw head's
## radius, the shank's width at each end, and the thickness.
const LENGTH := 13.1
const RING := 1.0
const HOLE := 0.56
const HEAD := 1.18
const SHANK := Vector2(0.78, 0.98)
const THICK := 0.46
const JAW_DEG := 15.0
## The jaw's opening runs this far into the head past its middle, round-bottomed.
const JAW_DEPTH := 0.12
const RING_SIDES := 24
const HOLE_POINTS := 12

const CHROME := Color(0.86, 0.87, 0.88)
const SIZES: Array[float] = [0.01, 0.013, 0.017, 0.019]

func build(def: ItemDef) -> Node3D:
	var s := Params.number(def.params, "size", DEFAULT_SIZE)
	var length := s * LENGTH * pow(s / DEFAULT_SIZE, -0.2)
	var ring_at := Vector2(length * 0.5 - s * RING, 0.0)
	var head_at := Vector2(-length * 0.5 + s * HEAD * 0.8, 0.0)
	var outline := _circle(ring_at, s * RING, RING_SIDES)
	var shank := PackedVector2Array([Vector2(ring_at.x, -s * SHANK.x * 0.5), Vector2(ring_at.x, s * SHANK.x * 0.5),
			Vector2(head_at.x, s * SHANK.y * 0.5), Vector2(head_at.x, -s * SHANK.y * 0.5)])
	outline = Geometry2D.merge_polygons(outline, shank)[0]
	outline = Geometry2D.merge_polygons(outline, _circle(head_at, s * HEAD, RING_SIDES))[0]
	outline = Geometry2D.clip_polygons(outline, _jaw(head_at, s))[0]
	var hole := _circle(ring_at, s * HOLE, HOLE_POINTS)
	var reach := length
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		var half := PackedVector2Array([Vector2(-reach, 0.0), Vector2(reach, 0.0), Vector2(reach, side * reach), Vector2(-reach, side * reach)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(outline, half):
			for cut: PackedVector2Array in Geometry2D.clip_polygons(piece, hole):
				parts.append([Props.extrude(cut, Vector3.ZERO, Vector3.BACK, Vector3.RIGHT, Vector3.UP, 0.0, s * THICK), Transform3D.IDENTITY])
	var root := Node3D.new()
	root.add_child(Props.mi(Props.bake(parts), Mats.of("metal_brushed", CHROME, 0.25)))
	return root

func variant(index: int) -> Dictionary:
	return {"size": SIZES[index % SIZES.size()]}

static func _circle(centre: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(sides):
		var a := TAU * float(k) / sides
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out

## The jaw's opening: as wide as the size, from a round bottom just past the head's middle out beyond its
## end, turned off the shank's line.
static func _jaw(head_at: Vector2, s: float) -> PackedVector2Array:
	var along := Vector2(-1, 0).rotated(deg_to_rad(JAW_DEG))
	var across := Vector2(-along.y, along.x)
	var bottom := head_at - along * s * JAW_DEPTH
	var out := PackedVector2Array()
	for k in range(9):
		var a := PI * float(k) / 8.0
		out.append(bottom + across * cos(a) * s * 0.5 - along * sin(a) * s * 0.5)
	var far := bottom + along * s * HEAD * 3.0
	out.append(far - across * s * 0.5)
	out.append(far + across * s * 0.5)
	return out
