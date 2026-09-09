class_name StairDef
extends Resource
## A flight connecting two rooms on adjacent storeys. Stairs are data for the same reason walls
## are: `dev/PlanProbe.gd` needs to know that the basement is reachable, and a staircase that is
## only geometry cannot be asked.

@export var lower_room: StringName
@export var upper_room: StringName
## Plan position of the bottom step's front edge, at its centre.
@export var foot := Vector2.ZERO
## Horizontal direction of travel going UP. Should be axis-aligned.
@export var direction := Vector2(0, 1)
@export var width := 1.0
## Total horizontal run. The rise comes from the storeys, so a flight cannot disagree with the
## floor it lands on.
@export var run := 3.6
@export var tread_slot := "floor_wood"

## Plan rectangle the flight occupies. It is also the stairwell: the hole in the floor above
## and the ceiling below, so the flight arrives somewhere instead of into a slab.
func footprint() -> Rect2:
	var across := Vector2(-direction.y, direction.x) * width * 0.5
	var head := foot + direction * run
	var r := Rect2(foot + across, Vector2.ZERO)
	for p: Vector2 in [foot - across, head + across, head - across] as Array[Vector2]:
		r = r.expand(p)
	return r

func head() -> Vector2:
	return foot + direction * run

## A comfortable domestic pitch is about 17 cm of rise to 28 cm of going; the step count is
## derived from the actual storey rise so it always lands flush.
static func step_count(rise: float) -> int:
	return maxi(2, int(round(rise / 0.175)))

static func make(lower: StringName, upper: StringName, foot_at: Vector2, dir: Vector2,
		run_len := 3.6, w := 1.0) -> StairDef:
	var s := StairDef.new()
	s.lower_room = lower
	s.upper_room = upper
	s.foot = foot_at
	s.direction = dir.normalized()
	s.run = run_len
	s.width = w
	return s
