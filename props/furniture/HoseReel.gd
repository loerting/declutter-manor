extends FurnitureGenerator
## A wall-mounted hose reel beside an outside tap: a steel back plate, a drum standing out from it with a flange on
## its front and a crank on the flange, and the tap below with a short lead hose from its spout up into the reel.
## The hose itself is an item, hung over the drum.
##
##     drum_y    float    the drum's middle above the ground, default 0.95
##
## Anchors:
##
##     drum     a coil's top when it hangs on the drum by its inner loop, at the drum's middle (GardenHose)
##     crank    the crank's handle, at its end

const DEFAULT_DRUM_Y := 0.95
## The back plate reaches up past the drum as far as a hung coil does, and down as far under it as the lead hose's
## stub.
const PLATE := Vector3(0.22, 0.48, 0.006)
const PLATE_RAISE := 0.06
const DRUM := Vector2(0.13, 0.13)
const FLANGE := Vector2(0.19, 0.008)
const FLANGE_RIM := Vector2(0.008, 0.012)
const CRANK := Vector3(0.012, 0.15, 0.008)
const CRANK_HANDLE := Vector2(0.014, 0.09)
## A hung coil stands this far over the drum: from the inner edge of its loop that rests on the drum to its
## highest point (`GardenHose`: the ground loop's outside against the top loop's inside at the -Z side).
const COIL_HANG := 0.128
## The tap: its height, how far to the left of the reel, and its parts.
const TAP_Y := 0.5
const TAP_X := -0.22
const TAP_FLANGE := Vector2(0.03, 0.008)
const TAP_BODY := Vector2(0.018, 0.07)
const TAP_WHEEL := Vector2(0.03, 0.006)
const LEAD := 0.009
## The brass stub under the back plate the lead hose runs into: radius and length.
const INLET := Vector2(0.012, 0.03)

const STEEL := Color(0.18, 0.32, 0.22)
const BRASS := Color(0.76, 0.6, 0.3)
const HOSE := Color(0.2, 0.52, 0.22)
const KNOB := Color(0.1, 0.1, 0.1)

func build(def: FurnitureDef) -> FurnitureNode:
	var drum_y := Params.number(def.params, "drum_y", DEFAULT_DRUM_Y)
	var piece := FurnitureNode.new()
	var depth := PLATE.z + DRUM.y + FLANGE.y + CRANK.z + CRANK_HANDLE.y
	piece.initialize(def, Vector2(FLANGE.x * 2.0 + absf(TAP_X) * 2.0, depth))
	piece.mounted = true
	var steel := Props.mat(STEEL, 0.45, 0.4)
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var front := PLATE.z + DRUM.y
	var parts: Array = [
		[Props.rounded_box(PLATE, 0.003, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, drum_y + PLATE_RAISE, PLATE.z * 0.5))],
		[Props.cyl(DRUM.x, DRUM.x, DRUM.y, 40), Transform3D(along_z, Vector3(0, drum_y, PLATE.z + DRUM.y * 0.5))],
		[Props.cyl(FLANGE.x, FLANGE.x, FLANGE.y, 48), Transform3D(along_z, Vector3(0, drum_y, front + FLANGE.y * 0.5))],
		[Props.torus(FLANGE_RIM.x, FLANGE.x - FLANGE_RIM.x), Transform3D(along_z, Vector3(0, drum_y, front + FLANGE.y))],
		[Props.rounded_box(Vector3(CRANK.x * 2.0, CRANK.y, CRANK.z), 0.003, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(0, drum_y + CRANK.y * 0.5, front + FLANGE.y + CRANK.z * 0.5))],
	]
	piece.add_child(Props.mi(Props.bake(parts), steel))
	var handle_at := Vector3(0, drum_y + CRANK.y - CRANK.x, front + FLANGE.y + CRANK.z)
	piece.add_child(Props.mi(Props.cyl(CRANK_HANDLE.x, CRANK_HANDLE.x, CRANK_HANDLE.y, 16), Props.mat(KNOB, 0.5), handle_at + Vector3(0, 0, CRANK_HANDLE.y * 0.5),
			Vector3(90, 0, 0)))

	var brass := Props.mat(BRASS, 0.35, 0.7)
	var tap: Array = [
		[Props.cyl(TAP_FLANGE.x, TAP_FLANGE.x, TAP_FLANGE.y, 20), Transform3D(along_z, Vector3(TAP_X, TAP_Y, TAP_FLANGE.y * 0.5))],
		[Props.cyl(TAP_BODY.x, TAP_BODY.x, TAP_BODY.y, 16), Transform3D(along_z, Vector3(TAP_X, TAP_Y, TAP_BODY.y * 0.5))],
		[Props.cyl(TAP_BODY.x * 0.8, TAP_BODY.x * 0.7, TAP_BODY.y * 0.6, 16), Transform3D.IDENTITY.translated(Vector3(TAP_X, TAP_Y - TAP_BODY.y * 0.3, TAP_BODY.y - TAP_BODY.x))],
		[Props.cyl(0.004, 0.004, 0.03, 8), Transform3D.IDENTITY.translated(Vector3(TAP_X, TAP_Y + 0.015, TAP_BODY.y * 0.6))],
	]
	# The lead hose from the tap's spout: down, back against the wall, and up behind the coil into a stub under
	# the back plate.
	var spout := Vector3(TAP_X, TAP_Y - TAP_BODY.y * 0.6, TAP_BODY.y - TAP_BODY.x)
	var wall := LEAD + 0.003
	var inlet := Vector3(-PLATE.x * 0.35, drum_y + PLATE_RAISE - PLATE.y * 0.5 - INLET.y * 0.5, wall)
	tap.append([Props.cyl(INLET.x, INLET.x, INLET.y, 14), Transform3D.IDENTITY.translated(inlet)])
	piece.add_child(Props.mi(Props.bake(tap), brass))
	piece.add_child(Props.mi(Props.cyl(TAP_WHEEL.x, TAP_WHEEL.x, TAP_WHEEL.y, 20), Props.mat(Color(0.7, 0.12, 0.1), 0.5), Vector3(TAP_X, TAP_Y + 0.03, TAP_BODY.y * 0.6)))
	var lead := Props.smooth_path(PackedVector3Array([spout, spout - Vector3(0, 0.06, 0), Vector3(TAP_X * 0.7, TAP_Y - 0.13, wall),
			Vector3(inlet.x, TAP_Y, wall), inlet - Vector3(0, INLET.y * 0.5 + 0.02, 0), inlet]), 5)
	piece.add_child(Props.mi(Props.tube(lead, LEAD, 10), Props.mat(HOSE, 0.5)))

	piece.add_anchor(&"drum", Transform3D(Basis.IDENTITY, Vector3(0, drum_y + DRUM.x + COIL_HANG, PLATE.z + DRUM.y * 0.5)), piece)
	piece.add_anchor(&"crank", Transform3D(Basis.IDENTITY, handle_at + Vector3(0, CRANK_HANDLE.x, CRANK_HANDLE.y)), piece)
	piece.add_box(Vector3(FLANGE.x * 2.0, FLANGE.x * 2.0, front + FLANGE.y), Vector3(0, drum_y, (front + FLANGE.y) * 0.5))
	return piece
