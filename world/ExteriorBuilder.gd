class_name ExteriorBuilder
## The two outdoor zones that are structures rather than paving: the deck and the pool.
##
## Everything else outside is a slab lying on the ground, which `HouseBuilder` already builds
## from the zone polygon. These two cannot be: a deck is held up by something, and a pool is a
## hole. Both are still driven entirely by the plan — `DeckDef` and `PoolDef` name a zone, and
## the geometry comes from that zone's own polygon, so neither can drift away from the room the
## player walks in.

## Boards and beams share one wood; the frame is the same wood read darker, the way a deck's
## underside always is.
const BOARD_TINT := Color(0.86, 0.80, 0.70)
const FRAME_TINT := Color(0.52, 0.46, 0.39)
const FRAME_SLOT := "painted_wood"
## Deck steps use the going and the riser limit the house's own outside steps use, so a flight
## off the deck and a flight off the back door are the same stair.
const STEP_BURY := 0.25
## Tread nosing: each tread runs this far past its riser, which is what puts a shadow line
## under it instead of leaving a stack of flush boxes.
const NOSING := 0.03

# --- Deck -------------------------------------------------------------------------------------

## Boards, rim beam, posts and steps, in place of the flat slab this zone would otherwise get.
static func build_deck(holder: Node3D, plan: FloorPlan, storey: StoreyDef, room: RoomDef,
		deck: DeckDef) -> void:
	var b := HouseBuilder.bounds(room.polygon)
	var top := room.floor_y(storey.base_y)
	var boards: Array = []
	var frame: Array = []

	# Sides that meet the house are tucked into its wall the way an indoor floor is; the free
	# sides stop exactly on the plan line, because that edge is a thing you can see.
	var against := _house_sides(plan, b)
	var deck_rect := b
	for i in range(4):
		if against[i]:
			deck_rect = _grow_side(deck_rect, i, HouseBuilder.SLAB_TUCK)
	boards.append(Props.part(Vector3(deck_rect.size.x, deck.board_thickness, deck_rect.size.y),
			Vector3(deck_rect.get_center().x, top - deck.board_thickness * 0.5, deck_rect.get_center().y)))

	var beam_mid := top - deck.board_thickness - deck.beam_depth * 0.5
	var post_top := top - deck.board_thickness
	for i in range(4):
		if against[i]:
			continue
		var seg := _side_segment(b, i, deck.beam_width * 0.5)
		var along := seg[1] - seg[0]
		var length: float = along.length()
		var mid: Vector2 = (seg[0] + seg[1]) * 0.5
		var horizontal := absf(along.x) > absf(along.y)
		var size := Vector3(length, deck.beam_depth, deck.beam_width) if horizontal \
				else Vector3(deck.beam_width, deck.beam_depth, length)
		frame.append(Props.part(size, Vector3(mid.x, beam_mid, mid.y)))
		# Posts at both ends of the beam and evenly between them, never further apart than
		# post_spacing. A corner post is shared by two beams and lands twice; the second one
		# is exactly inside the first and costs nothing, which is cheaper than tracking them.
		var count := int(ceil(length / deck.post_spacing))
		for k in range(count + 1):
			var t := float(k) / float(count) if count > 0 else 0.5
			var at: Vector2 = seg[0].lerp(seg[1], t)
			at = at.move_toward(mid, deck.post * 0.5)
			var height := post_top - HouseBuilder.GRADE + deck.post_bury
			frame.append(Props.part(Vector3(deck.post, height, deck.post),
					Vector3(at.x, post_top - height * 0.5, at.y)))

	for dir: Vector2 in deck.step_edges:
		_deck_steps(plan, storey, b, top, dir, deck, boards)

	var wood := Mats.of(room.floor_slot, BOARD_TINT, 0.7, 1.0, true)
	HouseBuilder.surface(holder, Props.union(boards), [wood], "Deck", true)
	HouseBuilder.surface(holder, Props.union(frame),
			[Mats.of(FRAME_SLOT, FRAME_TINT, 0.85, 1.0, true)], "DeckFrame", false)

