class_name ManorPlan
## The house. Twenty-six zones from `docs/HOUSE.md`, on four storeys, authored as rectangles;
## every wall is derived from them (`WallDeriver`) and every opening is placed by naming rooms
## and compass points, never coordinates. Plan (x, z) in metres; north (the street) is -Z.
##
## A centre-hall plan: the entry hall runs front to back through the middle of the house and
## carries both stairs, with the landing stacked over it and the basement stair hall under it,
## so the stairwells line up through the building the way structure does.
##
##            x: 4        8        11       14       17          23
##   z 6      +--------+--------+-----------------+-----------+
##            | office | entry  | dining          |  garage   |
##   z 9      +--------+  hall  +-----------------+           |
##            | living |        | kitchen         |           |
##   z 11.5   |        |        |                 +-----------+
##   z 13     |        |        +--------+--------+
##   z 15.5   +--------+--------+ mud    | powder |
##
## Upper floor mirrors it (children's rooms west, master suite east, landing over the hall); the
## basement mirrors the ground floor so every wall stacks.

const HOUSE := Rect2(4, 6, 13, 9.5)
## Flush with the house front: a garage that stood forward of it left its abutting roof end
## open to the sky for the stretch no wall covered. 5.5 m deep, which leaves the kitchen 1.5 m
## of outside wall behind it for a window.
const GARAGE := Rect2(17, 6, 6, 5.5)

const GROUND_HEIGHT := 2.7
const UPPER_HEIGHT := 2.6
const BASEMENT_HEIGHT := 2.4
const SLAB := 0.35
const GARAGE_DROP := 0.15
const PITCH := 32.0

## The attic is a band either side of the ridge, inset from the gable walls so its knee walls
## sit inside them rather than through them. Its wall height is derived from the roof.
const ATTIC := Rect2(4.3, 9.5, 12.4, 2.5)

static func build() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.id = &"manor"
	plan.lot = Rect2(0, 0, 26, 19)

	var basement := _storey(&"basement", -SLAB - BASEMENT_HEIGHT, BASEMENT_HEIGHT)
	var ground := _storey(&"ground", 0.0, GROUND_HEIGHT)
	var upper := _storey(&"upper", GROUND_HEIGHT + SLAB, UPPER_HEIGHT)
	var eave := upper.ceiling_y()
	var attic_base := eave + SLAB
	var knee := eave + (ATTIC.position.y - HOUSE.position.y) * tan(deg_to_rad(PITCH)) - attic_base
	var attic := _storey(&"attic", attic_base, knee)

	_basement(basement)
	_ground(ground)
	_upper(upper)
	_attic(attic)

	plan.storeys = [basement, ground, upper, attic]
	plan.stairs = [
		# west side of the hall going up, east side going down, both in the back half so the front
		# door opens onto floor rather than onto a stairwell
		StairDef.make(&"entry_hall", &"landing", Vector2(8.6, 14.5), WallDeriver.NORTH, 3.6, 0.9),
		StairDef.make(&"stair_hall_b", &"entry_hall", Vector2(10.4, 14.5), WallDeriver.NORTH, 3.6, 0.9),
		# the attic ladder: steep, short, and in the corner of the landing the stair does not use
		StairDef.make(&"landing", &"attic", Vector2(9.4, 10.2), WallDeriver.EAST, 1.4, 0.7),
	]
	var main_roof := RoofDef.gable(HOUSE, eave, true, PITCH)
	var garage_roof := RoofDef.gable(GARAGE, GROUND_HEIGHT, true, 28.0)
	garage_roof.abut_start = true   # meets the house's east wall; no gable, no overhang there
	main_roof.underside_tint = Color(0.74, 0.68, 0.58)
	plan.roofs = [main_roof, garage_roof]
	return plan

static func _storey(id: StringName, base: float, height: float) -> StoreyDef:
	var s := StoreyDef.new()
	s.id = id
	s.base_y = base
	s.height = height
	s.slab_thickness = SLAB
	return s

