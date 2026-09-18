class_name StoreyDef
extends Resource
## One level of the building. Storeys stack by `base_y`; nothing anywhere else knows how tall
## a floor is.

@export var id: StringName
## What the player calls it: "Ground floor".
@export var name_key := ""
## World Y of this storey's finished floor surface.
@export var base_y := 0.0
## Finished floor to finished ceiling.
@export var height := 2.7
## Structural depth between this ceiling and the next storey's floor. `HouseBuilder.FOUNDATION`
## assumes this value; change both or neither.
@export var slab_thickness := 0.35

@export var rooms: Array[RoomDef] = []
@export var walls: Array[WallSegment] = []

func room(room_id: StringName) -> RoomDef:
	for r: RoomDef in rooms:
		if r.id == room_id:
			return r
	return null

func ceiling_y() -> float:
	return base_y + height
