extends FurnitureGenerator
## A run of painted wall units hung over a worktop: a carcass of 18 mm panels with a shelf half way up
## every bay, and a hinged door on each bay, all of which open.
##
##     bays      int      how many 600 mm bays, default 2
##     bottom    float    the carcass's underside above the floor, default 1.45
##
## Parts, numbered from the run's left end seen from the front, starting at 1:
##
##     door_<n>     container
##     inside_<n>   anchor on the carcass floor behind door n, belonging to that door

const DEFAULT_BAYS := 2
const DEFAULT_BOTTOM := 1.45
const BAY := 0.6
const HEIGHT := 0.7
const DEPTH := 0.32
const BACK := 0.008
const SHELF_SHARE := 0.5
const DOOR_SWING_DEG := 100.0
const PULL_LENGTH := 0.12
## The pull sits this far up from the door's bottom edge, where a hand reaches for a wall unit.
const PULL_FROM_BOTTOM := 0.1
const PULL_PROUD := 0.03

const CARCASS := Color(0.9, 0.91, 0.87)

func build(def: FurnitureDef) -> FurnitureNode:
	var bays := maxi(1, Params.integer(def.params, "bays", DEFAULT_BAYS))
	var bottom := Params.number(def.params, "bottom", DEFAULT_BOTTOM)
	var width := BAY * float(bays)
	var p := Props.CARCASS_PANEL
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, DEPTH + Props.FRONT_PANEL + PULL_PROUD))
	piece.mounted = true
	var top := bottom + HEIGHT
	var cz := DEPTH * 0.5
	var parts: Array = [
		Props.part(Vector3(width, p, DEPTH), Vector3(0, bottom + p * 0.5, cz)),
		Props.part(Vector3(width, p, DEPTH), Vector3(0, top - p * 0.5, cz)),
		Props.part(Vector3(width - p * 2.0, HEIGHT - p * 2.0, BACK), Vector3(0, bottom + HEIGHT * 0.5, BACK * 0.5)),
	]
	for i in range(bays + 1):
		var x := -width * 0.5 + p * 0.5 + (width - p) * (float(i) / float(bays))
		parts.append(Props.part(Vector3(p, HEIGHT - p * 2.0, DEPTH), Vector3(x, bottom + HEIGHT * 0.5, cz)))
	var shelf_y := bottom + p + (HEIGHT - p * 2.0) * SHELF_SHARE
	for bay in range(bays):
		parts.append(Props.part(Vector3(BAY - p * 2.0, p, DEPTH - BACK - 0.02), Vector3(_bay_x(bay, width), shelf_y,
				BACK + (DEPTH - BACK - 0.02) * 0.5)))
	piece.add_child(Props.mi(Props.union(parts), Mats.of("painted_wood", CARCASS, 0.7)))

	var front := Vector2(BAY - Props.FRONT_REVEAL * 2.0, HEIGHT - Props.FRONT_REVEAL * 2.0)
	for bay in range(bays):
		var n := bay + 1
		# Neighbouring doors open away from each other, like the base run's.
		var hinge_left := bay < bays / 2 or bays == 1
		var cx := _bay_x(bay, width)
		var hinge := Vector3(cx + (-front.x * 0.5 if hinge_left else front.x * 0.5), bottom + HEIGHT * 0.5,
				DEPTH + Props.FRONT_PANEL)
		var mover := Props.cabinet_door(front, hinge_left, null, PULL_LENGTH,
				-front.y * 0.5 + PULL_FROM_BOTTOM + PULL_LENGTH * 0.5)
		mover.name = "Door_%d" % n
		mover.transform = Transform3D(Basis.IDENTITY, hinge)
		piece.add_child(mover)
		var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
		var container := piece.add_container(StringName("door_%d" % n), mover,
				Transform3D(Basis(Vector3.UP, swing), hinge), piece)
		container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(front.x * (0.5 if hinge_left else -0.5), 0, -0.02))
		piece.add_anchor(StringName("inside_%d" % n), Transform3D(Basis.IDENTITY, Vector3(cx, bottom + p, cz + BACK * 0.5)),
				piece, container)

	piece.add_box(Vector3(width, HEIGHT, DEPTH), Vector3(0, bottom + HEIGHT * 0.5, cz))
	return piece

static func _bay_x(bay: int, width: float) -> float:
	return -width * 0.5 + BAY * (float(bay) + 0.5)
