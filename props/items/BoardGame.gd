extends ItemGenerator
## A board game in its box, lying flat: a card base under a printed lid that comes two thirds of the way
## down it, a title band across the lid's top and a round emblem beside it.
##
##     width    float    across, metres, default 0.295
##     depth    float    front to back, metres, default 0.295
##     tint     Color    the lid, default RED
##     band     Color    the title band and the emblem, default GOLD

## Every box is this tall, so a stack of them in a cube is a stack and not a pile with gaps.
const HEIGHT := 0.07
const DEFAULT_SIZE := 0.295
const LID_DROP := 0.047
## The base stands in from the lid's walls by the card's thickness.
const WALL := 0.0018
const EASE := 0.0015
## The band's share of the lid's width and depth, and how far forward of the middle it lies.
const BAND := Vector2(0.78, 0.2)
const BAND_FORWARD := 0.22
const EMBLEM := 0.18
const EMBLEM_AT := Vector2(0.28, -0.22)

const RED := Color(0.7, 0.16, 0.1)
const GOLD := Color(0.93, 0.74, 0.28)
const CARD := Color(0.84, 0.8, 0.72)
const VARIANTS: Array[Dictionary] = [
	{"width": 0.295, "depth": 0.295, "tint": RED, "band": GOLD},
	{"width": 0.3, "depth": 0.22, "tint": Color(0.14, 0.2, 0.42), "band": Color(0.95, 0.94, 0.9)},
	{"width": 0.27, "depth": 0.27, "tint": Color(0.2, 0.45, 0.24), "band": Color(0.96, 0.86, 0.5)},
	{"width": 0.31, "depth": 0.24, "tint": Color(0.93, 0.92, 0.88), "band": Color(0.16, 0.36, 0.7)},
	{"width": 0.295, "depth": 0.295, "tint": Color(0.08, 0.08, 0.09), "band": Color(0.8, 0.62, 0.26)},
	{"width": 0.26, "depth": 0.19, "tint": Color(0.92, 0.5, 0.12), "band": Color(0.2, 0.16, 0.14)},
]

func build(def: ItemDef) -> Node3D:
	var width := Params.number(def.params, "width", DEFAULT_SIZE)
	var depth := Params.number(def.params, "depth", DEFAULT_SIZE)
	var tint := Params.colour(def.params, "tint", RED)
	var band_tint := Params.colour(def.params, "band", GOLD)
	var root := Node3D.new()
	var base := Vector3(width - WALL * 2.0, HEIGHT - WALL, depth - WALL * 2.0)
	root.add_child(Props.mi(Props.rounded_box(base, EASE, 2, 8), Mats.of("paper", CARD, 1.0), Vector3(0, base.y * 0.5, 0)))
	var lid := Vector3(width, LID_DROP, depth)
	root.add_child(Props.mi(Props.rounded_box(lid, EASE, 2, 8), Mats.finish("paper", tint, 0.42), Vector3(0, HEIGHT - lid.y * 0.5, 0)))
	var print_parts: Array = [
		Props.part(Vector3(width * BAND.x, Props.PROUD * 2.0, depth * BAND.y), Vector3(0, HEIGHT, depth * BAND_FORWARD)),
		[Props.cyl(width * EMBLEM * 0.5, width * EMBLEM * 0.5, Props.PROUD * 2.0, 20),
				Transform3D(Basis.IDENTITY, Vector3(width * EMBLEM_AT.x, HEIGHT, depth * EMBLEM_AT.y))],
	]
	root.add_child(Props.mi(Props.bake(print_parts), Mats.finish("paper", band_tint, 0.42)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]
