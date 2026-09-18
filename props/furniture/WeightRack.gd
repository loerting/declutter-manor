extends FurnitureGenerator
## A black steel dumbbell stand: at each end an A-frame of square tube, the two joined by rails front
## and back, and a flat steel tray on top with rubber stops either side of each dumbbell's place.
##
## No parameters.
##
## Anchors:
##
##     saddles    on the tray at the left dumbbell's place

const WIDTH := 0.6
const DEPTH := 0.42
const HEIGHT := 0.62
const TUBE := 0.03
## The legs splay from this far in at the top to the ends of the depth at the floor.
const LEG_TOP_IN := 0.1
const RAIL_Y := 0.1
const TRAY := Vector3(0.6, 0.008, 0.36)
const STOP := Vector3(0.018, 0.016, 0.34)
## The dumbbells lie across the tray, their middles this far either side of the middle, and a stop
## stands this far out from each middle.
const PLACE_X := 0.15
const STOP_OUT := 0.066

const STEEL := Color(0.06, 0.06, 0.065)
const RUBBER := Color(0.12, 0.12, 0.12)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var cz := DEPTH * 0.5
	var under := HEIGHT - TRAY.y
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		var x := side * (WIDTH * 0.5 - TUBE * 0.5)
		for end: float in [-1.0, 1.0]:
			var foot := Vector3(x, 0.0, cz + end * (DEPTH * 0.5 - TUBE * 0.5))
			var top := Vector3(x, under, cz + end * (DEPTH * 0.5 - LEG_TOP_IN))
			var along := top - foot
			# A tube cut square to its own length leans, so its foot is lifted by what its corner dips; its
			# top runs on into the rail under the tray.
			var dip := TUBE * 0.5 * absf(along.z) / along.length()
			parts.append([Props.box(Vector3(TUBE, along.length(), TUBE)), Transform3D(Props.aim_y(along),
					(foot + top) * 0.5 + Vector3(0, dip, 0))])
		parts.append(Props.part(Vector3(TUBE, TUBE, DEPTH - LEG_TOP_IN * 2.0 + TUBE), Vector3(x, under - TUBE * 0.5, cz)))
	for end: float in [-1.0, 1.0]:
		var at := end * ((DEPTH * 0.5 - TUBE * 0.5) - (LEG_TOP_IN - TUBE * 0.5) * RAIL_Y / under)
		parts.append(Props.part(Vector3(WIDTH - TUBE * 2.0, TUBE, TUBE), Vector3(0, RAIL_Y, cz + at)))
	parts.append(Props.part(TRAY, Vector3(0, HEIGHT - TRAY.y * 0.5, cz)))
	piece.add_child(Props.mi(Props.union(parts), Mats.finish("painted_metal", STEEL, 0.5)))
	var stops: Array = []
	for place: float in [-PLACE_X, PLACE_X]:
		for side: float in [-1.0, 1.0]:
			stops.append([Props.rounded_box(STOP, 0.006, 4, 12), Transform3D(Basis.IDENTITY,
					Vector3(place + side * STOP_OUT, HEIGHT + STOP.y * 0.5, cz))])
	piece.add_child(Props.mi(Props.bake(stops), Mats.of("rubber", RUBBER, 0.9)))

	piece.add_box(Vector3(WIDTH, HEIGHT, DEPTH), Vector3(0, HEIGHT * 0.5, cz))
	piece.add_anchor(&"saddles", Transform3D(Basis.IDENTITY, Vector3(-PLACE_X, HEIGHT, cz)), piece)
	return piece
