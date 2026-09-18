class_name ManorPlan
## The house. Every zone is a room an American family house actually has, placed where one
## actually is (`docs/HOUSE.md`, "The programme"), on four storeys, authored as rectangles;
## every wall is derived from them (`WallDeriver`). Plan (x, z) in metres; north (the street) is -Z.
##
## A centre-hall plan. The front door opens into a hall that runs through to the back door onto
## the deck; the stair rises against the hall's east wall, and the basement stair goes down under
## it behind an under-stair wall. Living rooms west, kitchen wing east against the garage, with
## the mudroom between the garage and the kitchen, because that is the door groceries come in by,
## and the half bath off the mudroom.
##
##   ground   x: 4        8     11     14.5    17          23
##   z 6      +--------+------+-------------+-----------+
##            | office | hall |   dining    |  garage   |
##   z 9.5    +--------+  |S| +------+------+           |
##            |        |  |S| |      | mud  |           |
##   z 11.5   | living |      |kitch-| room +-----------+
##   z 13     |        |      | en   +------+
##            |        |      |      |powder|
##   z 15.5   +--------+------+------+------+
##
## Upper: kids' room and guest room west, landing and hall bath over the hall, master suite east.
## Basement: the stair comes down into the rec room; laundry, utility, workshop and storage.

const HOUSE := Rect2(4, 6, 13, 9.5)
## Flush with the house front: a garage that stood forward of it left its abutting roof end
## open to the sky for the stretch no wall covered. 5.5 m deep, which leaves the kitchen 1.5 m
## of outside wall behind it for a window.
const GARAGE := Rect2(17, 6, 6, 5.5)

const GROUND_HEIGHT := 2.7
const UPPER_HEIGHT := 2.6
const BASEMENT_HEIGHT := 2.4
const SLAB := 0.35
## Finished ground floor above grade. A house whose floor is level with its lawn sits on it
## like a box on a table; this is what puts three steps at every outside door and a plinth
## under the siding (`HouseBuilder.PLINTH_TOP`).
const FLOOR_ABOVE_GRADE := 0.45
## Paving, gravel and deck boards are in full daylight, which the scans were not lit for.
const OUTDOOR_TINT := Color(0.85, 0.85, 0.85)
## Builder beige: over the neutral carpet scan, 0.70, 0.66, 0.58 on the floor.
const CARPET_TINT := Color(1.10, 1.00, 0.86)
## OSB a few years under a roof has greyed from the mill's orange.
const OSB_TINT := Color(0.80, 0.76, 0.72)
## The garage slab sits a hair above the wall footing (`HouseBuilder.FOUNDATION`), so the garage
## door comes down to it and the driveway needs only a shallow ramp.
const GARAGE_DROP := SLAB - 0.02
const PITCH := 32.0

## The attic is a band either side of the ridge, inset from the gable walls so its knee walls
## sit inside them rather than through them. Its wall height is derived from the roof.
const ATTIC := Rect2(4.3, 9.5, 12.4, 2.5)

## The deck behind the hall, level with the floor inside so the back door opens straight onto
## it, and the lap pool cut into the paving east of it. Both are structures, not paving, and
## `ExteriorBuilder` builds them; the zones themselves are ordinary rooms.
const DECK := Rect2(6, 15.5, 6, 3)
## Carried 2 m past the pool's deep end: at 11 m the paving beyond the coping was 1.7 m either end,
## and a diving board and a pair of loungers, which a pool area has, fitted at neither (2026-09-15).
## As deep as the pool needs: its south edge is the pool's plus the same 0.6 m of paving.
const POOL_AREA := Rect2(12, 15.5, 13, 5.25)
## Set 1.05 m off the house wall and 0.6 m off the paving's south edge: the first cut left
## half a metre of walkway between the coping and the siding, which read as a moat. 3.6 m wide, a
## family pool's width: at 1.65 m it read as a gutter (the author, 2026-09-18).
const POOL := Rect2(14.2, 16.55, 6.6, 3.6)
const POOL_DEPTH := 1.5

