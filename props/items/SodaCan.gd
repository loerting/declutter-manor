extends ItemGenerator
## An empty aluminium soda can standing up: a domed foot, a printed body, a neck necking in to a
## rolled rim round a sunk lid, and the ring pull lying flat on the lid.
##
##     tint    Color    the printed body, default RED

const FOOT: Array[Vector2] = [Vector2(0.0, 0.007), Vector2(0.019, 0.003), Vector2(0.025, 0.0), Vector2(0.03, 0.003),
	Vector2(0.033, 0.012)]
const BODY: Array[Vector2] = [Vector2(0.033, 0.012), Vector2(0.033, 0.106)]
const NECK: Array[Vector2] = [Vector2(0.033, 0.106), Vector2(0.031, 0.113), Vector2(0.0275, 0.12), Vector2(0.027, 0.1225),
	Vector2(0.0258, 0.1228), Vector2(0.025, 0.1195), Vector2(0.0, 0.1195)]
const SEGMENTS := 32
const TAB := Vector3(0.012, 0.0012, 0.02)

const RED := Color(0.72, 0.08, 0.08)
const ALUMINIUM := Color(0.82, 0.83, 0.85)
const TINTS: Array[Color] = [RED, Color(0.15, 0.5, 0.2), Color(0.12, 0.25, 0.6), Color(0.92, 0.5, 0.08), Color(0.78, 0.78, 0.8)]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var metal := Mats.of("metal_brushed", ALUMINIUM, 0.3)
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(FOOT), SEGMENTS), metal))
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(BODY), SEGMENTS), Props.mat(Params.colour(def.params, "tint", RED), 0.3, 0.6)))
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(NECK), SEGMENTS), metal))
	root.add_child(Props.mi(Props.rounded_box(TAB, 0.0005, 2, 8), metal, Vector3(0, NECK[6].y + TAB.y * 0.5, 0.004)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## Put down, it lies on its side.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)
