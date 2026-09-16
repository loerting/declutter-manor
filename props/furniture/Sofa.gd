extends FurnitureGenerator
## A three-seat fabric sofa: an upholstered frame on four tapered walnut legs, three welted box
## cushions on its deck and three back cushions leaning on its raked back.
##
##     tint    Color    upholstery colour, default FABRIC
##
## The frame is built the way a real one is: two arms, a base between them and a back standing
## behind the deck, each an upholstered part that meets its neighbours face to face. Every cushion
## is its own mesh, sitting on the deck or lying against the back.
##
## Anchors: seat — on the seat cushions just in front of the back cushions' face, where the
## left-most of four throw cushions stands.

const WIDTH := 2.10
const DEPTH := 0.92
const FABRIC := Color(0.40, 0.45, 0.50)
const LEG_TINT := Color(0.78, 0.70, 0.64)

## Legs, one under each corner of each arm.
const LEG_HEIGHT := 0.13
const LEG_TOP_RADIUS := 0.022
const LEG_FOOT_RADIUS := 0.015
const LEG_INSET := 0.07
const LEG_SEGMENTS := 20

## Frame.
const ARM_WIDTH := 0.15
const ARM_HEIGHT := 0.62
const ARM_ROUND := 0.05
const ARM_PUFF := 0.008
const ARM_CROWN := 0.005
const DECK_Y := 0.30
const BASE_FRONT := 0.905
const BASE_ROUND := 0.018
const BASE_PUFF := 0.006
## The back frame's front face at and below the deck; above it the face leans back.
const BACK_DEPTH := 0.16
const BACK_TOP := 0.78
const BACK_ROUND := 0.045
const BACK_RAKE_DEG := 6.0
const BACK_CROWN := 0.004
## Every underside edge, and a plan corner where one part is pushed against another.
const UNDER_ROUND := 0.015
const TIGHT_CORNER := 0.012

## Cushions.
const SEAT_BACK := 0.325
const SEAT_FRONT := 0.922
const SEAT_THICK := 0.14
const SEAT_CROWN := 0.014
const BACK_CUSHION_HEIGHT := 0.53
const BACK_CUSHION_THICK := 0.16
const BACK_CUSHION_CROWN := 0.022
const CUSHION_GAP := 0.002

## Where the throw cushions stand: four of them 0.445 m apart and centred, so the left-most is at
## -1.5 steps. The anchor is a hair under the seat's surface, because a cushion sinks into a seat.
const THROW_LEFT_X := -0.6675
const ANCHOR_Z := SEAT_BACK + 0.03
const SEAT_SINK := 0.004

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var fabric := Mats.of("sofa_fabric", Params.colour(def.params, "tint", FABRIC), 0.95)
	var inner := WIDTH * 0.5 - ARM_WIDTH
	_add_frame(piece, fabric, inner)
	_add_legs(piece)
	_add_cushions(piece, fabric, inner)

	var seat_depth := DEPTH - SEAT_BACK
	piece.add_box(Vector3(inner * 2.0, SEAT_THICK + DECK_Y + 0.01, seat_depth),
			Vector3(0, (SEAT_THICK + DECK_Y + 0.01) * 0.5, SEAT_BACK + seat_depth * 0.5))
	var back_height := DECK_Y + BACK_CUSHION_HEIGHT + 0.02
	piece.add_box(Vector3(inner * 2.0, back_height, SEAT_BACK),
			Vector3(0, back_height * 0.5, SEAT_BACK * 0.5))
	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(ARM_WIDTH, ARM_HEIGHT, DEPTH),
				Vector3(side * (inner + ARM_WIDTH * 0.5), ARM_HEIGHT * 0.5, DEPTH * 0.5))

	var seat_x := -inner + inner / 3.0
	var seat_z := (SEAT_BACK + SEAT_FRONT) * 0.5
	var crown := Props.pillow_profile((THROW_LEFT_X - seat_x) / (inner / 3.0),
			(ANCHOR_Z - seat_z) / ((SEAT_FRONT - SEAT_BACK) * 0.5), Props.PILLOW_CROWN_EXP)
	var seat_y := DECK_Y + SEAT_THICK + SEAT_CROWN * crown - SEAT_SINK
	piece.add_anchor(&"seat", Transform3D(Basis.IDENTITY, Vector3(THROW_LEFT_X, seat_y, ANCHOR_Z)),
			piece)
	return piece

# --- Frame --------------------------------------------------------------------------------------

