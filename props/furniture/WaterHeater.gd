extends FurnitureGenerator
## A 50-gallon gas water heater: a round jacketed tank on its base ring, the gas control valve and burner
## cover low on its front, a draft hood on legs over its top and the flue up from it, cold and hot copper
## pipes up out of the top with a shut-off on the cold, and the relief valve on its side with its discharge
## pipe running down to the floor.
##
##     ceiling    float    the room's height, which the flue and pipes run up to, default 2.4

const RADIUS := 0.28
const HEIGHT := 1.45
const WALL_GAP := 0.03
const SEGMENTS := 40
const CONTROL := Vector3(0.1, 0.12, 0.07)
const CONTROL_Y := 0.34
const KNOB := Vector2(0.022, 0.02)
## The burner cover is narrow enough to lie on the round tank without standing off it at its ends.
const COVER := Vector3(0.12, 0.1, 0.006)
## The draft hood's legs, cone and the flue's radius.
const HOOD := Vector3(0.14, 0.05, 0.1)
const FLUE := 0.05
const PIPE := 0.011
const PIPE_X := 0.14
const SHUTOFF := Vector3(0.06, 0.012, 0.02)
const RELIEF_Y := 1.2
const DISCHARGE_TO := 0.15
const DEFAULT_CEILING := 2.4
const CEILING_GAP := 0.005

const JACKET := Color(0.9, 0.89, 0.86)
const BLACK := Color(0.05, 0.05, 0.05)
const RED := Color(0.75, 0.1, 0.08)
const BLUE := Color(0.12, 0.3, 0.7)
const COPPER := Color(0.85, 0.5, 0.32)
const GALVANISED := Color(0.72, 0.73, 0.74)
const BRASS := Color(0.78, 0.62, 0.32)

func build(def: FurnitureDef) -> FurnitureNode:
	var ceiling := Params.number(def.params, "ceiling", DEFAULT_CEILING) - CEILING_GAP
	var piece := FurnitureNode.new()
	var size := RADIUS * 2.0 + WALL_GAP
	piece.initialize(def, Vector2(size + 0.08, size + CONTROL.z))
	var cz := WALL_GAP + RADIUS
	var at := Vector3(0, 0, cz)
	var jacket := PackedVector2Array([Vector2(0.0, 0.0), Vector2(RADIUS - 0.02, 0.0), Vector2(RADIUS - 0.012, 0.03),
			Vector2(RADIUS, 0.05), Vector2(RADIUS, HEIGHT - 0.05), Vector2(RADIUS - 0.03, HEIGHT - 0.008),
			Vector2(RADIUS - 0.06, HEIGHT), Vector2(0.0, HEIGHT)])
	piece.add_child(Props.mi(Props.lathe(jacket, SEGMENTS), Mats.finish("painted_metal", JACKET, 0.35), at))
	var front := cz + RADIUS
	piece.add_child(Props.mi(Props.rounded_box(CONTROL, 0.006, 2, 8), Mats.finish("plastic", BLACK, 0.4),
			Vector3(0, CONTROL_Y, front + CONTROL.z * 0.5 - 0.02)))
	piece.add_child(Props.mi(Props.cyl(KNOB.x, KNOB.x, KNOB.y, 20), Mats.finish("plastic", RED, 0.4),
			Vector3(0, CONTROL_Y + 0.02, front + CONTROL.z - 0.02 + KNOB.y * 0.5), Vector3(90, 0, 0)))
	piece.add_child(Props.mi(Props.box(COVER), Mats.finish("painted_metal", Color(0.3, 0.3, 0.32), 0.5), Vector3(0, 0.12, front - 0.01)))

	var top := HEIGHT
	var flue: Array = [[Props.lathe(PackedVector2Array([Vector2(HOOD.x, top + HOOD.y), Vector2(FLUE + 0.01, top + HOOD.y + HOOD.z)]), SEGMENTS),
			Transform3D(Basis.IDENTITY, at)]]
	flue.append([Props.cyl(FLUE, FLUE, ceiling - top - HOOD.y - HOOD.z + 0.01, 20),
			Transform3D(Basis.IDENTITY, at + Vector3(0, (ceiling + top + HOOD.y + HOOD.z - 0.01) * 0.5, 0))])
	for k in range(3):
		var a := TAU * float(k) / 3.0 + PI * 0.5
		flue.append(Props.part(Vector3(0.012, HOOD.y + 0.01, 0.003), at + Vector3(cos(a) * HOOD.x * 0.9, top + HOOD.y * 0.5 - 0.005, sin(a) * HOOD.x * 0.9),
				Basis(Vector3.UP, -a)))
	piece.add_child(Props.mi(Props.bake(flue), Mats.finish("metal_brushed", GALVANISED, 0.45)))

	var copper: Array = []
	for side: float in [-1.0, 1.0]:
		copper.append([Props.cyl(PIPE, PIPE, ceiling - top + 0.01, 12), Transform3D(Basis.IDENTITY,
				at + Vector3(side * PIPE_X, (ceiling + top - 0.01) * 0.5, 0))])
	var relief := at + Vector3(RADIUS, RELIEF_Y, 0).rotated(Vector3.UP, -PI * 0.25)
	var out := Vector3(1, 0, 0).rotated(Vector3.UP, -PI * 0.25)
	copper.append([Props.tube(PackedVector3Array([relief, relief + out * 0.05, relief + out * 0.07 + Vector3(0, -0.02, 0),
			relief + out * 0.07 + Vector3(0, -0.06, 0), Vector3(relief.x + out.x * 0.07, DISCHARGE_TO, relief.z + out.z * 0.07)]), PIPE, 10),
			Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(copper), Mats.finish("metal_polished", COPPER, 0.35)))
	piece.add_child(Props.mi(Props.box(Vector3(0.04, 0.05, 0.04)), Mats.finish("metal_polished", BRASS, 0.3), relief + out * 0.03))
	piece.add_child(Props.mi(Props.box(SHUTOFF), Mats.finish("plastic", BLUE, 0.4), at + Vector3(-PIPE_X, top + 0.25, PIPE + SHUTOFF.z * 0.5)))
	piece.add_box(Vector3(RADIUS * 2.0, HEIGHT, RADIUS * 2.0), Vector3(0, HEIGHT * 0.5, cz))
	return piece
