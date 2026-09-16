class_name FurnitureBuilder
## The furniture the plan does not describe. `HouseBuilder` builds the shell; this puts the
## things with moving parts and place-slots into it.
##
## The kitchen is the reference implementation of the whole interaction system
## (`docs/ROADMAP.md`, Phase 2): a run of base units whose drawers slide, whose doors swing,
## whose west drawer is the home of twelve spoons, and whose east cupboard starts with six of
## them in the wrong place. Everything else in the house is Phase 4 content.
##
## Positions are derived from the plan, never typed: the run stands against the kitchen's north
## wall wherever the kitchen happens to be, so moving the room moves the kitchen with it.

const RUN_BAYS := 2
const BAY := 0.6
const RUN_WIDTH := BAY * float(RUN_BAYS)
const CARCASS_HEIGHT := 0.72
const CARCASS_DEPTH := 0.58

## Fronts: a drawer above a door in every bay, with a 3 mm reveal all round.
const FRONT_WIDTH := BAY - 0.024
const DRAWER_HEIGHT := 0.16
const DRAWER_DEPTH := 0.46
## How far a drawer comes out. Short of its own depth, because a drawer pulled past its runners
## falls on the floor.
const DRAWER_TRAVEL := 0.42
const DOOR_SWING_DEG := 100.0

## The drawer that is the spoons' home, and the cupboard the clutter starts in.
const CUTLERY_DRAWER := &"kitchen_drawer_w"
const CLUTTER_CUPBOARD := &"kitchen_door_e"
const CUTLERY_GROUP := &"kitchen_cutlery"
const CUTLERY_CAPACITY := 12
## Twelve spoons in a pile, one spoon thick apart. Any more and the pile is a tower; any less
## and the twelfth spoon is inside the first (`docs/ARCHITECTURE.md`, "Placement").
const CUTLERY_STEP := 0.004

static func build(plan: FloorPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Furniture"
	var kitchen := plan.find_room(&"kitchen")
	if kitchen != null:
		var run := _kitchen_run(plan)
		# On the kitchen's render layer, so the kitchen's bulb lights it and no other does.
		RoomLayers.stamp(run, RoomLayers.mask(RoomLayers.derive(plan), kitchen.id))
		root.add_child(run)
	return root

## Where the run stands, in world space. Public because the authored item placements are
## expressed against it — a spoon on the worktop and the worktop itself must not be able to
## disagree about where the worktop is.
static func run_origin(plan: FloorPlan) -> Transform3D:
	var room := plan.find_room(&"kitchen")
	if room == null:
		return Transform3D.IDENTITY
	var rect := _bounds(room)
	var face := WallDeriver.DEFAULT_THICKNESS * 0.5
	# Against the north wall, its west end flush with the west wall. The worktop's back edge is
	# on the plaster, which is what `Props.base_carcass` puts the upstand on.
	var x := rect.position.x + face + RUN_WIDTH * 0.5
	var z := rect.position.y + face + (CARCASS_DEPTH + Props.WORKTOP_NOSE) * 0.5
	var y := room.floor_y(plan.storey_of(room.id).base_y)
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))

## The top of the worktop in world space: what stands on it stands here.
static func worktop_height(plan: FloorPlan) -> float:
	return run_origin(plan).origin.y + Props.worktop_y(CARCASS_HEIGHT)

static func _bounds(room: RoomDef) -> Rect2:
	var r := Rect2(room.polygon[0], Vector2.ZERO)
	for p: Vector2 in room.polygon:
		r = r.expand(p)
	return r

static func _kitchen_run(plan: FloorPlan) -> Node3D:
	var run := Node3D.new()
	run.name = "KitchenRun"
	run.transform = run_origin(plan)
	run.add_child(Props.base_carcass(RUN_WIDTH, RUN_BAYS, CARCASS_HEIGHT, CARCASS_DEPTH))
	_collide(run)

	var top := Props.PLINTH_HEIGHT + CARCASS_HEIGHT
	var front_z := CARCASS_DEPTH * 0.5 + Props.FRONT_PANEL
	for bay in range(RUN_BAYS):
		var west := bay == 0
		var cx := -RUN_WIDTH * 0.5 + BAY * (float(bay) + 0.5)
		var suffix := "_w" if west else "_e"
		_add_drawer(run, StringName("kitchen_drawer" + suffix), Vector3(
				cx, top - Props.FRONT_REVEAL - DRAWER_HEIGHT * 0.5, front_z), west)
		# The door fills what is left of the bay under the drawer, hinged on the outside edge
		# so two doors open away from each other rather than into one another.
		var door_top := top - 2.0 * Props.FRONT_REVEAL - DRAWER_HEIGHT
		var door_bottom := Props.PLINTH_HEIGHT + Props.FRONT_REVEAL
		_add_door(run, StringName("kitchen_door" + suffix),
				Vector2(FRONT_WIDTH, door_top - door_bottom),
				Vector3(cx - (FRONT_WIDTH * 0.5 if west else -FRONT_WIDTH * 0.5),
						(door_top + door_bottom) * 0.5, front_z), west)
	return run

