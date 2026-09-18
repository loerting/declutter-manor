extends FurnitureGenerator
## A garage workbench against the wall: a butcher-block top on a pine frame with a plywood shelf low down,
## a bench vise on its front right corner, and a pegboard on furring strips on the wall above it with a
## screwdriver rack and a row of hooks for wrenches. It carries no tool that is not an item: a hammer on the pegboard
## looked like one the player could pick up (the author, 2026-09-17).
##
## No parameters.
##
## Anchors:
##
##     top             the middle of the top
##     vise            between the vise's jaws
##     screwdrivers    over the rack's left-most hole, a handle's length above it
##     wrenches        on the left-most wrench hook, where a ring end hangs from it

const WIDTH := 1.8
const DEPTH := 0.6
const HEIGHT := 0.9
const TOP := 0.045
const TOP_EASE := 0.003
const LEG := 0.07
## The legs stand in from the ends and from the front and back by these.
const LEG_IN := Vector2(0.06, 0.03)
const RAIL := Vector2(0.09, 0.035)
const SHELF_Y := 0.2
const PLY := 0.018

## A 4 x 2 foot sheet of 3/16" hardboard at one-inch hole pitch, standing off the wall on two strips.
const PEGBOARD := Vector2(1.22, 0.61)
const PEG_THICK := 0.0048
const PEG_PITCH := 0.0254
const PEG_HOLE := 0.0032
const PEG_Y := 1.05
const STANDOFF := 0.019
const STRIP := 0.04

## The vise: the fixed jaw's face this far in from the bench's front edge, the opening between the jaws,
## and the body, jaw and bar sizes. It stands this far in from the bench's right end.
const VISE_X := 0.28
const VISE_SET_BACK := 0.01
const VISE_GAP := 0.05
const VISE_BODY := Vector3(0.12, 0.07, 0.2)
const VISE_JAW := Vector3(0.14, 0.065, 0.04)
const VISE_PLATE := Vector3(0.12, 0.04, 0.006)
const VISE_MOVING := Vector3(0.14, 0.1, 0.045)
const VISE_BAR := Vector2(0.034, 0.028)
const VISE_SCREW := Vector2(0.009, 0.035)
const VISE_HANDLE := Vector2(0.006, 0.2)
const VISE_KNOB := 0.011

## The screwdriver rack: its centre along the board, height, reach out from the board, hole spacing,
## the holes' radius and the plate's thickness. Six holes.
const RACK_X := -0.36
const RACK_Y := 1.42
const RACK_REACH := 0.06
const RACK_PITCH := 0.045
const RACK_HOLE := 0.0068
const RACK_PLATE := 0.006
const RACK_HOLES := 6
## A screwdriver's handle, which is what stands above the rack (`Screwdriver.HANDLE_LENGTH`).
const HANDLE_LENGTH := 0.1
## Wrench hooks: the first one's hole column and row on the board, holes between hooks, the wire, its
## reach out of the board and the rise of its tip. Four hooks.
const HOOK_COLUMN := 30
const HOOK_ROW := 12
const HOOK_EVERY := 3
const HOOKS := 4
const HOOK_WIRE := 0.0024
const HOOK_REACH := 0.05
const HOOK_TIP := 0.016
## Where a wrench's ring meets the hook: a 13 mm ring's wall over the hook's top, out along its arm.
const RING_WALL := 0.0057
const HANG_OUT := 0.034

