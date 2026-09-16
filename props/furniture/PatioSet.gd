extends FurnitureGenerator
## A teak conversation set for a deck: two deep-seating armchairs side by side facing two more across a low
## slatted table. Each chair is a frame of posts and rails with a slatted seat, slats under its arms and a raked
## slatted back; the seat cushions are items and are not built here.
##
## No parameters.
##
## Anchors:
##
##     seats    on the seat slats of the back-left chair, at the middle of where a cushion lies; the chair beside
##              it is CHAIR.x + PAIR_GAP to the right, and the pair across the table is the set's depth less
##              twice CUSHION_Z forward

## A chair: width over its arms, depth, the seat slats' top, the arms' top and the back's top.
const CHAIR := Vector3(0.76, 0.72, 0.33)
const ARM_TOP := 0.6
const BACK_TOP := 0.78
const POST := 0.05
const RAIL := Vector2(0.06, 0.03)
const ARM := Vector2(0.08, 0.03)
const ARM_OVERHANG := 0.02
const SEAT_SLATS := 6
const SEAT_SLAT := Vector2(0.07, 0.02)
const CLEAT := 0.02
const SIDE_SLATS := 3
const SIDE_SLAT := 0.04
## The back: its posts lean back from the seat by this much at the top, and carry horizontal slats.
const BACK_RAKE := 0.07
const BACK_SLATS := 4
const BACK_SLAT := Vector2(0.06, 0.02)
## The cushion's middle stands this far forward of the chair's back.
const CUSHION_Z := 0.4
const PAIR_GAP := 0.08
const LEGROOM := 0.22
## The table: width, depth, height, and its top's slats.
const TABLE := Vector3(0.9, 0.46, 0.42)
const TABLE_SLATS := 5
## A slat's share of its pitch; the rest is the gap.
const SLAT_SHARE := 0.85
const TABLE_TOP := 0.025
const TABLE_LEG := 0.045
const EASE := 0.003

const TEAK := Color(0.62, 0.46, 0.32)

func build(def: FurnitureDef) -> FurnitureNode:
	var seat_step := CHAIR.x + PAIR_GAP
	var table_z := CHAIR.y + LEGROOM + TABLE.z * 0.5
	var depth := CHAIR.y * 2.0 + LEGROOM * 2.0 + TABLE.z
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(seat_step + CHAIR.x, depth))
	var parts: Array = []
	for row: int in 2:
		for column: int in 2:
			var x := (float(column) - 0.5) * seat_step
			var chair := Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)) if row == 0 \
					else Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, depth))
			for part: Array in _chair():
				parts.append([part[0], chair * (part[1] as Transform3D)])
			piece.add_box(Vector3(CHAIR.x, ARM_TOP, CHAIR.y), chair * Vector3(0, ARM_TOP * 0.5, CHAIR.y * 0.5))
	parts.append_array(_table(Vector3(0, 0, table_z)))
	piece.add_box(TABLE, Vector3(0, TABLE.y * 0.5, table_z))
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("oak", TEAK, 0.8)))
	piece.add_anchor(&"seats", Transform3D(Basis.IDENTITY, Vector3(-seat_step * 0.5, CHAIR.z, CUSHION_Z)), piece)
	return piece

