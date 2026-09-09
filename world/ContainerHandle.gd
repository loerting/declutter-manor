class_name ContainerHandle
extends StaticBody3D
## What the interaction ray hits when the player looks at a drawer front or a cabinet door.
## It is a separate type rather than a flag on a body so the interactor can resolve what it hit
## by casting, never by asking a node whether it happens to have a method (rule 7).

var container: ContainerComponent

func initialize(owner_container: ContainerComponent, size: Vector3, offset: Vector3) -> void:
	container = owner_container
	collision_layer = Layers.bit(Layers.CONTAINER)
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	add_child(shape)
