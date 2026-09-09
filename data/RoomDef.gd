class_name RoomDef
extends Resource
## A zone: its floor polygon, its surfaces, and the ambience bed it will own in Phase 5.
## One RoomDef is one of the 26 zones in `docs/HOUSE.md`.

enum Zone { INTERIOR, GARAGE, EXTERIOR }

@export var id: StringName
@export var name_key := ""
## Closed polygon in plan metres, no repeated last point.
@export var polygon := PackedVector2Array()
@export var zone: Zone = Zone.INTERIOR

@export var floor_slot := "floor_wood"
@export var ceiling_slot := "ceiling_plaster"
## The finish on every wall face that looks into this room.
@export var wall_slot := "wall_plaster"

@export var has_ceiling := true
## Metres below the storey's base level, for a garage slab or a sunken lounge.
@export var floor_drop := 0.0

## Every interior zone owns its light. It is data rather than a placed node for the same
## reason the walls are: the house is generated, so anything hand-placed would have to be
## kept in step with a plan that moves. In Phase 5 this same fixture carries the room's bulb
## hum, which is why it belongs to the room and not to the lighting pass.
@export var light_energy := 2.4
@export var light_color := Color(1.0, 0.94, 0.86)
## Below the ceiling.
@export var light_offset := 0.35
@export var light_range := 9.0

func centroid() -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in polygon:
		c += p
	return c / maxf(float(polygon.size()), 1.0)

func area() -> float:
	var s := 0.0
	for i in range(polygon.size()):
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5

func contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, polygon)

func floor_y(storey_base: float) -> float:
	return storey_base - floor_drop

static func rect(room_id: StringName, key: String, x0: float, z0: float, x1: float, z1: float) -> RoomDef:
	var r := RoomDef.new()
	r.id = room_id
	r.name_key = key
	r.polygon = PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
	return r
