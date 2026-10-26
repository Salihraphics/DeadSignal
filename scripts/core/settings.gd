extends Node
## Player preferences (autoload "Settings"): audio volumes, subtitles and
## controls. Graphics quality is owned by GraphicsSettings (autoload
## "Graphics"); both persist to the same user://settings.cfg and always
## load-modify-save so neither overwrites the other's section.
##
## Listeners connect to `changed(key)` and read the values directly.

signal changed(key: String)

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX", "Voice"]
const SUBTITLE_SIZES := ["SMALL", "MEDIUM", "LARGE"]
const SUBTITLE_PX := {"SMALL": 22, "MEDIUM": 28, "LARGE": 36}

## Linear 0..1 per bus.
var volume := {"Master": 0.9, "Music": 0.6, "SFX": 0.9, "Voice": 1.0}
var subtitles := true
var subtitle_size := "MEDIUM"
## Multiplier on the camera's drag speed.
var sensitivity := 1.0
var invert_vertical := false
## Removes camera sway and shake and light flicker.
var reduced_motion := false


func _ready() -> void:
	_ensure_buses()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for b in BUSES:
			volume[b] = clampf(float(cfg.get_value("audio", b.to_lower(), volume[b])), 0.0, 1.0)
		subtitles = bool(cfg.get_value("subtitles", "enabled", subtitles))
		var sz: String = cfg.get_value("subtitles", "size", subtitle_size)
		subtitle_size = sz if sz in SUBTITLE_SIZES else "MEDIUM"
		sensitivity = clampf(float(cfg.get_value("controls", "sensitivity", sensitivity)), 0.5, 2.0)
		invert_vertical = bool(cfg.get_value("controls", "invert_vertical", invert_vertical))
		reduced_motion = bool(cfg.get_value("controls", "reduced_motion", reduced_motion))
	for b in BUSES:
		_apply_volume(b)


## Writes one value without disturbing the rest of the file.
static func store(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)                       # missing file: start empty
	cfg.set_value(section, key, value)
	cfg.save(PATH)


func set_volume(bus: String, v: float) -> void:
	volume[bus] = clampf(snappedf(v, 0.05), 0.0, 1.0)
	_apply_volume(bus)
	store("audio", bus.to_lower(), volume[bus])
	changed.emit("volume")


func set_subtitles(on: bool) -> void:
	subtitles = on
	store("subtitles", "enabled", on)
	changed.emit("subtitles")


func set_subtitle_size(s: String) -> void:
	if s in SUBTITLE_SIZES:
		subtitle_size = s
		store("subtitles", "size", s)
		changed.emit("subtitles")


func subtitle_px() -> int:
	return SUBTITLE_PX[subtitle_size]


func set_sensitivity(v: float) -> void:
	sensitivity = clampf(snappedf(v, 0.1), 0.5, 2.0)
	store("controls", "sensitivity", sensitivity)
	changed.emit("controls")


func set_invert_vertical(on: bool) -> void:
	invert_vertical = on
	store("controls", "invert_vertical", on)
	changed.emit("controls")


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	store("controls", "reduced_motion", on)
	changed.emit("controls")


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v: float = volume[bus]
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)
