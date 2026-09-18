extends FurnitureGenerator
## A single shelf board on two black steel brackets: a strap screwed flat to the wall, an arm on
## edge under the board and a diagonal brace between them.
##
##     width     float     metres, default 0.9
##     depth     float     metres, default 0.3
##     height    float     the board's top above the floor, default 1.25
##     finish    String    "oak" or "pine", default "oak"
##
## Anchors:
##
##     top    the middle of the board's top

const DEFAULT_WIDTH := 0.9
const DEFAULT_DEPTH := 0.3
const DEFAULT_HEIGHT := 1.25
const BOARD := 0.024
const EASE := 0.004
## The brackets stand in from the board's ends by this share of its width.
const BRACKET_IN := 0.16
const BAR := Vector2(0.03, 0.005)
## The bracket's arm is short of the board's depth; its upright hangs this far down the wall.
const ARM_SHORT := 0.03
const UPRIGHT := 0.2
const BRACE_FROM := 0.35
const BRACE_OVERRUN := 0.01
const SCREW_RADIUS := 0.0045
const SCREW_PROUD := 0.002

const OAK := Color(0.92, 0.82, 0.68)
const PINE := Color(1.0, 0.97, 0.92)
const STEEL := Color(0.05, 0.05, 0.055)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var depth := Params.number(def.params, "depth", DEFAULT_DEPTH)
	var height := Params.number(def.params, "height", DEFAULT_HEIGHT)
	var pine := Params.text(def.params, "finish", "oak") == "pine"
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, depth))
	piece.mounted = true
	var wood := Mats.of("pine", PINE, 0.7) if pine else Mats.of("oak", OAK, 0.6)
	piece.add_child(Props.mi(Props.rounded_box(Vector3(width, BOARD, depth), EASE, 4, 20), wood,
			Vector3(0, height - BOARD * 0.5, depth * 0.5)))

	var under := height - BOARD
	var arm := depth - ARM_SHORT
	var parts: Array = []
	var screws: Array = []
	var screw := Props.lathe(PackedVector2Array([Vector2(SCREW_RADIUS, 0), Vector2(SCREW_RADIUS * 0.8, SCREW_PROUD * 0.7),
			Vector2(0, SCREW_PROUD)]), 12)
	for side: float in [-1.0, 1.0]:
		var x := side * width * (0.5 - BRACKET_IN)
		parts.append(Props.part(Vector3(BAR.y, BAR.x, arm), Vector3(x, under - BAR.x * 0.5, arm * 0.5)))
		# The upright is a strap flat on the wall, screwed through; the arm and the brace stand on edge.
		parts.append(Props.part(Vector3(BAR.x, UPRIGHT, BAR.y), Vector3(x, under - UPRIGHT * 0.5, BAR.y * 0.5)))
		# Its foot stands off the wall by its own half width, and it runs on past both ends into the bars.
		var low := Vector3(x, under - UPRIGHT + BAR.x, BAR.y + BAR.x * 0.4)
		var high := Vector3(x, under - BAR.x * 0.5, arm * (1.0 - BRACE_FROM))
		var along := high - low
		parts.append([Props.box(Vector3(BAR.y, BAR.x * 0.8, along.length() + BRACE_OVERRUN * 2.0)),
				Transform3D(Basis.looking_at(along, Vector3.UP), (low + high) * 0.5)])
		for y: float in [under - UPRIGHT * 0.45, under - UPRIGHT * 0.85]:
			screws.append([screw, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, y, BAR.y))])
	var steel := Mats.finish("painted_metal", STEEL, 0.55)
	piece.add_child(Props.mi(Props.bake(parts), steel))
	piece.add_child(Props.mi(Props.bake(screws), steel))

	piece.add_box(Vector3(width, BOARD, depth), Vector3(0, height - BOARD * 0.5, depth * 0.5))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, height, depth * 0.5)), piece)
	return piece
