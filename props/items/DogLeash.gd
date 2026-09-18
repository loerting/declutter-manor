extends ItemGenerator
## A rope dog leash hanging from its handle: the handle a loop of the rope spliced back into itself,
## the rope hanging from the splice, and a brass snap hook on a swivel at its end.
##
## No parameters.

const ROPE_RADIUS := 0.0055
const LOOP_HALF := Vector2(0.032, 0.07)
const LOOP_POINTS := 40
const DROP := 0.55
const SPLICE := Vector2(0.009, 0.05)
const SWIVEL := Vector3(0.009, 0.0022, 0.028)
const HOOK_RADIUS := 0.0028

const ROPE := Color(0.55, 0.12, 0.1)
const BRASS := Color(0.78, 0.62, 0.32)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var rope := Mats.of("rug_wool", ROPE, 0.9, 0.25)
	var brass := Mats.finish("metal_polished", BRASS, 0.3)
	var top := DROP + SPLICE.y + LOOP_HALF.y * 2.0
	var join := top - LOOP_HALF.y * 2.0
	var parts: Array = []
	var loop := PackedVector3Array()
	for i in range(LOOP_POINTS + 1):
		var a := -PI * 0.5 + TAU * float(i) / float(LOOP_POINTS)
		loop.append(Vector3(cos(a) * LOOP_HALF.x * (1.0 - 0.35 * maxf(0.0, -sin(a))), top - LOOP_HALF.y + sin(a) * -LOOP_HALF.y, 0.0))
	parts.append([Props.tube(loop, ROPE_RADIUS, 10), Transform3D.IDENTITY])
	# The splice: both ends of the loop bound together, a little fatter than the rope.
	parts.append([Props.cyl(SPLICE.x, SPLICE.x, SPLICE.y, 12), Transform3D(Basis.IDENTITY, Vector3(0, join - SPLICE.y * 0.5, 0))])
	var hang := Props.smooth_path(PackedVector3Array([Vector3(0, join - SPLICE.y, 0), Vector3(0.004, join - SPLICE.y - DROP * 0.35, 0.003),
			Vector3(-0.003, join - SPLICE.y - DROP * 0.7, -0.002), Vector3(0, SWIVEL.z + 0.03, 0)]), 6)
	parts.append([Props.tube(hang, ROPE_RADIUS, 10), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(parts), rope))

	var metal: Array = []
	metal.append([Props.cyl(SWIVEL.x, SWIVEL.x * 0.8, SWIVEL.z, 12), Transform3D(Basis.IDENTITY, Vector3(0, 0.03 + SWIVEL.z * 0.5, 0))])
	var hook := Props.smooth_path(PackedVector3Array([Vector3(0, 0.032, 0), Vector3(-0.008, 0.02, 0), Vector3(-0.007, 0.004, 0),
			Vector3(0.0, HOOK_RADIUS, 0), Vector3(0.007, 0.006, 0), Vector3(0.006, 0.02, 0)]), 5)
	metal.append([Props.tube(hook, HOOK_RADIUS, 8), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(metal), brass))
	return root

## Put down, it lies along the floor.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5)
