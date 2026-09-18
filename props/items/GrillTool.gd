extends ItemGenerator
## One barbecue tool from a matched set, lying flat with its length along Z and the end it hangs from at +Z:
## stainless steel with black handles.
##
##     kind    String    "tongs", "spatula" or "brush", default "tongs"
##
## Tongs are one strip of steel bent double, the spring bend at +Z with a ring through it. The spatula's
## blade is cut from its outline with two slots in it, and a polygon with holes is not one polygon: it is cut
## along each slot into strips with a notch, which share their edges along the cuts. The spatula and the
## brush hang from a cord loop out of the handle's end.

const LENGTH := 0.43
## Tongs: the strip's height and thickness, the arms' half spread at the tips and at the bend, the grips,
## and the ring's radius, wire and tilt (it lies through the bend with its far side on the ground).
const STRIP := Vector2(0.011, 0.0007)
const SPREAD := Vector2(0.034, 0.007)
const BEND_STEPS := 8
const TIP_CURL := 0.006
const TONG_GRIP := Vector3(0.009, 0.024, 0.14)
const TONG_GRIP_FROM := 0.035
const RING := Vector2(0.012, 0.0016)
const RING_TILT_DEG := 25.0
## Spatula: the blade, its two slots, the neck that rises to the handle.
const BLADE := Vector3(0.1, 0.0018, 0.13)
const BLADE_CORNER := 0.012
const CORNER_STEPS := 4
const SLOT := Vector2(0.008, 0.075)
const SLOT_X := 0.02
const NECK := Vector3(0.018, 0.0022, 0.07)
const NECK_RISE := 0.02
const NECK_STEPS := 6
## The spatula's and the brush's handle section.
const HANDLE := Vector2(0.026, 0.017)
const HANDLE_EASE := 0.006
## The handle starts this far back along the neck or shaft, over its end.
const HANDLE_OVERLAP := 0.012
## Brush: the head block, the bristle tufts under it, the scraper plate at its tip, and the shaft.
const HEAD := Vector3(0.05, 0.022, 0.13)
const TUFT := Vector2(0.0045, 0.024)
const TUFT_FLARE := 1.35
const TUFT_GRID := Vector2i(3, 7)
const SCRAPER := Vector3(0.05, 0.03, 0.0015)
const SHAFT := 0.007
const SHAFT_RUN := Vector2(0.012, 0.07)
## The cord loop: its radius, its thickness, and how far into the handle its ends are buried.
const LOOP := Vector2(0.016, 0.0022)
const LOOP_BURY := 0.008
const LOOP_STEPS := 12

const STEEL := Color(0.82, 0.82, 0.83)
const NYLON := Color(0.07, 0.07, 0.07)
const BRASS := Color(0.78, 0.6, 0.3)
const CORD := Color(0.12, 0.12, 0.12)
const KINDS: Array[String] = ["tongs", "spatula", "brush"]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	match Params.text(def.params, "kind", "tongs"):
		"spatula":
			_spatula(root)
		"brush":
			_brush(root)
		_:
			_tongs(root)
	return root

func variant(index: int) -> Dictionary:
	return {"kind": KINDS[index % KINDS.size()]}

static func _steel() -> Material:
	return Mats.finish("metal_brushed", STEEL, 0.3)

static func _grip() -> Material:
	return Mats.finish("plastic", NYLON, 0.55)

