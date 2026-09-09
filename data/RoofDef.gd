class_name RoofDef
extends Resource
## A roof over one rectangular block of the building. The house is a main block plus a garage
## wing, so it is two of these rather than one general solution to roofing arbitrary polygons —
## a straight skeleton would be a project of its own and would still need authoring.
##
## The roof is generated from the same plan as the rooms below it, which is what keeps the attic
## inside the roof volume instead of near it (`docs/HOUSE.md`).

enum Kind { GABLE, HIP, SHED }

@export var kind: Kind = Kind.GABLE
## Plan rectangle covered, measured to the outside of the walls. The overhang is added on top.
@export var footprint := Rect2()
## World Y of the eave — normally the top of the walls it sits on.
@export var eave_y := 2.7
@export var pitch_deg := 32.0
@export var overhang := 0.45
@export var thickness := 0.16
## Thickness of the walls this roof lands on, so the gable end sits flush with the siding below
## it rather than 10 cm behind it.
@export var wall_thickness := 0.20
## GABLE and SHED only: which way the ridge runs. HIP ignores it.
@export var ridge_along_x := true
## SHED only: which end is high.
@export var shed_high_at_min := false

## An end that butts against a taller wall — the garage roof meeting the house — gets neither
## a gable nor an overhang there; it stops at the footprint line and the wall closes it.
@export var abut_start := false
@export var abut_end := false

@export var slot := "roof_tiles"
## What the attic sees looking up.
@export var underside_slot := "oak"
@export var underside_tint := Color(0.55, 0.50, 0.42)
## The triangle of wall between the eave and the slope at a gable end.
@export var gable_slot := "painted_wood"
@export var gable_tint := Color(0.80, 0.82, 0.73)
@export var fascia_slot := "painted_wood"

## Height of the ridge above the eave.
func rise() -> float:
	var span := footprint.size.y if ridge_along_x else footprint.size.x
	return tan(deg_to_rad(pitch_deg)) * span * 0.5

func ridge_y() -> float:
	return eave_y + rise()

static func gable(rect: Rect2, eave: float, along_x: bool, pitch := 32.0) -> RoofDef:
	var r := RoofDef.new()
	r.kind = Kind.GABLE
	r.footprint = rect
	r.eave_y = eave
	r.ridge_along_x = along_x
	r.pitch_deg = pitch
	return r