## The stair core. The main flight's east edge is let into the hall's east wall; the basement
## flight under it shares that edge, and both end at the same line, where the hall carries on to
## the kitchen door and the back door.
const HALL_EAST := 11.0
## How far a flight against a wall is let into it. Flush with the plaster, the stairwell's cut edge
## is the same plane as the wall face and the two z-fight all the way down the well
## (`dev/SeamProbe.tscn`, 2026-09-13); a stringer is housed in the wall anyway.
const HOUSED := 0.02
const MAIN_STAIR_X := HALL_EAST - WallDeriver.DEFAULT_THICKNESS * 0.5 + HOUSED - 0.45
const BASEMENT_STAIR_X := HALL_EAST - WallDeriver.DEFAULT_THICKNESS * 0.5 + HOUSED - 0.4
const STAIR_FOOT_Z := 7.4
const MAIN_RUN := 4.0
const BASEMENT_RUN := 3.6

static func build() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.id = &"manor"
	plan.lot = Rect2(0, 0, 26, 19)

	var ground := _storey(&"ground", FLOOR_ABOVE_GRADE, GROUND_HEIGHT)
	var basement := _storey(&"basement", ground.base_y - SLAB - BASEMENT_HEIGHT, BASEMENT_HEIGHT)
	var upper := _storey(&"upper", ground.ceiling_y() + SLAB, UPPER_HEIGHT)
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
		# Against the hall's east wall, climbing south from inside the front door to the landing.
		# Every flight in the house used to stand in the middle of a room with a walking lane either
		# side of it, which no house has (the author, 2026-09-13). 4.0 m of run for a 3.05 m rise
		# is 37 degrees, inside the IRC's 7 3/4" riser and 10" tread.
		StairDef.make(&"entry_hall", &"landing", Vector2(MAIN_STAIR_X, STAIR_FOOT_Z), WallDeriver.SOUTH,
				MAIN_RUN, 0.9),
		# The basement stair under it, climbing the other way: it comes up out of the rec room and
		# arrives in the hall where the main flight above is at its highest, so there is headroom
		# over every step of it. 0.8 m is the IRC width for a stair serving a basement.
		StairDef.make(&"rec_room", &"entry_hall", Vector2(BASEMENT_STAIR_X, STAIR_FOOT_Z + MAIN_RUN - BASEMENT_RUN),
				WallDeriver.SOUTH, BASEMENT_RUN, 0.8),
		# The attic ladder, against the landing's west wall between the kids' room and guest room
		# doors, and all of it under the attic: a hatch outside the attic band opens into the roof.
		StairDef.make(&"landing", &"attic", Vector2(8.0 + WallDeriver.DEFAULT_THICKNESS * 0.5 - HOUSED + 0.35, 9.9), WallDeriver.SOUTH, 1.4, 0.7),
	]
	plan.decks = [DeckDef.make(&"deck", [WallDeriver.SOUTH, WallDeriver.EAST])]
	plan.pools = [PoolDef.make(&"pool_area", POOL, POOL_DEPTH)]
	var main_roof := RoofDef.gable(HOUSE, eave, true, PITCH)
	var garage_roof := RoofDef.gable(GARAGE, ground.ceiling_y(), true, 28.0)
	garage_roof.abut_start = true   # meets the house's east wall; no gable, no overhang there
	plan.roofs = [main_roof, garage_roof]
	# Inside the front door, looking down the hall into the house — the first thing the player
	# sees is the centre-hall plan this house is organised around, not a wall.
	plan.spawn_room = &"entry_hall"
	plan.spawn_offset = Vector2(0.0, -3.5)
	plan.spawn_facing = 180.0
	return plan

static func _storey(id: StringName, base: float, height: float) -> StoreyDef:
	var s := StoreyDef.new()
	s.id = id
	s.name_key = "storey." + String(id)
	s.base_y = base
	s.height = height
	s.slab_thickness = SLAB
	return s

static func _room(id: StringName, x0: float, z0: float, x1: float, z1: float, floor := "floor_wood") -> RoomDef:
	var r := RoomDef.rect(id, "room." + String(id), x0, z0, x1, z1)
	r.floor_slot = floor
	return r

