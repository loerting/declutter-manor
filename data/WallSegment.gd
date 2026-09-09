class_name WallSegment
extends Resource
## One wall, built as one mesh with two faces and a rim. It is never two walls that happen to
## agree; `room_a` and `room_b` name what is on each side and the materials follow from that,
## which is why the outside of the house cannot drift away from the inside.

## Plan endpoints, in metres. Plan (x, y) maps to world (x, ·, y); north is -Z.
@export var a := Vector2.ZERO
@export var b := Vector2.ZERO
@export var thickness := 0.20

## What is on each side. `&""` means outdoors. Side A is the side on your RIGHT when walking
## from a to b — `dev/PlanProbe.gd` checks that against the named rooms' actual positions, so
## getting this backwards is caught rather than rendered.
@export var room_a: StringName = &""
@export var room_b: StringName = &""

@export var openings: Array[Opening] = []

## 0 takes the storey's height. Used for a knee wall, a parapet or a garage with its own head
## height.
@export var height_override := 0.0

## Height of a triangular top above the wall's head, peaking at the middle of the wall. It is
## what closes a room whose ceiling is the roof: the attic's end walls stop at knee height and
## the roof above them keeps climbing to the ridge, so a rectangular wall leaves a triangle of
## the roof void open to the room. The plan sets it, because only the plan knows the pitch.
@export var gable_rise := 0.0

func dir() -> Vector2:
	return (b - a).normalized()

func length() -> float:
	return a.distance_to(b)

## Unit plan normal pointing at side A.
func normal() -> Vector2:
	var d := dir()
	return Vector2(-d.y, d.x)

func midpoint() -> Vector2:
	return (a + b) * 0.5

func is_exterior() -> bool:
	return room_a == &"" or room_b == &""

## Point at distance `u` along the wall.
func at_u(u: float) -> Vector2:
	return a + dir() * u

static func make(pa: Vector2, pb: Vector2, side_a: StringName, side_b: StringName,
		openings_in: Array[Opening] = [], thick := 0.20) -> WallSegment:
	var w := WallSegment.new()
	w.a = pa
	w.b = pb
	w.room_a = side_a
	w.room_b = side_b
	w.openings = openings_in
	w.thickness = thick
	return w
