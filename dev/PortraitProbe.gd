extends Node
## The item pictures (`Portraits`), rendered from the manor's catalogue the way the game renders them, and
## measured cell by cell. It needs a renderer: headless, there are no pictures to measure.
##
##     godot --path . dev/PortraitProbe.tscn [-- --screenshot=/abs/atlas.png]
##
##     portrait.renderer  the probe is not running headless
##     portrait.every     every item of the catalogue has a picture, and two item types never share one
##     portrait.fills     each picture's drawn part spans at least `FILL_MIN` of its cell the long way, so no
##                        item is a speck, and leaves the cell's outer `EDGE` pixels clear, so none is cut off
##     portrait.visible   at least `LIGHT_SHARE_MIN` of each picture's drawn part is lighter than `LIGHT`, so a
##                        black item does not vanish into the dark card
##     portrait.time      the pictures are ready within `Balance.PORTRAIT_BUDGET_MS` of being asked for
##     portrait.card      the item card shows the picture of the item it describes, and the carry bar draws
##                        each carried item's picture inside its block
##
## `--screenshot` saves the atlas over the colour of the card, for the eye.

const CARD := preload("res://ui/ItemCard.tscn")
const BAR := preload("res://ui/CarryBar.tscn")
const FILL_MIN := 0.7
const EDGE := 2
const LIGHT := 0.5
const LIGHT_SHARE_MIN := 0.05
## Roughly the card's glass over a dark room, which is what a picture is seen against.
const CARD_COLOUR := Color(0.16, 0.145, 0.13)

var _violations := 0

func _ready() -> void:
	_ok("portrait.renderer", DisplayServer.get_name() != "headless", "run it without --headless")
	if _violations == 0:
		await _check(WorldBuilder.catalogue(ManorPlan.build()))
	print("PortraitProbe: %d violation(s)" % _violations)
	get_tree().quit(1 if _violations > 0 else 0)

func _check(content: Catalogue) -> void:
	# The game builds every item's meshes before it asks for pictures (`GameWorld`); so does the probe, so the
	# time measured is the pictures' own.
	var kinds: Array[ItemDef] = []
	var seen: Dictionary[String, bool] = {}
	for def: ItemDef in content.items:
		ItemFactory.extent(def)
		var key := Params.key(def.generator, def.params)
		if not seen.has(key):
			seen[key] = true
			kinds.append(def)
	var portraits := Portraits.new()
	add_child(portraits)
	var t0 := Time.get_ticks_msec()
	portraits.render(content.items)
	await portraits.rendered
	var ms := Time.get_ticks_msec() - t0
	_ok("portrait.time", ms <= Balance.PORTRAIT_BUDGET_MS, "%d item types took %d ms" % [kinds.size(), ms])
	print("portrait.time %d item types in %d ms" % [kinds.size(), ms])

	var regions: Dictionary[Rect2, String] = {}
	for def: ItemDef in content.items:
		var picture := portraits.of(def) as AtlasTexture
		if not _ok("portrait.every", picture != null, "'%s' has no picture" % def.id):
			continue
		var key := Params.key(def.generator, def.params)
		_ok("portrait.every", regions.get(picture.region, key) == key,
				"'%s' shares its picture with another item type" % def.id)
		regions[picture.region] = key

	var atlas := portraits.atlas()
	var worst_fill := 1.0
	var worst_light := 1.0
	for def: ItemDef in kinds:
		var picture := portraits.of(def) as AtlasTexture
		if picture == null:
			continue
		var region := Rect2i(picture.region)
		var m := _measure(atlas, region)
		worst_fill = minf(worst_fill, m.x)
		worst_light = minf(worst_light, m.z)
		_ok("portrait.fills", m.x >= FILL_MIN, "'%s' spans %.2f of its cell" % [def.id, m.x])
		_ok("portrait.fills", m.y == 0.0, "'%s' reaches %d pixels into its cell's edge" % [def.id, int(m.y)])
		_ok("portrait.visible", m.z >= LIGHT_SHARE_MIN, "'%s' is %.3f light" % [def.id, m.z])
	print("portrait.fills worst %.2f, portrait.visible worst %.3f" % [worst_fill, worst_light])
	_check_card(content, portraits)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			var shot := Image.create(atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8)
			shot.fill(CARD_COLOUR)
			var flat := atlas.duplicate() as Image
			flat.clear_mipmaps()
			shot.blend_rect(flat, Rect2i(Vector2i.ZERO, flat.get_size()), Vector2i.ZERO)
			shot.save_png(arg.trim_prefix("--screenshot="))

## For one cell: how far its drawn part spans the long way, as a share of the cell; how many drawn pixels lie
## in its outer `EDGE` pixels; and what share of its drawn pixels is lighter than `LIGHT`.
func _measure(atlas: Image, region: Rect2i) -> Vector3:
	var drawn := Rect2i()
	var any := false
	var count := 0
	var light := 0
	var edge := 0
	var inner := region.grow(-EDGE)
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var c := atlas.get_pixel(x, y)
			if c.a < 0.5:
				continue
			count += 1
			if c.get_luminance() > LIGHT:
				light += 1
			if not inner.has_point(Vector2i(x, y)):
				edge += 1
			drawn = Rect2i(x, y, 1, 1) if not any else drawn.expand(Vector2i(x, y)).merge(Rect2i(x, y, 1, 1))
			any = true
	return Vector3(maxf(drawn.size.x, drawn.size.y) / float(region.size.x), edge, light / maxf(count, 1.0))

func _check_card(content: Catalogue, portraits: Portraits) -> void:
	var card := CARD.instantiate() as ItemCard
	add_child(card)
	var def := content.items[0]
	card.show_item(def, content, ManorPlan.build(), 0, portraits.of(def))
	_ok("portrait.card", card.picture() == portraits.of(def) and card.picture() != null,
			"the card for '%s' does not show its picture" % def.id)
	var bar := BAR.instantiate() as CarryBar
	add_child(bar)
	var carried: Array[ItemDef] = [content.items[0], content.items[1]]
	var pictures: Array[Texture2D] = [portraits.of(carried[0]), portraits.of(carried[1])]
	bar.show_load(carried, 8, 0, pictures)
	var blocks := bar.cells().blocks()
	for k: int in carried.size():
		var at := bar.cells().picture_rect(k)
		_ok("portrait.card", at.has_area() and blocks[k].encloses(at),
				"the carry bar draws carried item %d's picture at %s, its block is %s" % [k, at, blocks[k]])
	card.queue_free()
	bar.queue_free()

func _ok(check: String, condition: bool, detail: String) -> bool:
	if not condition:
		_violations += 1
		print("  VIOLATION [%s] %s" % [check, detail])
	return condition
