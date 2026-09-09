class_name Mats
## PBR material library backed by the CC0 textures listed in assets/textures.json.
##
## The procedural meshes in Props.gd have no meaningful UV layout - unwrapping a
## lathe or a swept tube by hand would be a project of its own - so every material
## here uses TRIPLANAR mapping. The texture is projected down the three world axes
## and blended by the surface normal, which needs no UVs at all and cannot stretch
## or seam the way a bad unwrap does.
##
## Because triplanar works in metres rather than UV units, each texture carries the
## real-world size of one tile ("scale" in the manifest). Setting uv1_scale to its
## reciprocal makes the oak grain, the carpet pile and the plaster grit all come out
## at true physical size relative to one another - which is most of what separates a
## scene that reads as real from one that reads as plastic.

const DIR := "res://assets/textures/"

static var _specs: Dictionary = {}
static var _cache: Dictionary = {}
static var _warned := false

static func _load_specs() -> void:
	if not _specs.is_empty():
		return
	var f := FileAccess.open("res://assets/textures.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("textures"):
		_specs = parsed["textures"]

static func _tex(slot: String, map: String) -> Texture2D:
	var path := DIR + slot + "/" + map + ".jpg"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## Returns the material for a manifest slot.
##  `tint`       modulates the albedo, so one wood or fabric serves several colourways;
##  `rough_mul`  scales the roughness map (>1 duller, <1 glossier);
##  `scale_mul`  scales the tile size, for the odd prop that wants finer or coarser grain.
##  `world_space` projects in world coordinates instead of the object's own. Props want local,
##  so a mug keeps its glaze when it is picked up; architecture wants world, so plaster and
##  siding run continuously across a corner instead of restarting on every wall segment.
## `matte` drops the packed ORM map and takes `rough_mul` as a flat roughness instead of a
## multiplier. It exists for surfaces the scan was not taken from: the roof boards are sawn
## timber, and every wood scan here is a finished floor or panel at roughness ~0.53, which put
## two mirror highlights of the attic bulb on the underside of the roof. The cost is the map's
## baked ambient occlusion, which is nothing on a flat board.
static func of(slot: String, tint := Color.WHITE, rough_mul := 1.0, scale_mul := 1.0,
		world_space := false, matte := false, vertex_tint := false) -> Material:
	_load_specs()
	var key := "%s|%s|%.3f|%.3f|%s|%s|%s" % [slot, tint.to_html(), rough_mul, scale_mul,
			world_space, matte, vertex_tint]
	if _cache.has(key):
		return _cache[key]

	var spec: Dictionary = _specs.get(slot, {})
	var albedo := _tex(slot, "albedo")
	if albedo == null:
		# The textures are downloaded on demand (see tools/fetch_textures.py), so the
		# scene has to stay runnable without them rather than crashing.
		if not _warned:
			_warned = true
			# Named, because "no textures" is two different problems: none downloaded at all,
			# and one slot in the manifest that nothing on disk answers to. The second one is
			# a flat-coloured surface in a render nobody notices is flat.
			push_warning("No texture for slot '%s' in %s - run: python3 tools/fetch_textures.py"
					% [slot, DIR])
		var flat := Props.mat(tint, clampf(0.85 * rough_mul, 0.0, 1.0))
		_cache[key] = flat
		return flat

	var metres: float = float(spec.get("scale", 1.0)) * scale_mul

	var m := ORMMaterial3D.new()
	m.albedo_texture = albedo
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex(slot, "normal")
	m.normal_scale = float(spec.get("normal_scale", 1.0))
	m.ao_enabled = not matte
	m.orm_texture = null if matte else _tex(slot, "orm")
	# ORMMaterial3D multiplies the map by these, so they must not sit at zero or the
	# packed roughness/metallic channels are thrown away.
	m.roughness = clampf(rough_mul, 0.0, 1.0)
	m.metallic = 0.0 if matte else 1.0
	m.ao_light_affect = 0.5

	# Mipmaps kill the moire that unfiltered textures show at a distance, but on their own
	# they also smear the weave and plaster grain out of any surface seen at a grazing
	# angle - which is most of a floor or a sofa. Anisotropic filtering keeps that detail.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	# `vertex_tint` multiplies the albedo by the mesh's own vertex colours: macro variation the
	# texture cannot carry, for surfaces far larger than one tile. See `Props.ground_slab`.
	m.vertex_color_use_as_albedo = vertex_tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_space
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / maxf(metres, 0.001)

	_cache[key] = m
	return m

## True once the textures have actually been downloaded.
static func available() -> bool:
	return ResourceLoader.exists(DIR + "oak/albedo.jpg")