## A flight off one edge of the deck, centred on that edge and cut to the rise it actually has.
static func _deck_steps(plan: FloorPlan, storey: StoreyDef, b: Rect2, top: float, dir: Vector2,
		deck: DeckDef, boards: Array) -> void:
	var i := _side_index(dir)
	var seg := _side_segment(b, i, 0.0)
	var mid: Vector2 = (seg[0] + seg[1]) * 0.5
	var ground := HouseBuilder.ground_level(plan, storey, mid + dir * 0.6)
	var rise := top - ground
	if rise < 0.05:
		return
	var risers := int(ceil(rise / HouseBuilder.STEP_RISER_MAX))
	var riser := rise / float(risers)
	var going := HouseBuilder.STEP_GOING
	for k in range(risers):
		# Counted from the deck outward: tread k sits one riser lower than the one behind it and
		# reaches from the edge to the nose of the next.
		var y := top - riser * float(k + 1)
		var near: float = going * float(k)
		var far: float = going * float(k + 1) + NOSING
		var c: Vector2 = mid + dir * ((near + far) * 0.5)
		var depth := far - near
		var size := Vector3(deck.step_width, riser, depth) if absf(dir.x) < 0.5 \
				else Vector3(depth, riser, deck.step_width)
		# The bottom tread runs down into the ground so no step floats over uneven paving.
		var extra: float = STEP_BURY if k == risers - 1 else 0.0
		boards.append(Props.part(Vector3(size.x, size.y + extra, size.z),
				Vector3(c.x, y + riser * 0.5 - extra * 0.5, c.y)))

## For each side of the deck (0 north, 1 east, 2 south, 3 west), whether the building is on the
## other side of it. Probed rather than authored: room polygons meet on the wall centre line,
## so a point just past a deck edge that meets the house lands inside the room behind the wall.
static func _house_sides(plan: FloorPlan, b: Rect2) -> Array[bool]:
	var out: Array[bool] = [false, false, false, false]
	for i in range(4):
		var seg := _side_segment(b, i, 0.0)
		var probe: Vector2 = (seg[0] + seg[1]) * 0.5 + _side_normal(i) * 0.05
		for room: RoomDef in plan.all_rooms():
			if room.zone == RoomDef.Zone.EXTERIOR:
				continue
			if room.contains(probe):
				out[i] = true
				break
	return out

## The side's two corners, pulled in from the rect edge by `inset` and shortened by it at both
## ends so a beam meets its neighbour rather than crossing it.
static func _side_segment(b: Rect2, i: int, inset: float) -> Array[Vector2]:
	var n := _side_normal(i)
	var centre := b.get_center() + n * (Vector2(b.size.x, b.size.y).dot(n.abs()) * 0.5 - inset)
	var across := Vector2(-n.y, n.x)
	var half: float = Vector2(b.size.x, b.size.y).dot(across.abs()) * 0.5 - inset
	return [centre - across * half, centre + across * half]

static func _side_normal(i: int) -> Vector2:
	return [WallDeriver.NORTH, WallDeriver.EAST, WallDeriver.SOUTH, WallDeriver.WEST][i]

static func _side_index(dir: Vector2) -> int:
	for i in range(4):
		if _side_normal(i).is_equal_approx(dir):
			return i
	push_error("ExteriorBuilder: %s is not a compass direction" % dir)
	return 0

static func _grow_side(r: Rect2, i: int, by: float) -> Rect2:
	var n := _side_normal(i)
	var grown := r
	grown.position += Vector2(minf(n.x, 0.0), minf(n.y, 0.0)) * by
	grown.size += n.abs() * by
	return grown

# --- Pool -------------------------------------------------------------------------------------

