class_name CarryBar
extends PanelContainer
## How full the player's hands are: slots used of capacity and how many are free, a cell per slot with
## each carried item covering what it costs and showing its picture, which item is selected, and the keys that drop and throw it.

@onready var _used: Label = %Used
@onready var _free: Label = %Free
@onready var _cells: CarryCells = %Cells
@onready var _selected: Control = %Selected
@onready var _selected_name: Label = %SelectedName
@onready var _drop_key: Label = %DropKey
@onready var _drop_text: Label = %DropText
@onready var _throw_key: Label = %ThrowKey
@onready var _throw_text: Label = %ThrowText

## `selected` indexes `carried`, or is -1 with empty hands. `pictures` holds each carried item's picture in
## the same order, null where there is none.
func show_load(carried: Array[ItemDef], capacity: int, selected: int, pictures: Array[Texture2D]) -> void:
	var costs: Array[int] = []
	var used := 0
	for def: ItemDef in carried:
		costs.append(def.slot_cost)
		used += def.slot_cost
	_used.text = NumberFormatter.slots_of(used, capacity)
	_free.text = tr("hud.free") % NumberFormatter.count(capacity - used)
	_cells.show_load(costs, capacity, selected, pictures)
	_drop_key.text = InputNames.of(&"drop_item")
	_drop_text.text = tr("hud.drop")
	_throw_key.text = InputNames.of(&"throw_item")
	_throw_text.text = tr("hud.throw")
	# The line keeps its height while empty, so the bar does not jump as the first item is taken. It is never
	# cut short: at the start of a run the bar is one cell wide, and the name is the point of the line.
	var held := selected >= 0 and selected < carried.size()
	_selected.modulate.a = 1.0 if held else 0.0
	_selected_name.text = tr(carried[selected].name_key) if held else ""

func used_text() -> String:
	return _used.text

## The selected item's name, or "" with empty hands.
func selected_text() -> String:
	return _selected_name.text

## The keys the line names for dropping and throwing, as their caps print them.
func key_texts() -> PackedStringArray:
	return PackedStringArray([_drop_key.text, _throw_key.text])

func selected_label() -> Label:
	return _selected_name

func cells() -> CarryCells:
	return _cells
