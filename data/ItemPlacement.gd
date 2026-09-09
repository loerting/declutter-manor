class_name ItemPlacement
extends Resource
## Where an item starts the game — the authored wrong place. Every player gets the same house
## and the same hiding places, so this is fixed content and never randomised
## (`docs/ARCHITECTURE.md`, "Items").
##
## `xform` is in plan space when `container` is empty, and in the named container's own local
## space when it is not, so a spoon in a cabinet keeps its position when the cabinet moves.

@export var room: StringName
@export var xform := Transform3D.IDENTITY
## The `ContainerComponent.container_id` this placement is inside, or &"" for out in the open.
@export var container: StringName = &""

static func at(room_id: StringName, position: Vector3, yaw_degrees := 0.0) -> ItemPlacement:
	var p := ItemPlacement.new()
	p.room = room_id
	p.xform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), position)
	return p

static func inside(room_id: StringName, container_id: StringName, position: Vector3,
		yaw_degrees := 0.0) -> ItemPlacement:
	var p := at(room_id, position, yaw_degrees)
	p.container = container_id
	return p
