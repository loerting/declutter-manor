extends ItemGenerator
## A child's 20-inch bicycle standing upright, its front wheel to +Z and the origin on the floor under
## that wheel's axle, which is where a rack holds it: a steel frame of tubes, a fork, a riser bar with
## grips, a saddle on its post, cranks and pedals, a chainring with its chain to the rear hub, and two
## spoked wheels.
##
##     tint    Color    the frame, default RED

const WHEEL := 0.254
const TYRE := 0.022
const RIM := Vector2(0.212, 0.007)
const HUB := Vector2(0.018, 0.07)
const SPOKES := 16
const WHEEL_SEGMENTS := 40
const SPOKE_RADIUS := 0.0012
const WHEELBASE := 0.82

## Frame points in (z, y), from the front axle.
const BOTTOM_BRACKET := Vector2(-0.5, 0.27)
const SEAT_TOP := Vector2(-0.6, 0.6)
const HEAD_LOW := Vector2(-0.1, 0.56)
const HEAD_HIGH := Vector2(-0.13, 0.67)
const TUBE := 0.016
const STAY := 0.009
const STAY_SPREAD := 0.05
const FORK_SPREAD := 0.048

const BAR_HALF := 0.25
const BAR_Y := 0.78
const GRIP := Vector2(0.018, 0.1)
const POST := Vector2(0.012, 0.12)
const SADDLE := Vector3(0.075, 0.045, 0.13)
const CRANK := 0.13
const PEDAL := Vector3(0.09, 0.022, 0.06)
const CHAINRING := Vector2(0.075, 0.004)
const COG := 0.03
const CHAIN_RADIUS := 0.0035
const CHAIN_X := 0.045

