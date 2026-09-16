extends FurnitureGenerator
## An armchair put away under a dust sheet: a sheet thrown over it that shows the chair only by what it
## lies on — the high back, the two arms, the seat sagging between them — and hangs from its edges to the
## floor in folds that flare where they meet it.
##
## The sheet is one closed shell of cloth: lofted from a ring at its crown out over the chair, round its
## edges, down the skirt to the hem and back up the inside. The chair under it is never built; it is the
## height the sheet lies at (`_support`), with the cloth pulled taut between its high points (`_tent`).
##
##     tint    Color    the sheet, default LINEN

## The hidden chair: width and depth, and its seat, arm and back heights.
const CHAIR := Vector2(0.86, 0.82)
const SEAT := 0.46
const ARM := 0.64
const ARM_WIDTH := 0.15
const BACK := 0.95
const BACK_DEPTH := 0.22
## How far the back's top falls away toward its ends.
const BACK_SHOULDER := 0.25
## Cloth between two supports falls no steeper than this, rise over run.
const TENT_SLOPE := 1.6
## The heightfield the cloth is laid over: its cell, and the margin round the chair it covers.
const CELL := 0.02
const MARGIN := 0.04
## The sheet's outline in plan, a superellipse this square, and the points round each ring.
const OUTLINE_POWER := 6.0
const POINTS := 96
## Rings from the crown to the edge of the top, round the edge, and down the skirt.
const TOP_RINGS := 14
const ROLL_RINGS := 3
const SKIRT_RINGS := 12
const ROLL := 0.03
## At the hem the skirt stands out this much more than at the top, in this many folds round it, this deep.
const FLARE := 0.07
const FOLDS := 15
const FOLD := 0.022
const THICK := 0.003
## How far the sheet stands out past the chair at the hem, at most.
const SKIRT_REACH := MARGIN * 0.5 + ROLL + FLARE + FOLD
## The chair stands this far off the wall, so its skirt hangs as freely at the back as anywhere.
const BACK_OFF := SKIRT_REACH + 0.006
const SEED := 9127

const LINEN := Color(0.86, 0.84, 0.78)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(CHAIR.x + SKIRT_REACH * 2.0, BACK_OFF + CHAIR.y + SKIRT_REACH))
	var field := _tent()
	var centre := Vector2(0.0, BACK_OFF + CHAIR.y * 0.5)
	var half := CHAIR * 0.5 + Vector2.ONE * MARGIN * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var phase := PackedFloat32Array()
	for j in range(POINTS):
		phase.append(rng.randf_range(-0.6, 0.6))
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for k in range(TOP_RINGS + ROLL_RINGS + SKIRT_RINGS + 1):
		var ring := PackedVector3Array()
		var under := PackedVector3Array()
		for j in range(POINTS):
			var theta := TAU * float(j) / float(POINTS)
			var dir := Vector2(cos(theta), sin(theta))
			var edge := centre + dir * Props.superellipse(theta, half, OUTLINE_POWER)
			var top := _sample(field, edge)
			var p := Vector3.ZERO
			var n := Vector3.UP
			if k <= TOP_RINGS:
				var r := lerpf(0.04, 1.0, float(k) / float(TOP_RINGS))
				var at := centre + (edge - centre) * r
				p = Vector3(at.x, _sample(field, at), at.y)
			elif k <= TOP_RINGS + ROLL_RINGS:
				var a := PI * 0.5 * float(k - TOP_RINGS) / float(ROLL_RINGS)
				var at := edge + dir * ROLL * sin(a)
				p = Vector3(at.x, top - ROLL * (1.0 - cos(a)), at.y)
				n = Vector3(dir.x * sin(a), cos(a), dir.y * sin(a))
			else:
				var t := float(k - TOP_RINGS - ROLL_RINGS) / float(SKIRT_RINGS)
				var fold := FOLD * pow(t, 1.5) * sin(FOLDS * theta + phase[j])
				var at := edge + dir * (ROLL + FLARE * t * t + fold)
				p = Vector3(at.x, (top - ROLL) * (1.0 - t), at.y)
				n = Vector3(dir.x, 0.0, dir.y)
			ring.append(p)
			var q := p - n * THICK
			q.y = maxf(q.y, 0.0)
			under.append(q)
		outer.append(ring)
		inner.append(under)
	# Down the inside from its crown, out across the hem and up the outside to its crown: one closed shell,
	# capped at both crowns. Rings turn +X to +Z, which faces out where they stack upward (`Props.loft`),
	# so it is the outside that climbs.
	var rings: Array = []
	for k in range(inner.size()):
		rings.append(inner[k])
	for k in range(outer.size() - 1, -1, -1):
		rings.append(outer[k])
	piece.add_child(Props.mi(Props.loft(rings), Mats.of("shade_linen", Params.colour(def.params, "tint", LINEN), 1.0)))
	piece.add_box(Vector3(CHAIR.x, BACK, CHAIR.y), Vector3(0, BACK * 0.5, BACK_OFF + CHAIR.y * 0.5))
	return piece

