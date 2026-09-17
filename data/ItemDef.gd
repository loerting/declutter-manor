class_name ItemDef
extends Resource
## One item type. Data, never code (`docs/ARCHITECTURE.md`, "Items"): the generator is named,
## not called, so a family of eight books is eight resources over one generator rather than
## eight functions. Content volume is this project's largest risk and this is the mitigation.
##
## `id` is the save key. It is fixed at authoring time and never reused, even after the item is
## deleted — the save contract identifies items by it and nothing else.

@export var id: StringName
@export var name_key := ""
## 1, 2, 4 or 8. `Balance.is_valid_slot_cost` is the check; anything else is a content error.
@export var slot_cost := 1
## Kilograms, from the weights `tools/content_model.py` derives the slot cost from. A thrown item is
## thrown with the player's effort, not at a speed, so this is what makes a dumbbell land short.
@export var mass := 1.0
## Which set this belongs to, or &"" for scenery that is never collected.
@export var set_id: StringName = &""
## The family in `ItemFactory` that builds it.
@export var generator: StringName
## The family's parameters. What a generator accepts is documented on the generator.
@export var params: Dictionary = {}
## The `PlaceSlotGroup.id` that accepts it. An item with no home is scenery.
@export var home: StringName = &""
## The authored wrong place it starts in.
@export var start: ItemPlacement

static func make(item_id: StringName, gen: StringName, home_group: StringName,
		set_name: StringName = &"") -> ItemDef:
	var d := ItemDef.new()
	d.id = item_id
	d.generator = gen
	d.home = home_group
	d.set_id = set_name
	return d