static func _tongs(root: Node3D) -> void:
	var tip_z := -LENGTH * 0.5
	var bend_z := LENGTH * 0.5 - SPREAD.y - RING.x * 2.0 * cos(deg_to_rad(RING_TILT_DEG))
	var y := TONG_GRIP.y * 0.5
	var mid_z := lerpf(tip_z, bend_z, 0.5)
	# One strip: up one arm from its tip, round the spring bend and back down the other.
	var path := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var arm := PackedVector3Array([Vector3(side * (SPREAD.x - TIP_CURL), y, tip_z), Vector3(side * SPREAD.x, y, tip_z + 0.03),
				Vector3(side * lerpf(SPREAD.x, SPREAD.y, 0.5), y, mid_z), Vector3(side * SPREAD.y, y, bend_z)])
		if side > 0.0:
			arm.reverse()
		path.append_array(Props.smooth_path(arm, 4))
		if side < 0.0:
			for k in range(1, BEND_STEPS):
				var a := PI * (1.0 - float(k) / float(BEND_STEPS))
				path.append(Vector3(cos(a) * SPREAD.y, y, bend_z + sin(a) * SPREAD.y))
	var half := PackedVector2Array()
	for i in range(path.size()):
		half.append(Vector2(STRIP.x * 0.5, STRIP.y * 0.5))
	root.add_child(Props.mi(Props.sweep_bar(path, Vector3.UP, half, STRIP.y * 0.4, 1), _steel()))
	# Black grips on both arms, along their line toward the bend.
	var grips: Array = []
	for side: float in [-1.0, 1.0]:
		var from := Vector3(side * lerpf(SPREAD.x, SPREAD.y, 0.5), y, mid_z)
		var to := Vector3(side * SPREAD.y, y, bend_z)
		var dir := (to - from).normalized()
		grips.append([Props.rounded_box(TONG_GRIP, 0.004, 3, 12),
				Transform3D(Basis.looking_at(-dir, Vector3.UP), to - dir * (TONG_GRIP_FROM + TONG_GRIP.z * 0.5))])
	root.add_child(Props.mi(Props.bake(grips), _grip()))
	# The ring passes through the bend at its apex and lies tilted, its far side on the ground.
	var tilt := deg_to_rad(RING_TILT_DEG)
	var centre := Vector3(0, RING.x * sin(tilt) + RING.y, bend_z + SPREAD.y + RING.x * cos(tilt))
	root.add_child(Props.mi(Props.torus(RING.y, RING.x), _steel(), centre, Vector3(RING_TILT_DEG, 0, 0)))

