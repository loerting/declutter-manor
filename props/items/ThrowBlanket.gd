extends ItemGenerator
## A knitted throw, folded lengthways and rolled up, standing on end the way one is kept in a
## basket. A flat fold would lie out of sight at the bottom of a 0.4 m basket; a roll stands above
## the rim.
##
##     tint    Color    wool colour, default RUST

const HEIGHT := 0.44
## The folded throw's thickness, and how far each turn of the roll steps out: a little more than a
## layer, so the turns show from above.
const LAYER := 0.019
const PITCH := 0.025
const CORE := 0.025
const TURNS := 3.0
## A rolled throw is not a machined cylinder: the core stands up out of the roll by this much and the
## roll is squeezed a little oval.
const TELESCOPE := 0.018
const OVAL := 0.06
const STEPS_PER_TURN := 44
const END_STEPS := 5
const SIDE_STEPS := 10
## The throw's free end thins over this much of a turn so it lies into the roll.
const TAPER_TURN := 0.3
const END_THINNING := 0.4

const RUST := Color(0.62, 0.33, 0.22)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var wool := Mats.of("rug_wool", Params.colour(def.params, "tint", RUST), 1.0)
	root.add_child(Props.mi(_roll(), wool))
	return root

func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)

## The layer's section, a stadium LAYER thick, swept along an Archimedean spiral from the core out.
static func _roll() -> ArrayMesh:
	var steps := int(TURNS * STEPS_PER_TURN)
	var rings: Array = []
	for k in range(steps + 1):
		var turn := TURNS * float(k) / float(steps)
		var theta := TAU * turn
		var out := Vector3(cos(theta), 0, sin(theta))
		var r := (CORE + PITCH * turn) * (1.0 + OVAL * cos(theta * 2.0))
		var lift := TELESCOPE * (1.0 - turn / TURNS)
		var thin := minf(smoothstep(0.0, TAPER_TURN, turn), smoothstep(0.0, TAPER_TURN, TURNS - turn))
		var half := LAYER * 0.5 * lerpf(END_THINNING, 1.0, thin)
		var ring := PackedVector3Array()
		for p: Vector2 in _stadium(half):
			ring.append(out * (r + p.x) + Vector3(0, p.y + lift, 0))
		rings.append(ring)
	# Stacked from the free end in, which is the order that winds the skin outward.
	rings.reverse()
	return Props.loft(rings)

## Counter-clockwise in (out, up): up the outer face, over the top, down the inner face, under the
## bottom. The flat faces carry points along them, or smooth shading darkens them.
static func _stadium(half: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var low := LAYER * 0.5
	var high := HEIGHT - LAYER * 0.5
	for i in range(SIDE_STEPS):
		pts.append(Vector2(half, lerpf(low, high, float(i) / float(SIDE_STEPS))))
	for i in range(END_STEPS + 1):
		var a := PI * float(i) / float(END_STEPS)
		pts.append(Vector2(cos(a) * half, high + sin(a) * LAYER * 0.5))
	for i in range(1, SIDE_STEPS):
		pts.append(Vector2(-half, lerpf(high, low, float(i) / float(SIDE_STEPS))))
	for i in range(END_STEPS + 1):
		var a := PI + PI * float(i) / float(END_STEPS)
		pts.append(Vector2(cos(a) * half, low + sin(a) * LAYER * 0.5))
	return pts
