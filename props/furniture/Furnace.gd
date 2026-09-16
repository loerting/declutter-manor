extends FurnitureGenerator
## A gas furnace against the wall: a painted steel cabinet with a burner door over a blower door, a supply
## plenum on its top and the trunk duct up from it into the ceiling, the two white plastic flue pipes out of
## its right side and up, and the black gas pipe down its right with a yellow shut-off.
##
##     ceiling    float    the room's height, which the ducts and pipes run up to, default 2.4

const CABINET := Vector3(0.56, 1.2, 0.74)
const EASE := 0.006
const PANEL_INSET := 0.02
const PANEL_PROUD := 0.004
const SPLIT := 0.62
const LOUVRES := 6
const LOUVRE := Vector3(0.3, 0.01, 0.012)
const SIGHT := Vector3(0.06, 0.03, 0.004)
const PLENUM := Vector3(0.58, 0.34, 0.66)
const TRUNK := Vector3(0.46, 0.0, 0.26)
const SEAM := 0.012
## Stop this short of the ceiling so nothing lies in its plane.
const CEILING_GAP := 0.005
const DEFAULT_CEILING := 2.4
## The flue pipes: radius, how far out of the side, the height they leave the cabinet, their spacing.
const FLUE := 0.038
const FLUE_OUT := 0.09
const FLUE_Y := 0.95
const FLUE_Z := Vector2(0.28, 0.46)
const GAS := 0.014
const GAS_Y := 0.45
const GAS_Z := 0.62
const VALVE := Vector3(0.02, 0.022, 0.07)
const SIDE_ROOM := 0.2

const PAINT := Color(0.78, 0.76, 0.72)
const GALVANISED := Color(0.72, 0.73, 0.74)
const PVC := Color(0.93, 0.93, 0.91)
const IRON := Color(0.08, 0.08, 0.08)
const YELLOW := Color(0.95, 0.75, 0.1)
const DARK := Color(0.04, 0.04, 0.05)

func build(def: FurnitureDef) -> FurnitureNode:
	var ceiling := Params.number(def.params, "ceiling", DEFAULT_CEILING) - CEILING_GAP
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(CABINET.x + SIDE_ROOM * 2.0, CABINET.z))
	var cz := CABINET.z * 0.5
	var front := CABINET.z
	var paint := Props.mat(PAINT, 0.4, 0.2)
	piece.add_child(Props.mi(Props.rounded_box(CABINET, EASE, 2, 8), paint, Vector3(0, CABINET.y * 0.5, cz)))
	var panels: Array = []
	for span: Vector2 in [Vector2(0.05, SPLIT - 0.01), Vector2(SPLIT + 0.01, CABINET.y - 0.05)]:
		panels.append(Props.part(Vector3(CABINET.x - PANEL_INSET * 2.0, span.y - span.x, PANEL_PROUD * 2.0),
				Vector3(0, (span.x + span.y) * 0.5, front)))
	for k in range(LOUVRES):
		var y := 0.18 + k * 0.05
		panels.append(Props.part(LOUVRE, Vector3(0, y, front + PANEL_PROUD + LOUVRE.z * 0.5), Basis(Vector3.RIGHT, -0.5)))
	piece.add_child(Props.mi(Props.bake(panels), paint))
	piece.add_child(Props.mi(Props.box(SIGHT), Props.mat(DARK, 0.1), Vector3(-0.12, SPLIT + 0.3, front + PANEL_PROUD + SIGHT.z * 0.5)))

	var duct: Array = [Props.part(PLENUM, Vector3(0, CABINET.y + PLENUM.y * 0.5, cz))]
	var trunk_bottom := CABINET.y + PLENUM.y
	var trunk := Vector3(TRUNK.x, ceiling - trunk_bottom, TRUNK.z)
	var trunk_z := TRUNK.z * 0.5 + 0.03
	duct.append(Props.part(trunk, Vector3(0, trunk_bottom + trunk.y * 0.5, trunk_z)))
	for y: float in [trunk_bottom + 0.004, trunk_bottom + trunk.y * 0.5]:
		duct.append(Props.part(Vector3(trunk.x + SEAM * 0.5, SEAM, trunk.z + SEAM * 0.5), Vector3(0, y + SEAM * 0.5, trunk_z)))
	duct.append(Props.part(Vector3(PLENUM.x + SEAM * 0.5, SEAM, PLENUM.z + SEAM * 0.5), Vector3(0, CABINET.y + SEAM * 0.5, cz)))
	piece.add_child(Props.mi(Props.bake(duct), Props.mat(GALVANISED, 0.45, 0.5)))
	piece.add_box(CABINET, Vector3(0, CABINET.y * 0.5, cz))
	piece.add_box(PLENUM, Vector3(0, CABINET.y + PLENUM.y * 0.5, cz))
	piece.add_box(trunk, Vector3(0, trunk_bottom + trunk.y * 0.5, trunk_z))

	var side := CABINET.x * 0.5
	var pvc: Array = []
	for z: float in [FLUE_Z.x, FLUE_Z.y]:
		pvc.append([Props.tube(_elbow(Vector3(side - 0.02, FLUE_Y, z), FLUE_OUT, ceiling, FLUE), FLUE, 16), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(pvc), Props.mat(PVC, 0.35)))
	var gas := PackedVector3Array([Vector3(side - 0.02, GAS_Y, GAS_Z), Vector3(side + 0.05, GAS_Y, GAS_Z)])
	gas.append_array(_arc(Vector3(side + 0.05, GAS_Y, GAS_Z), 0.03))
	gas.append(Vector3(side + 0.08, ceiling, GAS_Z))
	piece.add_child(Props.mi(Props.tube(gas, GAS, 10), Props.mat(IRON, 0.5, 0.4)))
	piece.add_child(Props.mi(Props.box(VALVE), Props.mat(YELLOW, 0.4), Vector3(side + 0.08 + GAS + VALVE.x * 0.5, GAS_Y + 0.35, GAS_Z)))
	return piece

## Out of the side along +X, round a bend and straight up to the ceiling.
static func _elbow(from: Vector3, out: float, ceiling: float, radius: float) -> PackedVector3Array:
	var path := PackedVector3Array([from, from + Vector3(out - radius * 2.0, 0, 0)])
	path.append_array(_arc(from + Vector3(out - radius * 2.0, 0, 0), radius * 2.0))
	path.append(Vector3(from.x + out, ceiling, from.z))
	return path

## A quarter bend of `radius` from heading +X to heading up, starting at `at`, without its first point.
static func _arc(at: Vector3, radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in range(1, 5):
		var a := PI * 0.5 * float(k) / 4.0
		out.append(at + Vector3(sin(a) * radius, (1.0 - cos(a)) * radius, 0))
	return out