static func _room(id: StringName, x0: float, z0: float, x1: float, z1: float, floor := "floor_wood") -> RoomDef:
	var r := RoomDef.rect(id, "room." + String(id), x0, z0, x1, z1)
	r.floor_slot = floor
	return r

static func _outdoor(id: StringName, x0: float, z0: float, x1: float, z1: float, floor: String) -> RoomDef:
	var r := _room(id, x0, z0, x1, z1, floor)
	r.zone = RoomDef.Zone.EXTERIOR
	r.floor_tint = Color(0.62, 0.62, 0.60) if floor == "concrete" else Color(0.85, 0.85, 0.85)
	r.has_ceiling = false
	r.light_energy = 0.0
	return r

# --- Basement: mirrors the ground floor so every wall stacks ----------------------------------

static func _basement(s: StoreyDef) -> void:
	s.rooms = [
		_room(&"stair_hall_b", 8, 6, 11, 15.5, "concrete"),
		_room(&"laundry", 4, 6, 8, 10.5, "concrete"),
		_room(&"rec_room", 4, 10.5, 8, 15.5, "rug_wool"),
		_room(&"storage", 11, 6, 17, 10, "concrete"),
		_room(&"workshop", 11, 10, 17, 13.5, "concrete"),
		_room(&"utility", 11, 13.5, 17, 15.5, "concrete"),
	]
	var w := WallDeriver.derive(s.rooms)
	for other: StringName in [&"laundry", &"rec_room", &"storage", &"workshop", &"utility"] as Array[StringName]:
		WallDeriver.pierce_between(w, &"stair_hall_b", other, Opening.door(0.0))
	s.walls = w

# --- Ground ---------------------------------------------------------------------------------------

static func _ground(s: StoreyDef) -> void:
	var garage := _room(&"garage", GARAGE.position.x, GARAGE.position.y, GARAGE.end.x, GARAGE.end.y, "concrete")
	garage.zone = RoomDef.Zone.GARAGE
	garage.floor_drop = GARAGE_DROP
	s.rooms = [
		_room(&"entry_hall", 8, 6, 11, 15.5),
		_room(&"office", 4, 6, 8, 10.5),
		_room(&"living", 4, 10.5, 8, 15.5),
		_room(&"dining", 11, 6, 17, 9),
		_room(&"kitchen", 11, 9, 17, 13, "worktop_stone"),
		_room(&"mudroom", 11, 13, 14, 15.5, "concrete"),
		_room(&"powder", 14, 13, 17, 15.5, "porcelain"),
		garage,
		_outdoor(&"driveway", 15.5, 0.5, 23.5, 6, "concrete"),
		_outdoor(&"deck", 6, 15.5, 12, 18.5, "floor_wood"),
		_outdoor(&"pool_area", 12, 15.5, 23, 18.8, "concrete"),
		_outdoor(&"side_garden", 0.5, 6, 4, 15.5, "gravel"),
	]
	var w := WallDeriver.derive(s.rooms)
	WallDeriver.pierce_exterior(w, &"entry_hall", WallDeriver.NORTH, Opening.door(0.0, 1.0, 2.1))
	WallDeriver.pierce_exterior(w, &"entry_hall", WallDeriver.SOUTH, Opening.door(0.0, 1.0, 2.1))
	WallDeriver.pierce_between(w, &"entry_hall", &"office", Opening.door(0.0), 0.35)
	WallDeriver.pierce_between(w, &"entry_hall", &"living", Opening.arch(0.0, 1.8, 2.2))
	WallDeriver.pierce_between(w, &"entry_hall", &"dining", Opening.arch(0.0, 1.6, 2.2))
	WallDeriver.pierce_between(w, &"entry_hall", &"kitchen", Opening.door(0.0), 0.3)
	WallDeriver.pierce_between(w, &"entry_hall", &"mudroom", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"dining", &"kitchen", Opening.arch(0.0, 2.0, 2.2))
	WallDeriver.pierce_between(w, &"kitchen", &"mudroom", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"kitchen", &"powder", Opening.door(0.0, 0.8))
	WallDeriver.pierce_between(w, &"garage", &"kitchen", Opening.door(0.0))
	WallDeriver.pierce_exterior(w, &"mudroom", WallDeriver.SOUTH, Opening.door(0.0))
	WallDeriver.pierce_exterior(w, &"garage", WallDeriver.NORTH, Opening.garage_door(0.0, 4.2, 2.2))
	WallDeriver.pierce_exterior(w, &"garage", WallDeriver.EAST, Opening.window(0.0, 1.0, 0.9, 1.5))
	WallDeriver.pierce_exterior(w, &"office", WallDeriver.NORTH, Opening.window(0.0, 1.4, 1.4, 0.9))
	WallDeriver.pierce_exterior(w, &"office", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.4, 0.9))
	WallDeriver.pierce_exterior(w, &"living", WallDeriver.WEST, Opening.window(0.0, 2.2, 1.6, 0.7))
	WallDeriver.pierce_exterior(w, &"living", WallDeriver.SOUTH, Opening.window(0.0, 1.8, 1.6, 0.7))
	WallDeriver.pierce_exterior(w, &"dining", WallDeriver.NORTH, Opening.window(0.0, 2.4, 1.5, 0.8))
	WallDeriver.pierce_exterior(w, &"kitchen", WallDeriver.EAST, Opening.window(0.0, 1.2, 1.0, 1.1))
	WallDeriver.pierce_exterior(w, &"powder", WallDeriver.SOUTH, Opening.window(0.0, 0.6, 0.6, 1.6))
	WallDeriver.pierce_exterior(w, &"powder", WallDeriver.EAST, Opening.window(0.0, 0.6, 0.6, 1.6))
	s.walls = w

