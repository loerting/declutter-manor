class_name Outline
extends RefCounted
## A line round something the player is looking for, seen from anywhere in the house (`docs/ARCHITECTURE.md`, "The way
## home"): the home of a carried item, or a misplaced member of the set the player picked in the ledger. Every mesh
## gets a hull: the same mesh with its normals averaged per corner, grown in screen space
## (`world/outline.gdshaderinc`). The hull is drawn twice: faint through every wall and floor
## (`outline_through.gdshader`) and at full strength over the part in plain sight (`outline_seen.gdshader`). A mask,
## the mesh itself marking its pixels, keeps the line off the thing (`outline_mask.gdshader`). All of them hang
## under the mesh they outline, so a door's outline swings with the door and an item's rolls with the item.
##
## Items are not the piece: one standing on it or put away in it is left out, and never outlined with it.

enum Kind { HOME, SOUGHT }

const SEEN := preload("res://world/outline_seen.gdshader")
const THROUGH := preload("res://world/outline_through.gdshader")
const MASK := preload("res://world/outline_mask.gdshader")
## A home is white and a member of the set looked for amber. Colour is never the only sign: the HUD shows the set
## looked for by its picture, and a home is a piece of furniture where an item is a thing on its own.
const COLORS: Dictionary[Kind, Color] = {Kind.HOME: Color(0.961, 0.937, 0.894), Kind.SOUGHT: Color(1.0, 0.71, 0.24)}

## The node outlined.
var target: Node3D

var kind: Kind

var _hulls: Array[MeshInstance3D] = []
var _masks: Array[MeshInstance3D] = []
var _shown := false

## Kind -> the faint material the hull is drawn with, and the full one drawn over it.
static var _through: Dictionary[Kind, ShaderMaterial] = {}
static var _seen: Dictionary[Kind, ShaderMaterial] = {}
static var _mask_material: ShaderMaterial
## Mesh -> its hull mesh. A drawer shared by twelve pieces is averaged once.
static var _smoothed: Dictionary[Mesh, ArrayMesh] = {}

func _init(outlined: Node3D, outline_kind: Kind) -> void:
	target = outlined
	kind = outline_kind

func show(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if on and _hulls.is_empty():
		var meshes: Array[MeshInstance3D] = []
		_collect(target, target, meshes)
		# After the walk, so a hull is never found by it and outlined in turn.
		for mi: MeshInstance3D in meshes:
			var hull := MeshInstance3D.new()
			hull.name = "Outline"
			hull.mesh = _smooth(mi.mesh)
			hull.material_override = _material(_through, THROUGH, kind)
			hull.material_overlay = _material(_seen, SEEN, kind)
			hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hull.layers = mi.layers
			mi.add_child(hull)
			_hulls.append(hull)
			var mask := MeshInstance3D.new()
			mask.name = "OutlineMask"
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

static func _collect(node: Node, outlined: Node3D, into: Array[MeshInstance3D]) -> void:
	if node is ItemNode and node != outlined:
		return
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		into.append(mi)
	for child: Node in node.get_children():
		_collect(child, outlined, into)

## One material per kind and pass, shared by every hull. The faint pass is drawn after every mask, and the full
## one after it: all three are drawn with the transparent things, lowest priority first.
static func _material(cache: Dictionary[Kind, ShaderMaterial], shader: Shader, of: Kind) -> ShaderMaterial:
	if cache.has(of):
		return cache[of]
	var material := ShaderMaterial.new()
	material.shader = shader
	var color := COLORS[of]
	if shader == THROUGH:
		color.a = Balance.OUTLINE_THROUGH_ALPHA
	material.set_shader_parameter(&"line_color", color)
	material.set_shader_parameter(&"width", Balance.HOME_OUTLINE_PX if of == Kind.HOME else Balance.SOUGHT_OUTLINE_PX)
	material.set_shader_parameter(&"pull", Balance.HOME_OUTLINE_PULL)
	material.render_priority = 2 if shader == SEEN else 1
	cache[of] = material
	return material

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