## The height of the chair's top at a plan point, in the piece's space: its seat, its arms, its back.
static func _support(point: Vector2) -> float:
	var at := point - Vector2(0.0, BACK_OFF)
	var hx := CHAIR.x * 0.5
	if absf(at.x) > hx or at.y < 0.0 or at.y > CHAIR.y:
		return 0.0
	var h := SEAT
	if absf(at.x) > hx - ARM_WIDTH:
		h = ARM
	if at.y < BACK_DEPTH:
		h = maxf(h, BACK - BACK_SHOULDER * pow(absf(at.x) / hx, 4.0))
	return h

## The heightfield the cloth lies at: every support, with the cloth falling off each at TENT_SLOPE and
## held up by whichever is highest. Two sweeps of a chamfer pass, which is a cone laid over each point.
static func _tent() -> Dictionary:
	var lo := Vector2(-CHAIR.x * 0.5 - MARGIN, BACK_OFF - MARGIN)
	var size := Vector2i(ceili((CHAIR.x + MARGIN * 2.0) / CELL) + 1, ceili((CHAIR.y + MARGIN * 2.0) / CELL) + 1)
	var h := PackedFloat32Array()
	h.resize(size.x * size.y)
	for iz in range(size.y):
		for ix in range(size.x):
			h[iz * size.x + ix] = _support(lo + Vector2(ix, iz) * CELL)
	var straight := TENT_SLOPE * CELL
	var diagonal := straight * sqrt(2.0)
	for sweep in range(2):
		var forward := sweep == 0
		for step in range(size.x * size.y):
			var i := step if forward else size.x * size.y - 1 - step
			var ix := i % size.x
			var iz := i / size.x
			var s := -1 if forward else 1
			var best := h[i]
			if ix + s >= 0 and ix + s < size.x:
				best = maxf(best, h[i + s] - straight)
			if iz + s >= 0 and iz + s < size.y:
				best = maxf(best, h[i + s * size.x] - straight)
				if ix + s >= 0 and ix + s < size.x:
					best = maxf(best, h[i + s * size.x + s] - diagonal)
				if ix - s >= 0 and ix - s < size.x:
					best = maxf(best, h[i + s * size.x - s] - diagonal)
			h[i] = best
	return {"lo": lo, "size": size, "h": h}

## The heightfield at a plan point, bilinear.
static func _sample(field: Dictionary, at: Vector2) -> float:
	var size: Vector2i = field["size"]
	var h: PackedFloat32Array = field["h"]
	var g := (at - (field["lo"] as Vector2)) / CELL
	var ix := clampi(floori(g.x), 0, size.x - 2)
	var iz := clampi(floori(g.y), 0, size.y - 2)
	var fx := clampf(g.x - ix, 0.0, 1.0)
	var fz := clampf(g.y - iz, 0.0, 1.0)
	var top := lerpf(h[iz * size.x + ix], h[iz * size.x + ix + 1], fx)
	var bottom := lerpf(h[(iz + 1) * size.x + ix], h[(iz + 1) * size.x + ix + 1], fx)
	return lerpf(top, bottom, fz)
