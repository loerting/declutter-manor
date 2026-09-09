class_name Opening
extends Resource
## A hole in a wall. Defined exactly once, on exactly one WallSegment, and consumed by that
## segment's single mesh — so an opening cannot exist on the inside of the house and not on
## the outside. That is the whole point of `docs/VISION.md`'s "one floor plan, two sides".

enum Kind { DOOR, WINDOW, ARCH, GARAGE_DOOR }

@export var kind: Kind = Kind.WINDOW
## Centre of the opening, in metres along the wall measured from the segment's point a.
@export var at := 1.0
@export var width := 1.2
@export var height := 1.4
## Bottom edge above the storey's finished floor. Doors, arches and garage doors sit at 0.
@export var sill := 0.9
## Windows get glazing and both-side trim; a doorway does not.
@export var glazed := true
## Reveal trim (frame) is drawn around the hole. Arches are trimless.
@export var trimmed := true

func bottom() -> float:
	return 0.0 if kind != Kind.WINDOW else sill

func top() -> float:
	return bottom() + height

func u0() -> float:
	return at - width * 0.5

func u1() -> float:
	return at + width * 0.5

## Named constructors, so a plan reads as a description of a building rather than as field
## assignments. Every dimension a plan does not state comes from here.
static func door(at_u: float, w := 0.9, h := 2.05) -> Opening:
	var o := Opening.new()
	o.kind = Kind.DOOR
	o.at = at_u
	o.width = w
	o.height = h
	o.sill = 0.0
	o.glazed = false
	return o

static func arch(at_u: float, w := 1.4, h := 2.2) -> Opening:
	var o := door(at_u, w, h)
	o.kind = Kind.ARCH
	o.trimmed = false
	return o

static func window(at_u: float, w := 1.2, h := 1.4, sill_h := 0.9) -> Opening:
	var o := Opening.new()
	o.kind = Kind.WINDOW
	o.at = at_u
	o.width = w
	o.height = h
	o.sill = sill_h
	return o

static func garage_door(at_u: float, w := 4.2, h := 2.2) -> Opening:
	var o := Opening.new()
	o.kind = Kind.GARAGE_DOOR
	o.at = at_u
	o.width = w
	o.height = h
	o.sill = 0.0
	o.glazed = false
	return o
