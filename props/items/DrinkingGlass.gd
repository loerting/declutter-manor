extends ItemGenerator
## A straight tumbler, a little wider at the rim than at its heavy base. One closed turned solid of
## clear glass.
##
## No parameters.

## Counter-clockwise in (radius, height): across the base, up the outside, over the rim, down the
## inside to the top of the base.
const SECTION: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.031, 0.0), Vector2(0.0325, 0.003), Vector2(0.0365, 0.118), Vector2(0.0362, 0.12),
	Vector2(0.0345, 0.12), Vector2(0.0342, 0.118), Vector2(0.0302, 0.014), Vector2(0.027, 0.011), Vector2(0.0, 0.011)]
const SEGMENTS := 32
const TINT := Color(0.84, 0.92, 0.9, 0.2)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(SECTION), SEGMENTS, true), Props.glass(TINT)))
	return root
