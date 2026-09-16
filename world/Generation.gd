class_name Generation
extends RefCounted
## Every furniture piece and every distinct item a catalogue holds, generated before the house is
## furnished, on every core there is.
##
## Generation was most of what a boot cost: 8 of the 9 seconds before the world was ready, one piece
## and one item after another (2026-09-15, 78 pieces and 250 items). No piece or item depends on
## another, so each is built on the `WorkerThreadPool` into its own slot of `_results`, and the main
## thread hands them over when the pool is done.
##
## Two things make that safe, and both are load-bearing:
##
## - Generators share no state but `Mats`' cache, which locks, and `ItemFactory`'s recipes, which only
##   the main thread writes (`ItemFactory.keep`). A generator that keeps a static cache of its own
##   has to lock it too.
## - A generator reads meshes back from the rendering server (`Props.bake`), and a call from a worker
##   thread waits until the main thread serves it. So the main thread never blocks on the pool: it
##   serves the server until the pool is done. Blocked, the first boot deadlocked.
##
## `--headless` swaps in a renderer whose mesh storage is not thread-safe (it crashed on the first
## try), so there everything is generated in order on the calling thread. The probes run headless
## and prove that path; `dev/GenerationProbe.tscn` proves the threaded one builds the same meshes.

## How long the main thread sleeps between serving the rendering server. 0, 50 and 500 µs all
## measured the same (1.43-1.52 s for the furniture): the workers, not the pump, set the pace.
const PUMP_USEC := 200
## Pool threads generation leaves to the engine. The renderer compiles shaders on the same pool, and on a
## first launch — an empty shader cache — the main thread waits for those compiles while serving the
## workers. With every pool thread taken by a generator waiting on the main thread, no compile could
## start and the boot hung for good (2026-09-16: 6 of 6 cold boots; 0 of 6 with the cache kept).
const RESERVED_THREADS := 2

var _furniture: Array[FurnitureDef] = []
var _items: Array[ItemDef] = []
## A `FurnitureNode` per furniture def, then the recipe (`ItemFactory.generate`) of each item.
var _results: Array = []

## The pieces of `content.furniture`, in its order (null where a family does not exist), with the
## recipe of every item in `content.items` kept by `ItemFactory`. `threaded` false builds in order.
static func run(content: Catalogue, threaded := true) -> Array[FurnitureNode]:
	var job := Generation.new()
	job._furniture = content.furniture
	var wanted: Dictionary[String, bool] = {}
	for def: ItemDef in content.items:
		var key := Params.key(def.generator, def.params)
		if ItemFactory.has_recipe(key) or wanted.has(key):
			continue
		wanted[key] = true
		job._items.append(def)
	job._results.resize(job._furniture.size() + job._items.size())
	if threaded and DisplayServer.get_name() != "headless":
		job._on_pool()
	else:
		for i in range(job._results.size()):
			job._build(i)
	var pieces: Array[FurnitureNode] = []
	for i in range(job._furniture.size()):
		pieces.append(job._results[i] as FurnitureNode)
	for k in range(job._items.size()):
		ItemFactory.keep(job._items[k], job._results[job._furniture.size() + k] as Array)
	return pieces

func _on_pool() -> void:
	var threads := maxi(OS.get_processor_count() - RESERVED_THREADS, 1)
	var task := WorkerThreadPool.add_group_task(_build, _results.size(), threads, true, "Generation")
	while not WorkerThreadPool.is_group_task_completed(task):
		RenderingServer.force_sync()
		OS.delay_usec(PUMP_USEC)
	WorkerThreadPool.wait_for_group_task_completion(task)

func _build(i: int) -> void:
	if i < _furniture.size():
		_results[i] = FurnitureFactory.build(_furniture[i])
	else:
		_results[i] = ItemFactory.generate(_items[i - _furniture.size()])
