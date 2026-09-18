extends ItemGenerator
## A moulded plastic laundry basket standing on its floor: a tapered rectangle with rounded corners, open
## at the top, a solid band round its foot, a row of slots through every side, a hand hole through each
## end under a lip that flares out round the rim. One moulding, so one connected mesh: the wall is laid
## out flat round the basket as a grid, a cell is plastic or a hole, and every edge between the two is a
## face through the wall.
##
##     tint    Color    default WHITE

const TOP := Vector2(0.62, 0.44)
const BOTTOM := Vector2(0.55, 0.37)
const HEIGHT := 0.27
const CORNER := 0.06
const WALL := 0.006
const FLOOR := 0.012
## The slots run between these heights, at this pitch round the straight sides, and stay this far from a
## corner.
const SLOTS := Vector2(0.07, 0.19)
const SLOT_PITCH := 0.036
const SLOT_WIDTH := 0.016
const SLOT_MARGIN := 0.025
## A hand hole's width and its bottom and top under the rim.
const HANDLE_WIDTH := 0.11
const HANDLE := Vector2(0.065, 0.03)
## The lip stands this far out over this height at the rim, flaring out from this far below it.
const LIP := 0.006
const LIP_HEIGHT := 0.012
const LIP_FLARE := 0.008
const CORNER_STEPS := 4

const WHITE := Color(0.93, 0.93, 0.91)
const TINTS: Array[Color] = [WHITE, Color(0.46, 0.66, 0.82)]

## The eight runs round the rim, from the start of the +X side turning toward +Z: sides at even indices,
## corners at odd.
const RUNS := 8
const SIDE_NORMALS: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]

