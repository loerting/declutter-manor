class_name PlaceGhost
extends Node3D
## The preview: the item's own mesh, unshaded, with a white inverted-hull outline behind it.
## Nothing about the ghost is the item — the item has not moved and is still in the player's
## hands until the click lands (`docs/ARCHITECTURE.md`, "Placement", step 3).
##
## The hull is a second copy of every mesh, grown along its normals and drawn front-face-culled,
## so what is left is the far side of a slightly larger item: an outline that follows the
## silhouette exactly and costs no shader.

var _def: ItemDef

func _ready() -> void:
	# The slot is a place in the world, not a place in front of the player: the ghost must not
	# ride along with the head it hangs under.
	top_level = true
	visible = false

## Shows the ghost at a slot. Rebuilds the meshes only when the item changes, because the slot
## changes every time the player's aim moves a pixel and the item almost never does.
func show_slot(def: ItemDef, xform: Transform3D) -> void:
	if def != _def:
		_def = def
		_rebuild(def)
	global_transform = xform
	visible = true

func clear() -> void:
	visible = false

func _rebuild(def: ItemDef) -> void:
	for child: Node in get_children():
		child.queue_free()
	var visual := ItemFactory.build_visual(def)
	var ghost := _ghost_material()
	var outline := _outline_material()
	add_child(visual)
	for mi: MeshInstance3D in WorldBuilder.meshes(visual):
		mi.material_override = ghost
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hull := MeshInstance3D.new()
		hull.mesh = mi.mesh
		hull.transform = mi.transform
		hull.material_override = outline
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.get_parent().add_child(hull)

func _ghost_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 1.0, 1.0, Balance.GHOST_ALPHA)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _outline_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = Balance.GHOST_OUTLINE
	return m
