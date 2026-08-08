extends Node
## Procedural SFX v2 — 44.1 kHz, richer synthesis.
## Music: royalty-free tracks by Eric Matyas (www.soundimage.org)
## Public API: play(name), duck(), muted, to_dict/from_dict.

const RATE := 44100
const MUSIC_FILES: Array[String] = [
	"res://assets/music/technoscape.mp3",
	"res://assets/music/network.mp3",
	"res://assets/music/city_of_tomorrow.mp3",
	"res://assets/music/stratosphere.mp3",
	"res://assets/music/beepage.mp3",
]
const ACTIVE_TRACKS: Array[String] = ["technoscape.mp3", "network.mp3", "beepage.mp3"]

var muted    := false
var music_vol := -18.0
var sfx_vol   := 0.0
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next      := 0
var _ambient: AudioStreamPlayer
## Paths, not streams: AudioStreamMP3 holds the whole compressed file in RAM, so
## preloading all 5 tracks cost ~12.5 MB resident to play one at a time. Loaded
## on demand at track boundaries (_start_music / _on_music_finished), where a
## crossfade already hides the load.
var _music_paths: Array[String] = []
var _music_idx: int = 0
# music fade-in on track change + side-chain duck under one-shot stingers. Both
# feed muted_music_db() (the per-frame volume authority in _process) so they need
# no separate tween that would fight it.
var _fadein_until := 0
var _fadein_dur := 1200
var _duck_until := 0
var _duck_hold := 400
var _duck_db := 0.0
var _last_deliver_snd := 0   # ms; throttles the delivery blip so it never spams
var _last_music_db := INF    # dirty-check for the per-frame volume write in _process
var _last_music_pitch := -1.0
var _mix_intensity := 0.0    # 0 calm economy → 1 event / high combo
var _mix_target := 0.0
var _mix_frame := 0

func _ready() -> void:
	_build_streams()
	_build_music()
	for i in range(16):
		var p := AudioStreamPlayer.new(); add_child(p); _players.append(p)
	_ambient = AudioStreamPlayer.new(); add_child(_ambient)
	_ambient.finished.connect(_on_music_finished)
	_start_music()
	if has_node("/root/GameState"):
		GameState.delivered.connect(_on_delivered)
		GameState.city_unlocked.connect(func(_i): play("unlock", 1.0, -3.0))
	# country_changed handled by main.gd — no double-play here
	if has_node("/root/Events"):
		Events.started.connect(func(_id): play("event_start", 1.0, -2.0))
	if has_node("/root/Daily"):
		Daily.reward_claimed.connect(func(_idx): play("daily", 1.0, 0.0))
	if has_node("/root/Prestige"):
		Prestige.prestiged.connect(func(_n): play("prestige", 0.95, 2.0))
	# off the boot critical path — the intro tweens get the frame, not synthesis
	get_tree().create_timer(2.0).timeout.connect(_build_deferred)

func _build_streams() -> void:
	_streams["tap"]         = _click(0.020, 0.18)
	_streams["page"]        = _whoosh(0.16, 0.10)
	_streams["buy"]         = _sweep(440.0, 880.0, 0.15, 0.22)
	_streams["whoosh"]      = _whoosh(0.30, 0.20)
	_streams["unlock"]      = _arp([392.0, 493.88, 587.33, 783.99], 0.072, 0.24)
	_streams["milestone"]   = _arp([261.63, 329.63, 392.00, 493.88, 523.25], 0.095, 0.26)
	_streams["achieve"]     = _jingle([587.33, 698.46, 880.00, 1046.5], 0.080, 0.25)
	# "prestige" is synthesized in _build_deferred() — see _ready()
	_streams["daily"]       = _arp([329.63, 415.30, 493.88, 622.25], 0.085, 0.24)
	_streams["event_start"] = _alert(0.22, 0.22)
	_streams["error"]       = _buzz(0.14, 0.18)
	# "pad" (the no-MP3 fallback bed) is built lazily in _start_music(): it is 8s
	# of PCM = 2.1M interpreted sin() calls and 689 KB, and the branch that uses
	# it never runs while the 5 MP3s ship in the PCK.