func _add_frame(piece: FurnitureNode, fabric: Material, inner: float) -> void:
	var under := LEG_HEIGHT
	for side: float in [-1.0, 1.0]:
		var outer := Vector4(ARM_PUFF if side > 0.0 else 0.0, ARM_PUFF if side < 0.0 else 0.0,
				ARM_PUFF * 0.6, 0.0)
		var arm := Props.upholstered_block(Vector3(ARM_WIDTH, ARM_HEIGHT - under, DEPTH),
				Vector4(ARM_ROUND, ARM_ROUND, TIGHT_CORNER, TIGHT_CORNER), UNDER_ROUND, ARM_ROUND,
				outer, ARM_CROWN)
		piece.add_child(Props.mi(arm, fabric, Vector3(side * (inner + ARM_WIDTH * 0.5), under, 0)))
	var base := Props.upholstered_block(Vector3(inner * 2.0, DECK_Y - under, BASE_FRONT - BACK_DEPTH),
			Vector4(TIGHT_CORNER, TIGHT_CORNER, TIGHT_CORNER, TIGHT_CORNER), UNDER_ROUND, BASE_ROUND,
			Vector4(0, 0, BASE_PUFF, 0), 0.0)
	piece.add_child(Props.mi(base, fabric, Vector3(0, under, BACK_DEPTH)))
	var back := Props.upholstered_block(Vector3(inner * 2.0, BACK_TOP - under, BACK_DEPTH),
			Vector4(BACK_ROUND, BACK_ROUND, TIGHT_CORNER, TIGHT_CORNER), UNDER_ROUND, BACK_ROUND,
			Vector4.ZERO, BACK_CROWN, tan(deg_to_rad(BACK_RAKE_DEG)), DECK_Y - under)
	piece.add_child(Props.mi(back, fabric, Vector3(0, under, 0)))

func _add_legs(piece: FurnitureNode) -> void:
	var wood := Mats.of("walnut", LEG_TINT, 0.7)
	# Tapered, with the foot's edge eased so it does not read as a sawn dowel.
	var profile := PackedVector2Array([
		Vector2(LEG_FOOT_RADIUS - 0.002, 0.0), Vector2(LEG_FOOT_RADIUS - 0.0005, 0.0015),
		Vector2(LEG_FOOT_RADIUS, 0.004), Vector2(LEG_TOP_RADIUS, LEG_HEIGHT - 0.004),
		Vector2(LEG_TOP_RADIUS - 0.001, LEG_HEIGHT)])
	var leg := Props.lathe(profile, LEG_SEGMENTS)
	var x := WIDTH * 0.5 - ARM_WIDTH * 0.5
	for side: float in [-1.0, 1.0]:
		for z: float in [LEG_INSET, DEPTH - LEG_INSET]:
			piece.add_child(Props.mi(leg, wood, Vector3(side * x, 0, z)))

# --- Cushions -----------------------------------------------------------------------------------

func _add_cushions(piece: FurnitureNode, fabric: Material, inner: float) -> void:
	var welt_out := Props.WELT * (1.0 - Props.WELT_SET)
	var pitch := inner * 2.0 / 3.0
	var half_x := pitch * 0.5 - welt_out - CUSHION_GAP * 0.5
	var seat := Props.box_cushion(Vector2(half_x, (SEAT_FRONT - SEAT_BACK) * 0.5 - welt_out),
			SEAT_THICK, SEAT_CROWN)
	var back := Props.box_cushion(Vector2(half_x, BACK_CUSHION_HEIGHT * 0.5 - welt_out),
			BACK_CUSHION_THICK, BACK_CUSHION_CROWN)
	# A back cushion lies flat against the raked face of the back frame and stands on the deck.
	var rake := deg_to_rad(BACK_RAKE_DEG)
	var lean := Basis(Vector3.RIGHT, PI * 0.5 - rake)
	var up_face := Vector3(0, cos(rake), -sin(rake))
	var on_face := Vector3(0, DECK_Y, BACK_DEPTH) + up_face * (BACK_CUSHION_HEIGHT * 0.5)
	var drop := _lowest(back, lean) + on_face.y - DECK_Y
	on_face -= up_face * (drop / up_face.y)
	for i in range(3):
		var x := -inner + pitch * (float(i) + 0.5)
		piece.add_child(Props.mi(seat, fabric, Vector3(x, DECK_Y, (SEAT_BACK + SEAT_FRONT) * 0.5)))
		var mi := Props.mi(back, fabric)
		mi.transform = Transform3D(lean, Vector3(x, on_face.y, on_face.z))
		piece.add_child(mi)

## The lowest point of `mesh` turned by `basis`, relative to its origin.
static func _lowest(mesh: ArrayMesh, basis: Basis) -> float:
	var low := INF
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		low = minf(low, (basis * v).y)
	return low
