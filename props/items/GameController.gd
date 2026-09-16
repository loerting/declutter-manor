extends ItemGenerator
## A gamepad lying on its grips, the shoulder buttons at the -Z edge: one moulded shell whose grips
## hang down and back, two thumbsticks with dished caps, a d-pad, four face buttons, a guide
## button, and bumpers over triggers along the top edge.
##
##     tint    Color    shell colour, default BLACK

## The shell's outline: a body, and a grip each side reaching back and out.
const BODY_CENTRE := Vector2(0.0, -0.01)
const BODY_HALF := Vector2(0.058, 0.036)
const BODY_ROUNDNESS := 3.2
const GRIP_CENTRE := Vector2(0.05, 0.022)
const GRIP_RADII := Vector2(0.028, 0.042)
const GRIP_TURN_DEG := 22.0
## Heights: the face at the middle, how far the grips' undersides hang and their tops fall away.
const TOP := 0.03
const FACE_FALL := 0.005
const GRIP_DROP := 0.022
const EDGE := 2.6

const STICK_AT := [Vector2(-0.036, -0.014), Vector2(0.021, 0.012)]
const STICK_RADIUS := 0.0085
const STICK_HEIGHT := 0.012
const DPAD_AT := Vector2(-0.021, 0.012)
const DPAD_ARM := Vector2(0.0205, 0.0068)
const FACE_AT := Vector2(0.036, -0.014)
const FACE_SPREAD := 0.0095
const FACE_RADIUS := 0.0042
const GUIDE_AT := Vector2(0.0, -0.028)
const GUIDE_RADIUS := 0.0055
const BUMPER_AT := Vector2(0.043, -0.041)
const BUMPER_SIZE := Vector3(0.036, 0.009, 0.014)
const BUMPER_TURN_DEG := 12.0
const BUTTON_HEIGHT := 0.0028
const SINK := 0.001

const BLACK := Color(0.045, 0.045, 0.05)
const WHITE := Color(0.88, 0.88, 0.86)
const GREY := Color(0.16, 0.16, 0.17)
const NEAR_BLACK := Color(0.02, 0.02, 0.022)
const GUIDE := Color(0.75, 0.75, 0.72)
const FACE_COLOURS: Array[Color] = [Color(0.2, 0.55, 0.25), Color(0.7, 0.16, 0.12), Color(0.18, 0.35, 0.7),
		Color(0.8, 0.65, 0.12)]

func build(def: ItemDef) -> Node3D:
	var tint := Params.colour(def.params, "tint", BLACK)
	var root := Node3D.new()
	var shell := Props.moulded(_radius, _bottom, _top, EDGE, Vector2.ONE, 96, 14)
	var body := Node3D.new()
	# The grips hang lowest, by less than their full drop once the edge is rolled over.
	body.position = Vector3(0, -shell.get_aabb().position.y, 0)
	root.add_child(body)
	body.add_child(Props.mi(shell, Props.mat(tint, 0.5)))

	var dark := Props.mat(GREY if tint.v > 0.5 else NEAR_BLACK, 0.6)
	var parts: Array = []
	for at: Vector2 in STICK_AT:
		parts.append([_stick(), Transform3D(Basis.IDENTITY, _on_face(at))])
	var cross: Array = [
		[Props.rounded_box(Vector3(DPAD_ARM.x, BUTTON_HEIGHT + SINK, DPAD_ARM.y), 0.0012, 4, 12), Transform3D.IDENTITY],
		[Props.rounded_box(Vector3(DPAD_ARM.y, BUTTON_HEIGHT + SINK, DPAD_ARM.x), 0.0012, 4, 12), Transform3D.IDENTITY],
	]
	parts.append([Props.bake(cross), Transform3D(Basis.IDENTITY, _on_face(DPAD_AT) + Vector3(0, (BUTTON_HEIGHT + SINK) * 0.5, 0))])
	for side: float in [-1.0, 1.0]:
		var turn := Basis(Vector3.UP, side * deg_to_rad(BUMPER_TURN_DEG))
		var at := Vector2(side * BUMPER_AT.x, BUMPER_AT.y)
		parts.append([Props.rounded_box(BUMPER_SIZE, 0.004, 6, 16),
				Transform3D(turn, Vector3(at.x, _top.call(at) - BUMPER_SIZE.y * 0.6, at.y))])
	body.add_child(Props.mi(Props.bake(parts), dark))

	var guide := Props.mi(_button(GUIDE_RADIUS), Props.mat(GUIDE, 0.3), _on_face(GUIDE_AT))
	body.add_child(guide)
	var offsets := [Vector2(0, FACE_SPREAD), Vector2(FACE_SPREAD, 0), Vector2(-FACE_SPREAD, 0), Vector2(0, -FACE_SPREAD)]
	for i in range(4):
		body.add_child(Props.mi(_button(FACE_RADIUS), Props.mat(FACE_COLOURS[i], 0.35), _on_face(FACE_AT + (offsets[i] as Vector2))))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": BLACK if index % 2 == 0 else WHITE}

