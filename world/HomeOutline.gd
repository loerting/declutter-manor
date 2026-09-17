class_name HomeOutline
extends RefCounted
## The white line round the piece a carried item belongs on, while the player is in its room
## (`docs/ARCHITECTURE.md`, "The way home"). Every mesh of the piece gets a hull: the same mesh with its
## normals averaged per corner, drawn behind it and grown in screen space (`world/home_outline.gdshader`), and
## a mask, the mesh itself marking its pixels so the line is never drawn over the piece
## (`world/home_outline_mask.gdshader`). Both hang under the mesh they outline, so a door's outline swings
## with the door.
##
## Items are not the piece: one standing on it or put away in it is left out, and never outlined with it.

const SHADER := preload("res://world/home_outline.gdshader")
const MASK := preload("res://world/home_outline_mask.gdshader")

## The node outlined.
var target: Node3D

var _hulls: Array[MeshInstance3D] = []
var _masks: Array[MeshInstance3D] = []
var _shown := false

static var _material: ShaderMaterial
static var _mask_material: ShaderMaterial
## Mesh -> its hull mesh. A drawer shared by twelve pieces is averaged once.
static var _smoothed: Dictionary[Mesh, ArrayMesh] = {}

func _init(outlined: Node3D) -> void:
	target = outlined

func show(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if on and _hulls.is_empty():
		var meshes: Array[MeshInstance3D] = []
		_collect(target, meshes)
		# After the walk, so a hull is never found by it and outlined in turn.
		for mi: MeshInstance3D in meshes:
			var hull := MeshInstance3D.new()
			hull.name = "HomeOutline"
			hull.mesh = _smooth(mi.mesh)
			hull.material_override = _outline_material()
			hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hull.layers = mi.layers
			mi.add_child(hull)
			_hulls.append(hull)
			var mask := MeshInstance3D.new()
			mask.name = "HomeOutlineMask"
			mask.mesh = mi.mesh
			mask.material_override = _mask()
			mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mask.layers = mi.layers
			mi.add_child(mask)
			_masks.append(mask)
	for hull: MeshInstance3D in _hulls:
		hull.visible = on
	for mask: MeshInstance3D in _masks:
		mask.visible = on

func shown() -> bool:
	return _shown

## The hulls, for `dev/WayProbe.gd`.
func hulls() -> Array[MeshInstance3D]:
	return _hulls

static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is ItemNode:
		return
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		into.append(mi)
	for child: Node in node.get_children():
		_collect(child, into)

static func _outline_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"width", Balance.HOME_OUTLINE_PX)
		_material.set_shader_parameter(&"pull", Balance.HOME_OUTLINE_PULL)
		# After every mask: both are drawn with the transparent things, lowest priority first.
		_material.render_priority = 1
	return _material

static func _mask() -> ShaderMaterial:
	if _mask_material == null:
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = MASK
	return _mask_material

## The mesh with every vertex's normal replaced by the mean of the normals at its position.
static func _smooth(mesh: Mesh) -> ArrayMesh:
	if _smoothed.has(mesh):
		return _smoothed[mesh]
	var out := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var array_mesh := mesh as ArrayMesh
		if array_mesh != null and array_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != vertices.size():
			continue
		var summed: Dictionary[Vector3, Vector3] = {}
		for i in range(vertices.size()):
			var key := vertices[i].snappedf(0.0001)
			summed[key] = summed.get(key, Vector3.ZERO) + normals[i]
		var smooth := PackedVector3Array()
		smooth.resize(vertices.size())
		for i in range(vertices.size()):
			var sum: Vector3 = summed[vertices[i].snappedf(0.0001)]
			smooth[i] = sum.normalized() if sum.length_squared() > 1e-8 else normals[i]
		var hull: Array = []
		hull.resize(Mesh.ARRAY_MAX)
		hull[Mesh.ARRAY_VERTEX] = vertices
		hull[Mesh.ARRAY_NORMAL] = smooth
		hull[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, hull)
	_smoothed[mesh] = out
	return out
