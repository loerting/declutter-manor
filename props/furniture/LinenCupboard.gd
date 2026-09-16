extends FurnitureGenerator
## A tall painted linen cupboard on a recessed plinth: a carcass of 18 mm panels with four shelves
## behind one hinged door, folded sheets on the shelves the towels do not use and a spare duvet on top.
##
## No parameters.
##
## Parts:
##
##     door      container
##
## Anchors:
##
##     towels    on the second shelf, at its middle, where the bath towels stack; belongs to the door

const WIDTH := 0.72
const DEPTH := 0.42
const HEIGHT := 2.0
const PLINTH := 0.08
const PLINTH_SETBACK := 0.03
const BACK := 0.008
## The shelves' tops above the floor. The towels stack on SHELVES[TOWEL_SHELF].
const SHELVES: Array[float] = [0.52, 0.95, 1.36, 1.7]
const TOWEL_SHELF := 1
const DOOR_SWING_DEG := 100.0
const PULL_LENGTH := 0.22
## Where the pull is, up from the door's middle: at a hand's height.
const PULL_UP := 0.08

## Folded linen on the other shelves: a fold's size, and per stack the shelf it stands on (0 the
## carcass floor, n on SHELVES[n - 1]) and how many folds high it is.
const SHEET := Vector3(0.3, 0.035, 0.26)
const SHEET_STACKS: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 5), Vector2i(3, 3)]
const DUVET := Vector3(0.6, 0.16, 0.32)

const PAINT := Color(0.86, 0.88, 0.84)
const LINEN: Array[Color] = [Color(0.96, 0.96, 0.94), Color(0.8, 0.86, 0.9), Color(0.92, 0.88, 0.8)]

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH + Props.FRONT_PANEL + 0.03))
	var p := Props.CARCASS_PANEL
	var cz := DEPTH * 0.5
	var inner := WIDTH - p * 2.0
	var parts: Array = [
		Props.part(Vector3(WIDTH, p, DEPTH), Vector3(0, PLINTH + p * 0.5, cz)),
		Props.part(Vector3(WIDTH, p, DEPTH), Vector3(0, HEIGHT - p * 0.5, cz)),
		Props.part(Vector3(inner, HEIGHT - PLINTH - p * 2.0, BACK), Vector3(0, (PLINTH + HEIGHT) * 0.5, BACK * 0.5)),
	]
	for side: float in [-1.0, 1.0]:
		parts.append(Props.part(Vector3(p, HEIGHT - PLINTH, DEPTH), Vector3(side * (WIDTH - p) * 0.5, (PLINTH + HEIGHT) * 0.5, cz)))
	for y: float in SHELVES:
		parts.append(Props.part(Vector3(inner, p, DEPTH - BACK - 0.01), Vector3(0, y - p * 0.5, BACK + (DEPTH - BACK - 0.01) * 0.5)))
	var paint := Mats.of("painted_wood", PAINT, 0.7)
	piece.add_child(Props.mi(Props.union(parts), paint))
	piece.add_child(Props.mi(Props.box(Vector3(WIDTH - 0.02, PLINTH, DEPTH - PLINTH_SETBACK)),
			Mats.of("painted_wood", Color(0.62, 0.62, 0.6), 0.8), Vector3(0, PLINTH * 0.5, (DEPTH - PLINTH_SETBACK) * 0.5)))
	piece.add_child(_linen(inner))

	var front := Vector2(WIDTH - Props.FRONT_REVEAL * 2.0, HEIGHT - PLINTH - Props.FRONT_REVEAL * 2.0)
	var hinge := Vector3(-front.x * 0.5, (PLINTH + HEIGHT) * 0.5, DEPTH + Props.FRONT_PANEL)
	var mover := Props.cabinet_door(front, true, paint, PULL_LENGTH, PULL_UP)
	mover.name = "Door"
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	piece.add_child(mover)
	var container := piece.add_container(&"door", mover, Transform3D(Basis(Vector3.UP, -deg_to_rad(DOOR_SWING_DEG)), hinge), piece)
	container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(front.x * 0.5, 0, -0.02))
	piece.add_anchor(&"towels", Transform3D(Basis.IDENTITY, Vector3(0, SHELVES[TOWEL_SHELF], cz)), piece, container)

	piece.add_box(Vector3(WIDTH, HEIGHT, DEPTH), Vector3(0, HEIGHT * 0.5, cz))
	return piece

## Stacks of folded sheets on the shelves the towels leave free, and a folded duvet on the top shelf.
static func _linen(inner: float) -> Node3D:
	var root := Node3D.new()
	var by_colour: Array[Array] = [[], [], []]
	for stack: Vector2i in SHEET_STACKS:
		var y0 := PLINTH + Props.CARCASS_PANEL if stack.x == 0 else SHELVES[stack.x - 1]
		for side: float in [-1.0, 1.0]:
			for k in range(stack.y):
				var colour := (k + (1 if side > 0.0 else 0) + stack.x) % LINEN.size()
				by_colour[colour].append([Props.rounded_box(SHEET, 0.012, 4, 12), Transform3D(Basis.IDENTITY,
						Vector3(side * inner * 0.25, y0 + SHEET.y * (float(k) + 0.5), DEPTH * 0.52))])
	by_colour[0].append([Props.rounded_box(DUVET, 0.05, 6, 16), Transform3D(Basis.IDENTITY,
			Vector3(0, SHELVES[SHELVES.size() - 1] + DUVET.y * 0.5, DEPTH * 0.52))])
	for i in range(LINEN.size()):
		root.add_child(Props.mi(Props.bake(by_colour[i]), Mats.of("pillow_fabric", LINEN[i], 0.95)))
	return root
