class_name NumberFormatter
## Every number shown to the player goes through here. Never `str(x)` in UI code.

## "3 of 12"
static func of_total(have: int, total: int) -> String:
	return TranslationServer.translate("%d of %d", "NumberFormatter") % [have, total]

## "1:23:45" past an hour, "23:45" below it.
static func duration(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]

## "6" — a count on its own, in a list whose heading says what is being counted.
static func count(n: int) -> String:
	return "%d" % n

## "84%" — always floored, so a player never reads 100% before they are finished.
static func percent(fraction: float) -> String:
	return "%d%%" % int(floorf(clampf(fraction, 0.0, 1.0) * 100.0))

## "6 of 9 slots" / "0 of 1 slot"
static func slots_of(used: int, capacity: int) -> String:
	return TranslationServer.translate("%d of %d slot", "NumberFormatter") % [used, capacity] if capacity == 1 \
			else TranslationServer.translate("%d of %d slots", "NumberFormatter") % [used, capacity]

## "4 slots" / "1 slot"
static func slots(n: int) -> String:
	return TranslationServer.translate("%d slot", "NumberFormatter") % n if n == 1 else TranslationServer.translate("%d slots", "NumberFormatter") % n
