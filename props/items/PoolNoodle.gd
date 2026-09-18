extends ItemGenerator
## A foam pool noodle standing on end: a fluted tube with a hole down its middle, cut square at both ends.
## The hole is seen at every end, so it is a hole: the outside, one end, the bore and the other end are one
## closed surface.
##
##     tint    Color    the foam, default YELLOW

const LENGTH := 1.52
const RADIUS := 0.032
const BORE := 0.011
## Ridges round the outside, and how far each stands out and in as a share of the radius.
const LOBES := 8
const FLUTE := 0.07
const POINTS_PER_LOBE := 6

const YELLOW := Color(0.98, 0.84, 0.16)
const TINTS: Array[Color] = [YELLOW, Color(0.95, 0.36, 0.62), Color(0.3, 0.78, 0.36), Color(0.2, 0.56, 0.9)]

func build(def: ItemDef) -> Node3D:
	var tint := Params.colour(def.params, "tint", YELLOW)
	var points := LOBES * POINTS_PER_LOBE
	var outer_bottom := _ring(points, 0.0, true)
	var outer_top := _ring(points, LENGTH, true)
	var inner_top := _ring(points, LENGTH, false)
	var inner_bottom := _ring(points, 0.0, false)
	# Up the outside, in across the top, down the bore and out across the bottom, as a closed lathe would
	# go: each corner ring twice, so the corners are edges and not rounded by the shading.
	var rings: Array = [outer_bottom, outer_top, outer_top, inner_top, inner_top, inner_bottom, inner_bottom, outer_bottom]
	var root := Node3D.new()
	root.add_child(Props.mi(Props.loft(rings, false, false), Mats.finish("plastic", tint, 0.85)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## Put down anywhere but the pool bin, a noodle lies along Z.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.5)

## A ring at height `y`, turning from +X toward +Z: the fluted outside, or the round bore.
static func _ring(points: int, y: float, outside: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in range(points):
		var a := TAU * float(j) / float(points)
		var r := RADIUS * (1.0 + FLUTE * cos(float(LOBES) * a)) if outside else BORE
		out.append(Vector3(cos(a) * r, y, sin(a) * r))
	return out