const BUTCHER := Color(0.95, 0.8, 0.62)
const PINE := Color(1.0, 0.92, 0.76)
const HARDBOARD := Color(0.6, 0.45, 0.3)
const VISE_BLUE := Color(0.18, 0.3, 0.44)
const STEEL := Color(0.72, 0.73, 0.75)
const BLACK := Color(0.06, 0.06, 0.065)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var jaw_face := DEPTH - VISE_SET_BACK
	var reach := jaw_face + VISE_GAP + VISE_MOVING.z + VISE_SCREW.y + VISE_HANDLE.x
	piece.initialize(def, Vector2(WIDTH, reach))
	var cz := DEPTH * 0.5
	var pine := Mats.of("oak", PINE, 0.7, 1.4)
	piece.add_child(Props.mi(Props.rounded_box(Vector3(WIDTH, TOP, DEPTH), TOP_EASE, 4, 16), Mats.of("oak", BUTCHER, 0.8, 0.6),
			Vector3(0, HEIGHT - TOP * 0.5, cz)))
	piece.add_box(Vector3(WIDTH, TOP, DEPTH), Vector3(0, HEIGHT - TOP * 0.5, cz))
	var frame: Array = []
	var under := HEIGHT - TOP
	var leg_x := WIDTH * 0.5 - LEG_IN.x - LEG * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * leg_x, under * 0.5, cz + sz * (cz - LEG_IN.y - LEG * 0.5))
			frame.append(Props.part(Vector3(LEG, under, LEG), at))
			piece.add_box(Vector3(LEG, under, LEG), at)
	var span := WIDTH - (LEG_IN.x + LEG) * 2.0
	var side_span := DEPTH - (LEG_IN.y + LEG) * 2.0
	for y: float in [under - RAIL.x * 0.5, SHELF_Y - PLY - RAIL.x * 0.5]:
		for sz: float in [-1.0, 1.0]:
			frame.append(Props.part(Vector3(span, RAIL.x, RAIL.y), Vector3(0, y, cz + sz * (cz - LEG_IN.y - RAIL.y * 0.5))))
		for sx: float in [-1.0, 1.0]:
			frame.append(Props.part(Vector3(RAIL.y, RAIL.x, side_span), Vector3(sx * (leg_x + LEG * 0.5 - RAIL.y * 0.5), y, cz)))
	var shelf := Vector3(span, PLY, DEPTH - LEG_IN.y * 2.0)
	frame.append(Props.part(shelf, Vector3(0, SHELF_Y - PLY * 0.5, cz)))
	piece.add_box(shelf, Vector3(0, SHELF_Y - PLY * 0.5, cz))
	for y: float in [PEG_Y + STRIP * 0.5, PEG_Y + PEGBOARD.y - STRIP * 0.5]:
		frame.append(Props.part(Vector3(PEGBOARD.x, STRIP, STANDOFF), Vector3(0, y, STANDOFF * 0.5)))
	piece.add_child(Props.mi(Props.bake(frame), pine))

	piece.add_child(Props.mi(_pegboard(), Props.mat(HARDBOARD, 0.8), Vector3(0, PEG_Y, STANDOFF)))
	piece.add_box(Vector3(PEGBOARD.x, PEGBOARD.y, PEG_THICK), Vector3(0, PEG_Y + PEGBOARD.y * 0.5, STANDOFF + PEG_THICK * 0.5))
	var board_front := STANDOFF + PEG_THICK
	_vise(piece, jaw_face)
	_rack(piece, board_front)
	_hooks(piece, board_front)
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, cz)), piece)
	return piece

