extends FurnitureGenerator
## A walk-in shower in a corner: a low white tray with a steel grate over its drain, a fixed glass screen
## on a chrome channel along its front from the corner wall, braced back to the wall at its top, and a
## round rain head on an arm from the wall with a mixer under it. The corner wall is at +X and the way in
## is at -X.
##
##     width    float    along the wall, default 1.2
##     depth    float    default 0.9
##
## No anchors.

const DEFAULT_WIDTH := 1.2
const DEFAULT_DEPTH := 0.9
const TRAY := 0.04
const TRAY_ROUND := 0.012
const GRATE := Vector3(0.12, 0.003, 0.12)
## The screen: its share of the width, height, thickness, how far in from the tray's front edge it
## stands, and its channel.
const SCREEN_SHARE := 0.62
const SCREEN_HEIGHT := 1.95
const SCREEN_THICK := 0.008
const SCREEN_IN := 0.05
const CHANNEL := Vector2(0.022, 0.02)
const BRACE_RADIUS := 0.009
const HEAD := Vector3(0.12, 0.012, 2.08)
const ARM := 0.34
const ARM_RADIUS := 0.011
const ARM_RISE := 0.08
const ARM_BEND := 0.04
const MIXER := Vector3(0.06, 0.012, 1.05)
const LEVER := Vector3(0.012, 0.012, 0.08)

const PORCELAIN := Color(0.97, 0.97, 0.96)
const CHROME := Color(0.9, 0.91, 0.93)
const GLASS := Color(0.85, 0.92, 0.94, 0.14)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var depth := Params.number(def.params, "depth", DEFAULT_DEPTH)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, depth))
	piece.add_child(Props.mi(Props.rounded_box(Vector3(width, TRAY, depth), TRAY_ROUND, 4, 20), Mats.of("porcelain", PORCELAIN, 0.25),
			Vector3(0, TRAY * 0.5, depth * 0.5)))
	var chrome: Array = [Props.part(GRATE, Vector3(width * 0.2, TRAY + GRATE.y * 0.5, depth * 0.5))]
	var screen := width * SCREEN_SHARE
	var screen_x := width * 0.5 - screen * 0.5
	var screen_z := depth - SCREEN_IN
	piece.add_child(Props.mi(Props.box(Vector3(screen, SCREEN_HEIGHT - CHANNEL.y, SCREEN_THICK)), Props.glass(GLASS, 0.02),
			Vector3(screen_x, TRAY + CHANNEL.y + (SCREEN_HEIGHT - CHANNEL.y) * 0.5, screen_z)))
	chrome.append(Props.part(Vector3(screen, CHANNEL.y, CHANNEL.x), Vector3(screen_x, TRAY + CHANNEL.y * 0.5, screen_z)))
	# The wall channel stands `Props.PROUD` over the glass: level with it, the two tops lay in one plane.
	chrome.append(Props.part(Vector3(CHANNEL.y, SCREEN_HEIGHT + Props.PROUD, CHANNEL.x),
			Vector3(width * 0.5 - CHANNEL.y * 0.5, TRAY + (SCREEN_HEIGHT + Props.PROUD) * 0.5, screen_z)))
	# The brace from the screen's free top corner straight back to the wall.
	var free_x := width * 0.5 - screen + BRACE_RADIUS * 2.0
	var brace_y := TRAY + SCREEN_HEIGHT - 0.06
	chrome.append([Props.cyl(BRACE_RADIUS, BRACE_RADIUS, screen_z, 12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(free_x, brace_y, screen_z * 0.5))])
	# The rain head on an arm out of the wall level, round a bend and straight down into it; the mixer's
	# plate and lever under it.
	var arm_y := HEAD.z + ARM_RISE
	var arm := PackedVector3Array([Vector3(0, arm_y, 0), Vector3(0, arm_y, ARM - ARM_BEND)])
	for s in range(1, 7):
		var a := PI * 0.5 * float(s) / 6.0
		arm.append(Vector3(0, arm_y - ARM_BEND + cos(a) * ARM_BEND, ARM - ARM_BEND + sin(a) * ARM_BEND))
	arm.append(Vector3(0, HEAD.z, ARM))
	chrome.append([Props.tube(arm, ARM_RADIUS, 12), Transform3D.IDENTITY])
	chrome.append([Props.cyl(HEAD.x, HEAD.x, HEAD.y, 32), Transform3D(Basis.IDENTITY, Vector3(0, HEAD.z, ARM))])
	chrome.append([Props.cyl(MIXER.x, MIXER.x, MIXER.y, 28), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, MIXER.z, MIXER.y * 0.5))])
	chrome.append(Props.part(LEVER, Vector3(0, MIXER.z, MIXER.y + LEVER.z * 0.5)))
	piece.add_child(Props.mi(Props.bake(chrome), Mats.of("metal_brushed", CHROME, 0.15)))

	piece.add_box(Vector3(width, TRAY, depth), Vector3(0, TRAY * 0.5, depth * 0.5))
	piece.add_box(Vector3(screen, SCREEN_HEIGHT, CHANNEL.x), Vector3(screen_x, TRAY + SCREEN_HEIGHT * 0.5, screen_z))
	return piece
