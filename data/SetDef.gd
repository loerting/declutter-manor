class_name SetDef
extends Resource
## One set: a group of items that grants a slot once every one of them is at home
## (`docs/VISION.md`, "The loop"). Data, never code.
##
## The members are not listed here. An item names its set (`ItemDef.set_id`) and that is the only
## place membership is written down, so an item cannot be in a set that does not list it, or
## listed by a set it does not name — `Catalogue.members` derives the list.
##
## `id` is a save key, with the same rule as an item's: fixed at authoring time, never reused.

@export var id: StringName
@export var name_key := ""

static func make(set_id: StringName, key: String) -> SetDef:
	var d := SetDef.new()
	d.id = set_id
	d.name_key = key
	return d
