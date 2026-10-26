extends Node
## Sound playback (autoload "Sfx"). Effects live in res://assets/audio/sfx
## as <name>.wav; placeholders are synthesised by tools/gen_sounds.py and
## can be replaced by recordings with the same name.
##
## One-shots come from a small pool of non-positional players (cheap on
## every preset). Loops (room ambience) are keyed by name. Voice lines use
## their own player on the Voice bus; a missing voice file is not an error:
## callers fall back to subtitles only.

const DIR := "res://assets/audio/sfx/"
const LOOPS := ["generator_hum", "fluorescent", "static_loop", "park", "drone"]
const POOL := 8

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {}
var _voice: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # ambience continues while paused
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)


func stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := DIR + sound + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV and sound in LOOPS:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	_streams[sound] = s
	return s


func length(sound: String) -> float:
	var s := stream(sound)
	return s.get_length() if s else 0.0


## Plays a one-shot. Returns the player (or null if the sound is missing).
func play(sound: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var s := stream(sound)
	if s == null:
		return null
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stop()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()
	return p


## Starts (or retunes) a named loop. Fades in over `fade` seconds.
func loop(sound: String, volume_db := 0.0, bus := "SFX", fade := 0.0) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		var s := stream(sound)
		if s == null:
			return
		p = AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		add_child(p)
		_loops[sound] = p
	if p.has_meta("tween"):
		(p.get_meta("tween") as Tween).kill()
	if not p.playing:
		p.volume_db = -60.0 if fade > 0.0 else volume_db
		p.play()
	if fade > 0.0:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", volume_db, fade)
		p.set_meta("tween", tw)
	else:
		p.volume_db = volume_db


func stop_loop(sound: String, fade := 0.0) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		return
	_loops.erase(sound)
	if fade <= 0.0:
		p.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_loops(fade := 0.0) -> void:
	for k in _loops.keys():
		stop_loop(k, fade)


func is_looping(sound: String) -> bool:
	return _loops.has(sound)


## Plays a recorded voice line. Returns its length, or -1.0 when the file
## does not exist (the caller then shows the subtitle on its own).
func voice(path: String) -> float:
	if path == "" or not ResourceLoader.exists(path):
		return -1.0
	var s: AudioStream = load(path)
	if s == null:
		return -1.0
	_voice.stop()
	_voice.stream = s
	_voice.play()
	return s.get_length()


func stop_voice() -> void:
	_voice.stop()
