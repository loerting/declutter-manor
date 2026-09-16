class_name FurnitureDef
extends Resource
## One piece of furniture: what builds it, the room it stands in, where in that room, and the
## place-slot groups it carries. Data, never code, for the same reason an item is
## (`docs/ARCHITECTURE.md`, "Furniture"): 55 homes are 55 resources, not 55 functions.
##
## Where a piece stands is said relative to a wall of its room, never as a position — so a room
## that moves or grows takes its furniture with it, the way the kitchen run always has.
##
## `id` names the piece's containers (`<id>_<part>`), which a save and an item's start refer to.
## It has the same rule as an item's id: fixed at authoring time, never reused.

## The wall the piece's back is against. Its front faces into the room.
enum Wall { NORTH, EAST, SOUTH, WEST }
## Which end of that wall `along` is measured from, by the compass rather than by the viewer:
## START is the west end of a north or south wall and the north end of an east or west wall, END
## the other. CENTRE measures from the middle of the wall to the middle of the piece.
enum Align { START, CENTRE, END }

@export var id: StringName
## The family in `FurnitureFactory` that builds it.
@export var generator: StringName
## The family's parameters. What a generator accepts is documented on the generator.
@export var params: Dictionary = {}
@export var room: StringName
@export var wall: Wall = Wall.NORTH
@export var align: Align = Align.CENTRE
## Metres from the face of the wall at the aligned end to the piece's near edge (START, END), or
## from the wall's middle to the piece's middle, positive towards the END (CENTRE).
@export var along := 0.0
## Metres between the wall's face and the piece's back: 0 stands it against the plaster, 1.2
## stands a sofa out in the room with its back to that wall.
@export var out := 0.0
## An extra turn about the piece's own origin, for a chair set at an angle. Degrees, anticlockwise
## seen from above.
@export var turn_degrees := 0.0
## The homes this piece carries. Each names the anchor it hangs from (`PlaceSlotGroup.anchor`).
@export var slots: Array[PlaceSlotGroup] = []
