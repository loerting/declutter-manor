extends ItemGenerator
## A hand towel folded in three along its length and hung over a rail, the front fall longer than the
## back: its section, a U of terry round the rail, drawn out across its width.
##
##     tint    Color    default SAGE

const WIDTH := 0.2
const THICK := 0.009
const RAIL_RADIUS := 0.011
const FRONT := 0.24
const BACK := 0.19
const ARC_STEPS := 10

const SAGE := Color(0.62, 0.72, 0.62)
const VARIANTS: Array[Color] = [SAGE, Color(0.94, 0.9, 0.82)]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var inner := RAIL_RADIUS
	var outer := RAIL_RADIUS + THICK
	# The section in (z, y), the rail's middle at (0, top): up the front's outside, over the rail, down
	# the back's outside, then back along the inside, which wraps the rail's top.
	var top := FRONT + outer
	var section := PackedVector2Array()
	section.append(Vector2(outer, 0.0))
	section.append_array(_arc(Vector2(0, top), outer, 0.0, PI))
	section.append(Vector2(-outer, top - BACK))
	section.append(Vector2(-inner, top - BACK))
	section.append_array(_arc(Vector2(0, top), inner, PI, 0.0))
	section.append(Vector2(inner, 0.0))
	root.add_child(Props.mi(Props.extrude(section, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -WIDTH * 0.5, WIDTH * 0.5),
			Mats.of("rug_wool", Params.colour(def.params, "tint", SAGE), 1.0, 0.3)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": VARIANTS[index % VARIANTS.size()]}

## Put down, it lies folded flat.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5)

## The arc of `radius` about `centre` from `from` to `to`, both ends included, angles from +Z toward +Y.
static func _arc(centre: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(ARC_STEPS + 1):
		var a := lerpf(from, to, float(i) / float(ARC_STEPS))
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out
