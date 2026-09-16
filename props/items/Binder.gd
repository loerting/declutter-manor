extends ItemGenerator
## A ring binder standing on its bottom edge, its spine to -Z: one polypropylene cover folded round
## a board in a U, a pocket on the spine holding a white label, and a block of punched paper filed
## inside, short of the cover at head, tail and fore-edge.
##
##     tint    Color    cover colour, default NAVY

const HEIGHT := 0.318
const DEPTH := 0.29
const SPINE := 0.068
const COVER := 0.003
const CORNER := 0.007
const CORNER_STEPS := 5
const PAPER := Vector3(0.042, 0.296, 0.262)
const PAPER_FROM_SPINE := 0.012
const LABEL := Vector3(0.042, 0.11, 0.0012)
const LABEL_AT := 0.62

const NAVY := Color(0.1, 0.16, 0.34)
## Six years of household paperwork, one colour each.
const TINTS: Array[Color] = [NAVY, Color(0.62, 0.1, 0.1), Color(0.06, 0.06, 0.07), Color(0.14, 0.38, 0.22),
		Color(0.86, 0.86, 0.84), Color(0.9, 0.7, 0.12)]
const SHEET := Color(0.96, 0.95, 0.92)
const LABEL_CARD := Color(0.98, 0.98, 0.96)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var plastic := Props.mat(Params.colour(def.params, "tint", NAVY), 0.45)
	root.add_child(Props.mi(Props.extrude(_cover_outline(), Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			0.0, HEIGHT), plastic))
	var paper_z0 := -DEPTH * 0.5 + COVER + PAPER_FROM_SPINE
	root.add_child(Props.mi(Props.box(PAPER), Mats.of("paper", SHEET, 0.95),
			Vector3(0, (HEIGHT - PAPER.y) * 0.5 + PAPER.y * 0.5, paper_z0 + PAPER.z * 0.5)))
	root.add_child(Props.mi(Props.box(LABEL), Mats.of("paper", LABEL_CARD, 0.9),
			Vector3(0, HEIGHT * LABEL_AT, -DEPTH * 0.5 - LABEL.z * 0.5 + 0.0003)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## Put down anywhere but its shelf, a binder lies on its back cover.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)

## The cover in plan: the spine at -Z with its outside corners rounded, the two boards running forward
## to +Z, the whole of it `COVER` thick.
static func _cover_outline() -> PackedVector2Array:
	var hx := SPINE * 0.5
	var back := -DEPTH * 0.5
	var front := DEPTH * 0.5
	var pts := PackedVector2Array()
	# `Props.arc` leaves out its first point; each run's start is added before it.
	pts.append(Vector2(-hx, front))
	pts.append(Vector2(-hx, back + CORNER))
	pts.append_array(Props.arc(Vector2(-hx + CORNER, back + CORNER), Vector2.ONE * CORNER, PI, PI * 1.5, CORNER_STEPS))
	pts.append(Vector2(hx - CORNER, back))
	pts.append_array(Props.arc(Vector2(hx - CORNER, back + CORNER), Vector2.ONE * CORNER, PI * 1.5, TAU, CORNER_STEPS))
	pts.append(Vector2(hx, front))
	pts.append(Vector2(hx - COVER, front))
	var inner := CORNER - COVER
	pts.append(Vector2(hx - COVER, back + CORNER))
	pts.append_array(Props.arc(Vector2(hx - CORNER, back + CORNER), Vector2.ONE * inner, TAU, PI * 1.5, CORNER_STEPS))
	pts.append(Vector2(-hx + CORNER, back + COVER))
	pts.append_array(Props.arc(Vector2(-hx + CORNER, back + CORNER), Vector2.ONE * inner, PI * 1.5, PI, CORNER_STEPS))
	pts.append(Vector2(-hx + COVER, front))
	return pts