## Synthesis that must exist eventually but not at boot. _fanfare() alone was
## ~49 ms desktop (est. 200-400 ms on a low-end phone) of the boot intro, for a
## sting that cannot fire until the player prestiges hours later. Deferred to an
## idle frame rather than made lazy-on-first-play, which would hitch exactly at
## the prestige celebration. play() no-ops on a missing key until this lands.
func _build_deferred() -> void:
	_streams["prestige"] = _fanfare([261.63, 329.63, 392.00, 523.25, 659.26], 0.75, 0.28)

## Load an imported MP3 track. MUST use load() (not FileAccess) so it works in
## exported builds: Godot strips the raw .mp3 source from the PCK and only ships
## the imported resource, so FileAccess.get_file_as_bytes("res://…mp3") returns
## empty on-device (the reason music was silent in the APK even though it played
## in the editor). Looping is handled by the playlist (_on_music_finished), so
## force loop off on the shared resource.
func _load_mp3(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is AudioStreamMP3:
		(res as AudioStreamMP3).loop = false
	return res as AudioStream

## Only checks existence — loading is deferred to the track boundary. Keeping the
## ResourceLoader.exists() filter here preserves the old "missing MP3s -> pad
## fallback" behaviour without paying for 5 decoders up front.
func _build_music() -> void:
	for path in MUSIC_FILES:
		if ResourceLoader.exists(path):
			_music_paths.append(path)

## Assigning _ambient.stream drops the previous track's last reference, so only
## one AudioStreamMP3 is ever resident.
func _play_track(idx: int) -> void:
	var st := _load_mp3(_music_paths[idx])
	if st == null:
		return
	_ambient.stream = st
	_fadein_until = Time.get_ticks_msec() + _fadein_dur
	_ambient.volume_db = muted_music_db()

func _start_music() -> void:
	if _music_paths.is_empty():
		if not _streams.has("pad"):
			_streams["pad"] = _pad(8.0)   # built only if we truly have no music
		_ambient.stream = _streams["pad"]
		_ambient.volume_db = muted_music_db()
		_ambient.play()
		return
	_music_idx = _pick_music_track(false)   # calm first impression; still varied
	_play_track(_music_idx)
	_ambient.play()

func _on_music_finished() -> void:
	if _music_paths.is_empty(): return
	_music_idx = _pick_music_track(_mix_intensity >= 0.55)
	_play_track(_music_idx)   # ease the new track in (no hard slam)
	if not muted:
		_ambient.play()

## Selects a calm or active playlist pool without repeating the track that just
## ended. If a build ships only a subset of music files, it gracefully falls
## back to every available track.
func _pick_music_track(want_active: bool) -> int:
	var pool: Array[int] = []
	for i in range(_music_paths.size()):
		var is_active := _music_paths[i].get_file() in ACTIVE_TRACKS
		if is_active == want_active:
			pool.append(i)
	if pool.is_empty():
		for i in range(_music_paths.size()): pool.append(i)
	if pool.size() > 1 and _music_idx in pool:
		pool.erase(_music_idx)
	return pool[randi() % pool.size()]

func _process(delta: float) -> void:
	_mix_frame += 1
	if _mix_frame % 12 == 0:
		_mix_target = 0.0
		if has_node("/root/GameState"):
			_mix_target = clampf((GameState.combo_mult() - 1.0) / 2.0, 0.0, 0.72)
		if has_node("/root/Events") and Events.is_active():
			_mix_target = maxf(_mix_target, 0.88)
	_mix_intensity = move_toward(_mix_intensity, _mix_target, delta * 0.55)
	if _ambient:
		# Both are AudioServer writes; muted_music_db() only moves during a
		# fade-in/duck window, so skip the write on the ~99% of frames where
		# nothing changed instead of poking the server 120x/sec.
		if _ambient.stream_paused != muted:
			_ambient.stream_paused = muted
		var db := muted_music_db()
		if not muted:
			# Calm play sits slightly behind the UI; a hot streak/event moves the
			# same track forward without ever overpowering reward stingers.
			db += lerpf(-1.2, 1.0, _mix_intensity)
		if not is_equal_approx(db, _last_music_db):
			_last_music_db = db
			_ambient.volume_db = db
		var pitch := lerpf(0.995, 1.025, _mix_intensity)
		if not is_equal_approx(pitch, _last_music_pitch):
			_last_music_pitch = pitch
			_ambient.pitch_scale = pitch

func _on_delivered(_amount: float, _hub: int, _count: int) -> void:
	# Subtle, THROTTLED delivery blip (full removal made the core loop feel dead).
	# Rate-limited to ~1 per 280ms and quiet, so it reads as gentle activity, not
	# the machine-gun spam that got it removed at high drone counts.
	if muted: return
	var now := Time.get_ticks_msec()
	var cadence_ms := int(lerpf(380.0, 220.0, _mix_intensity))
	if now - _last_deliver_snd < cadence_ms: return
	_last_deliver_snd = now
	play("tap", randf_range(1.12, 1.30) + _mix_intensity * 0.12,
		lerpf(-18.0, -14.5, _mix_intensity))

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if muted or not _streams.has(name): return
	# micro-detune repeated short SFX so rapid taps/buys don't sound robotic
	if pitch == 1.0 and name in ["tap", "buy", "whoosh"]:
		pitch = randf_range(0.97, 1.03)
	# big celebratory stingers duck the music so they punch through
	if name == "prestige":
		duck(-9.0, 900)
	elif name in ["milestone", "achieve"]:
		duck(-6.0, 500)
	var p := _players[_next]; _next = (_next + 1) % _players.size()
	p.stream = _streams[name]; p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = vol_db + sfx_vol; p.play()

## Side-chain duck: briefly lower the music bed so a one-shot stinger (prestige,
## milestone) punches through, then ramp back. Feeds muted_music_db() so the
## per-frame volume write in _process applies it — no separate tween needed.
func duck(amount_db := -8.0, hold_ms := 500) -> void:
	_duck_db = amount_db
	_duck_hold = hold_ms
	_duck_until = Time.get_ticks_msec() + hold_ms

func set_music_vol(db: float) -> void:
	music_vol = clampf(db, -40.0, 0.0)
	if _ambient: _ambient.volume_db = muted_music_db()

func set_sfx_vol(db: float) -> void:
	sfx_vol = clampf(db, -20.0, 6.0)

func muted_music_db() -> float:
	if muted:
		return -80.0
	var v := music_vol
	var now := Time.get_ticks_msec()
	# fade-in on track change (ramps -40 → music_vol)
	if now < _fadein_until:
		var p := 1.0 - float(_fadein_until - now) / float(_fadein_dur)
		v = lerpf(-40.0, music_vol, clampf(p, 0.0, 1.0))
	# stinger duck (snaps down, ramps back toward 0 over the hold)
	if now < _duck_until:
		v += _duck_db * (float(_duck_until - now) / float(maxi(1, _duck_hold)))
	return v

# ── Oscillators ──────────────────────────────────────────────────────────────────

func _sine(freq: float, t: float) -> float:
	return sin(TAU * freq * t)

func _tri(freq: float, t: float) -> float:
	return 1.0 - 4.0 * abs(fmod(freq * t, 1.0) - 0.5)

func _saw(freq: float, t: float) -> float:
	return 2.0 * fmod(freq * t, 1.0) - 1.0

# Exponential decay with a short linear attack
func _dec(i: int, n: int, atk: int, decay: float) -> float:
	if i < atk:
		return float(i) / float(max(1, atk))
	return pow(1.0 - float(i - atk) / float(max(1, n - atk)), decay)

# ── Sound builders ───────────────────────────────────────────────────────────────

## Soft noise click for tap / tick
func _click(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var env := pow(1.0 - float(i) / float(n), 3.0)
		var raw := randf() * 2.0 - 1.0
		prev = lerpf(prev, raw, 0.22)
		data.encode_s16(i * 2, int(clampf(prev * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Rising sine+triangle sweep — buy button
func _sweep(f1: float, f2: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.004 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var freq := lerpf(f1, f2, pow(float(i) / float(n), 0.7))
		var env := _dec(i, n, atk, 2.0)
		var s := (_sine(freq, t) * 0.65 + _tri(freq, t) * 0.35) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Rising noise + tone whoosh — griffin courier hire
func _whoosh(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var frac := float(i) / float(n)
		var env := sin(PI * frac)
		var raw := randf() * 2.0 - 1.0
		prev = lerpf(prev, raw, 0.05 + 0.35 * frac)
		var t := float(i) / RATE
		var tone := _sine(lerpf(80.0, 400.0, pow(frac, 1.5)), t) * 0.3 * frac
		data.encode_s16(i * 2, int(clampf((prev * 0.7 + tone) * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Ascending arpeggio (sine + triangle blend) — unlock / milestone / daily
func _arp(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_n := int(note_dur * RATE)
	var n := note_n * freqs.size()
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.004 * RATE)
	for s_idx in range(freqs.size()):
		var freq: float = float(freqs[s_idx])
		var base := s_idx * note_n
		for i in range(note_n):
			var t := float(base + i) / RATE
			var env := _dec(i, note_n, atk, 1.6)
			var s := (_sine(freq, t) * 0.75 + _tri(freq, t) * 0.25) * env * vol
			var prev_val := float(data.decode_s16((base + i) * 2)) / 32767.0
			data.encode_s16((base + i) * 2, int(clampf(prev_val + s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Staccato jingle with gap before final long note — achievements
func _jingle(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_n := int(note_dur * RATE)
	var gap_n  := int(0.040 * RATE)
	var total  := (note_n + gap_n) * (freqs.size() - 1) + note_n * 2
	var data := PackedByteArray(); data.resize(total * 2)
	var atk := int(0.003 * RATE)
	var cursor := 0
	for s_idx in range(freqs.size()):
		var freq: float = float(freqs[s_idx])
		var this_n := note_n * 2 if s_idx == freqs.size() - 1 else note_n
		for i in range(this_n):
			var t := float(cursor + i) / RATE
			var env := _dec(i, this_n, atk, 1.8)
			var s := _sine(freq, t) * env * vol
			data.encode_s16((cursor + i) * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
		cursor += this_n
		if s_idx < freqs.size() - 1:
			cursor += gap_n
	return _wav(data)

## Staggered chord fanfare — prestige
func _fanfare(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var stagger := int(0.040 * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var sz := freqs.size()
	for s_idx in range(sz):
		var freq: float = float(freqs[s_idx])
		var start := s_idx * stagger
		var atk := int(0.010 * RATE)
		for i in range(start, n):
			var t := float(i) / RATE
			var local_n := n - start
			var env := _dec(i - start, local_n, atk, 1.8)
			var existing := float(data.decode_s16(i * 2)) / 32767.0
			var s := _sine(freq, t) * env * vol / float(sz)
			data.encode_s16(i * 2, int(clampf(existing + s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Two rising chirps — event start
func _alert(dur: float, vol: float) -> AudioStreamWAV:
	var chirp_n := int(dur * 0.4 * RATE)
	var gap_n   := int(dur * 0.2 * RATE)
	var n := chirp_n * 2 + gap_n
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.005 * RATE)
	for chirp in range(2):
		var f1 := 440.0 if chirp == 0 else 660.0
		var f2 := 880.0 if chirp == 0 else 1320.0
		var base := chirp * (chirp_n + gap_n)
		for i in range(chirp_n):
			var t := float(base + i) / RATE
			var freq := lerpf(f1, f2, float(i) / float(chirp_n))
			var env := _dec(i, chirp_n, atk, 2.0)
			var s := _sine(freq, t) * env * vol
			data.encode_s16((base + i) * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Detuned sawtooth buzz — error
func _buzz(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.003 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var env := _dec(i, n, atk, 2.5)
		var s := (_saw(180.0, t) + _saw(182.7, t)) * 0.5 * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## C major pad with vibrato + tremolo, loops every 8 s
func _pad(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		var vib := 1.0 + 0.003 * sin(TAU * 3.8 * t)
		var lfo := 0.84 + 0.16 * sin(TAU * 0.11 * t)
		# C major triad + octave C, all with gentle vibrato
		var s := (
			sin(TAU * 130.81 * vib * t) * 0.40 +
			sin(TAU * 164.81 * vib * t) * 0.28 +
			sin(TAU * 196.00 * vib * t) * 0.22 +
			sin(TAU * 261.63 * vib * t) * 0.10
		) * lfo * 0.48
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0; st.loop_end = n - 1
	return st

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE; st.stereo = false; st.data = data
	return st

# ── Persistence ──────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {"muted": muted, "music_vol": music_vol, "sfx_vol": sfx_vol}

func from_dict(d: Dictionary) -> void:
	muted     = bool(d.get("muted", false))
	music_vol = float(d.get("music_vol", -18.0))
	sfx_vol   = float(d.get("sfx_vol", 0.0))
