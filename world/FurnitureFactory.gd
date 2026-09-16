class_name FurnitureFactory
## Turns a `FurnitureDef` into a `FurnitureNode`. The def names its family and the family is
## looked up here, the same way an item's is (`ItemFactory`).

const FAMILIES: Dictionary[StringName, Script] = {
	&"base_run": preload("res://props/furniture/BaseRun.gd"),
	&"key_hooks": preload("res://props/furniture/KeyHooks.gd"),
	&"umbrella_stand": preload("res://props/furniture/UmbrellaStand.gd"),
	&"coat_hooks": preload("res://props/furniture/CoatHooks.gd"),
	&"tv_stand": preload("res://props/furniture/TvStand.gd"),
	&"sofa": preload("res://props/furniture/Sofa.gd"),
	&"coffee_table": preload("res://props/furniture/CoffeeTable.gd"),
	&"blanket_basket": preload("res://props/furniture/BlanketBasket.gd"),
	&"bookshelf": preload("res://props/furniture/Bookshelf.gd"),
	&"mantel": preload("res://props/furniture/Mantel.gd"),
	&"desk": preload("res://props/furniture/Desk.gd"),
	&"wall_shelf": preload("res://props/furniture/WallShelf.gd"),
	&"sideboard": preload("res://props/furniture/Sideboard.gd"),
	&"dining_table": preload("res://props/furniture/DiningTable.gd"),
	&"wall_cabinet": preload("res://props/furniture/WallCabinet.gd"),
	&"coffee_maker": preload("res://props/furniture/CoffeeMaker.gd"),
	&"range": preload("res://props/furniture/Range.gd"),
	&"fridge": preload("res://props/furniture/Fridge.gd"),
	&"bench": preload("res://props/furniture/Bench.gd"),
	&"shoe_rack": preload("res://props/furniture/ShoeRack.gd"),
	&"dog_bed": preload("res://props/furniture/DogBed.gd"),
	&"toilet": preload("res://props/furniture/Toilet.gd"),
	&"pedestal_basin": preload("res://props/furniture/PedestalBasin.gd"),
	&"towel_rail": preload("res://props/furniture/TowelRail.gd"),
	&"bike_rack": preload("res://props/furniture/BikeRack.gd"),
	&"recycling_bin": preload("res://props/furniture/RecyclingBin.gd"),
	&"car": preload("res://props/furniture/Car.gd"),
	&"linen_cupboard": preload("res://props/furniture/LinenCupboard.gd"),
	&"bed": preload("res://props/furniture/Bed.gd"),
	&"dresser": preload("res://props/furniture/Dresser.gd"),
	&"clothes_rail": preload("res://props/furniture/ClothesRail.gd"),
	&"vanity": preload("res://props/furniture/Vanity.gd"),
	&"mirror": preload("res://props/furniture/Mirror.gd"),
	&"shower": preload("res://props/furniture/Shower.gd"),
	&"bathtub": preload("res://props/furniture/Bathtub.gd"),
	&"bunk_bed": preload("res://props/furniture/BunkBed.gd"),
	&"toy_box": preload("res://props/furniture/ToyBox.gd"),
	&"weight_rack": preload("res://props/furniture/WeightRack.gd"),
	&"steel_shelving": preload("res://props/furniture/SteelShelving.gd"),
	&"workbench": preload("res://props/furniture/Workbench.gd"),
	&"washer_dryer": preload("res://props/furniture/WasherDryer.gd"),
	&"furnace": preload("res://props/furniture/Furnace.gd"),
	&"water_heater": preload("res://props/furniture/WaterHeater.gd"),
	&"breaker_panel": preload("res://props/furniture/BreakerPanel.gd"),
	&"cube_shelf": preload("res://props/furniture/CubeShelf.gd"),
	&"ping_pong_table": preload("res://props/furniture/PingPongTable.gd"),
	&"trunk": preload("res://props/furniture/Trunk.gd"),
	&"box_stack": preload("res://props/furniture/BoxStack.gd"),
	&"dust_sheet": preload("res://props/furniture/DustSheet.gd"),
	&"dress_form": preload("res://props/furniture/DressForm.gd"),
	&"rolled_rug": preload("res://props/furniture/RolledRug.gd"),
	&"grill": preload("res://props/furniture/Grill.gd"),
	&"patio_set": preload("res://props/furniture/PatioSet.gd"),
	&"sun_lounger": preload("res://props/furniture/SunLounger.gd"),
	&"diving_board": preload("res://props/furniture/DivingBoard.gd"),
	&"pool_bin": preload("res://props/furniture/PoolBin.gd"),
	&"hose_reel": preload("res://props/furniture/HoseReel.gd"),
	&"potting_bench": preload("res://props/furniture/PottingBench.gd"),
	&"flower_bed": preload("res://props/furniture/FlowerBed.gd"),
}

## Null, with an error, for a family that does not exist; `FurnitureProbe` reports it by name.
static func build(def: FurnitureDef) -> FurnitureNode:
	var script: Script = FAMILIES.get(def.generator, null)
	if script == null:
		push_error("FurnitureFactory: no family named '%s' (piece '%s')" % [def.generator, def.id])
		return null
	var family := script.new() as FurnitureGenerator
	assert(family != null, "FurnitureFactory: '%s' is not a FurnitureGenerator" % def.generator)
	var piece := family.build(def)
	assert(piece.def == def, "FurnitureFactory: '%s' did not initialize its node" % def.generator)
	return piece

static func knows(generator: StringName) -> bool:
	return FAMILIES.has(generator)

static func families() -> Array[StringName]:
	return FAMILIES.keys() as Array[StringName]