func _vise(piece: FurnitureNode, jaw_face: float) -> void:
	var x := WIDTH * 0.5 - VISE_X
	var body: Array = [
		Props.part(VISE_BODY, Vector3(x, HEIGHT + VISE_BODY.y * 0.5, jaw_face - VISE_BODY.z * 0.5)),
		Props.part(VISE_JAW, Vector3(x, HEIGHT + VISE_BODY.y + VISE_JAW.y * 0.5 - 0.01, jaw_face - VISE_JAW.z * 0.5)),
		Props.part(VISE_MOVING, Vector3(x, HEIGHT + VISE_BODY.y + VISE_JAW.y - 0.01 - VISE_MOVING.y * 0.5,
				jaw_face + VISE_GAP + VISE_MOVING.z * 0.5)),
	]
	piece.add_child(Props.mi(Props.bake(body), Props.mat(VISE_BLUE, 0.5, 0.2)))
	var jaw_y := HEIGHT + VISE_BODY.y + VISE_JAW.y - 0.01 - VISE_PLATE.y * 0.5 - 0.004
	var bar_y := HEIGHT + VISE_BAR.y * 0.5 + 0.012
	var screw_z := jaw_face + VISE_GAP + VISE_MOVING.z
	var screw_y := HEIGHT + VISE_BODY.y * 0.5 + 0.01
	var handle_z := screw_z + VISE_SCREW.y - VISE_HANDLE.x
	var steel: Array = [
		Props.part(VISE_PLATE, Vector3(x, jaw_y, jaw_face + VISE_PLATE.z * 0.5)),
		Props.part(VISE_PLATE, Vector3(x, jaw_y, jaw_face + VISE_GAP - VISE_PLATE.z * 0.5)),
		Props.part(Vector3(VISE_BAR.x, VISE_BAR.y, VISE_GAP + 0.02), Vector3(x, bar_y, jaw_face + VISE_GAP * 0.5)),
		[Props.cyl(VISE_SCREW.x, VISE_SCREW.x, VISE_SCREW.y, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(x, screw_y, screw_z + VISE_SCREW.y * 0.5))],
		[Props.cyl(VISE_HANDLE.x, VISE_HANDLE.x, VISE_HANDLE.y, 12), Transform3D(Basis.IDENTITY,
				Vector3(x, screw_y - VISE_HANDLE.y * 0.3, handle_z))],
	]
	for end: float in [-1.0, 1.0]:
		var y := screw_y - VISE_HANDLE.y * 0.3 + end * VISE_HANDLE.y * 0.5
		steel.append([Props.ellipsoid(Vector3.ONE * VISE_KNOB, 6, 12), Transform3D(Basis.IDENTITY, Vector3(x, y, handle_z))])
	piece.add_child(Props.mi(Props.bake(steel), Mats.of("metal_brushed", STEEL, 0.4)))
	piece.add_box(Vector3(VISE_JAW.x, VISE_BODY.y + VISE_JAW.y, VISE_BODY.z), Vector3(x, HEIGHT + (VISE_BODY.y + VISE_JAW.y) * 0.5,
			jaw_face - VISE_BODY.z * 0.5))
	piece.add_anchor(&"vise", Transform3D(Basis.IDENTITY, Vector3(x, HEIGHT + VISE_BODY.y, jaw_face + VISE_GAP * 0.5)), piece)