static func _spatula(root: Node3D) -> void:
	var tip_z := -LENGTH * 0.5
	var blade_back := tip_z + BLADE.z
	var w := BLADE.x * 0.5
	# The blade's outline in (x, z): the back edge, then round the front corners.
	var outline := PackedVector2Array([Vector2(w, blade_back), Vector2(-w, blade_back)])
	for corner: Vector2 in [Vector2(-w + BLADE_CORNER, tip_z + BLADE_CORNER), Vector2(w - BLADE_CORNER, tip_z + BLADE_CORNER)]:
		var from := PI if corner.x < 0.0 else PI * 1.5
		for k in range(CORNER_STEPS + 1):
			var a := from + PI * 0.5 * float(k) / float(CORNER_STEPS)
			outline.append(corner + Vector2(cos(a), sin(a)) * BLADE_CORNER)
	var slot_mid := tip_z + BLADE.z * 0.5
	var slots: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var x := side * SLOT_X
		slots.append(PackedVector2Array([Vector2(x - SLOT.x * 0.5, slot_mid - SLOT.y * 0.5), Vector2(x + SLOT.x * 0.5, slot_mid - SLOT.y * 0.5),
				Vector2(x + SLOT.x * 0.5, slot_mid + SLOT.y * 0.5), Vector2(x - SLOT.x * 0.5, slot_mid + SLOT.y * 0.5)]))
	# Cut along both slots' middles: three strips, the outer two notched on one side, the middle on both.
	var cuts: Array[float] = [-BLADE.x, -SLOT_X, SLOT_X, BLADE.x]
	var parts: Array = []
	for i in range(cuts.size() - 1):
		var strip := PackedVector2Array([Vector2(cuts[i], tip_z - BLADE.z), Vector2(cuts[i + 1], tip_z - BLADE.z),
				Vector2(cuts[i + 1], blade_back + BLADE.z), Vector2(cuts[i], blade_back + BLADE.z)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(outline, strip):
			var pieces: Array[PackedVector2Array] = [piece]
			for slot: PackedVector2Array in slots:
				var next: Array[PackedVector2Array] = []
				for p: PackedVector2Array in pieces:
					next.append_array(Geometry2D.clip_polygons(p, slot))
				pieces = next
			for p: PackedVector2Array in pieces:
				parts.append([Props.extrude(p, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, BLADE.y), Transform3D.IDENTITY])
	# The neck: a strap from inside the blade's back edge rising to the handle.
	var neck := PackedVector3Array()
	var neck_half := PackedVector2Array()
	for k in range(NECK_STEPS + 1):
		var t := float(k) / float(NECK_STEPS)
		neck.append(Vector3(0, BLADE.y * 0.5 + NECK_RISE * smoothstep(0.0, 1.0, t), blade_back - BLADE_CORNER * 0.5 + NECK.z * t))
		neck_half.append(Vector2(NECK.x * 0.5, NECK.y * 0.5))
	parts.append([Props.sweep_bar(neck, Vector3.RIGHT, neck_half, NECK.y * 0.4, 1), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(parts), _steel()))
	_handle(root, Vector3(0, BLADE.y * 0.5 + NECK_RISE, neck[NECK_STEPS].z - HANDLE_OVERLAP))

static func _brush(root: Node3D) -> void:
	var tip_z := -LENGTH * 0.5
	var head_y := TUFT.y + HEAD.y * 0.5
	root.add_child(Props.mi(Props.rounded_box(HEAD, 0.005, 3, 12), _grip(), Vector3(0, head_y, tip_z + HEAD.z * 0.5)))
	var tufts: Array = []
	var tuft_h := TUFT.y + 0.004
	for i in range(TUFT_GRID.x):
		for j in range(TUFT_GRID.y):
			var x := (float(i) - float(TUFT_GRID.x - 1) * 0.5) * HEAD.x * 0.3
			var z := tip_z + HEAD.z * (float(j) + 0.8) / (float(TUFT_GRID.y) + 0.6)
			tufts.append([Props.cyl(TUFT.x, TUFT.x * TUFT_FLARE, tuft_h, 8), Transform3D(Basis.IDENTITY, Vector3(x, tuft_h * 0.5, z))])
	root.add_child(Props.mi(Props.bake(tufts), Props.mat(BRASS, 0.5, 0.7)))
	var metal: Array = [Props.part(SCRAPER, Vector3(0, head_y, tip_z - SCRAPER.z * 0.5))]
	# The shaft rises out of the head's back end to the handle.
	var shaft_from := Vector3(0, head_y, tip_z + HEAD.z - SHAFT_RUN.x)
	var shaft_to := Vector3(0, head_y + SHAFT_RUN.x, tip_z + HEAD.z + SHAFT_RUN.y)
	metal.append([Props.tube(PackedVector3Array([shaft_from, shaft_to]), SHAFT, 10), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(metal), _steel()))
	_handle(root, Vector3(0, shaft_to.y, shaft_to.z - HANDLE_OVERLAP))

## A black handle from `from` back to the tool's end, with the cord loop out of its end.
static func _handle(root: Node3D, from: Vector3) -> void:
	var end_z := LENGTH * 0.5 - LOOP.x * 2.0
	var length := end_z - from.z
	root.add_child(Props.mi(Props.rounded_box(Vector3(HANDLE.x, HANDLE.y, length), HANDLE_EASE, 4, 16), _grip(),
			Vector3(0, from.y, from.z + length * 0.5)))
	# Out of the end face, down to the ground and round, and back in: its two ends are buried in the handle.
	var at := Vector3(0, from.y, end_z)
	var centre := Vector3(0, LOOP.y, end_z + LOOP.x)
	var path := PackedVector3Array([Vector3(-HANDLE.x * 0.15, at.y, at.z - LOOP_BURY)])
	for k in range(LOOP_STEPS + 1):
		var t := float(k) / float(LOOP_STEPS)
		var a := lerpf(0.35, TAU - 0.35, t)
		var drop := clampf(minf(t, 1.0 - t) * 3.0, 0.0, 1.0)
		path.append(Vector3(-sin(a) * LOOP.x, lerpf(at.y, centre.y, drop), centre.z - cos(a) * LOOP.x))
	path.append(Vector3(HANDLE.x * 0.15, at.y, at.z - LOOP_BURY))
	root.add_child(Props.mi(Props.tube(Props.smooth_path(path, 3), LOOP.y, 8), Props.mat(CORD, 0.8)))
