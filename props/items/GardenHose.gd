extends ItemGenerator
## Fifteen metres of garden hose coiled flat, one tube from end to end: the coupling end comes in from outside,
## five loops spiral in along the ground, half a loop climbs onto them on the inside, five loops spiral back out
## on top, and the free end runs off the top toward +Z and down to a spray nozzle. Both brass fittings lie on
## the ground.
##
## No parameters.
##
## Hung on the hose reel (`HoseReel.COIL_HANG`), the +Z side points down and the -Z side is the top.

const TUBE := 0.011
## The innermost loop's radius, one loop's radial step (the tube's width and a hair, so loops lie side by
## side without touching), and the loops in each layer.
const INNER := 0.16
const STEP := TUBE * 2.0 + 0.0015
const LOOPS := 5
const POINTS_PER_LOOP := 36
const SEGMENTS := 10
## The fittings are fatter than the hose, so the hose rises to meet them and they lie on the ground.
const FITTING := 0.019
const TAIL_POINTS := 8
## Where the coupling's tail starts, outside the coil, from where the first loop starts.
const COUPLING_AT := Vector2(0.04, -0.14)
## The free end after the last top loop, which ends over the +Z side going toward -X: (x, share of the way
## down from the top loops to the ground, z).
const NOZZLE_RUN: Array[Vector3] = [Vector3(-0.07, 0.0, 0.265), Vector3(-0.13, 0.15, 0.3), Vector3(-0.18, 0.7, 0.35),
		Vector3(-0.21, 1.0, 0.4)]

const GREEN := Color(0.2, 0.52, 0.22)
const BRASS := Color(0.78, 0.62, 0.32)

func build(_def: ItemDef) -> Node3D:
	var outer := INNER + STEP * float(LOOPS)
	var path := PackedVector3Array()
	# The coupling's tail, from outside the coil in to where the first loop starts, at angle 0 (+X).
	for k in range(TAIL_POINTS):
		var t := float(k) / float(TAIL_POINTS)
		path.append(Vector3(outer + COUPLING_AT.x * (1.0 - t) * (1.0 - t), lerpf(FITTING, TUBE, smoothstep(0.0, 0.6, t)),
				COUPLING_AT.y * (1.0 - t)))
	# In along the ground, a step per loop.
	for i in range(LOOPS * POINTS_PER_LOOP):
		var t := float(i) / float(POINTS_PER_LOOP)
		path.append(_on_loop(TAU * t, outer - STEP * t, TUBE))
	# Up onto the loops over half a loop, drawing in half a step so it stays a step inside the loop under it.
	# That puts the top loops half a step off the ones below, in the grooves between them.
	var half := POINTS_PER_LOOP / 2
	var turn := TAU * float(LOOPS)
	for i in range(half):
		var t := float(i) / float(half)
		path.append(_on_loop(turn + PI * t, INNER - STEP * t * 0.5, TUBE * (1.0 + 2.0 * smoothstep(0.0, 1.0, t))))
	# Back out on top, a step per loop, ending a quarter short at the +Z side.
	var top := TUBE * 3.0
	var top_loops := float(LOOPS) - 0.25
	var steps := int(top_loops * float(POINTS_PER_LOOP))
	for i in range(steps + 1):
		var t := top_loops * float(i) / float(steps)
		path.append(_on_loop(turn + PI + TAU * t, INNER - STEP * 0.5 + STEP * t, top))
	# The free end carries on round the way the loop was going, turns out from the coil and drops to the ground
	# once it is clear of the outside loop.
	for p: Vector3 in NOZZLE_RUN:
		path.append(Vector3(p.x, lerpf(top, FITTING, p.y), p.z))
	var smooth := Props.smooth_path(path, 2)
	var root := Node3D.new()
	root.add_child(Props.mi(Props.tube(smooth, TUBE, SEGMENTS), Mats.finish("plastic", GREEN, 0.5)))

	var brass := Mats.finish("metal_polished", BRASS, 0.3)
	var n := smooth.size()
	var tip := smooth[n - 1]
	var nozzle := Node3D.new()
	nozzle.transform = Transform3D(Props.aim_y(tip - smooth[n - 3]), tip)
	nozzle.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(0.0125, -0.012), Vector2(0.016, 0.0), Vector2(0.016, 0.03),
			Vector2(0.012, 0.036), Vector2(0.0105, 0.09), Vector2(0.007, 0.096), Vector2(0.0, 0.096)]), 20), brass))
	nozzle.add_child(Props.mi(Props.cyl(0.0185, 0.0185, 0.012, 6), brass, Vector3(0, 0.018, 0)))
	root.add_child(nozzle)
	var coupling := Node3D.new()
	coupling.transform = Transform3D(Props.aim_y(smooth[0] - smooth[2]), smooth[0])
	coupling.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(0.0125, -0.01), Vector2(0.016, 0.0), Vector2(0.016, 0.012),
			Vector2(FITTING, 0.014), Vector2(FITTING, 0.03), Vector2(0.0, 0.03)]), 20), brass))
	root.add_child(coupling)
	return root

static func _on_loop(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)
