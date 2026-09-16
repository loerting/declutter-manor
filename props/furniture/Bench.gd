extends FurnitureGenerator
## A painted mudroom bench: a seat board with its edges eased, standing on two end panels with an arch
## cut out of their feet, and a slatted shelf low between them for boots.
##
##     width    float    metres, default 1.2
##
## Anchors:
##
##     seat    the middle of the seat

const DEFAULT_WIDTH := 1.2
const DEPTH := 0.4
const HEIGHT := 0.46
const SEAT := 0.03
const END := 0.028
const EASE := 0.006
const ARCH := Vector2(0.24, 0.07)
const ARCH_STEPS := 8
const SHELF_Y := 0.12
const SLAT := Vector2(0.07, 0.018)
const SLATS := 4
const SEAT_OVERHANG := 0.02

const PAINT := Color(0.62, 0.7, 0.62)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, DEPTH))
	var under := HEIGHT - SEAT
	var parts: Array = [[Props.rounded_box(Vector3(width, SEAT, DEPTH), EASE, 4, 20),
			Transform3D(Basis.IDENTITY, Vector3(0, under + SEAT * 0.5, DEPTH * 0.5))]]
	# An end panel in side view, (z, y): a rectangle with a low arch cut up into its foot.
	var outline := PackedVector2Array([Vector2(SEAT_OVERHANG, 0.0), Vector2(DEPTH * 0.5 - ARCH.x * 0.5, 0.0)])
	outline.append_array(Props.arc(Vector2(DEPTH * 0.5, 0.0), Vector2(ARCH.x * 0.5, ARCH.y), PI, 0.0, ARCH_STEPS))
	outline.append(Vector2(DEPTH - SEAT_OVERHANG, 0.0))
	outline.append(Vector2(DEPTH - SEAT_OVERHANG, under))
	outline.append(Vector2(SEAT_OVERHANG, under))
	var end := Props.extrude(outline, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -END * 0.5, END * 0.5)
	var ex := width * 0.5 - SEAT_OVERHANG - END * 0.5
	for side: float in [-1.0, 1.0]:
		parts.append([end, Transform3D(Basis.IDENTITY, Vector3(side * ex, 0, 0))])
	var slat_run := DEPTH - SEAT_OVERHANG * 2.0 - 0.02
	for i in range(SLATS):
		var z := SEAT_OVERHANG + 0.01 + SLAT.x * 0.5 + (slat_run - SLAT.x) * float(i) / float(SLATS - 1)
		parts.append(Props.part(Vector3(ex * 2.0, SLAT.y, SLAT.x), Vector3(0, SHELF_Y, z)))
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("painted_wood", PAINT, 0.7)))

	piece.add_box(Vector3(width, HEIGHT, DEPTH), Vector3(0, HEIGHT * 0.5, DEPTH * 0.5))
	piece.add_anchor(&"seat", Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, DEPTH * 0.5)), piece)
	return piece
