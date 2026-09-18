extends FurnitureGenerator
## A chrome towel rail: a round bar held off the wall by a post at each end, each post on a round rose.
##
##     width     float    between the posts, default 0.5
##     height    float    the bar's top above the floor, default 1.05
##
## Anchors:
##
##     bar    over the bar's top by a folded towel's thickness, where the left towel's top is

const DEFAULT_WIDTH := 0.5
const DEFAULT_HEIGHT := 1.05
const BAR_RADIUS := 0.011
const REACH := 0.07
const POST_RADIUS := 0.008
const ROSE := Vector2(0.024, 0.01)
## Two towels hang side by side, their middles a quarter of the width in from the middle.
const TOWEL_SHARE := 0.25
## A towel folded over the bar stands this far over the bar's top.
const TOWEL_THICK := 0.009

const CHROME := Color(0.9, 0.91, 0.93)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var height := Params.number(def.params, "height", DEFAULT_HEIGHT)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width + ROSE.x * 2.0, REACH + BAR_RADIUS))
	piece.mounted = true
	var y := height - BAR_RADIUS
	var parts: Array = [[Props.cyl(BAR_RADIUS, BAR_RADIUS, width + POST_RADIUS * 2.0, 20),
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, y, REACH))]]
	for side: float in [-1.0, 1.0]:
		var x := side * width * 0.5
		parts.append([Props.cyl(POST_RADIUS, POST_RADIUS, REACH, 12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, y, REACH * 0.5))])
		parts.append([Props.lathe(PackedVector2Array([Vector2(ROSE.x, 0.0), Vector2(ROSE.x, ROSE.y * 0.5),
				Vector2(POST_RADIUS * 1.5, ROSE.y), Vector2(0.0, ROSE.y)]), 20), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, y, 0))])
	piece.add_child(Props.mi(Props.bake(parts), Mats.finish("metal_polished", CHROME, 0.06)))
	piece.add_box(Vector3(width, BAR_RADIUS * 2.0, REACH + BAR_RADIUS), Vector3(0, y, (REACH + BAR_RADIUS) * 0.5))
	piece.add_anchor(&"bar", Transform3D(Basis.IDENTITY, Vector3(-width * TOWEL_SHARE, height + TOWEL_THICK, REACH)), piece)
	return piece
