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

## The directional shadow map, per tier. This is the one setting the eave sawtooth actually
## responded to: bias, normal bias and cascade count all left it, and resolution removed it.
## The high tier doubles the engine default and pays for it in memory, measured by PerfProbe;
## the other two keep the default, which is already the density the low tier's single 25 m
## cascade needs.
const SHADOW_ATLAS := {Tier.LOW: 4096, Tier.MEDIUM: 4096, Tier.HIGH: 8192}
## 16-bit depth over a 40 m cascade resolves to well under a millimetre and halves the atlas.
const SHADOW_16_BITS := true
## How many taps a shadow edge takes. The style test set Soft Ultra for every tier and recorded no
## reason; on the high tier it cost 2.75 ms a frame over Soft Low (PerfProbe, 2026-09-16).
const SHADOW_FILTER := {
	Tier.LOW: RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	Tier.MEDIUM: RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	Tier.HIGH: RenderingServer.SHADOW_QUALITY_SOFT_LOW,
}
## SSIL at the engine's default quality cost the high tier 2.4 ms a frame; at low quality and half
## size it measured within noise of having none (PerfProbe, 2026-09-16). The remaining arguments are
## the engine's defaults.
const SSIL_QUALITY := RenderingServer.ENV_SSIL_QUALITY_LOW
const SSIL_HALF_SIZE := true
const SSIL_ADAPTIVE_TARGET := 0.5
const SSIL_BLUR_PASSES := 4
const SSIL_FADE := Vector2(50.0, 300.0)

## Every room gets a reflection probe, on every tier. This is not polish: a metal in Godot has
## no diffuse response at all, so it renders nothing but what it reflects, and the manor's
## interiors gave it nothing to reflect. Twelve steel spoons on a stone worktop came out as
## flat dark smudges and were reported missing twice by the author before the cause was found
## (2026-09-10) — SDFGI's cascades are far too coarse to resolve a 6 mm spoon, and the low tier
## has no GI at all. Reflections are what makes the game's only pickup readable, so they are
## not a setting the low tier goes without.
##
## `interior` keeps the sky out of a room that cannot see it; ambient stays DISABLED because
## the environment and SDFGI already light the room and a probe adding its own on top blew
## every interior render out. Baked once at build time: nothing in the house moves except
## drawers and doors, and a probe that re-renders six faces a frame is not affordable.
const PROBE_INTENSITY := 1.0
## Grown past the room's own walls so the box a reflection is projected into contains the
## surfaces standing on the boundary rather than cutting them in half.
const PROBE_MARGIN := 0.25

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
	# Below the horizon the sky's own ground shows wherever the lot's grass runs out. Brown
	# earth there reads as a hole in the world from anything above eye level, so it is the
	# colour of land seen through haze instead.
	skymat.ground_bottom_color = Color(0.44, 0.48, 0.38)
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
	# Distance fog. The lot's grass runs 45 m past the fence so no view ends in a hard edge
	# (`TerrainBuilder.SURROUND`), but without haze that far grass stays as saturated as the
	# lawn underfoot and the horizon reads as a painted backdrop. Depth fog, beginning past the
	# far side of the property so nothing the player walks through is touched by it.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 220.0
	env.fog_depth_curve = 0.6
	env.fog_density = 0.7
	env.fog_light_color = Color(0.80, 0.83, 0.86)
	env.fog_sun_scatter = 0.12
	env.fog_aerial_perspective = 0.25
	# The sky is not fogged at all. It already carries its own haze band at the horizon, and
	# fogging it as well turned the whole dome one flat grey — visible in the first aerial.
	env.fog_sky_affect = 0.0
	return env

static func apply(env: Environment, tier: Tier) -> void:
	env.sdfgi_enabled = tier == Tier.HIGH
	env.sdfgi_bounce_feedback = 1.0
	env.ssil_enabled = tier == Tier.HIGH
	RenderingServer.environment_set_ssil_quality(SSIL_QUALITY, SSIL_HALF_SIZE, SSIL_ADAPTIVE_TARGET,
			SSIL_BLUR_PASSES, SSIL_FADE.x, SSIL_FADE.y)
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
	# One cascade, not two and not the four of the default. Every cascade re-renders the whole
	# house into the shadow map: PerfProbe measured the four-split default at 2069 draw calls for
	# the empty manor, two splits at 1585, and this at 1476. The lot is 26 m across, so one
	# 40 m box covers everything the player can see a shadow on, and at 8192 its texels are finer
	# than the two-split arrangement ever gave the house: the sawtooth along the eave's shadow in
	# the west view is gone.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0 if tier != Tier.LOW else 25.0
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[tier], SHADOW_16_BITS)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER[tier])
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
