extends ItemGenerator
## A child's school backpack standing up, its front pocket to +Z: a padded body rounded at every edge,
## a zipped front pocket, two shoulder straps down the back from under a grab loop, and a zip pull.
##
##     tint    Color    the body's colour, default RED
##     trim    Color    straps, loop and zip, default CHARCOAL

const BODY := Vector3(0.3, 0.42, 0.14)
const BODY_ROUND := 0.05
const POCKET := Vector3(0.23, 0.2, 0.055)
const POCKET_ROUND := 0.022
const POCKET_Y := 0.13
const ZIP_RADIUS := 0.003
const STRAP_RADIUS := 0.012
const STRAP_X := 0.075
const LOOP_RADIUS := 0.006
const LOOP_HEIGHT := 0.035
const PULL := Vector3(0.012, 0.03, 0.004)

const RED := Color(0.72, 0.14, 0.12)
const TEAL := Color(0.12, 0.45, 0.48)
const CHARCOAL := Color(0.12, 0.12, 0.13)
const VARIANTS: Array[Color] = [RED, TEAL]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var fabric := Mats.of("sofa_fabric", Params.colour(def.params, "tint", RED), 0.95, 0.6)
	var trim := Mats.of("rubber", Params.colour(def.params, "trim", CHARCOAL), 0.8)
	var body: Array = [[Props.rounded_box(BODY, BODY_ROUND, 8, 24), Transform3D(Basis.IDENTITY, Vector3(0, BODY.y * 0.5, 0))]]
	var pocket_z := BODY.z * 0.5 - POCKET_ROUND
	body.append([Props.rounded_box(POCKET, POCKET_ROUND, 6, 20), Transform3D(Basis.IDENTITY,
			Vector3(0, POCKET_Y, pocket_z + POCKET.z * 0.5))])
	root.add_child(Props.mi(Props.bake(body), fabric))

	var parts: Array = []
	# The zip runs round the pocket's top edge, where its face turns over into its side.
	var zip := PackedVector3Array()
	var zy := POCKET_Y + POCKET.y * 0.5 - POCKET_ROUND * 0.35
	var zz := pocket_z + POCKET.z - POCKET_ROUND * 0.35
	for k in range(13):
		var t := float(k) / 12.0
		zip.append(Vector3(lerpf(-POCKET.x * 0.5 + POCKET_ROUND, POCKET.x * 0.5 - POCKET_ROUND, t), zy, zz))
	parts.append([Props.tube(zip, ZIP_RADIUS, 6), Transform3D.IDENTITY])
	parts.append([Props.rounded_box(PULL, 0.0015, 4, 8), Transform3D(Basis(Vector3.RIGHT, 0.25),
			Vector3(POCKET.x * 0.25, zy - PULL.y * 0.5, zz + 0.004))])
	# Shoulder straps: out of the back's top, curving away from it and back in at its bottom corners.
	var back := -BODY.z * 0.5
	for side: float in [-1.0, 1.0]:
		var strap := Props.smooth_path(PackedVector3Array([
			Vector3(side * STRAP_X * 0.6, BODY.y - 0.02, back + 0.01), Vector3(side * STRAP_X, BODY.y - 0.08, back - 0.03),
			Vector3(side * STRAP_X * 1.2, BODY.y * 0.5, back - 0.04), Vector3(side * BODY.x * 0.42, 0.1, back - 0.02),
			Vector3(side * BODY.x * 0.45, 0.04, back + 0.02)]), 6)
		parts.append([Props.tube(strap, STRAP_RADIUS, 10), Transform3D.IDENTITY])
	# The grab loop stands on the middle of the top, which is where a hook holds it level.
	var loop := Props.smooth_path(PackedVector3Array([Vector3(-0.035, BODY.y - 0.01, 0.0),
			Vector3(-0.02, BODY.y + LOOP_HEIGHT * 0.8, 0.0), Vector3(0.0, BODY.y + LOOP_HEIGHT, 0.0),
			Vector3(0.02, BODY.y + LOOP_HEIGHT * 0.8, 0.0), Vector3(0.035, BODY.y - 0.01, 0.0)]), 5)
	parts.append([Props.tube(loop, LOOP_RADIUS, 8), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(parts), trim))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": VARIANTS[index % VARIANTS.size()]}

## Put down, it lies on its straps with the pocket up.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5)