## The carcass as an obstacle. One box: the player cannot walk through a kitchen unit, and no
## part of one is worth a trimesh.
static func _collide(run: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "RunBody"
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var height := Props.worktop_y(CARCASS_HEIGHT)
	box.size = Vector3(RUN_WIDTH, height, CARCASS_DEPTH + Props.WORKTOP_NOSE)
	shape.shape = box
	shape.position = Vector3(0, height * 0.5, Props.WORKTOP_NOSE * 0.5)
	body.add_child(shape)
	run.add_child(body)

static func _add_drawer(run: Node3D, id: StringName, at: Vector3, cutlery: bool) -> void:
	var front := Vector2(FRONT_WIDTH, DRAWER_HEIGHT)
	var mover := Props.drawer(front, DRAWER_DEPTH)
	mover.name = "Drawer_" + String(id)
	mover.transform = Transform3D(Basis.IDENTITY, at)
	run.add_child(mover)
	var container := _container(run, id, mover,
			Transform3D(Basis.IDENTITY, at + Vector3(0, 0, DRAWER_TRAVEL)))
	container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(0, 0, -0.02))
	if not cutlery:
		return
	# The slots hang under the drawer, not under the run: what is in a drawer travels with it,
	# and a ghost previewed at a slot that stayed behind would be a ghost inside the carcass.
	# The container is handed over with them, because a group that requires an open container
	# has to be able to ask one whether it is open.
	var slots := PlaceSlots.new()
	slots.initialize(_cutlery_group(front), container)
	mover.add_child(slots)

static func _add_door(run: Node3D, id: StringName, size: Vector2, hinge: Vector3,
		hinge_left: bool) -> void:
	var mover := Props.cabinet_door(size, hinge_left)
	mover.name = "Door_" + String(id)
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	run.add_child(mover)
	var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
	_container(run, id, mover, Transform3D(Basis(Vector3.UP, swing), hinge)) \
			.add_handle(Vector3(size.x, size.y, 0.08),
					Vector3(size.x * (0.5 if hinge_left else -0.5), 0, -0.02))

static func _container(run: Node3D, id: StringName, mover: Node3D,
		open_xform: Transform3D) -> ContainerComponent:
	var c := ContainerComponent.new()
	c.name = "Container_" + String(id)
	run.add_child(c)
	c.initialize(id, mover, open_xform)
	return c

## Twelve spoons, stacked. The base transform is measured off the spoon's own mesh rather than
## typed, so the bottom one rests on the drawer floor whatever the generator does next.
static func _cutlery_group(front: Vector2) -> PlaceSlotGroup:
	var g := PlaceSlotGroup.new()
	g.id = CUTLERY_GROUP
	g.accepts = [&"spoon"] as Array[StringName]
	g.capacity = CUTLERY_CAPACITY
	g.fill_order = PlaceSlotGroup.FillOrder.SEQUENTIAL
	g.layout = PlaceSlotGroup.Layout.STACK
	g.step = Vector3(0, CUTLERY_STEP, 0)
	g.requires_open = true
	var floor_at := Props.drawer_floor(front, DRAWER_DEPTH)
	g.base_xform = Transform3D(Basis.IDENTITY, floor_at + rest_offset(&"spoon"))
	return g

## Lifts and centres an item so it rests on the surface a slot names instead of hovering over
## it or sinking into it (modelling rule 5). Measured from the mesh, once, at build time.
static func rest_offset(generator: StringName) -> Vector3:
	var def := ItemDef.make(&"_measure", generator, &"")
	var visual := ItemFactory.build_visual(def)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in WorldBuilder.meshes(visual):
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	visual.free()
	var centre := box.get_center()
	return Vector3(-centre.x, -box.position.y, -centre.z)
