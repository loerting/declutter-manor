extends ItemGenerator
## A 55-inch flat television standing on its two blade feet, the screen to +Z: a thin panel with a
## narrow bezel round a glossy screen, a deeper housing low on its back, and a foot near each end.
##
## No parameters.

const PANEL := Vector3(1.23, 0.71, 0.026)
const BEZEL := 0.008
const SCREEN_PROUD := 0.0015
const HOUSING := Vector3(0.86, 0.36, 0.034)
const HOUSING_DROP := 0.05
## The panel stands this high on its feet.
const LIFT := 0.078
const FOOT_X := 0.5
const FOOT_WIDTH := 0.014
## A foot's side view: toes FOOT_REACH out front and back, rising to where it enters the panel.
const FOOT_REACH := 0.125
const FOOT_TOE := 0.018
const FOOT_NECK := 0.014
const FOOT_EASE := 0.002

const SHELL := Color(0.1, 0.1, 0.105)
const SCREEN := Color(0.012, 0.013, 0.016)
const FOOT := Color(0.28, 0.28, 0.3)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var centre := Vector3(0, LIFT + PANEL.y * 0.5, 0)
	root.add_child(Props.mi(Props.rounded_box(PANEL, 0.004, 6, 24), Props.mat(SHELL, 0.45), centre))
	var screen := Props.mat(SCREEN, 0.06)
	root.add_child(Props.mi(Props.box(Vector3(PANEL.x - BEZEL * 2.0, PANEL.y - BEZEL * 2.0, 0.002)), screen,
			centre + Vector3(0, 0, PANEL.z * 0.5 - 0.001 + SCREEN_PROUD)))
	root.add_child(Props.mi(Props.rounded_box(HOUSING, 0.012, 6, 24), Props.mat(SHELL, 0.6),
			Vector3(0, LIFT + HOUSING.y * 0.5 + HOUSING_DROP, -PANEL.z * 0.5 - HOUSING.z * 0.5 + 0.006)))
	var metal := Mats.of("metal_brushed", FOOT, 0.5)
	var blade := _foot()
	for side: float in [-1.0, 1.0]:
		root.add_child(Props.mi(blade, metal, Vector3(side * FOOT_X, 0, 0)))
	return root

## A flat blade bent into a shallow V, extruded across its width.
static func _foot() -> ArrayMesh:
	var neck_y := LIFT + 0.02
	var polygon := PackedVector2Array([
		Vector2(-FOOT_REACH, 0.0), Vector2(-FOOT_REACH + FOOT_TOE, 0.0), Vector2(0.0, LIFT - FOOT_TOE * 0.6),
		Vector2(FOOT_REACH - FOOT_TOE, 0.0), Vector2(FOOT_REACH, 0.0), Vector2(FOOT_NECK * 0.5, neck_y),
		Vector2(-FOOT_NECK * 0.5, neck_y),
	])
	return Props.extrude(polygon, Vector3(-FOOT_WIDTH * 0.5, 0, 0), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.0, FOOT_WIDTH)
