extends ItemGenerator
## A bath towel folded for the linen cupboard, lying flat: the fold rolled round at its front (+Z), the
## layers' edges showing at its back, and its top a little full.
##
##     tint    Color    default WHITE

const WIDTH := 0.3
const DEPTH := 0.25
const THICK := 0.05
const CROWN := 0.004
const LAYERS := 3
## How far each layer's edge stands out at the back, and how far in the creases between them are.
const LAYER_BULGE := 0.004
const ARC_STEPS := 8
const TOP_STEPS := 8
## The towel's ends are eased this far in over this far along it.
const END_EASE := Vector2(0.006, 0.012)

const WHITE := Color(0.95, 0.94, 0.9)
## Two per person: a pair in each colour.
const VARIANTS: Array[Color] = [WHITE, WHITE, Color(0.62, 0.72, 0.62), Color(0.62, 0.72, 0.62),
		Color(0.28, 0.36, 0.52), Color(0.28, 0.36, 0.52), Color(0.86, 0.78, 0.64), Color(0.86, 0.78, 0.64)]

func build(def: ItemDef) -> Node3D:
	var section := _section()
	var rings: Array = []
	for x: float in [-WIDTH * 0.5, -WIDTH * 0.5 + END_EASE.y, WIDTH * 0.5 - END_EASE.y, WIDTH * 0.5]:
		var ease := END_EASE.x if absf(x) > WIDTH * 0.5 - END_EASE.y * 0.5 else 0.0
		var ring := PackedVector3Array()
		for p: Vector2 in section:
			var towards := (Vector2(0, THICK * 0.5) - p).normalized() * ease
			ring.append(Vector3(x, p.y + towards.y, p.x + towards.x))
		rings.append(ring)
	var root := Node3D.new()
	root.add_child(Props.mi(Props.loft(rings), Mats.of("rug_wool", Params.colour(def.params, "tint", WHITE), 1.0, 0.3)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": VARIANTS[index % VARIANTS.size()]}

## The section in (z, y), counter-clockwise, which is what a loft stacked along +X needs to face out:
## along the bottom to the front, round the fold, back over the full top, and down the layers' edges.
static func _section() -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := THICK * 0.5
	var fold := Vector2(DEPTH * 0.5 - r, r)
	var back := -DEPTH * 0.5
	for i in range(TOP_STEPS):
		out.append(Vector2(lerpf(back + LAYER_BULGE, fold.x, float(i) / float(TOP_STEPS)), 0.0))
	for i in range(ARC_STEPS + 1):
		var a := -PI * 0.5 + PI * float(i) / float(ARC_STEPS)
		out.append(fold + Vector2(cos(a), sin(a)) * r)
	for i in range(1, TOP_STEPS):
		var z := lerpf(fold.x, back + LAYER_BULGE, float(i) / float(TOP_STEPS))
		var share := (z - back) / DEPTH
		out.append(Vector2(z, THICK + CROWN * 4.0 * share * (1.0 - share)))
	# Down the back, one bulge per layer.
	var steps := 4
	for layer in range(LAYERS):
		for s in range(steps):
			var t := (float(LAYERS - 1 - layer) + 1.0 - float(s) / float(steps)) / float(LAYERS)
			var bulge := sin(PI * (1.0 - float(s) / float(steps)))
			out.append(Vector2(back + LAYER_BULGE * (1.0 - bulge), THICK * t))
	return out
