extends Node3D
## Proves that every item type lands: one of each, let go of in `TURNS` different turns over a floor built
## the way the house builds one, comes to rest lying on it — not sunk into it, not through it, not still
## tumbling. A thin item that tips over is the case this exists for: a TV remote landing on its end spun
## at 40 rad/s, came to rest 2 cm inside the floor with the engine's default penetration slop, and fell
## through a floor that was only a surface (2026-09-16).
##
##     godot --headless --path . dev/DropProbe.tscn
##
## Exit code is the number of violations. Where an item lands in the house, and what happens to one that
## lands out of reach, is `InteractProbe`'s (`carry.*`).

## Each item is let go of this high over the floor, turned by each of these, as Euler angles in radians.
const DROP_HEIGHT := 1.2
const TURNS: Array[Vector3] = [Vector3.ZERO, Vector3(0.9, 2.1, 0.6), Vector3(1.8, 4.2, 1.2)]
## Items are this far apart, so none lands on another: the longest item is 1.52 m.
const SPACING := 1.8
## A resting item's lowest point is within this of the floor's surface: the engine's contact margin.
const LIE_EPS := 0.003
## Seconds of wall clock the whole drop is given to come to rest.
const TIMEOUT := Balance.LOOSE_SETTLE_LIMIT + 4.0

var _violations := 0

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	var content := WorldBuilder.catalogue(ManorPlan.build())
	var types: Array[ItemDef] = []
	for s: SetDef in content.sets:
		types.append(content.members(s.id)[0])
	var count := types.size() * TURNS.size()
	# A square of floors a room wide each, the way the house is floored: one floor 100 m long is a mesh of
	# two triangles 100 m long, which no room has.
	var side := int(ceil(sqrt(float(count))))
	var dropped: Array[ItemNode] = []
	for k in range(count):
		var cell := Vector2(SPACING * float(k % side), SPACING * float(k / side))
		var area := PackedVector2Array([cell - Vector2.ONE * SPACING * 0.5, cell + Vector2(SPACING, -SPACING) * 0.5,
				cell + Vector2.ONE * SPACING * 0.5, cell + Vector2(-SPACING, SPACING) * 0.5])
		HouseBuilder.surface(self, Props.prism(area, -HouseBuilder.FLOOR_SLAB, 0.0), [], "Floor%d" % k, true)
		HouseBuilder.backing(self, area, -HouseBuilder.FLOOR_SLAB, 0.0, "Floor%dBacking" % k)
		var item := ItemFactory.build(types[k % types.size()])
		add_child(item)
		item.global_transform = Transform3D(Basis.from_euler(TURNS[k / types.size()]),
				Vector3(cell.x, DROP_HEIGHT, cell.y))
		item.let_go(Vector3.ZERO)
		dropped.append(item)
	var until := Time.get_ticks_msec() + int(TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < until and dropped.any(func(i: ItemNode) -> bool: return not i.sleeping):
		await get_tree().physics_frame
	var worst := 0.0
	for k in range(dropped.size()):
		var item := dropped[k]
		var turn := k / types.size()
		if not item.sleeping:
			_fail("drop.rest", "%s in turn %d still moving after %.0f s" % [item.def.set_id, turn, TIMEOUT])
		# The mesh, not the hull: what the player sees lying in the floor is the mesh.
		var lowest := item.global_position.y + ItemFactory.bounds(item.def, item.global_basis).position.y
		worst = maxf(worst, absf(lowest))
		if absf(lowest) > LIE_EPS:
			_fail("drop.lies", "%s in turn %d lies %.4f m off the floor" % [item.def.set_id, turn, lowest])
	print("  %d types in %d turns, worst %.4f m off the floor" % [types.size(), TURNS.size(), worst])
	print("")
	print("DropProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)
