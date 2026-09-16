extends FurnitureGenerator
## A small oak key rack beside the front door: a board with its edges eased, screwed to the wall
## through two brass screws, and two black hooks that reach out and turn up at the tip.
##
## No parameters.
##
## Anchors:
##
##     hooks    over the left hook's bend, where the top of a key ring hangs

const WIDTH := 0.3
const BOARD := Vector3(0.3, 0.12, 0.018)
const CENTRE_Y := 1.45
const EASE := 0.004
const SCREW_X := 0.125
const SCREW_RADIUS := 0.0055
const SCREW_PROUD := 0.0022

const HOOK_X: Array[float] = [-0.06, 0.06]
## A hook's path out of the board: out, into a bend, up to the tip.
const HOOK_Y := 1.415
const HOOK_REACH := 0.05
const HOOK_RISE := 0.018
const HOOK_RADIUS := 0.0038
const ROSE_RADIUS := 0.009
const ROSE_THICK := 0.004
## A key ring's wire sits on top of the hook in its bend.
const RING_WIRE := 0.0014
const DEPTH := BOARD.z + HOOK_REACH + HOOK_RADIUS * 2.0

const OAK := Color(0.9, 0.78, 0.62)
const IRON := Color(0.06, 0.06, 0.065)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	piece.mounted = true
	piece.add_child(Props.mi(Props.rounded_box(BOARD, EASE, 6, 24), Mats.of("oak", OAK, 0.6),
			Vector3(0, CENTRE_Y, BOARD.z * 0.5)))
	var brass := Mats.of("metal_brushed", Props.BRASS, 0.4)
	var screw := Props.lathe(PackedVector2Array([Vector2(SCREW_RADIUS, 0), Vector2(SCREW_RADIUS * 0.85, SCREW_PROUD * 0.7),
			Vector2(SCREW_RADIUS * 0.45, SCREW_PROUD), Vector2(0, SCREW_PROUD)]), 16)
	for side: float in [-1.0, 1.0]:
		var head := Props.mi(screw, brass, Vector3(side * SCREW_X, CENTRE_Y, BOARD.z - 0.0005))
		head.rotation = Vector3(PI * 0.5, 0, 0)
		piece.add_child(head)

	var iron := Props.mat(IRON, 0.5, 0.6)
	var parts: Array = []
	for x: float in HOOK_X:
		var path := Props.smooth_path(PackedVector3Array([
			Vector3(x, HOOK_Y, BOARD.z - 0.002), Vector3(x, HOOK_Y, BOARD.z + HOOK_REACH * 0.55),
			Vector3(x, HOOK_Y + HOOK_RISE * 0.2, BOARD.z + HOOK_REACH * 0.92),
			Vector3(x, HOOK_Y + HOOK_RISE, BOARD.z + HOOK_REACH)]), 6)
		parts.append([Props.tube(path, HOOK_RADIUS, 12), Transform3D.IDENTITY])
		parts.append([Props.lathe(PackedVector2Array([Vector2(ROSE_RADIUS, 0), Vector2(ROSE_RADIUS, ROSE_THICK * 0.6),
				Vector2(ROSE_RADIUS * 0.6, ROSE_THICK), Vector2(0, ROSE_THICK)]), 20),
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, HOOK_Y, BOARD.z - 0.0005))])
	piece.add_child(Props.mi(Props.bake(parts), iron))

	piece.add_box(Vector3(BOARD.x, BOARD.y, DEPTH), Vector3(0, CENTRE_Y, DEPTH * 0.5))
	var bend := Vector3(HOOK_X[0], HOOK_Y + HOOK_RADIUS + RING_WIRE * 2.0, BOARD.z + HOOK_REACH * 0.62)
	piece.add_anchor(&"hooks", Transform3D(Basis.IDENTITY, bend), piece)
	return piece