## The basin, its coping and its water. The hole these sit in is cut out of the zone's paving by
## `HouseBuilder` and out of the lawn by `TerrainBuilder`, both from `PoolDef.hole()`.
static func build_pool(holder: Node3D, storey: StoreyDef, room: RoomDef, pool: PoolDef) -> void:
	var top := room.floor_y(storey.base_y)
	var r := pool.rect
	var c := r.get_center()
	var t := pool.shell
	var floor_y := top - pool.depth

	# Shell: four walls and a floor, each a solid box with two faces and an edge. An open box of
	# single-sided quads would need CULL_DISABLED, and nothing in this repo relies on that.
	var shell: Array = []
	shell.append(Props.part(Vector3(r.size.x + t * 2.0, t, r.size.y + t * 2.0),
			Vector3(c.x, floor_y - t * 0.5, c.y)))
	for i in range(4):
		var n := _side_normal(i)
		var horizontal := absf(n.x) < 0.5
		var length: float = (r.size.x + t * 2.0) if horizontal else r.size.y
		var size := Vector3(length, pool.depth, t) if horizontal else Vector3(t, pool.depth, length)
		var at := c + n * (Vector2(r.size.x, r.size.y).dot(n.abs()) * 0.5 + t * 0.5)
		shell.append(Props.part(size, Vector3(at.x, floor_y + pool.depth * 0.5, at.y)))

	# Entry steps at the west end, inside the basin: a real pool is climbed out of.
	var step_rise := (pool.depth - pool.water_below) / float(pool.step_count + 1)
	for k in range(pool.step_count):
		var y := top - pool.water_below - step_rise * float(k + 1)
		var going := 0.30
		var depth := going * float(k + 1)
		shell.append(Props.part(Vector3(depth, step_rise, pool.step_width),
				Vector3(r.position.x + depth * 0.5, y + step_rise * 0.5, c.y)))

	# Coping: a band from the water's edge outward, standing proud of the paving. It covers the
	# shell, the joint around it and the cut edge of the lawn in one piece.
	var coping: Array = []
	var outer := r.grow(pool.coping)
	var band := pool.coping
	var cy := top + pool.coping_proud - HouseBuilder.FLOOR_SLAB * 0.5
	var ch := HouseBuilder.FLOOR_SLAB + pool.coping_proud
	coping.append(Props.part(Vector3(outer.size.x, ch, band),
			Vector3(c.x, cy, r.position.y - band * 0.5)))
	coping.append(Props.part(Vector3(outer.size.x, ch, band),
			Vector3(c.x, cy, r.end.y + band * 0.5)))
	coping.append(Props.part(Vector3(band, ch, r.size.y),
			Vector3(r.position.x - band * 0.5, cy, c.y)))
	coping.append(Props.part(Vector3(band, ch, r.size.y),
			Vector3(r.end.x + band * 0.5, cy, c.y)))

	HouseBuilder.surface(holder, Props.union(shell),
			[Mats.of(pool.liner_slot, pool.liner_tint, 0.5, 1.0, true)], "PoolShell", true)
	HouseBuilder.surface(holder, Props.union(coping),
			[Mats.of(pool.coping_slot, pool.coping_tint, 0.9, 1.0, true)], "PoolCoping", true)

	# The water is the volume, not a plane on top of it: its top face is what you see, and its
	# sides and bottom face away from the viewer and are culled, so the liner shows through the
	# tint at the right depth without a second transparent surface to sort against.
	var water := Props.prism(_ring(r.grow(-0.005)), floor_y + 0.02, top - pool.water_below)
	HouseBuilder.surface(holder, water, [_water(pool.water_tint)], "Water", false)

static func _ring(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])

static func _water(tint: Color) -> StandardMaterial3D:
	# Water is the smoothest thing on the property: at 0.03 roughness it takes the sky, which is
	# most of what separates a pool from a pane of blue glass lying in the ground.
	var m := Props.mat(tint, 0.02)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m
