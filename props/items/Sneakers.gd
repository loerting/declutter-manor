extends ItemGenerator
## A pair of sneakers side by side, toes to +Z: each a rubber sole with a rolled edge under an upper
## that rises from it to a collar round a real opening, lined down to the insole, with laces across
## the vamp and a tab at the heel (`ShoeLast`, at its default numbers).
##
##     tint      Color    the upper, default WHITE
##     length    float    the sole's length in metres, default 0.29

const WHITE := Color(0.93, 0.93, 0.92)
const SOLE_RUBBER := Color(0.95, 0.94, 0.9)
const LACE := Color(0.98, 0.98, 0.97)
## Two pairs each for the adults, then the children's smaller pairs.
const VARIANTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const TINTS: Array[Color] = [WHITE, Color(0.08, 0.08, 0.09), Color(0.55, 0.56, 0.58), Color(0.14, 0.2, 0.36),
		Color(0.75, 0.16, 0.14), Color(0.9, 0.55, 0.66), Color(0.2, 0.45, 0.8), Color(0.25, 0.55, 0.3)]
const LENGTHS: Array[float] = [0.29, 0.21]

func build(def: ItemDef) -> Node3D:
	var upper := Mats.of("sofa_fabric", Params.colour(def.params, "tint", WHITE), 0.9, 0.5)
	return ShoeLast.new().pair(Params.number(def.params, "length", ShoeLast.LENGTH), upper, Props.mat(SOLE_RUBBER, 0.8),
			Props.mat(LACE, 0.8))

func variant(index: int) -> Dictionary:
	var v := VARIANTS[index % VARIANTS.size()]
	return {"tint": TINTS[v.x], "length": LENGTHS[v.y]}