## Wall-to-wall plush, as an American bedroom is floored.
static func _carpeted(r: RoomDef) -> RoomDef:
	r.floor_slot = "carpet"
	r.floor_tint = CARPET_TINT
	return r

## The unfinished half of a basement: its walls are the poured foundation, form seams and tie
## holes showing, not drywall.
static func _unfinished(r: RoomDef) -> RoomDef:
	r.wall_slot = "foundation"
	return r

static func _outdoor(id: StringName, x0: float, z0: float, x1: float, z1: float, floor: String) -> RoomDef:
	var r := _room(id, x0, z0, x1, z1, floor)
	_outside(r)
	return r

## Paving lies on the ground, a storey's floor height below the finished floor.
static func _outside(r: RoomDef) -> void:
	r.zone = RoomDef.Zone.EXTERIOR
	r.floor_drop = FLOOR_ABOVE_GRADE
	r.floor_tint = OUTDOOR_TINT
	r.has_ceiling = false
	r.light_energy = 0.0

## The deck is the one exterior zone at the finished floor level rather than on the ground:
## `floor_drop` 0 puts its boards level with the hall inside, which is what a back door onto a
## deck looks like and what stops `HouseBuilder` putting steps in the doorway. The steps are on
## the far side, off the deck.
static func _deck() -> RoomDef:
	var r := _outdoor(&"deck", DECK.position.x, DECK.position.y, DECK.end.x, DECK.end.y, "deck_boards")
	r.floor_drop = 0.0
	return r

## The driveway with the front walk as part of it: an L from the street side of the garage to
## the front door, and the stoop under the front steps. One zone, because a path is not a
## place items live; a polygon, because only walls need rectangles and paving has none. The
## strip between the walk and the house is in it too: the front flower bed stands there, and a
## bed on the lawn stood on grass 2 cm under the zone's floor (2026-09-15).
static func _driveway() -> RoomDef:
	var r := RoomDef.new()
	r.id = &"driveway"
	r.name_key = "room.driveway"
	r.polygon = PackedVector2Array([Vector2(15.5, 0.5), Vector2(23.5, 0.5), Vector2(23.5, 6),
			Vector2(9, 6), Vector2(9, 4), Vector2(15.5, 4)])
	r.floor_slot = "concrete_broom"
	_outside(r)
	return r

# --- Basement --------------------------------------------------------------------------------

## The stair lands in the finished half: a rec room under the hall and the living room. The
## unfinished half is east, under the kitchen wing, where the furnace and the tools are.
static func _basement(s: StoreyDef) -> void:
	s.rooms = [
		_room(&"rec_room", 4, 6, HALL_EAST, 12.5, "rug_wool"),
		_room(&"laundry", 4, 12.5, 7.5, 15.5, "concrete"),
		_unfinished(_room(&"utility", 7.5, 12.5, HALL_EAST, 15.5, "concrete")),
		_unfinished(_room(&"workshop", HALL_EAST, 6, 17, 10.5, "concrete")),
		_unfinished(_room(&"storage", HALL_EAST, 10.5, 17, 15.5, "concrete")),
	]
	var w := WallDeriver.derive(s.rooms)
	WallDeriver.pierce_between(w, &"rec_room", &"laundry", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"rec_room", &"utility", Opening.door(0.0))
	# Either side of the flight standing against this wall, not into its side.
	WallDeriver.pierce_between_at(w, &"rec_room", &"workshop", Opening.door(0.0), 6.85)
	WallDeriver.pierce_between_at(w, &"rec_room", &"storage", Opening.door(0.0), 12.0)
	WallDeriver.pierce_between(w, &"workshop", &"storage", Opening.door(0.0))
	s.walls = w

# --- Ground ---------------------------------------------------------------------------------------

