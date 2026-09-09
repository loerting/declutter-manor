class_name ManorItems
## The manor's authored content. Twelve spoons, which is Phase 2's whole item list: six on the
## kitchen worktop and six shut in the cupboard beside it, all of them belonging in the drawer
## between the two (`docs/ROADMAP.md`, Phase 2).
##
## Both `home` and `start` are fixed. Every player gets the same house and the same hiding
## places — there is no seeded variation anywhere in item placement.
##
## Positions are given in the kitchen run's own space and converted here, so the spoons and the
## worktop they lie on cannot disagree about where the worktop is.

const SET := &"cutlery"

## x, z and yaw in the run's local space. Authored, not generated: a scatter that reads as
## dropped rather than as a row is the point of them.
const ON_WORKTOP: Array[Vector3] = [
	Vector3(-0.46, 0.02, 12.0), Vector3(-0.28, -0.06, -25.0), Vector3(-0.08, 0.06, 40.0),
	Vector3(0.12, -0.03, -8.0), Vector3(0.30, 0.07, 65.0), Vector3(0.47, -0.05, -50.0),
]
const IN_CUPBOARD: Array[Vector3] = [
	Vector3(0.12, -0.10, 20.0), Vector3(0.22, 0.08, -35.0), Vector3(0.34, -0.05, 70.0),
	Vector3(0.45, 0.12, -15.0), Vector3(0.30, 0.20, 5.0), Vector3(0.18, -0.22, -60.0),
]

static func build(plan: FloorPlan) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	var run := FurnitureBuilder.run_origin(plan)
	var rest := FurnitureBuilder.rest_offset(&"spoon")
	var worktop := Props.worktop_y(FurnitureBuilder.CARCASS_HEIGHT)
	var shelf := Props.PLINTH_HEIGHT + Props.CARCASS_PANEL
	for i in range(ON_WORKTOP.size()):
		var at: Vector3 = ON_WORKTOP[i]
		var def := _spoon(i + 1)
		# Out in the open, so its transform is the world's.
		def.start = ItemPlacement.new()
		def.start.room = &"kitchen"
		def.start.xform = run * _lying(Vector3(at.x, worktop, at.y), at.z, rest)
		out.append(def)
	for i in range(IN_CUPBOARD.size()):
		var at: Vector3 = IN_CUPBOARD[i]
		var def := _spoon(ON_WORKTOP.size() + i + 1)
		# Inside a container, so its transform is that container's, and it stays with the
		# carcass rather than swinging out with the door.
		def.start = ItemPlacement.new()
		def.start.room = &"kitchen"
		def.start.container = FurnitureBuilder.CLUTTER_CUPBOARD
		def.start.xform = _lying(Vector3(at.x, shelf, at.y), at.z, rest)
		out.append(def)
	return out

## Lying on a surface at `at`, turned by `yaw` about its own centre. The rest offset is applied
## after the rotation, which is what turns a spoon on the spot instead of swinging it around
## the origin of its own mesh.
static func _lying(at: Vector3, yaw: float, rest: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at) * Transform3D(Basis.IDENTITY, rest)

static func _spoon(n: int) -> ItemDef:
	var def := ItemDef.make(StringName("spoon_%02d" % n), &"spoon",
			FurnitureBuilder.CUTLERY_GROUP, SET)
	def.name_key = "item.spoon"
	def.slot_cost = 1
	return def