# --- Upper ------------------------------------------------------------------------------------------

static func _upper(s: StoreyDef) -> void:
	s.rooms = [
		_room(&"landing", 8, 9.5, 11, 15.5),
		_room(&"family_bath", 8, 6, 11, 9.5, "porcelain"),
		_room(&"child1", 4, 6, 8, 11, "rug_wool"),
		_room(&"child2", 4, 11, 8, 15.5, "rug_wool"),
		_room(&"closet", 11, 6, 14, 10),
		_room(&"master_bath", 14, 6, 17, 10, "porcelain"),
		_room(&"master_bed", 11, 10, 17, 15.5),
	]
	var w := WallDeriver.derive(s.rooms)
	WallDeriver.pierce_between(w, &"landing", &"family_bath", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"landing", &"child1", Opening.door(0.0, 0.85))
	WallDeriver.pierce_between(w, &"landing", &"child2", Opening.door(0.0), 0.3)
	WallDeriver.pierce_between(w, &"landing", &"master_bed", Opening.door(0.0), 0.3)
	WallDeriver.pierce_between(w, &"master_bed", &"closet", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"master_bed", &"master_bath", Opening.door(0.0))
	WallDeriver.pierce_exterior(w, &"child1", WallDeriver.NORTH, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"child1", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"child2", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"child2", WallDeriver.SOUTH, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"family_bath", WallDeriver.NORTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"closet", WallDeriver.NORTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"master_bath", WallDeriver.NORTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"master_bed", WallDeriver.SOUTH, Opening.window(0.0, 2.0, 1.4, 0.8))
	# the east wall's northern part is behind the garage roof, so the window sits toward the back
	WallDeriver.pierce_exterior(w, &"master_bed", WallDeriver.EAST, Opening.window(0.0, 1.2, 1.3, 0.9), 0.72)
	s.walls = w

# --- Attic ------------------------------------------------------------------------------------------

static func _attic(s: StoreyDef) -> void:
	var attic := _room(&"attic", ATTIC.position.x, ATTIC.position.y, ATTIC.end.x, ATTIC.end.y)
	attic.has_ceiling = false   # the roof is the ceiling, boards and all
	attic.ceiling_slot = ""
	attic.wall_slot = "painted_wood"
	attic.light_energy = 2.2
	attic.light_range = 12.0
	s.rooms = [attic]
	s.walls = WallDeriver.derive(s.rooms)