const RED := Color(0.75, 0.1, 0.1)
const BLUE := Color(0.12, 0.3, 0.7)
const VARIANTS: Array[Color] = [RED, BLUE]
const BLACK := Color(0.04, 0.04, 0.045)
const CHROME := Color(0.8, 0.81, 0.83)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var paint := Props.mat(Params.colour(def.params, "tint", RED), 0.3, 0.4)
	var rubber := Mats.of("rubber", BLACK, 0.8)
	var chrome := Mats.of("metal_brushed", CHROME, 0.25)
	var black := Props.mat(BLACK, 0.5)
	var front := Vector3(0, WHEEL, 0)
	var rear := Vector3(0, WHEEL, -WHEELBASE)

	var tyres: Array = []
	var metal: Array = []
	# A tyre and a rim are rings turned from a small section, round the wheel's axle.
	var tyre := Props.lathe(_ring_section(WHEEL - TYRE, TYRE, 8), WHEEL_SEGMENTS, true)
	var rim := Props.lathe(_ring_section(RIM.x, RIM.y, 4), WHEEL_SEGMENTS, true)
	var hub := Props.cyl(HUB.x, HUB.x, HUB.y, 12)
	var spoke_length := Vector2(HUB.y * 0.4, RIM.x).length()
	var spoke := Props.cyl(SPOKE_RADIUS, SPOKE_RADIUS, spoke_length, 4)
	for axle: Vector3 in [front, rear]:
		var turn := Transform3D(Basis(Vector3.BACK, PI * 0.5), axle)
		tyres.append([tyre, turn])
		metal.append([rim, turn])
		metal.append([hub, turn])
		for i in range(SPOKES):
			var a := TAU * float(i) / float(SPOKES)
			var side := HUB.y * 0.4 * (1.0 if i % 2 == 0 else -1.0)
			var from := axle + Vector3(side, 0, 0)
			var to := axle + Vector3(0, sin(a) * RIM.x, cos(a) * RIM.x)
			metal.append([spoke, Transform3D(Props.aim_y(to - from), (from + to) * 0.5)])
	root.add_child(Props.mi(Props.bake(tyres), rubber))

	var frame: Array = []
	var bb := _at(BOTTOM_BRACKET)
	var seat := _at(SEAT_TOP)
	var head_low := _at(HEAD_LOW)
	var head_high := _at(HEAD_HIGH)
	frame.append(_tube([bb, head_low], TUBE))
	frame.append(_tube([seat - (seat - bb) * 0.08, head_high + (head_low - head_high) * 0.35], TUBE))
	frame.append(_tube([bb, seat], TUBE))
	frame.append(_tube([head_low + (head_low - head_high) * 0.1, head_high - (head_low - head_high) * 0.3], TUBE * 1.3))
	for sx: float in [-1.0, 1.0]:
		var dropout := rear + Vector3(sx * STAY_SPREAD, 0, 0)
		frame.append(_tube([bb + Vector3(sx * 0.02, 0, 0), dropout], STAY))
		frame.append(_tube([seat + Vector3(sx * 0.015, -0.03, 0), dropout], STAY))
		# Fork blades, raked forward to the axle.
		var crown := head_low + Vector3(sx * FORK_SPREAD * 0.6, -0.02, 0)
		frame.append([Props.tube(Props.smooth_path(PackedVector3Array([crown, crown.lerp(front, 0.5) + Vector3(sx * 0.01, 0, 0.02),
				front + Vector3(sx * FORK_SPREAD, 0, 0)]), 5), STAY * 1.2, 8), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(frame), paint))

	# The bar: a stem up out of the head tube, a riser bar across, and its ends swept back.
	var stem_top := head_high + (head_high - head_low).normalized() * 0.06
	metal.append(_tube([head_high, stem_top], 0.012))
	var bar := PackedVector3Array()
	for i in range(11):
		var t := lerpf(-1.0, 1.0, float(i) / 10.0)
		bar.append(Vector3(t * BAR_HALF, BAR_Y + 0.03 * t * t, stem_top.z - 0.05 * t * t))
	metal.append([Props.tube(bar, 0.01, 10), Transform3D.IDENTITY])
	metal.append(_tube([stem_top, Vector3(0, BAR_Y, stem_top.z)], 0.011))
	metal.append(_tube([seat, seat + (seat - bb).normalized() * POST.y], POST.x))
	# Cranks and the spindle, the chainring on the right.
	var crank_dir := Vector3(0, 0.5, 0.866)
	for sx: float in [-1.0, 1.0]:
		var end := bb + Vector3(sx * 0.07, 0, 0) + crank_dir * CRANK * sx
		metal.append(_tube([bb + Vector3(sx * 0.07, 0, 0), end], 0.008))
		metal.append([Props.box(PEDAL), Transform3D(Basis.IDENTITY, end + Vector3(sx * PEDAL.x * 0.5, 0, 0))])
	metal.append([Props.cyl(0.01, 0.01, 0.16, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), bb)])
	metal.append([Props.torus(CHAINRING.y, CHAINRING.x), Transform3D(Basis(Vector3.BACK, PI * 0.5), bb + Vector3(CHAIN_X, 0, 0))])
	root.add_child(Props.mi(Props.bake(metal), chrome))

	var dark: Array = []
	var chain := PackedVector3Array()
	var ring_c := Vector2(bb.z, bb.y)
	var cog_c := Vector2(rear.z, rear.y)
	for i in range(25):
		var a := PI * 0.5 + PI * float(i) / 24.0
		chain.append(Vector3(CHAIN_X, cog_c.y + sin(a) * COG, cog_c.x + cos(a) * COG))
	for i in range(25):
		var a := -PI * 0.5 + PI * float(i) / 24.0
		chain.append(Vector3(CHAIN_X, ring_c.y + sin(a) * CHAINRING.x, ring_c.x + cos(a) * CHAINRING.x))
	chain.append(chain[0])
	dark.append([Props.tube(chain, CHAIN_RADIUS, 6, false), Transform3D.IDENTITY])
	for sx: float in [-1.0, 1.0]:
		dark.append([Props.cyl(GRIP.x, GRIP.x, GRIP.y, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5),
				bar[10 if sx > 0.0 else 0] - Vector3(sx * GRIP.y * 0.4, 0, 0))])
	var saddle_at := seat + (seat - bb).normalized() * POST.y
	var half := Vector2(SADDLE.x, SADDLE.z)
	var outline := func(theta: float) -> float:
		return Props.superellipse(theta, half, 2.4) * (1.0 - 0.45 * maxf(0.0, sin(theta)) * pow(cos(theta), 2.0))
	var under := func(_p: Vector2) -> float: return 0.0
	var over := func(p: Vector2) -> float: return SADDLE.y * (1.0 - 0.3 * pow(p.y / SADDLE.z, 2.0))
	dark.append([Props.moulded(outline, under, over, 3.0, half, 48, 8), Transform3D(Basis.IDENTITY, saddle_at - Vector3(0, 0.005, 0.02))])
	root.add_child(Props.mi(Props.bake(dark), black))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": VARIANTS[index % VARIANTS.size()]}

## Put down anywhere but its rack, it lies on its left side.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)

## A round section of `radius` whose middle is `from_axis` out from the axle, counter-clockwise in
## (radius, height) as a closed lathe needs it.
static func _ring_section(from_axis: float, radius: float, points: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points):
		var a := -PI * 0.5 + TAU * float(i) / float(points)
		out.append(Vector2(from_axis + cos(a) * radius, sin(a) * radius))
	return out

static func _at(zy: Vector2) -> Vector3:
	return Vector3(0, zy.y, zy.x)

static func _tube(points: Array, radius: float) -> Array:
	return [Props.tube(PackedVector3Array(points), radius, 10), Transform3D.IDENTITY]