static func _ground(s: StoreyDef) -> void:
	var garage := _room(&"garage", GARAGE.position.x, GARAGE.position.y, GARAGE.end.x, GARAGE.end.y, "concrete")
	garage.zone = RoomDef.Zone.GARAGE
	garage.floor_drop = GARAGE_DROP
	s.rooms = [
		_room(&"entry_hall", 8, 6, HALL_EAST, 15.5),
		_room(&"office", 4, 6, 8, 9.5),
		_room(&"living", 4, 9.5, 8, 15.5),
		_room(&"dining", HALL_EAST, 6, 17, 9.5),
		# the hall's oak runs on through the kitchen, which is how a kitchen off a centre hall is floored
		_room(&"kitchen", HALL_EAST, 9.5, 14.5, 15.5),
		# Carried 1.5 m past the garage's back wall. Ended level with it, four walls met at one point
		# on the facade; ended 0.5 or 1.0 m past it, the stub of outside wall was too short for
		# `HouseBuilder._build_plinth` to mitre, and its plinth lapped the garage's by 35 mm
		# (`dev/SeamProbe.tscn`, 2026-09-13). A mudroom this deep holds a bench and a coat wall.
		_room(&"mudroom", 14.5, 9.5, 17, 13, "tile_stone"),
		# off the mudroom, which is where a half bath goes in a house with a garage entry
		_room(&"powder", 14.5, 13, 17, 15.5, "tile_stone"),
		garage,
		_driveway(),
		_deck(),
		_outdoor(&"pool_area", POOL_AREA.position.x, POOL_AREA.position.y,
				POOL_AREA.end.x, POOL_AREA.end.y, "concrete_broom"),
		_outdoor(&"side_garden", 0.5, 6, 4, 15.5, "gravel"),
	]
	var w := WallDeriver.derive(s.rooms)
	WallDeriver.pierce_exterior(w, &"entry_hall", WallDeriver.NORTH, Opening.door(0.0, 1.0, 2.1))
	WallDeriver.pierce_exterior(w, &"entry_hall", WallDeriver.SOUTH, Opening.door(0.0, 1.0, 2.1))
	WallDeriver.pierce_between_at(w, &"entry_hall", &"office", Opening.door(0.0), 7.75)
	WallDeriver.pierce_between_at(w, &"entry_hall", &"living", Opening.arch(0.0, 1.8, 2.2), 12.5)
	# In front of the stair's foot, the only stretch of this wall it does not stand against.
	WallDeriver.pierce_between_at(w, &"entry_hall", &"dining", Opening.door(0.0, 0.8), 6.7)
	WallDeriver.pierce_between_at(w, &"entry_hall", &"kitchen", Opening.door(0.0), 13.2)
	# East of the kitchen run, which stands against this wall's west end.
	WallDeriver.pierce_between_at(w, &"dining", &"kitchen", Opening.arch(0.0, 1.6, 2.2), 13.4)
	WallDeriver.pierce_between(w, &"garage", &"mudroom", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"kitchen", &"mudroom", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"mudroom", &"powder", Opening.door(0.0, 0.8))
	WallDeriver.pierce_exterior(w, &"garage", WallDeriver.NORTH, Opening.garage_door(0.0, 4.2, 2.2))
	WallDeriver.pierce_exterior(w, &"garage", WallDeriver.EAST, Opening.window(0.0, 1.0, 0.9, 1.5))
	WallDeriver.pierce_exterior(w, &"office", WallDeriver.NORTH, Opening.window(0.0, 1.4, 1.4, 0.9))
	WallDeriver.pierce_exterior(w, &"office", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.4, 0.9))
	WallDeriver.pierce_exterior(w, &"living", WallDeriver.WEST, Opening.window(0.0, 2.2, 1.6, 0.7))
	WallDeriver.pierce_exterior(w, &"living", WallDeriver.SOUTH, Opening.window(0.0, 1.8, 1.6, 0.7))
	WallDeriver.pierce_exterior(w, &"dining", WallDeriver.NORTH, Opening.window(0.0, 2.4, 1.5, 0.8))
	# over the sink, looking out at the pool
	WallDeriver.pierce_exterior(w, &"kitchen", WallDeriver.SOUTH, Opening.window(0.0, 1.4, 1.0, 1.1))
	WallDeriver.pierce_exterior(w, &"powder", WallDeriver.EAST, Opening.window(0.0, 0.6, 0.6, 1.6))
	s.walls = w

# --- Upper ------------------------------------------------------------------------------------------

