extends Node
## Procedural sound effects — port of the WebAudio beep() synth in the HTML game.
## Tones are synthesized once into AudioStreamWAV and played from a small pool.

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0

# Background music (optional file, dropped in by the user). First existing wins.
const MUSIC_PATHS := ["res://audio/music.ogg", "res://audio/music.mp3", "res://audio/music.wav"]
var _music: AudioStreamPlayer
var _has_music := false


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -32.0  # quiet background, sits well under the game SFX
	_music.bus = "Master"
	add_child(_music)
	for path in MUSIC_PATHS:
		if ResourceLoader.exists(path):
			var stream := load(path)
			if stream is AudioStream:
				if "loop" in stream:
					stream.loop = true
				_music.stream = stream
				_has_music = true
				break
	update_music()


## Call whenever Meta.music_on changes (or on startup) to sync playback.
func update_music() -> void:
	if not _has_music:
		return
	if Meta.music_on:
		if not _music.playing:
			_music.play()
	else:
		if _music.playing:
			_music.stop()


# --- Haptics: light vibration for game feel (Android / iOS / Web; no-op on desktop) ---
func vibrate(ms: int) -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(ms)


func tick() -> void: vibrate(25)          # any button press
func buzz_perfect() -> void: vibrate(45)  # perfect landing
func buzz_die() -> void: vibrate(220)     # death / falling off


func _tone(freq: float, type: String, dur: float, vol: float) -> AudioStreamWAV:
	var key := "%s_%s_%s_%s" % [freq, type, dur, vol]
	if _cache.has(key):
		return _cache[key]
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var ph := fmod(t * freq, 1.0)
		var s := 0.0
		match type:
			"sine": s = sin(TAU * freq * t)
			"sawtooth": s = 2.0 * ph - 1.0
			"triangle": s = 4.0 * absf(ph - 0.5) - 1.0
		var env := exp(-6.9 * t / dur)  # ~exponentialRampToValueAtTime(0.001)
		data.encode_s16(i * 2, int(clampf(s * vol * env, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	_cache[key] = w
	return w


func beep(freq: float, type: String, dur: float, vol: float = 0.2) -> void:
	if not Meta.sound_on:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _tone(freq, type, dur, vol)
	p.play()


func _delayed(delay: float, freq: float, type: String, dur: float, vol: float = 0.2) -> void:
	await get_tree().create_timer(delay).timeout
	beep(freq, type, dur, vol)


func grow() -> void: beep(200, "sawtooth", 0.04, 0.07)
func fall() -> void: beep(160, "sine", 0.3)
func land() -> void: beep(420, "sine", 0.12)
func score() -> void: beep(520, "triangle", 0.1)


func perfect() -> void:
	buzz_perfect()
	beep(660, "sine", 0.1, 0.3)
	_delayed(0.08, 880, "sine", 0.15, 0.3)


func fail() -> void:
	buzz_die()
	beep(200, "sawtooth", 0.15)
	_delayed(0.12, 110, "sawtooth", 0.35)


func lvl() -> void:
	beep(523, "sine", 0.12, 0.3)
	_delayed(0.12, 659, "sine", 0.12, 0.3)
	_delayed(0.24, 784, "sine", 0.2, 0.3)
