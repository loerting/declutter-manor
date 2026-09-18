extends ItemGenerator
## A one-gallon paint can standing up, half used: a steel can with a rolled chime at its foot and its
## rim, a lid pressed into the rim, a paper label round the body, paint dried in the rim's groove and down
## one side, and a wire bail with a plastic grip hanging down over the front from an ear on each side.
##
##     paint    Color    the paint, default SAGE
##     label    Color    the label's band, default ORANGE

## Radius and height of the can, and the chimes' reach past the body.
const RADIUS := 0.082
const HEIGHT := 0.19
const CHIME := 0.0025
const CHIME_HEIGHT := 0.006
## The lid sits this far down inside the top chime, with a groove round it.
const LID_SINK := 0.004
const GROOVE := Vector2(0.008, 0.003)
const BEAD_STEPS := 6
const FOOT_SINK := 0.003
const SEGMENTS := 36
const LABEL := Vector2(0.03, 0.155)
const BAND := Vector2(0.11, 0.145)
## Ears high on each side, and how far the bail hangs down the front from them.
const EAR := Vector3(0.012, 0.018, 0.006)
const EAR_Y := 0.165
const BAIL_WIRE := 0.0018
const BAIL_DROP := 0.1
const BAIL_STEPS := 14
const GRIP := Vector2(0.006, 0.05)
## A run of paint down the side: where it starts round the rim (degrees from +Z), how long, how wide.
const DRIP := Vector3(-30.0, 0.05, 0.006)

const SAGE := Color(0.55, 0.62, 0.5)
const ORANGE := Color(0.9, 0.46, 0.12)
const PAPER := Color(0.95, 0.94, 0.9)
const TIN := Color(0.8, 0.8, 0.8)
const GRIP_BLACK := Color(0.06, 0.06, 0.06)
const VARIANTS: Array[Dictionary] = [
	{"paint": SAGE, "label": ORANGE},
	{"paint": Color(0.93, 0.9, 0.82), "label": ORANGE},
	{"paint": Color(0.72, 0.42, 0.32), "label": Color(0.16, 0.3, 0.62)},
	{"paint": Color(0.36, 0.44, 0.56), "label": Color(0.16, 0.3, 0.62)},
]

func build(def: ItemDef) -> Node3D:
	var paint := Props.mat(Params.colour(def.params, "paint", SAGE), 0.35)
	var root := Node3D.new()
	var outer := RADIUS + CHIME
	var top := HEIGHT - LID_SINK
	# Up from the middle of the sunk foot, over the foot chime, up the body, over the top chime and down
	# into the groove round the lid.
	var can := PackedVector2Array([Vector2(0.0, FOOT_SINK), Vector2(RADIUS - 0.004, FOOT_SINK), Vector2(RADIUS - 0.002, 0.0),
			Vector2(outer, 0.0), Vector2(outer, CHIME_HEIGHT), Vector2(RADIUS, CHIME_HEIGHT + 0.002),
			Vector2(RADIUS, HEIGHT - CHIME_HEIGHT - 0.002), Vector2(outer, HEIGHT - CHIME_HEIGHT), Vector2(outer, HEIGHT),
			Vector2(RADIUS - 0.002, HEIGHT), Vector2(RADIUS - 0.003, top), Vector2(RADIUS - GROOVE.x, top - GROOVE.y),
			Vector2(RADIUS - GROOVE.x - 0.002, top), Vector2(0.0, top)])
	root.add_child(Props.mi(Props.lathe(can, SEGMENTS), Mats.of("metal_brushed", TIN, 0.45)))
	var label := PackedVector2Array([Vector2(RADIUS + Props.PROUD, LABEL.x), Vector2(RADIUS + Props.PROUD, LABEL.y)])
	root.add_child(Props.mi(Props.lathe(label, SEGMENTS), Mats.of("paper", PAPER, 0.9)))
	var band := PackedVector2Array([Vector2(RADIUS + Props.PROUD * 2.0, BAND.x), Vector2(RADIUS + Props.PROUD * 2.0, BAND.y)])
	root.add_child(Props.mi(Props.lathe(band, SEGMENTS), Mats.finish("paper", Params.colour(def.params, "label", ORANGE), 0.5)))

	# Paint left in the groove, and one run of it down over the chime and the label.
	var bead := PackedVector2Array()
	for k in range(BEAD_STEPS):
		var a := TAU * float(k) / BEAD_STEPS
		bead.append(Vector2(RADIUS - GROOVE.x * 0.5 + cos(a) * GROOVE.x * 0.4, top - GROOVE.y * 0.5 + sin(a) * GROOVE.y * 0.6))
	var dried: Array = [[Props.lathe(bead, SEGMENTS, true), Transform3D.IDENTITY]]
	var drip_at := deg_to_rad(DRIP.x)
	var out := Vector3(sin(drip_at), 0, cos(drip_at))
	var drip := PackedVector3Array()
	for k in range(6):
		var t := float(k) / 5.0
		var y := HEIGHT - t * DRIP.y
		var reach := outer if y > HEIGHT - CHIME_HEIGHT - 0.002 else RADIUS + Props.PROUD * 2.0
		drip.append(out * (reach + 0.0008) + Vector3(0, y, 0))
	var widths := PackedFloat32Array([0.8, 1.0, 0.9, 0.75, 0.7, 0.9])
	for k in range(widths.size()):
		widths[k] *= DRIP.z * 0.5
	dried.append([Props.tube(drip, DRIP.z * 0.5, 8, true, widths), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(dried), paint))

	# The bail: from one ear, down round the front of the can and up to the other.
	var bail := PackedVector3Array()
	var hang := RADIUS + EAR.z + BAIL_WIRE
	for k in range(BAIL_STEPS + 1):
		var a := PI * float(k) / BAIL_STEPS
		bail.append(Vector3(cos(a) * hang, EAR_Y - sin(a) * BAIL_DROP, sin(a) * hang))
	var metal: Array = [[Props.tube(bail, BAIL_WIRE, 6), Transform3D.IDENTITY]]
	for side: float in [-1.0, 1.0]:
		metal.append(Props.part(EAR, Vector3(side * (RADIUS + EAR.z * 0.5), EAR_Y, 0), Basis(Vector3.UP, PI * 0.5)))
	root.add_child(Props.mi(Props.bake(metal), Mats.of("metal_brushed", TIN, 0.45)))
	var grip_at := Vector3(0, EAR_Y - BAIL_DROP, hang)
	root.add_child(Props.mi(Props.cyl(GRIP.x, GRIP.x, GRIP.y, 12), Mats.finish("plastic", GRIP_BLACK, 0.6), grip_at, Vector3(0, 0, 90)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]
