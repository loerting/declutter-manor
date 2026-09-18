extends FurnitureGenerator
## A run of kitchen base units: plinth, carcass, worktop and upstand, and in every bay a drawer
## over a hinged door. All of them open.
##
##     bays    int    how many 600 mm bays, default 2
##     sink    int    the bay with a sink in it, from 1; 0 for none, default 0. That bay has a fixed
##                    front where its drawer would be, because the basin fills that space.
##     bowl    bool   a fruit bowl in the middle of the worktop (`FruitBowl`), default false
##     hinges  String the side each door hinges on, "l" or "r" from the left (`Props.hinged_left`); by default
##                    the outer edge, so neighbours open away from each other
##
## Parts, numbered from the run's left end seen from the front, starting at 1:
##
##     drawer_<n>     container, and an anchor on the drawer box's inside floor
##     door_<n>       container
##     cupboard_<n>   anchor on the carcass floor behind door n, belonging to that door
##     worktop        anchor on the worktop, at the middle of the run
##     bowl           anchor in the fruit bowl, on the fruit, when there is one

const DEFAULT_BAYS := 2
const BAY := 0.6
const CARCASS_HEIGHT := 0.72
const CARCASS_DEPTH := 0.58

## Fronts: a drawer above a door in every bay, with a 3 mm reveal all round.
const FRONT_WIDTH := BAY - 0.024
const DRAWER_HEIGHT := 0.16
const DRAWER_DEPTH := 0.46
## How far a drawer comes out. Short of its own depth, because a drawer pulled past its runners
## falls on the floor.
const DRAWER_TRAVEL := 0.42
## A door opens square to its front and no further: past square, the end door of a run against a wall swung
## into the wall and the two middle doors of a double vanity into each other (`FurnitureProbe`,
## `container.swing`, 2026-09-17).
const DOOR_SWING_DEG := 90.0

func build(def: FurnitureDef) -> FurnitureNode:
	var bays := maxi(1, Params.integer(def.params, "bays", DEFAULT_BAYS))
	var sink := clampi(Params.integer(def.params, "sink", 0), 0, bays)
	var width := BAY * float(bays)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, CARCASS_DEPTH + Props.WORKTOP_NOSE))
	# `Props.base_carcass` is centred on the carcass depth; the piece's origin is at its back, where
	# the carcass back panel and the worktop's back edge both stand on the plaster.
	var run := Node3D.new()
	run.name = "Run"
	run.position = Vector3(0, 0, CARCASS_DEPTH * 0.5)
	piece.add_child(run)
	run.add_child(Props.base_carcass(width, bays, CARCASS_HEIGHT, CARCASS_DEPTH, sink))

	var height := Props.worktop_y(CARCASS_HEIGHT)
	var covers := CARCASS_DEPTH + Props.WORKTOP_NOSE
	piece.add_box(Vector3(width, height, covers), Vector3(0, height * 0.5, covers * 0.5))
	piece.add_anchor(&"worktop", Transform3D(Basis.IDENTITY, Vector3(0, height, Props.WORKTOP_NOSE * 0.5)),
			run)
	if Params.flag(def.params, "bowl", false):
		var bowl_at := Vector3(0, height, Props.WORKTOP_NOSE * 0.5)
		run.add_child(FruitBowl.build(bowl_at))
		piece.add_anchor(&"bowl", Transform3D(Basis.IDENTITY, bowl_at + Vector3(0, FruitBowl.ON_FRUIT, 0)), run)

	var top := Props.PLINTH_HEIGHT + CARCASS_HEIGHT
	var front_z := CARCASS_DEPTH * 0.5 + Props.FRONT_PANEL
	for bay in range(bays):
		var n := bay + 1
		# Doors hinge on the outside edge, so two neighbours open away from each other.
		var hinge_left := Props.hinged_left(Params.text(def.params, "hinges", ""), bay, bay < bays / 2 or bays == 1)
		var cx := -width * 0.5 + BAY * (float(bay) + 0.5)
		var drawer_at := Vector3(cx, top - Props.FRONT_REVEAL - DRAWER_HEIGHT * 0.5, front_z)
		if n == sink:
			run.add_child(Props.mi(Props.rounded_box(Vector3(FRONT_WIDTH, DRAWER_HEIGHT, Props.FRONT_PANEL), 0.004, 4, 20),
					Mats.of("painted_wood", Props.FRONT_WHITE, 0.65), drawer_at - Vector3(0, 0, Props.FRONT_PANEL * 0.5)))
		else:
			_add_drawer(piece, run, n, drawer_at)
		# The door fills what is left of the bay under the drawer.
		var door_top := top - 2.0 * Props.FRONT_REVEAL - DRAWER_HEIGHT
		var door_bottom := Props.PLINTH_HEIGHT + Props.FRONT_REVEAL
		var door := _add_door(piece, run, n, Vector2(FRONT_WIDTH, door_top - door_bottom),
				Vector3(cx - (FRONT_WIDTH * 0.5 if hinge_left else -FRONT_WIDTH * 0.5),
						(door_top + door_bottom) * 0.5, front_z), hinge_left)
		piece.add_anchor(StringName("cupboard_%d" % n), Transform3D(Basis.IDENTITY,
				Vector3(cx, Props.PLINTH_HEIGHT + Props.CARCASS_PANEL, 0)), run, door)
	return piece

func _add_drawer(piece: FurnitureNode, run: Node3D, n: int, at: Vector3) -> void:
	var front := Vector2(FRONT_WIDTH, DRAWER_HEIGHT)
	var mover := Props.drawer(front, DRAWER_DEPTH)
	mover.name = "Drawer_%d" % n
	mover.transform = Transform3D(Basis.IDENTITY, at)
	run.add_child(mover)
	var container := piece.add_container(StringName("drawer_%d" % n), mover,
			Transform3D(Basis.IDENTITY, at + Vector3(0, 0, DRAWER_TRAVEL)), run)
	container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(0, 0, -0.02))
	# On the drawer, not on the carcass: what is in a drawer travels with it, and a ghost previewed
	# at a slot that stayed behind would be a ghost inside the carcass.
	piece.add_anchor(StringName("drawer_%d" % n),
			Transform3D(Basis.IDENTITY, Props.drawer_floor(front, DRAWER_DEPTH)), mover, container)

func _add_door(piece: FurnitureNode, run: Node3D, n: int, size: Vector2, hinge: Vector3,
		hinge_left: bool) -> ContainerComponent:
	var mover := Props.cabinet_door(size, hinge_left)
	mover.name = "Door_%d" % n
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	run.add_child(mover)
	var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
	var container := piece.add_container(StringName("door_%d" % n), mover,
			Transform3D(Basis(Vector3.UP, swing), hinge), run)
	container.add_handle(Vector3(size.x, size.y, 0.08),
			Vector3(size.x * (0.5 if hinge_left else -0.5), 0, -0.02))
	return container