func _on_face(at: Vector2) -> Vector3:
	return Vector3(at.x, float(_top.call(at)) - SINK, at.y)

## The outline's distance from the origin: whichever of the body and the two grips reaches
## further along the ray.
func _radius(theta: float) -> float:
	var dir := Vector2(cos(theta), sin(theta))
	var reach := _superellipse_reach(dir)
	for side: float in [-1.0, 1.0]:
		reach = maxf(reach, _ellipse_reach(dir, Vector2(side * GRIP_CENTRE.x, GRIP_CENTRE.y), GRIP_RADII,
				side * deg_to_rad(GRIP_TURN_DEG)))
	return reach

func _superellipse_reach(dir: Vector2) -> float:
	# From the body's own centre, then moved back to the origin along the ray, which is close
	# enough for an outline this near round.
	var from_centre := Props.superellipse(atan2(dir.y, dir.x), BODY_HALF, BODY_ROUNDNESS)
	return from_centre + dir.dot(BODY_CENTRE)

## The far crossing of a ray from the origin with a turned ellipse, or 0 when it misses.
func _ellipse_reach(dir: Vector2, centre: Vector2, radii: Vector2, turn: float) -> float:
	var o := (-centre).rotated(-turn) / radii
	var d := dir.rotated(-turn) / radii
	var a := d.dot(d)
	var b := 2.0 * o.dot(d)
	var c := o.dot(o) - 1.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return 0.0
	return maxf(0.0, (-b + sqrt(disc)) / (2.0 * a))

func _grip(p: Vector2) -> float:
	return smoothstep(0.0, 0.05, p.y) * smoothstep(0.018, 0.058, absf(p.x))

func _bottom(p: Vector2) -> float:
	return -GRIP_DROP * _grip(p)

func _top(p: Vector2) -> float:
	return TOP - FACE_FALL * smoothstep(0.0, 0.05, p.y) - GRIP_DROP * 0.5 * _grip(p)

static func _stick() -> ArrayMesh:
	# A neck, and a cap with a dished top and a rim.
	return Props.lathe(PackedVector2Array([Vector2(STICK_RADIUS * 0.55, 0), Vector2(STICK_RADIUS * 0.55, STICK_HEIGHT * 0.55),
			Vector2(STICK_RADIUS, STICK_HEIGHT * 0.62), Vector2(STICK_RADIUS, STICK_HEIGHT * 0.95),
			Vector2(STICK_RADIUS * 0.85, STICK_HEIGHT), Vector2(STICK_RADIUS * 0.5, STICK_HEIGHT * 0.9),
			Vector2(0, STICK_HEIGHT * 0.87)]), 24)

static func _button(radius: float) -> ArrayMesh:
	var h := BUTTON_HEIGHT + SINK
	return Props.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, h * 0.6),
			Vector2(radius * 0.8, h), Vector2(0, h)]), 20)
