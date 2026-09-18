extends ItemGenerator
## A phone charger put away tidily, lying flat: a white wall plug with its prongs folded in, and its
## cable wound into a loose flat coil round the connector.
##
## No parameters.

const BRICK := Vector3(0.03, 0.022, 0.03)
const BRICK_CORNER := 0.004
const CABLE_RADIUS := 0.0018
## The coil: its inner and outer radius, how many turns, and how far each turn wanders off true.
const COIL := Vector2(0.02, 0.05)
const TURNS := 2.3
const WANDER := 0.0025
const POINTS_PER_TURN := 36
const PLUG := Vector3(0.0075, 0.0045, 0.02)
const STRAIN := Vector2(0.0032, 0.014)

const WHITE := Color(0.95, 0.95, 0.94)
const METAL := Color(0.72, 0.73, 0.75)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var plastic := Mats.finish("plastic", WHITE, 0.3)
	var path := PackedVector3Array()
	var count := int(TURNS * POINTS_PER_TURN)
	for i in range(count + 1):
		var t := float(i) / float(count)
		var a := TAU * TURNS * t
		var r := lerpf(COIL.x, COIL.y, t) + WANDER * sin(a * 1.7 + 0.6)
		path.append(Vector3(cos(a) * r, CABLE_RADIUS, sin(a) * r))
	var parts: Array = [[Props.tube(path, CABLE_RADIUS, 8), Transform3D.IDENTITY]]
	# The connector's strain relief carries on from the coil's inner end, the plug from the outer.
	var inner_dir := (path[0] - path[1]).normalized()
	var inner_basis := Basis.looking_at(inner_dir)
	parts.append([Props.cyl(STRAIN.x, CABLE_RADIUS, STRAIN.y, 12), Transform3D(inner_basis * Basis(Vector3.RIGHT, -PI * 0.5),
			path[0] + inner_dir * STRAIN.y * 0.5 + Vector3(0, STRAIN.x - CABLE_RADIUS, 0))])
	var outer_dir := (path[count] - path[count - 1]).normalized()
	var brick_at := path[count] + outer_dir * BRICK.z * 0.5 + Vector3(0, BRICK.y * 0.5 - CABLE_RADIUS, 0)
	parts.append([Props.rounded_box(BRICK, BRICK_CORNER, 6, 20), Transform3D(Basis.looking_at(outer_dir), brick_at)])
	root.add_child(Props.mi(Props.bake(parts), plastic))
	var plug_at := path[0] + inner_dir * (STRAIN.y + PLUG.z * 0.5) + Vector3(0, PLUG.y * 0.5 - CABLE_RADIUS, 0)
	root.add_child(Props.mi(Props.bake([[Props.rounded_box(PLUG, 0.002, 4, 12), Transform3D(inner_basis, plug_at)]]),
			Props.mat(METAL, 0.3, 0.8)))
	return root
