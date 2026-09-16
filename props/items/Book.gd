extends ItemGenerator
## A hardback book, standing, its spine to -Z.
##
##     tint     Color    cover colour, default Props.TERRACOTTA
##     width    float    thickness across the spine in metres, default 0.14
##     height   float    metres, default 0.21
##     bands    int      gilt bands across the spine, 0 to 2, default 0

## A band is a thin strip of foil standing a hair proud of the spine.
const BAND_HEIGHT := 0.006
const BAND_PROUD := 0.0004
const BAND_AT: Array[float] = [0.84, 0.12]
const GILT := Color(0.74, 0.6, 0.34)

## The loose books' spread of sizes, which stays under the 5 cm a place on the shelf gives each.
const WIDTH_RANGE := Vector2(0.022, 0.046)
const HEIGHT_RANGE := Vector2(0.17, 0.26)
const SEED := 5021

func build(def: ItemDef) -> Node3D:
	var width := Params.number(def.params, "width", 0.14)
	var height := Params.number(def.params, "height", 0.21)
	var root := Props.book(Params.colour(def.params, "tint", Props.TERRACOTTA), width, height, Vector3.ZERO)
	var bands := clampi(Params.integer(def.params, "bands", 0), 0, BAND_AT.size())
	if bands == 0:
		return root
	# Props.book's spine is a half round of the book's width centred just inside its -Z edge.
	const BOOK_DEPTH := 0.2
	var spine := Vector3(0, 0, -BOOK_DEPTH * 0.5 + width * 0.5)
	var gilt := Props.mat(GILT, 0.35, 0.8)
	for i in range(bands):
		root.add_child(Props.mi(Props.cyl(width * 0.5 + BAND_PROUD, width * 0.5 + BAND_PROUD, BAND_HEIGHT, 12), gilt,
				spine + Vector3(0, height * BAND_AT[i], 0)))
	return root

func variant(index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(SEED + index)
	return {
		"tint": Props.BOOK_CLOTH[(index * 3 + rng.randi_range(0, 1)) % Props.BOOK_CLOTH.size()],
		"width": snappedf(rng.randf_range(WIDTH_RANGE.x, WIDTH_RANGE.y), 0.001),
		"height": snappedf(rng.randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y), 0.005),
		"bands": rng.randi_range(0, 2),
	}

## Put down anywhere but a shelf, a book lies on its back cover.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)
