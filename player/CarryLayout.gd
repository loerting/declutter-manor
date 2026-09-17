class_name CarryLayout
## Where each carried item is held out on screen, worked out on paper: the rectangles only, in screen
## heights (the screen is 1 high and `aspect` wide, 0 at the bottom edge and at the vertical centre line).
## `CarryView` turns them into places in front of the eye; `dev/tests/RunTests.gd` proves they never meet.
##
## The items are two hands: the row of carried items, in the order taken, split at the bottom centre,
## the first half to the left of the carry bar and the rest to its right, so a single item is held in the
## right hand. Each hand packs its items into rows from the bottom up, centred in the space beside the bar
## and never higher than `Balance.HAND_TOP`, so the crosshair, the prompt and the item card always have the
## middle of the screen. When a hand's rows do not fit, every item in both hands shrinks alike.

## `footprints` are each item's width and height at full size, in screen heights. Returns one rectangle per
## item, in the same order, each already grown by the room the selected one needs to stand out
## (`Balance.HAND_SELECT_SCALE`), so drawn at any selection nothing overlaps.
static func arrange(footprints: Array[Vector2], aspect: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.resize(footprints.size())
	if footprints.is_empty():
		return out
	var left := int(footprints.size() / 2.0)
	var scale := 1.0
	while true:
		# Both hands every time, so the rectangles a crowded hand ends on are the ones it was packed into.
		var left_fits := _pack(footprints, 0, left, _side(aspect, true), scale, out)
		var right_fits := _pack(footprints, left, footprints.size(), _side(aspect, false), scale, out)
		if (left_fits and right_fits) or scale <= Balance.HAND_MIN_SCALE:
			return out
		scale = maxf(scale * Balance.HAND_SHRINK_STEP, Balance.HAND_MIN_SCALE)
	return out

## The rectangle a hand's items are packed into.
static func _side(aspect: float, left: bool) -> Rect2:
	var width := aspect * 0.5 - Balance.HAND_EDGE - Balance.HAND_CENTRE_CLEAR
	var x := -aspect * 0.5 + Balance.HAND_EDGE if left else Balance.HAND_CENTRE_CLEAR
	return Rect2(x, Balance.HAND_BOTTOM, maxf(width, 0.0), Balance.HAND_TOP - Balance.HAND_BOTTOM)

## Packs items `from` to `to` into `region` in rows, bottom row first, each row bottom-aligned and centred.
## False when they do not fit at `scale`; the rectangles are written either way.
static func _pack(footprints: Array[Vector2], from: int, to: int, region: Rect2, scale: float,
		out: Array[Rect2]) -> bool:
	var grow := Balance.HAND_SELECT_SCALE
	var fits := true
	var rows: Array[Vector2i] = []
	var start := from
	var width := 0.0
	for i: int in range(from, to):
		var w := footprints[i].x * scale * grow
		fits = fits and w <= region.size.x
		var added := w if i == start else width + Balance.HAND_GAP + w
		if i > start and added > region.size.x:
			rows.append(Vector2i(start, i))
			start = i
			width = w
		else:
			width = added
	if to > from:
		rows.append(Vector2i(start, to))
	var y := region.position.y
	for row: Vector2i in rows:
		var row_width := 0.0
		var row_height := 0.0
		for i: int in range(row.x, row.y):
			var size := footprints[i] * scale * grow
			row_width += size.x + (Balance.HAND_GAP if i > row.x else 0.0)
			row_height = maxf(row_height, size.y)
		var x := region.position.x + (region.size.x - row_width) * 0.5
		for i: int in range(row.x, row.y):
			var size := footprints[i] * scale * grow
			out[i] = Rect2(x, y, size.x, size.y)
			x += size.x + Balance.HAND_GAP
		y += row_height + Balance.HAND_GAP
	return fits and y - Balance.HAND_GAP <= region.end.y + 0.0001

## How big an item of this size is held out, in screen heights: bigger for a bigger item, but by far less
## than it really is, so a spoon can be seen and a television still leaves the room it is carried through.
static func held_size(metres: float) -> float:
	var size := Balance.HAND_SIZE_REF * pow(maxf(metres, 0.001) / Balance.HAND_SIZE_REF_METRES,
			Balance.HAND_SIZE_EXPONENT)
	return clampf(size, Balance.HAND_SIZE_MIN, Balance.HAND_SIZE_MAX)
