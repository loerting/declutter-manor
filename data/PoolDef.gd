class_name PoolDef
extends Resource
## A swimming pool cut into an exterior zone. It is a real hole: the zone's paving and the lawn
## under it both lose the pool's footprint, and the basin is a shell with wall thickness that
## sits in that hole. `docs/HOUSE.md` calls this out as one of the two zones that test the
## one-floor-plan rule — a pool that sat on the ground would give the whole garden away.

## The exterior zone the pool is cut into.
@export var room: StringName
## Water's edge in plan metres. The shell and the hole are grown from it.
@export var rect := Rect2()
@export var depth := 1.5
## Wall and floor thickness of the shell. The hole in the ground is this much bigger again.
@export var shell := 0.15
## Coping: the band around the rim, its width outward from the water's edge and how far it
## stands above the paving. It covers the shell, the gap around it and the cut edge of the lawn.
@export var coping := 0.35
@export var coping_proud := 0.04
## Water sits this far below the paving, which is where the tile line of a real pool sits.
@export var water_below := 0.14
## Steps into the shallow end, at the west end of the basin.
@export var step_count := 3
@export var step_width := 1.2

@export var liner_slot := "porcelain"
@export var liner_tint := Color(0.66, 0.86, 0.95)
@export var coping_slot := "concrete"
@export var coping_tint := Color(0.78, 0.76, 0.72)
## Deep enough to read as water rather than as tinted glass, clear enough to show the liner.
## The first pass was 0.29,0.62,0.66 at 0.62 alpha over a white liner, which came out as milk.
@export var water_tint := Color(0.06, 0.30, 0.36, 0.72)

## The footprint removed from the paving and the lawn: the water rect plus the shell around it,
## plus a millimetre so the shell's outer faces never end up coplanar with the cut earth.
func hole() -> Rect2:
	return rect.grow(shell + 0.001)

static func make(zone: StringName, r: Rect2, d: float) -> PoolDef:
	var p := PoolDef.new()
	p.room = zone
	p.rect = r
	p.depth = d
	return p
