class_name Params
## Reads a generator's parameters out of the `params` of an `ItemDef` or a `FurnitureDef`. A key
## that is missing or holds the wrong type reads as the family's default, so a resource written
## before a parameter existed still builds. Keys are Strings: `"width"`, not `&"width"`.

static func number(p: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = p.get(key, fallback)
	return float(v) if v is float or v is int else fallback

static func integer(p: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = p.get(key, fallback)
	return int(v) if v is int or v is float else fallback

static func colour(p: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = p.get(key, fallback)
	return v as Color if v is Color else fallback

static func flag(p: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = p.get(key, fallback)
	return v as bool if v is bool else fallback

static func text(p: Dictionary, key: String, fallback: String) -> String:
	var v: Variant = p.get(key, fallback)
	return str(v) if v is String or v is StringName else fallback

## One string per distinct generator and parameter set, whatever order the keys were written in.
## Two items that would build the same mesh share one key, and so share one mesh (`ItemFactory`).
static func key(generator: StringName, p: Dictionary) -> String:
	var keys := p.keys()
	keys.sort()
	var out := String(generator)
	for k: Variant in keys:
		out += "|%s=%s" % [k, var_to_str(p[k])]
	return out
