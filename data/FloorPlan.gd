class_name FloorPlan
extends Resource
## The only description of the building. Interior geometry, exterior shell, collision,
## occluders, zone list and ambience beds are all read from this one resource — see
## `docs/ARCHITECTURE.md`, "The house is data".

@export var id: StringName
@export var storeys: Array[StoreyDef] = []
@export var roofs: Array[RoofDef] = []

## Outside finishes, used by every wall face whose side is outdoors. The tint is what gives the
## house a colour: the CC0 scan is near-neutral so one texture serves any colourway.
@export var siding_slot := "painted_wood"
@export var siding_tint := Color(0.80, 0.82, 0.73)
@export var ground_slot := "lawn"
## Plan-space extent of the lot, used for terrain and for the probe's bounds checks.
@export var lot := Rect2(0, 0, 26, 19)

func all_rooms() -> Array[RoomDef]:
	var out: Array[RoomDef] = []
	for s: StoreyDef in storeys:
		out.append_array(s.rooms)
	return out

func find_room(room_id: StringName) -> RoomDef:
	for s: StoreyDef in storeys:
		var r := s.room(room_id)
		if r != null:
			return r
	return null

func storey_of(room_id: StringName) -> StoreyDef:
	for s: StoreyDef in storeys:
		if s.room(room_id) != null:
			return s
	return null

## Identity of the built house, stored in every save. A save whose hash differs is migrated,
## never discarded (`docs/ARCHITECTURE.md`, "Save format contract"), so this must change when
## the geometry changes and must not change when it does not — hence a canonical text form
## rather than object hashing, which is not stable across runs.
func plan_hash() -> String:
	var parts := PackedStringArray()
	for s: StoreyDef in storeys:
		parts.append("S|%s|%.3f|%.3f" % [s.id, s.base_y, s.height])
		for r: RoomDef in s.rooms:
			var poly := PackedStringArray()
			for p: Vector2 in r.polygon:
				poly.append("%.3f,%.3f" % [p.x, p.y])
			parts.append("R|%s|%d|%s" % [r.id, r.zone, ";".join(poly)])
		for w: WallSegment in s.walls:
			parts.append("W|%.3f,%.3f|%.3f,%.3f|%s|%s|%d" % [
				w.a.x, w.a.y, w.b.x, w.b.y, w.room_a, w.room_b, w.openings.size()])
			for o: Opening in w.openings:
				parts.append("O|%d|%.3f|%.3f|%.3f|%.3f" % [o.kind, o.at, o.width, o.height, o.sill])
	for r: RoofDef in roofs:
		parts.append("F|%d|%s|%.3f|%.3f|%s" % [r.kind, r.footprint, r.eave_y, r.pitch_deg, r.ridge_along_x])
	return "\n".join(parts).sha256_text().substr(0, 16)