static func _upper(s: StoreyDef) -> void:
	s.rooms = [
		_room(&"landing", 8, 6, HALL_EAST, 12.5),
		_room(&"hall_bath", 8, 12.5, HALL_EAST, 15.5, "tile_hex"),
		_carpeted(_room(&"kids_room", 4, 6, 8, 10.5)),
		_carpeted(_room(&"guest_room", 4, 10.5, 8, 15.5)),
		_carpeted(_room(&"closet", HALL_EAST, 6, 13.5, 10.5)),
		_room(&"master_bath", 13.5, 6, 17, 10.5, "tile_stone"),
		_carpeted(_room(&"master_bed", HALL_EAST, 10.5, 17, 15.5)),
	]
	var w := WallDeriver.derive(s.rooms)
	# The landing's west wall has the attic ladder against it and its east wall has the stairwell:
	# every door on either is placed clear of them.
	WallDeriver.pierce_between_at(w, &"landing", &"kids_room", Opening.door(0.0), 7.5)
	WallDeriver.pierce_between_at(w, &"landing", &"guest_room", Opening.door(0.0), 12.0)
	WallDeriver.pierce_between_at(w, &"landing", &"master_bed", Opening.door(0.0), 12.0)
	WallDeriver.pierce_between_at(w, &"landing", &"hall_bath", Opening.door(0.0), 9.3)
	WallDeriver.pierce_between(w, &"master_bed", &"closet", Opening.door(0.0))
	WallDeriver.pierce_between(w, &"master_bed", &"master_bath", Opening.door(0.0))
	WallDeriver.pierce_exterior(w, &"landing", WallDeriver.NORTH, Opening.window(0.0, 1.0, 1.2, 1.0))
	WallDeriver.pierce_exterior(w, &"kids_room", WallDeriver.NORTH, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"kids_room", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"guest_room", WallDeriver.WEST, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"guest_room", WallDeriver.SOUTH, Opening.window(0.0, 1.2, 1.3, 0.9))
	WallDeriver.pierce_exterior(w, &"hall_bath", WallDeriver.SOUTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"closet", WallDeriver.NORTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"master_bath", WallDeriver.NORTH, Opening.window(0.0, 0.8, 0.8, 1.4))
	WallDeriver.pierce_exterior(w, &"master_bed", WallDeriver.SOUTH, Opening.window(0.0, 2.0, 1.4, 0.8))
	# the east wall's northern part is behind the garage roof, so the window sits toward the back
	WallDeriver.pierce_exterior(w, &"master_bed", WallDeriver.EAST, Opening.window(0.0, 1.2, 1.3, 0.9), 0.7)
	s.walls = w

# --- Attic ------------------------------------------------------------------------------------------

static func _attic(s: StoreyDef) -> void:
	# decked and knee-walled in OSB, under an OSB roof deck: a storage attic, not a finished room
	var attic := _room(&"attic", ATTIC.position.x, ATTIC.position.y, ATTIC.end.x, ATTIC.end.y, "osb")
	attic.has_ceiling = false   # the roof is the ceiling, boards and all
	attic.ceiling_slot = ""
	attic.wall_slot = "osb"
	attic.wall_tint = OSB_TINT
	attic.floor_tint = OSB_TINT
	attic.light_energy = 2.2
	attic.light_range = 12.0
	s.rooms = [attic]
	s.walls = WallDeriver.derive(s.rooms)
	# The knee walls north and south stop where the roof meets them, which is what their height
	# is derived from. The two end walls do not: the roof over them keeps climbing to the ridge,
	# and a rectangular wall left a triangle of the roof void open to the room — visible in the
	# attic render as a grey gap over the west wall. The attic band is centred on the ridge, so
	# the triangle peaks at the middle of each end wall, which is what `gable_rise` builds.
	var rise := ATTIC.size.y * 0.5 * tan(deg_to_rad(PITCH))
	for facing: Vector2 in [WallDeriver.EAST, WallDeriver.WEST] as Array[Vector2]:
		WallDeriver.facing_wall(s.walls, &"attic", facing).gable_rise = rise
