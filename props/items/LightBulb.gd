extends ItemGenerator
## A four-pack of light bulbs in its carton, standing up with its printed front to +Z: a folded card box
## with its tuck flap's edge across the top of the front, a coloured panel round its lower half, and a
## bulb printed on the front.
##
##     tint    Color    the panel, default BLUE

const SIZE := Vector3(0.13, 0.12, 0.066)
const EASE := 0.0012
## The panel's top as a share of the height, and the flap's edge under the top.
const PANEL := 0.52
const FLAP := 0.018
## The printed bulb: its globe's radius and middle over the carton's middle, and its screw base.
const GLOBE := 0.024
const GLOBE_Y := 0.012
const BASE := Vector2(0.018, 0.016)

const BLUE := Color(0.14, 0.34, 0.66)
const CARD := Color(0.95, 0.95, 0.93)
const WARM := Color(1.0, 0.86, 0.42)
const GREY := Color(0.6, 0.6, 0.62)
const TINTS: Array[Color] = [BLUE, Color(0.2, 0.52, 0.28), Color(0.9, 0.45, 0.1), BLUE]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	root.add_child(Props.mi(Props.rounded_box(SIZE, EASE, 2, 8), Mats.of("paper", CARD, 0.8), Vector3(0, SIZE.y * 0.5, 0)))
	var band := Vector3(SIZE.x + Props.PROUD * 2.0, SIZE.y * PANEL, SIZE.z + Props.PROUD * 2.0)
	# Starting above the carton's bottom: from it, the band's underside lay in the carton's.
	root.add_child(Props.mi(Props.box(band), Mats.finish("paper", Params.colour(def.params, "tint", BLUE), 0.45), Vector3(0, Props.PROUD * 2.0 + band.y * 0.5, 0)))
	var front := SIZE.z * 0.5 + Props.PROUD * 2.0
	var middle := SIZE.y * 0.5 + GLOBE_Y
	var globe: Array = [[Props.cyl(GLOBE, GLOBE, Props.PROUD * 2.0, 24), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, middle, front))]]
	root.add_child(Props.mi(Props.bake(globe), Props.mat(WARM, 0.45)))
	var printed: Array = [
		Props.part(Vector3(BASE.x, BASE.y, Props.PROUD * 2.0), Vector3(0, middle - GLOBE - BASE.y * 0.4, front)),
		Props.part(Vector3(SIZE.x, Props.PROUD * 2.0, Props.PROUD * 2.0), Vector3(0, SIZE.y - FLAP, SIZE.z * 0.5)),
	]
	root.add_child(Props.mi(Props.bake(printed), Props.mat(GREY, 0.5)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}