## A steel plate standing out of the board with a row of holes a screwdriver's collar drops through. A
## plate with holes is cut along the row into two notched halves (`Wrench`).
func _rack(piece: FurnitureNode, board_front: float) -> void:
	var half := RACK_PITCH * RACK_HOLES * 0.5
	var row := board_front + RACK_REACH * 0.55
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		var near := board_front if side < 0.0 else row
		var far := row if side < 0.0 else board_front + RACK_REACH
		var pieces: Array[PackedVector2Array] = [PackedVector2Array([Vector2(RACK_X - half, near), Vector2(RACK_X + half, near),
				Vector2(RACK_X + half, far), Vector2(RACK_X - half, far)])]
		for k in range(RACK_HOLES):
			var hole := _circle(Vector2(_rack_hole_x(k), row), RACK_HOLE, 12)
			var cut: Array[PackedVector2Array] = []
			for p: PackedVector2Array in pieces:
				cut.append_array(Geometry2D.clip_polygons(p, hole))
			pieces = cut
		for p: PackedVector2Array in pieces:
			parts.append([Props.extrude(p, Vector3(0, RACK_Y - RACK_PLATE, 0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, RACK_PLATE),
					Transform3D.IDENTITY])
	for end: float in [-1.0, 1.0]:
		var bracket := PackedVector2Array([Vector2(board_front, RACK_Y - RACK_PLATE), Vector2(board_front + RACK_REACH * 0.9, RACK_Y - RACK_PLATE),
				Vector2(board_front, RACK_Y - RACK_PLATE - RACK_REACH * 0.8)])
		var bx := RACK_X + end * (half - RACK_PLATE)
		parts.append([Props.extrude(bracket, Vector3(bx, 0, 0), Vector3.BACK, Vector3.UP, Vector3.RIGHT, -RACK_PLATE * 0.5, RACK_PLATE * 0.5),
				Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(parts), Props.mat(BLACK, 0.45, 0.3)))
	piece.add_anchor(&"screwdrivers", Transform3D(Basis.IDENTITY, Vector3(_rack_hole_x(0), RACK_Y + HANDLE_LENGTH, row)), piece)

func _rack_hole_x(k: int) -> float:
	return RACK_X + (float(k) - (RACK_HOLES - 1) * 0.5) * RACK_PITCH

## J-hooks out of the board's holes.
func _hooks(piece: FurnitureNode, board_front: float) -> void:
	var wire: Array = []
	for k in range(HOOKS):
		wire.append([_hook(_hole(HOOK_COLUMN + k * HOOK_EVERY, HOOK_ROW), board_front), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(wire), Mats.of("metal_brushed", STEEL, 0.4)))
	var first := _hole(HOOK_COLUMN, HOOK_ROW)
	piece.add_anchor(&"wrenches", Transform3D(Basis.IDENTITY, Vector3(first.x, first.y + HOOK_WIRE + RING_WALL,
			board_front + HANG_OUT)), piece)

## The middle of the board's hole in column `column` from its left and row `row` from its bottom, in the
## piece's space.
func _hole(column: int, row: int) -> Vector2:
	return Vector2(-PEGBOARD.x * 0.5 + (column + 0.5) * _pitch().x, PEG_Y + (row + 0.5) * _pitch().y)

func _pitch() -> Vector2:
	return Vector2(PEGBOARD.x / roundf(PEGBOARD.x / PEG_PITCH), PEGBOARD.y / roundf(PEGBOARD.y / PEG_PITCH))

func _hook(hole: Vector2, board_front: float) -> ArrayMesh:
	var y := hole.y
	var path := PackedVector3Array([Vector3(hole.x, y, board_front - PEG_THICK), Vector3(hole.x, y, board_front + HOOK_REACH - HOOK_TIP)])
	for k in range(1, 5):
		var a := PI * 0.5 * float(k) / 4.0
		path.append(Vector3(hole.x, y + HOOK_TIP * (1.0 - cos(a)), board_front + HOOK_REACH - HOOK_TIP + HOOK_TIP * sin(a)))
	return Props.tube(path, HOOK_WIRE, 8)

## The board, in its own space: its bottom left corner at x -width/2, y 0, its back at z 0. Every cell of
## the hole grid is a square round an octagonal hole, faced front and back, with the hole's wall through
## the board; written straight into arrays, because at 1152 holes a SurfaceTool is most of the cost.
static func _pegboard() -> ArrayMesh:
	var columns := int(roundf(PEGBOARD.x / PEG_PITCH))
	var rows := int(roundf(PEGBOARD.y / PEG_PITCH))
	var cell := Vector2(PEGBOARD.x / columns, PEGBOARD.y / rows)
	var ring := PackedVector2Array()
	var square := PackedVector2Array()
	for k in range(8):
		var a := PI * 0.25 * k
		ring.append(Vector2(cos(a), sin(a)) * PEG_HOLE)
		# The square's point at the same angle: an edge's middle or a corner.
		square.append(Vector2(signf(snappedf(cos(a), 0.001)), signf(snappedf(sin(a), 0.001))) * cell * 0.5)
	var cells := columns * rows
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	verts.resize(cells * 48 + 16)
	normals.resize(verts.size())
	tangents.resize(verts.size() * 4)
	indices.resize(cells * 144 + 24)
	var v := 0
	var n := 0
	for j in range(rows):
		for i in range(columns):
			var c := Vector2(-PEGBOARD.x * 0.5 + (i + 0.5) * cell.x, (j + 0.5) * cell.y)
			var base := v
			for k in range(8):
				var s := c + square[k]
				var h := c + ring[k]
				verts[v] = Vector3(s.x, s.y, PEG_THICK)
				verts[v + 1] = Vector3(h.x, h.y, PEG_THICK)
				verts[v + 2] = Vector3(s.x, s.y, 0.0)
				verts[v + 3] = Vector3(h.x, h.y, 0.0)
				normals[v] = Vector3.BACK
				normals[v + 1] = Vector3.BACK
				normals[v + 2] = Vector3.FORWARD
				normals[v + 3] = Vector3.FORWARD
				for t in range(4):
					tangents[(v + t) * 4] = 1.0
					tangents[(v + t) * 4 + 3] = 1.0
				v += 4
			for k in range(8):
				var a := base + k * 4
				var b := base + ((k + 1) % 8) * 4
				# Seen from +Z the square runs anticlockwise: the front's triangles are laid clockwise, the back's
				# anticlockwise, so each one's cross product points into the board.
				indices[n] = a; indices[n + 1] = b + 1; indices[n + 2] = b
				indices[n + 3] = a; indices[n + 4] = a + 1; indices[n + 5] = b + 1
				indices[n + 6] = a + 2; indices[n + 7] = b + 2; indices[n + 8] = b + 3
				indices[n + 9] = a + 2; indices[n + 10] = b + 3; indices[n + 11] = a + 3
				n += 12
			# The hole's wall: its own vertices, lit toward the hole's middle.
			for k in range(8):
				var h := c + ring[k]
				var inward := Vector3(-ring[k].x, -ring[k].y, 0.0).normalized()
				verts[v] = Vector3(h.x, h.y, 0.0)
				verts[v + 1] = Vector3(h.x, h.y, PEG_THICK)
				normals[v] = inward
				normals[v + 1] = inward
				for t in range(2):
					tangents[(v + t) * 4 + 2] = 1.0
					tangents[(v + t) * 4 + 3] = 1.0
				v += 2
			var wall := v - 16
			for k in range(8):
				var a := wall + k * 2
				var b := wall + ((k + 1) % 8) * 2
				indices[n] = a; indices[n + 1] = b; indices[n + 2] = a + 1
				indices[n + 3] = b; indices[n + 4] = b + 1; indices[n + 5] = a + 1
				n += 6
	# The board's four edges.
	var corners: Array[Vector2] = [Vector2(-PEGBOARD.x * 0.5, 0.0), Vector2(PEGBOARD.x * 0.5, 0.0), Vector2(PEGBOARD.x * 0.5, PEGBOARD.y),
			Vector2(-PEGBOARD.x * 0.5, PEGBOARD.y)]
	for k in range(4):
		var p := corners[k]
		var q := corners[(k + 1) % 4]
		var out := Vector3(q.y - p.y, p.x - q.x, 0.0).normalized()
		var along := Vector3(q.x - p.x, q.y - p.y, 0.0).normalized()
		for vert: Vector3 in [Vector3(p.x, p.y, 0.0), Vector3(q.x, q.y, 0.0), Vector3(q.x, q.y, PEG_THICK), Vector3(p.x, p.y, PEG_THICK)]:
			verts[v] = vert
			normals[v] = out
			tangents[v * 4] = along.x
			tangents[v * 4 + 1] = along.y
			tangents[v * 4 + 3] = 1.0
			v += 1
		var e := v - 4
		indices[n] = e; indices[n + 1] = e + 2; indices[n + 2] = e + 1
		indices[n + 3] = e; indices[n + 4] = e + 3; indices[n + 5] = e + 2
		n += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _circle(centre: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(sides):
		var a := TAU * float(k) / sides
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out
