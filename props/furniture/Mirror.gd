extends FurnitureGenerator
## A bathroom mirror hung on the wall: silvered glass in a slim black metal frame.
##
##     width     float    default 0.7
##     height    float    default 0.9
##     bottom    float    the frame's bottom edge above the floor, default 1.1
##
## No anchors.

const DEFAULT_WIDTH := 0.7
const DEFAULT_HEIGHT := 0.9
const DEFAULT_BOTTOM := 1.1
const FRAME := Vector2(0.022, 0.028)
const GLASS_THICK := 0.005
## The glass sits this far into the frame's depth, behind its front face.
const GLASS_BACK := 0.012

const FRAME_COLOUR := Color(0.06, 0.06, 0.065)
## A mirror is the one metal here with no tint and almost no roughness: it shows what the room's
## reflection probe shows.
const SILVER := Color(0.93, 0.94, 0.95)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var height := Params.number(def.params, "height", DEFAULT_HEIGHT)
	var bottom := Params.number(def.params, "bottom", DEFAULT_BOTTOM)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, FRAME.y))
	piece.mounted = true
	var cy := bottom + height * 0.5
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		parts.append([Props.rounded_box(Vector3(FRAME.x, height, FRAME.y), 0.003, 4, 12),
				Transform3D(Basis.IDENTITY, Vector3(side * (width - FRAME.x) * 0.5, cy, FRAME.y * 0.5))])
		parts.append([Props.rounded_box(Vector3(width - FRAME.x * 2.0, FRAME.x, FRAME.y), 0.003, 4, 12),
				Transform3D(Basis.IDENTITY, Vector3(0, cy + side * (height - FRAME.x) * 0.5, FRAME.y * 0.5))])
	piece.add_child(Props.mi(Props.bake(parts), Props.mat(FRAME_COLOUR, 0.45, 0.6)))
	piece.add_child(Props.mi(Props.box(Vector3(width - FRAME.x * 1.5, height - FRAME.x * 1.5, GLASS_THICK)),
			Props.mat(SILVER, 0.02, 1.0), Vector3(0, cy, GLASS_BACK + GLASS_THICK * 0.5)))
	piece.add_box(Vector3(width, height, FRAME.y), Vector3(0, cy, FRAME.y * 0.5))
	return piece
