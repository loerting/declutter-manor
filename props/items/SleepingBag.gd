extends ItemGenerator
## A sleeping bag packed in its stuff sack, lying on its side along Z: a nylon sack bulging where the bag
## pushes at it, a round seamed foot at -Z, the mouth at +Z gathered in by its drawstring to a puckered
## neck, and the cord out of it through a toggle.
##
##     tint    Color    the sack, default FOREST

const RADIUS := 0.105
const LENGTH := 0.4
## Along the sack from its foot, (share of the length, share of the radius): a domed foot, a full body,
## and the mouth pulled in.
const PROFILE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.015, 0.55), Vector2(0.05, 0.84), Vector2(0.11, 0.97),
		Vector2(0.3, 1.0), Vector2(0.55, 1.02), Vector2(0.78, 0.98), Vector2(0.88, 0.86), Vector2(0.94, 0.62),
		Vector2(0.975, 0.36), Vector2(0.99, 0.24), Vector2(1.0, 0.16)]
## How much the sack's surface ripples round and along, and the gathers' depth at the mouth.
const RIPPLE := 0.035
const GATHERS := 9
const GATHER := 0.3
const SIDES := 28
## The seam round the foot, the cord's radius and length out of the neck, and the toggle.
const SEAM_AT := 0.04
const SEAM := 0.0025
const CORD := 0.0025
const CORD_OUT := 0.07
const TOGGLE := Vector2(0.009, 0.022)

const FOREST := Color(0.18, 0.36, 0.22)
const BLACK := Color(0.05, 0.05, 0.05)
const TINTS: Array[Color] = [FOREST, Color(0.86, 0.4, 0.1), Color(0.16, 0.3, 0.64), Color(0.7, 0.14, 0.12)]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var rings: Array = []
	for row: Vector2 in PROFILE:
		var ring := PackedVector3Array()
		var gather := smoothstep(0.86, 1.0, row.x)
		for j in range(SIDES):
			var a := TAU * float(j) / SIDES
			var ripple := RIPPLE * sin(a * 3.0 + row.x * 9.0) * sin(row.x * PI)
			var r := RADIUS * row.y * (1.0 + ripple - GATHER * gather * maxf(cos(a * GATHERS), 0.0))
			ring.append(_at(a, r, row.x * LENGTH))
		rings.append(ring)
	# The foot ring has no size: it closes the dome to a point.
	var sack := Props.loft(rings.slice(1), true, true)
	var tint := Params.colour(def.params, "tint", FOREST)
	root.add_child(Props.mi(sack, Mats.finish("pillow_fabric", tint, 0.5)))
	var seam_r := RADIUS * _profile(SEAM_AT) + SEAM * 0.5
	var seam_ring := PackedVector3Array()
	for k in range(SIDES + 1):
		var a := TAU * float(k) / SIDES
		seam_ring.append(_at(a, seam_r, SEAM_AT * LENGTH))
	var trim: Array = [[Props.tube(seam_ring, SEAM, 6, false), Transform3D.IDENTITY]]
	var neck := Vector3(0, _axis(), LENGTH)
	var cord := PackedVector3Array([neck + Vector3(0, 0, -0.01), neck + Vector3(0.004, -0.01, CORD_OUT * 0.4),
			neck + Vector3(0.01, -0.035, CORD_OUT * 0.8), neck + Vector3(0.012, -0.06, CORD_OUT)])
	trim.append([Props.tube(Props.smooth_path(cord, 4), CORD, 6), Transform3D.IDENTITY])
	var toggle_at := neck + Vector3(0.006, -0.022, CORD_OUT * 0.62)
	trim.append([Props.cyl(TOGGLE.x, TOGGLE.x, TOGGLE.y, 12), Transform3D(Basis.looking_at(Vector3(0.1, -0.5, 1.0)) * Basis(Vector3.RIGHT, PI * 0.5), toggle_at)])
	root.add_child(Props.mi(Props.bake(trim), Mats.finish("plastic", BLACK, 0.6)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## A point round the sack's axis, which lies along Z as high over the floor as the sack reaches out from
## it. The ring runs from +X down toward -Y, which is the way round `Props.loft` skins a stack toward +Z.
static func _at(angle: float, radius: float, z: float) -> Vector3:
	return Vector3(cos(angle) * radius, _axis() - sin(angle) * radius, z)

## The sack's lowest point is its fullest row pushed out by the ripple, straight down.
static func _axis() -> float:
	var lowest := 0.0
	for k in range(PROFILE.size()):
		var row := PROFILE[k]
		var r := RADIUS * row.y * (1.0 + RIPPLE * sin(PI * 0.5 * 3.0 + row.x * 9.0) * sin(row.x * PI))
		lowest = maxf(lowest, r)
	return lowest

static func _profile(share: float) -> float:
	for k in range(1, PROFILE.size()):
		if PROFILE[k].x >= share:
			var t := inverse_lerp(PROFILE[k - 1].x, PROFILE[k].x, share)
			return lerpf(PROFILE[k - 1].y, PROFILE[k].y, t)
	return PROFILE[-1].y