## One chair facing +Z with its back at z = 0 and its middle at x = 0.
static func _chair() -> Array:
	var parts: Array = []
	var hx := CHAIR.x * 0.5
	var post_x := hx - POST * 0.5
	var rail_top := CHAIR.z - SEAT_SLAT.y
	var rail_y := rail_top - RAIL.x * 0.5
	for side: float in [-1.0, 1.0]:
		for z: float in [POST * 0.5, CHAIR.y - POST * 0.5]:
			parts.append(Props.part(Vector3(POST, ARM_TOP - ARM.y, POST), Vector3(side * post_x, (ARM_TOP - ARM.y) * 0.5, z)))
		# The side rail between the posts, and the slats standing on it under the arm.
		parts.append(Props.part(Vector3(RAIL.y, RAIL.x, CHAIR.y - POST * 2.0), Vector3(side * (hx - RAIL.y * 0.5), rail_y, CHAIR.y * 0.5)))
		var slat_h := ARM_TOP - ARM.y - rail_top
		for k in range(SIDE_SLATS):
			var z := POST + (CHAIR.y - POST * 2.0) * (float(k) + 0.5) / float(SIDE_SLATS)
			parts.append(Props.part(Vector3(RAIL.y * 0.6, slat_h, SIDE_SLAT), Vector3(side * (hx - RAIL.y * 0.5), rail_top + slat_h * 0.5, z)))
		parts.append([Props.rounded_box(Vector3(ARM.x, ARM.y, CHAIR.y + ARM_OVERHANG), EASE, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(side * (hx - ARM.x * 0.5), ARM_TOP - ARM.y * 0.5, (CHAIR.y + ARM_OVERHANG) * 0.5))])
	for z: float in [POST * 0.5, CHAIR.y - POST * 0.5]:
		parts.append(Props.part(Vector3(CHAIR.x - POST * 2.0, RAIL.x, RAIL.y), Vector3(0, rail_y, z)))
	var inner := CHAIR.x - RAIL.y * 2.0
	# The seat slats' ends rest on a cleat along the inside of each side rail.
	for side: float in [-1.0, 1.0]:
		parts.append(Props.part(Vector3(CLEAT, CLEAT, CHAIR.y - POST * 2.0), Vector3(side * (inner * 0.5 - CLEAT * 0.5), rail_top - CLEAT * 0.5, CHAIR.y * 0.5)))
	for k in range(SEAT_SLATS):
		var z := POST + (CHAIR.y - POST * 2.0) * (float(k) + 0.5) / float(SEAT_SLATS)
		parts.append(Props.part(Vector3(inner, SEAT_SLAT.y, SEAT_SLAT.x), Vector3(0, rail_top + SEAT_SLAT.y * 0.5, z)))
	# The back: two posts raked back from the first seat slat to the top, and slats across their fronts.
	var foot := Vector3(0, rail_top, BACK_RAKE + POST * 0.4)
	var head := Vector3(0, BACK_TOP, POST * 0.4)
	var along := Props.aim_y(head - foot)
	for side: float in [-1.0, 1.0]:
		var x := Vector3(side * (hx - RAIL.y - POST * 0.4), 0, 0)
		parts.append(Props.part(Vector3(POST * 0.8, foot.distance_to(head), POST * 0.8), x + (foot + head) * 0.5, along))
	for k in range(BACK_SLATS):
		var t := (float(k) + 1.0) / float(BACK_SLATS + 1)
		var centre := foot.lerp(head, t) + along.z * (POST * 0.4 + BACK_SLAT.y * 0.5)
		parts.append(Props.part(Vector3(inner - POST * 1.6, BACK_SLAT.x, BACK_SLAT.y), centre, along))
	return parts

## A low table with its middle at `at` on the floor: four legs, an apron, and a top of slats with gaps.
static func _table(at: Vector3) -> Array:
	var parts: Array = []
	var leg_h := TABLE.y - TABLE_TOP
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append(Props.part(Vector3(TABLE_LEG, leg_h, TABLE_LEG),
					at + Vector3(sx * (TABLE.x * 0.5 - TABLE_LEG * 0.5 - 0.03), leg_h * 0.5, sz * (TABLE.z * 0.5 - TABLE_LEG * 0.5 - 0.03))))
		parts.append(Props.part(Vector3(RAIL.y, RAIL.x, TABLE.z - 0.06 - TABLE_LEG * 2.0),
				at + Vector3(sx * (TABLE.x * 0.5 - 0.03 - TABLE_LEG * 0.5), leg_h - RAIL.x * 0.5, 0)))
	for sz: float in [-1.0, 1.0]:
		parts.append(Props.part(Vector3(TABLE.x - 0.06 - TABLE_LEG * 2.0, RAIL.x, RAIL.y),
				at + Vector3(0, leg_h - RAIL.x * 0.5, sz * (TABLE.z * 0.5 - 0.03 - TABLE_LEG * 0.5))))
	var pitch := TABLE.z / float(TABLE_SLATS)
	for k in range(TABLE_SLATS):
		parts.append([Props.rounded_box(Vector3(TABLE.x, TABLE_TOP, pitch * SLAT_SHARE), EASE, 2, 8),
				Transform3D(Basis.IDENTITY, at + Vector3(0, TABLE.y - TABLE_TOP * 0.5, -TABLE.z * 0.5 + pitch * (float(k) + 0.5)))])
	return parts
