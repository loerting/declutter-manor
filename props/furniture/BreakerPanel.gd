extends FurnitureGenerator
## An electrical breaker panel on the wall: a grey steel box, its hinged cover with a latch, a label card in
## a frame on the cover, and two conduits up out of its top to the ceiling.
##
##     bottom     float    the box's bottom above the floor, default 1.1
##     ceiling    float    the room's height, default 2.4

const BOX := Vector3(0.36, 0.76, 0.1)
const COVER := Vector3(0.34, 0.74, 0.008)
const LATCH := Vector3(0.02, 0.05, 0.012)
const CARD := Vector3(0.16, 0.22, 0.002)
const CONDUIT := 0.013
const CONDUIT_X := 0.08
const DEFAULT_BOTTOM := 1.1
const DEFAULT_CEILING := 2.4
const CEILING_GAP := 0.005

const STEEL := Color(0.62, 0.63, 0.64)
const CARD_TINT := Color(0.94, 0.94, 0.9)

func build(def: FurnitureDef) -> FurnitureNode:
	var bottom := Params.number(def.params, "bottom", DEFAULT_BOTTOM)
	var ceiling := Params.number(def.params, "ceiling", DEFAULT_CEILING) - CEILING_GAP
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(BOX.x, BOX.z + COVER.z + LATCH.z))
	piece.mounted = true
	var steel := Mats.finish("painted_metal", STEEL, 0.45)
	var parts: Array = [
		[Props.rounded_box(BOX, 0.006, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, bottom + BOX.y * 0.5, BOX.z * 0.5))],
		[Props.rounded_box(COVER, 0.003, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, bottom + BOX.y * 0.5, BOX.z + COVER.z * 0.5))],
		Props.part(LATCH, Vector3(BOX.x * 0.5 - 0.04, bottom + BOX.y * 0.5, BOX.z + COVER.z + LATCH.z * 0.5)),
	]
	var top := bottom + BOX.y
	for side: float in [-1.0, 1.0]:
		parts.append([Props.cyl(CONDUIT, CONDUIT, ceiling - top + 0.01, 12), Transform3D(Basis.IDENTITY,
				Vector3(side * CONDUIT_X, (ceiling + top - 0.01) * 0.5, BOX.z * 0.4))])
	piece.add_child(Props.mi(Props.bake(parts), steel))
	piece.add_child(Props.mi(Props.box(CARD), Props.mat(CARD_TINT, 0.7), Vector3(-0.04, top - 0.2, BOX.z + COVER.z + CARD.z * 0.5)))
	piece.add_box(BOX, Vector3(0, bottom + BOX.y * 0.5, BOX.z * 0.5))
	return piece
