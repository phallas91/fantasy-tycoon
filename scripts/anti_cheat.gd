extends Node
## Basic anti-cheat layer (autoload: AntiCheat).
## Detects time tampering, implausible balance spikes, enforces caps.

const MAX_OFFLINE_SECS := 86400.0         # hard 24h cap
# Preserve the original key so existing local saves remain readable after the
# fantasy rebrand. This is obfuscation compatibility, not a secret credential.
const XOR_KEY          := "DroneTycoonSky2026"

var _flags := 0
var _prev_credits := 0.0
var _prev_check_ms := 0

func _ready() -> void:
    if has_node("/root/GameState"):
        _prev_credits = GameState.credits
    _prev_check_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
    var now_ms := Time.get_ticks_msec()
    if now_ms - _prev_check_ms < 5000: return   # check every 5 s
    _prev_check_ms = now_ms
    if not has_node("/root/GameState"): return
    var cur: float = float(GameState.credits)
    var diff: float = cur - _prev_credits
    # Max possible income in 5s: income_per_sec * 5 * any event mult * safety factor 3x
    var event_mult: float = 1.0
    if has_node("/root/Events"):
        event_mult = float(Events.current_mult)
    var max_possible: float = float(GameState.income_per_sec()) * 5.0 * 3.0 * event_mult
    if diff > max_possible + 1_000_000.0:   # tolerance for manual transactions
        _flag("balance_spike diff=%.0f max=%.0f" % [diff, max_possible])
    _prev_credits = cur

## Validate a timestamp from a save file. Returns safe elapsed seconds.
func validate_elapsed(saved_ts: int) -> float:
    var now_ts: int = int(Time.get_unix_time_from_system())
    if saved_ts > now_ts + 300:
        _flag("future_ts saved=%d now=%d" % [saved_ts, now_ts])
        return 0.0
    var elapsed: float = float(max(0, now_ts - saved_ts))
    return minf(elapsed, MAX_OFFLINE_SECS)

## Clamp credits to a sane range.
func clamp_credits(v: float) -> float:
    return clampf(v, 0.0, 1e18)

## Clamp gems to sane range.
func clamp_gems(v: int) -> int:
    return clampi(v, 0, 999_999)

## Simple XOR obfuscation (not encryption — deters casual save editing).
## Builds bytes then hex-encodes natively: the old per-character `"%02x" % c`
## allocated a formatted String for every one of ~2500 chars on the main thread
## every 15s, which was the bulk of the autosave hitch. PackedByteArray.hex_encode()
## emits exactly 2 lowercase hex digits per byte — byte-identical output for the
## ASCII payload, so saves written by older builds still decode.
func encode(data: String) -> String:
    var kl: int = XOR_KEY.length()
    var n: int = data.length()
    var bytes := PackedByteArray()
    bytes.resize(n)
    for i in range(n):
        bytes[i] = (data.unicode_at(i) ^ XOR_KEY.unicode_at(i % kl)) & 0xFF
    return bytes.hex_encode()

func decode(hex: String) -> String:
    var result := ""
    var kl: int = XOR_KEY.length()
    var pairs: int = hex.length() / 2
    for i in range(pairs):
        var b: int = hex.substr(i * 2, 2).hex_to_int()
        result += char(b ^ XOR_KEY.unicode_at(i % kl))
    return result

## Fast checksum for integrity validation.
func checksum(data: String) -> String:
    var h: int = 0x811C9DC5  # FNV-1a seed
    for i in range(data.length()):
        h = h ^ data.unicode_at(i)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return "%08x" % h

func _flag(reason: String) -> void:
    _flags += 1
    push_warning("AntiCheat #%d: %s" % [_flags, reason])

func suspicious() -> bool:
    return _flags >= 5
