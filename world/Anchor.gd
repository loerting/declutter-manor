class_name Anchor
extends Node3D
## A named place on a piece of furniture: where a place-slot group hangs, or where an item starts. It
## hangs on the part it belongs to, so a place on a fridge door swings with the door and a place in a
## drawer slides with the drawer (`FurnitureNode.add_anchor`).

## Every anchor in the world. A start or a save finds its anchor by id, never by a path into furniture
## that is generated (rule 5).
const GROUP := &"anchors"

## `<piece id>_<name>`: unique in the house the way a container's id is, and what a start and a save name.
var anchor_id: StringName
## The container this place belongs to, or null: what a group here asks whether it is open.
var container: ContainerComponent
## True when this place is on the container's moving part rather than on the static half beside it. An
## item that starts here is written against the anchor, so it travels with the part (`ItemPlacement`).
var rides := false

func initialize(id: StringName, owner_container: ContainerComponent, on_the_mover: bool) -> void:
	anchor_id = id
	container = owner_container
	rides = on_the_mover
	add_to_group(GROUP)
