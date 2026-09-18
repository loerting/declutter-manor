extends ItemGenerator
## A pair of leather dress shoes side by side, toes to +Z: a thin sole arching up to a heel block, a
## long narrow vamp and a low top line in polished leather (`ShoeLast`). Oxfords are laced; loafers and
## flats are not.
##
##     style     int      0 an oxford, 1 a loafer, 2 a flat; default 0
##     tint      Color    the leather, default BLACK
##     length    float    the sole's length in metres, default 0.3

const DEFAULT_LENGTH := 0.3
const BLACK := Color(0.05, 0.05, 0.055)
const SOLE := Color(0.16, 0.1, 0.07)
const LACE := Color(0.06, 0.05, 0.05)
## Two pairs per adult: two oxfords, a loafer and a flat.
const VARIANTS: Array[Dictionary] = [
	{"style": 0, "tint": BLACK, "length": 0.3},
	{"style": 0, "tint": Color(0.36, 0.2, 0.1), "length": 0.3},
	{"style": 1, "tint": Color(0.32, 0.08, 0.1), "length": 0.26},
	{"style": 2, "tint": Color(0.1, 0.13, 0.24), "length": 0.25},
]

func build(def: ItemDef) -> Node3D:
	var style := Params.integer(def.params, "style", 0)
	var last := ShoeLast.new()
	last.half_width_share = 0.33
	last.outline = 2.0
	last.heel_narrow = 0.26
	last.big_toe = 0.03
	last.sole = 0.011
	last.sole_grow = 0.004
	last.tuck = 0.003
	last.top_side = 0.046
	last.top_heel = 0.02
	last.top_throat = 0.036
	last.toe_wall = Vector2(0.3, 0.3)
	last.opening_z = -0.27
	last.opening_half = Vector2(0.1, 0.12)
	last.lining = 0.003
	last.roll = 0.001
	last.insole = 0.008
	last.heel_tab = Vector3.ZERO
	last.heel = Vector2(0.024, 0.24)
	last.laces = 4
	last.lace_span = Vector2(0.62, 0.86)
	last.lace_radius = 0.0012
	last.lace_length = 0.026
	match style:
		1:
			last.laces = 0
			last.top_throat = 0.03
			last.opening_half = Vector2(0.11, 0.14)
			last.heel = Vector2(0.018, 0.22)
		2:
			last.laces = 0
			last.top_side = 0.03
			last.top_heel = 0.018
			last.top_throat = 0.012
			last.opening_z = -0.2
			last.opening_half = Vector2(0.115, 0.2)
			last.heel = Vector2(0.012, 0.2)
	var leather := Mats.finish("leather", Params.colour(def.params, "tint", BLACK), 0.28)
	return last.pair(Params.number(def.params, "length", DEFAULT_LENGTH), leather, Mats.finish("rubber", SOLE, 0.6), Props.mat(LACE, 0.7))

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]
