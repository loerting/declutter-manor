class_name CarryBar
extends PanelContainer
## How full the player's hands are: slots used of capacity and how many are free, a cell per slot with
## each carried item covering what it costs, and which item `return_item` would put back.

@onready var _used: Label = %Used
@onready var _free: Label = %Free
@onready var _cells: CarryCells = %Cells
@onready var _back: Control = %Back
@onready var _back_key: Label = %BackKey
@onready var _back_text: Label = %BackText

func show_load(carried: Array[ItemDef], capacity: int) -> void:
	var costs: Array[int] = []
	var used := 0
	for def: ItemDef in carried:
		costs.append(def.slot_cost)
		used += def.slot_cost
	_used.text = NumberFormatter.slots_of(used, capacity)
	_free.text = tr("hud.free") % NumberFormatter.count(capacity - used)
	_cells.show_load(costs, capacity)
	_back_key.text = InputNames.of(&"return_item")
	# The line keeps its height while empty, so the bar does not jump as the first item is taken. It is never
	# cut short: at the start of a run the bar is one cell wide, and the name is the point of the line.
	_back.modulate.a = 0.0 if carried.is_empty() else 1.0
	_back_text.text = "" if carried.is_empty() else tr("hud.pair") % [tr("hud.put_back"), tr(carried.back().name_key)]

func used_text() -> String:
	return _used.text

func back_text() -> String:
	return _back_text.text

func back_label() -> Label:
	return _back_text

func cells() -> CarryCells:
	return _cells
