class_name Graphics
## The three quality tiers from `docs/ARCHITECTURE.md`. They exist because this house is
## generated at runtime: `LightmapGI` needs a UV2 unwrap and an offline bake, so it is not
## available at all, and SDFGI is not available on the low end of the hardware the author asked
## to support. The low tier is a design constraint, not a fallback nobody looks at — the Phase 1
## gate renders it too.

enum Tier { LOW, MEDIUM, HIGH }

## Voxel size for the medium tier's runtime bake. Coarser than a room's furniture on purpose:
## the bake happens while the player is loading, and this is bounce light, not detail.
const VOXEL_SUBDIV := VoxelGI.SUBDIV_128

## Direct sunlight, calibrated outdoors against the driveway view rather than in a windowless
## test box. The style test's 4.2 at exposure 1.7 clipped every exterior surface to flat white.
const SUN_ENERGY := 2.6
const EXPOSURE := 1.0

## Sky ambient rises as global illumination falls away, so the low tier renders a lit house
## rather than a dark one. It never fully replaces bounce light — that is the visible
## difference between the tiers, and it is the author's call whether it is acceptable.
const LOW_AMBIENT := 2.0
const MEDIUM_AMBIENT := 1.3
const HIGH_AMBIENT := 1.0

static func tier_name(tier: Tier) -> String:
	match tier:
		Tier.LOW: return "low"
		Tier.MEDIUM: return "medium"
		_: return "high"

static func from_string(s: String) -> Tier:
	match s.to_lower():
		"low": return Tier.LOW
		"medium": return Tier.MEDIUM
		_: return Tier.HIGH

## The shared look. Everything tier-dependent is applied by `apply()` on top of this, so the
## three tiers cannot drift into three different art directions.
static func base_environment() -> Environment:
	var env := Environment.new()
	var skymat := ProceduralSkyMaterial.new()
	skymat.sky_top_color = Color(0.45, 0.62, 0.85)
	skymat.sky_horizon_color = Color(0.85, 0.80, 0.72)
	skymat.ground_bottom_color = Color(0.35, 0.30, 0.25)
	skymat.ground_horizon_color = Color(0.85, 0.80, 0.72)
	var sky := Sky.new()
	sky.sky_material = skymat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = EXPOSURE
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	return env

static func apply(env: Environment, tier: Tier) -> void:
	env.sdfgi_enabled = tier == Tier.HIGH
	env.sdfgi_bounce_feedback = 1.0
	env.ssil_enabled = tier == Tier.HIGH
	env.ssao_enabled = tier != Tier.LOW
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.4
	match tier:
		Tier.LOW: env.ambient_light_energy = LOW_AMBIENT
		Tier.MEDIUM: env.ambient_light_energy = MEDIUM_AMBIENT
		_: env.ambient_light_energy = HIGH_AMBIENT

static func make_sun(tier: Tier) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = SUN_ENERGY
	# From the south-west: the deck, the pool and the side garden — three of the four outdoor
	# zones — are on the south and west, and they should be the sunny side of the house.
	sun.rotation_degrees = Vector3(-46, -45, 0)
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.5 if tier != Tier.LOW else 0.0
	# Two cascades, not four: every cascade re-renders the whole house, and PerfProbe measured
	# the four-split default at 2069 draw calls for the empty manor on the high tier — the house
	# drawn once and then four more times for its own shadow. The lot is 26 m across.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if tier == Tier.LOW \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0 if tier != Tier.LOW else 25.0
	return sun

## The medium tier's global illumination: one VoxelGI baked once, at load, over the house that
## was just generated. Returns the node so the caller owns it; null on the tiers that do not
## use one.
static func make_voxel_gi(tier: Tier, bounds: AABB) -> VoxelGI:
	if tier != Tier.MEDIUM:
		return null
	var gi := VoxelGI.new()
	gi.subdiv = VOXEL_SUBDIV
	gi.size = bounds.size
	gi.position = bounds.get_center()
	return gi
