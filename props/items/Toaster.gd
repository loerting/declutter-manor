extends ItemGenerator
## A two-slice toaster (`Props.toaster`). No parameters.

func build(_def: ItemDef) -> Node3D:
	return Props.toaster()
