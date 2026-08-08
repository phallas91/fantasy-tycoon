extends Node
## Number formatting helpers (autoload: Fmt).
## Compact notation with K/M/B/T then aa, ab, ... suffixes.

const SUFFIXES := [
	"", "K", "M", "B", "T",
	"aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj",
	"ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at",
	"au", "av", "aw", "ax", "ay", "az", "ba", "bb", "bc", "bd",
]

## Short compact form, e.g. 1234567 -> "1.23M".
func short(n: float) -> String:
	if not is_finite(n):
		return "∞"
	if n < 0.0:
		return "-" + short(-n)
	if n < 1000.0:
		# Whole numbers below 1000 read cleaner without decimals.
		if n < 10.0 and n != floor(n):
			return "%.1f" % n
		return str(int(round(n)))
	var idx := 0
	while n >= 1000.0 and idx < SUFFIXES.size() - 1:
		n /= 1000.0
		idx += 1
	if n >= 100.0:
		return "%.0f%s" % [n, SUFFIXES[idx]]
	elif n >= 10.0:
		return "%.1f%s" % [n, SUFFIXES[idx]]
	return "%.2f%s" % [n, SUFFIXES[idx]]

## Fully-expanded grouped integer, e.g. 1234567 -> "1 234 567" (thin-space
## grouped). Falls back to short() for astronomically large values where the
## exact digits stop being meaningful. Used by the tap-to-expand number view.
func long(n: float) -> String:
	if not is_finite(n):
		return "∞"
	if abs(n) >= 1e15:
		return short(n)
	var digits := "%d" % int(round(abs(n)))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0.0 else "") + out

## Time in seconds -> "1h 23m" / "45s".
func duration(seconds: float) -> String:
	var s := int(max(0.0, seconds))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%dh %dm" % [h, m]
	if m > 0:
		return "%dm %ds" % [m, sec]
	return "%ds" % sec

## Depth in meters -> "1 234 m".
func meters(d: float) -> String:
	return "%s m" % short(floor(d))
