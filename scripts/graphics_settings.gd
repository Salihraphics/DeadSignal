extends Node
## Rendering quality presets. Only rendering cost changes here; gameplay,
## map layers, UI and controls are never touched.
##
## Values follow the measured costs (perf pass): MSAA and full-resolution
## 3D are the largest per-pixel costs, then the shadowed key light, the
## accent lights and glow. The 3D pixel cap is device-independent: a
## high-resolution tablet renders the 3D scene at about the pixel count of
## a phone and upscales it, while UI and CRT text stay at native resolution.
##
## AUTO starts from MEDIUM on mobile (HIGH on desktop), then measures this
## device's own frame rate once and steps down if it stays below 40 FPS.

signal preset_changed(mode: String, active: String)

const MODES := ["AUTO", "LOW", "MEDIUM", "HIGH"]
const PRESETS := {
	"LOW": {"msaa": Viewport.MSAA_DISABLED, "pixel_cap": 1.3e6, "shadows": false, "glow": false, "accent_lights": false, "radar_hz": 15.0},
	"MEDIUM": {"msaa": Viewport.MSAA_DISABLED, "pixel_cap": 2.4e6, "shadows": true, "glow": true, "accent_lights": true, "radar_hz": 24.0},
	"HIGH": {"msaa": Viewport.MSAA_2X, "pixel_cap": 0.0, "shadows": true, "glow": true, "accent_lights": true, "radar_hz": 30.0},
}
const ORDER := ["LOW", "MEDIUM", "HIGH"]
const SETTINGS_PATH := "user://settings.cfg"
## AUTO measurement: wait for the scene to settle, then average.
const WARMUP_S := 4.0
const SAMPLE_S := 4.0
const MIN_AUTO_FPS := 40.0

var mode := "AUTO"
var active := ""
var _auto_steps := 0
var _sample_t := -1.0
var _frames := 0


func _enter_tree() -> void:
	add_to_group("graphics")


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var saved: String = cfg.get_value("graphics", "mode", "AUTO")
		if saved in MODES:
			mode = saved
	get_viewport().size_changed.connect(func() -> void: _apply(active))
	_apply(_initial_preset())
	_restart_auto()


func _initial_preset() -> String:
	if mode != "AUTO":
		return mode
	return "MEDIUM" if OS.has_feature("mobile") else "HIGH"


## Cycles AUTO -> LOW -> MEDIUM -> HIGH -> AUTO (HUD button).
func cycle() -> void:
	set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()])


func set_mode(m: String) -> void:
	mode = m
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "mode", mode)
	cfg.save(SETTINGS_PATH)
	_auto_steps = 0
	_apply(_initial_preset())
	_restart_auto()


func _restart_auto() -> void:
	_sample_t = -WARMUP_S if mode == "AUTO" else -1.0e9
	_frames = 0


func _process(delta: float) -> void:
	if mode != "AUTO" or _sample_t < -1.0e8:
		return
	_sample_t += delta
	if _sample_t < 0.0:
		return
	_frames += 1
	if _sample_t < SAMPLE_S:
		return
	var fps := _frames / _sample_t
	var i := ORDER.find(active)
	if fps < MIN_AUTO_FPS and i > 0 and _auto_steps < 2:
		_auto_steps += 1
		_apply(ORDER[i - 1])
		get_tree().call_group("hud", "toast", "GRAPHICS: %s (MEASURED %d FPS)" % [active, roundi(fps)])
		_restart_auto()                 # measure again at the new level
	else:
		_sample_t = -1.0e9              # settled


func _apply(preset: String) -> void:
	active = preset
	var p: Dictionary = PRESETS[preset]
	var vp := get_viewport()
	vp.msaa_3d = p.msaa
	var pixels := float(vp.size.x * vp.size.y)
	var scale := 1.0
	if p.pixel_cap > 0.0 and pixels > p.pixel_cap:
		scale = clampf(sqrt(p.pixel_cap / pixels), 0.5, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	var room := get_tree().get_first_node_in_group("command_room")
	if room:
		room.set_quality(p.shadows, p.glow)
	for l in get_tree().get_nodes_in_group("accent_light"):
		l.visible = p.accent_lights
	for r in get_tree().get_nodes_in_group("radar"):
		r.redraw_hz = p.radar_hz
	preset_changed.emit(mode, active)


func render_scale() -> float:
	return get_viewport().scaling_3d_scale


func label() -> String:
	return "GFX AUTO: %s" % active if mode == "AUTO" else "GFX " + mode
