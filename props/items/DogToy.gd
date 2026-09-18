extends ItemGenerator
## A dog's toy, lying as it was dropped.
##
##     kind    String    "ball", a tennis ball with its seam; "rope", a twisted rope with a knot at
##                       each end; or "bone", a rubber bone. Default "ball".

const BALL_RADIUS := 0.033
const SEAM_A := 0.75
const SEAM_RADIUS := 0.0011
const SEAM_POINTS := 96

const ROPE_LENGTH := 0.2
const STRAND_RADIUS := 0.0062
const STRAND_TWIST := 0.0055
const STRAND_TURNS := 5.0
const KNOT_RADIUS := 0.024
const KNOT_SQUASH := 0.85

const BONE_SHAFT := Vector2(0.012, 0.09)
const BONE_KNOB := 0.018
const BONE_SPREAD := 0.013

const FELT := Color(0.78, 0.88, 0.18)
const SEAM := Color(0.96, 0.96, 0.94)
const STRANDS: Array[Color] = [Color(0.2, 0.35, 0.7), Color(0.95, 0.95, 0.92), Color(0.75, 0.15, 0.12)]
const RUBBER := Color(0.85, 0.35, 0.1)
const KINDS: Array[String] = ["ball", "rope", "bone"]

func build(def: ItemDef) -> Node3D:
	match Params.text(def.params, "kind", "ball"):
		"rope":
			return _rope()
		"bone":
			return _bone()
	return _ball()

func variant(index: int) -> Dictionary:
	return {"kind": KINDS[index % KINDS.size()]}

static func _ball() -> Node3D:
	var root := Node3D.new()
	# Its seam stands proud, so where the seam runs under it, the ball rests on the seam.
	var centre := Vector3(0, BALL_RADIUS + SEAM_RADIUS * 1.3, 0)
	root.add_child(Props.mi(_ball_mesh(BALL_RADIUS, 32), Mats.of("rug_wool", FELT, 1.0, 0.1), centre))
	# The seam of a tennis ball is a closed curve on its sphere: a + b = 1 keeps it there.
	var b := 1.0 - SEAM_A
	var seam := PackedVector3Array()
	for i in range(SEAM_POINTS + 1):
		var t := TAU * float(i) / float(SEAM_POINTS)
		var p := Vector3(SEAM_A * cos(t) + b * cos(3.0 * t), SEAM_A * sin(t) - b * sin(3.0 * t), 2.0 * sqrt(SEAM_A * b) * sin(2.0 * t))
		seam.append(centre + p.normalized() * (BALL_RADIUS + SEAM_RADIUS * 0.3))
	root.add_child(Props.mi(Props.tube(seam, SEAM_RADIUS, 6, false), Props.mat(SEAM, 0.7)))
	return root

static func _rope() -> Node3D:
	var root := Node3D.new()
	var y := KNOT_RADIUS * KNOT_SQUASH
	var half := ROPE_LENGTH * 0.5 - KNOT_RADIUS
	for s in range(STRANDS.size()):
		var path := PackedVector3Array()
		for i in range(33):
			var t := float(i) / 32.0
			var a := TAU * STRAND_TURNS * t + TAU * float(s) / float(STRANDS.size())
			path.append(Vector3(lerpf(-half, half, t), y + cos(a) * STRAND_TWIST, sin(a) * STRAND_TWIST))
		root.add_child(Props.mi(Props.tube(path, STRAND_RADIUS, 8), Mats.of("rug_wool", STRANDS[s], 1.0, 0.1)))
	for side: float in [-1.0, 1.0]:
		var knot := Props.mi(_ball_mesh(KNOT_RADIUS, 16), Mats.of("rug_wool", STRANDS[1], 1.0, 0.1),
				Vector3(side * (half + KNOT_RADIUS * 0.6), y, 0))
		knot.scale = Vector3(1.0, KNOT_SQUASH, 1.0)
		root.add_child(knot)
	return root

static func _bone() -> Node3D:
	var root := Node3D.new()
	var rubber := Mats.finish("rubber", RUBBER, 0.55)
	var y := BONE_KNOB
	var parts: Array = [[Props.cyl(BONE_SHAFT.x, BONE_SHAFT.x, BONE_SHAFT.y, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, y, 0))]]
	var knob := _ball_mesh(BONE_KNOB, 16)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([knob, Transform3D(Basis.IDENTITY, Vector3(sx * BONE_SHAFT.y * 0.5, y, sz * BONE_SPREAD))])
	root.add_child(Props.mi(Props.bake(parts), rubber))
	return root

## A sphere with `segments` round it and half as many rings: a toy a few centimetres across needs no
## more, and the engine's default is sixty-four.
static func _ball_mesh(radius: float, segments: int) -> SphereMesh:
	var ball := Props.sphere(radius)
	ball.radial_segments = segments
	ball.rings = segments / 2
	return ball
