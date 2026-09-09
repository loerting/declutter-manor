class_name DeckDef
extends Resource
## A raised timber deck laid over an exterior zone. The zone itself is an ordinary `RoomDef`
## with `floor_drop` 0, so it is level with the finished floor inside and a door onto it needs
## no steps; this resource is only the structure that holds it up, which `ExteriorBuilder`
## builds instead of the flat paving slab every other exterior zone gets.
##
## Joists are not modelled. Under a platform 0.45 m off the ground nothing but the rim beam and
## the posts is ever visible, and the same reasoning keeps stringers off the stairs.

## The exterior zone this deck surfaces.
@export var room: StringName
## Decking boards, and the rim beam they sit on. The beam is what reads as structure from the
## garden: without it the deck is a sheet of wood hovering over grass.
@export var board_thickness := 0.045
@export var beam_depth := 0.22
@export var beam_width := 0.06
## Posts: section, and the greatest gap allowed between two of them along a free edge.
@export var post := 0.12
@export var post_spacing := 2.0
## How far a post is set into the ground. Nothing floats and nothing sits on the turf.
@export var post_bury := 0.12
## Compass directions (`WallDeriver.NORTH` and friends) whose edge gets a flight down to the
## ground. An edge that meets the house never does.
@export var step_edges: Array[Vector2] = []
@export var step_width := 1.6

static func make(zone: StringName, steps: Array[Vector2]) -> DeckDef:
	var d := DeckDef.new()
	d.room = zone
	d.step_edges = steps
	return d