func build(def: ItemDef) -> Node3D:
	var columns := _columns()
	var rows := PackedFloat32Array([0.0, FLOOR, SLOTS.x, SLOTS.y, HEIGHT - HANDLE.x, HEIGHT - HANDLE.y,
			HEIGHT - LIP_HEIGHT - LIP_FLARE, HEIGHT - LIP_HEIGHT, HEIGHT])
	var count := columns.size()
	var levels := rows.size()
	# Every point of the grid once, outside and in, and whether each cell is plastic.
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	var normals := PackedVector3Array()
	var solid := PackedByteArray()
	var holes := _holes()
	for c in range(count):
		normals.append(_normal(columns[c]))
		var run := int(columns[c].x)
		var mid := (columns[c].y + _column_end(columns, c)) * 0.5
		for r in range(levels):
			outer.append(_outer(columns[c], rows[r]))
			inner.append(_inner(columns[c], rows[r]))
			if r == levels - 1:
				solid.append(1)
				continue
			var y := (rows[r] + rows[r + 1]) * 0.5
			var plastic := 1
			for hole: Vector4 in holes[run]:
				if mid > hole.x and mid < hole.y and y > hole.z and y < hole.w:
					plastic = 0
			solid.append(plastic)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in range(count):
		var n := (c + 1) % count
		var p := (c - 1 + count) % count
		for r in range(levels - 1):
			var at := c * levels + r
			if solid[at] == 0:
				continue
			var nx := n * levels + r
			Props._quad_normals(st, outer[at], outer[nx], outer[nx + 1], outer[at + 1], normals[c], normals[n], normals[n], normals[c])
			if rows[r] < FLOOR:
				continue
			Props._quad_normals(st, inner[at], inner[nx], inner[nx + 1], inner[at + 1], -normals[c], -normals[n], -normals[n], -normals[c])
			# A face through the wall wherever the next cell along or up is a hole, facing into it.
			if solid[nx] == 0:
				Props._quad(st, outer[nx], inner[nx], inner[nx + 1], outer[nx + 1], normals[n].cross(Vector3.UP))
			if solid[p * levels + r] == 0:
				Props._quad(st, outer[at], inner[at], inner[at + 1], outer[at + 1], -normals[c].cross(Vector3.UP))
			if r + 1 < levels - 1 and solid[at + 1] == 0:
				Props._quad(st, outer[at + 1], outer[nx + 1], inner[nx + 1], inner[at + 1], Vector3.UP)
			if r > 0 and solid[at - 1] == 0:
				Props._quad(st, outer[at], outer[nx], inner[nx], inner[at], Vector3.DOWN)
		var top := c * levels + levels - 1
		var top_next := n * levels + levels - 1
		Props._quad(st, outer[top], outer[top_next], inner[top_next], inner[top], Vector3.UP)
	# The floor: its underside across the outside of the foot, its top across the inside of the wall.
	for c in range(count):
		var n := (c + 1) % count
		Props._tri(st, Vector3.ZERO, outer[c * levels], outer[n * levels], Vector3.DOWN)
		Props._tri(st, Vector3(0, FLOOR, 0), inner[c * levels + 1], inner[n * levels + 1], Vector3.UP)
	var root := Node3D.new()
	root.add_child(Props.mi(Props.with_tangents(st.commit()), Mats.finish("plastic", Params.colour(def.params, "tint", WHITE), 0.5)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## Every column edge round the rim as (run, share along it), in order.
func _columns() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var holes := _holes()
	for run in range(RUNS):
		var cuts := PackedFloat32Array([0.0])
		if run % 2 == 1:
			for k in range(1, CORNER_STEPS):
				cuts.append(float(k) / CORNER_STEPS)
		else:
			for hole: Vector4 in holes[run]:
				cuts.append(hole.x)
				cuts.append(hole.y)
		cuts.sort()
		for f: float in cuts:
			if out.is_empty() or out[-1] != Vector2(run, f):
				out.append(Vector2(run, f))
	return out

func _column_end(columns: Array[Vector2], c: int) -> float:
	var next := columns[(c + 1) % columns.size()]
	return next.y if int(next.x) == int(columns[c].x) else 1.0

## Per run, its holes as (from share, to share, bottom, top): the slots along every side and a hand hole
## in the middle of each end.
func _holes() -> Array[Array]:
	var out: Array[Array] = []
	for run in range(RUNS):
		var holes: Array[Vector4] = []
		if run % 2 == 0:
			var length := _side_length(run, HEIGHT)
			var slots := floori((length - SLOT_MARGIN * 2.0 + SLOT_PITCH - SLOT_WIDTH) / SLOT_PITCH)
			var first := (length - (slots - 1) * SLOT_PITCH) * 0.5
			for k in range(slots):
				var mid := first + k * SLOT_PITCH
				holes.append(Vector4((mid - SLOT_WIDTH * 0.5) / length, (mid + SLOT_WIDTH * 0.5) / length, SLOTS.x, SLOTS.y))
			if run == 0 or run == 4:
				var half := HANDLE_WIDTH * 0.5 / length
				holes.append(Vector4(0.5 - half, 0.5 + half, HEIGHT - HANDLE.x, HEIGHT - HANDLE.y))
		out.append(holes)
	return out

func _half(y: float) -> Vector2:
	return BOTTOM.lerp(TOP, y / HEIGHT) * 0.5

func _side_length(run: int, y: float) -> float:
	var half := _half(y)
	return (half.y - CORNER) * 2.0 if run % 4 == 0 else (half.x - CORNER) * 2.0

## The outside of the wall at column `at`, height `y`, before the lip.
func _rim(at: Vector2, y: float) -> Vector3:
	var half := _half(y)
	var f := at.y
	var inner := Vector2(half.x - CORNER, half.y - CORNER)
	match int(at.x):
		0: return Vector3(half.x, y, lerpf(-inner.y, inner.y, f))
		2: return Vector3(lerpf(inner.x, -inner.x, f), y, half.y)
		4: return Vector3(-half.x, y, lerpf(inner.y, -inner.y, f))
		6: return Vector3(lerpf(-inner.x, inner.x, f), y, -half.y)
	var corner := int(at.x - 1.0) / 2
	var centre := Vector2(inner.x * (1.0 if corner == 0 or corner == 3 else -1.0), inner.y * (1.0 if corner < 2 else -1.0))
	return Vector3(centre.x, y, centre.y) + _normal(at) * CORNER

## Outward, level: the taper is too slight to light.
func _normal(at: Vector2) -> Vector3:
	var run := int(at.x)
	if run % 2 == 0:
		return SIDE_NORMALS[run / 2]
	var a := PI * 0.5 * (float(run - 1) * 0.5 + at.y)
	return Vector3(cos(a), 0, sin(a))

func _outer(at: Vector2, y: float) -> Vector3:
	var flare := clampf((y - (HEIGHT - LIP_HEIGHT - LIP_FLARE)) / LIP_FLARE, 0.0, 1.0)
	return _rim(at, y) + _normal(at) * LIP * flare

func _inner(at: Vector2, y: float) -> Vector3:
	return _rim(at, y) - _normal(at) * WALL
