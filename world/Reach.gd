class_name Reach
## Whether a player standing in the house could pick an item up where it is. `ContentImport` keeps
## authored starts to places that pass, `InteractProbe` proves every start does (`start.reachable`),
## and `LooseItems` sends back an item that was let go of and came to rest where it does not.

## Where a player might stand to reach an item: this many directions round it, at these distances, with
## the feet this far over the floor (a body standing, not lying in it).
const TURNS := 16
const OUT: Array[float] = [0.45, 0.8, 1.2, 1.6]
const FEET := 0.3
## An item seen this far behind the first solid thing on the line is still seen: the ray's hit and the
## item's box are measured on different shapes.
const SKIN := 0.005

## True when a player could pick up an item whose bounds are `box` at `xform`: some eye at standing height
## over `floor_y`, within reach, with nothing solid at its eye or its feet, sees the item before anything
## that stops the interaction ray. Other items do not count: the one in front is picked up first.
static func reachable(space: PhysicsDirectSpaceState3D, plan: FloorPlan, box: AABB, xform: Transform3D,
		floor_y: float) -> bool:
	var centre := xform * box.get_center()
	var local := xform.affine_inverse()
	for step in range(TURNS):
		var a := TAU * float(step) / float(TURNS)
		for out: float in OUT:
			var feet := Vector3(centre.x + cos(a) * out, floor_y + FEET, centre.z + sin(a) * out)
			var eye := Vector3(feet.x, floor_y + Balance.EYE_HEIGHT, feet.z)
			if eye.distance_to(centre) > Balance.INTERACT_REACH or plan.room_at(feet, ProgressSave.ROOM_SLACK) == null:
				continue
			if _solid_at(space, eye) or _solid_at(space, feet):
				continue
			var entry: Variant = box.intersects_segment(local * eye, local * centre)
			if entry == null:
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, centre,
					Layers.interact_mask() & ~Layers.bit(Layers.ITEM)))
			if hit.is_empty() or eye.distance_to(hit["position"] as Vector3) >= eye.distance_to(xform * (entry as Vector3)) - SKIN:
				return true
	return false

static func _solid_at(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at
	q.collision_mask = Layers.bit(Layers.WORLD)
	return not space.intersect_point(q, 1).is_empty()
