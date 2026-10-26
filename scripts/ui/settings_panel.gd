extends PanelContainer
## Settings screen shared by the main menu and the in-game pause menu.
## Every row writes straight through to Settings / Graphics, which persist
## immediately; there is no separate "apply" step to forget.
##
## Rows are steppers ([<] value [>]) rather than sliders: large, precise
## targets on a touch screen. Volumes and sensitivity also show a level
## meter.

signal closed

const TABS := ["GRAPHICS", "AUDIO", "SUBTITLES", "CONTROLS"]

var _tab := "GRAPHICS"
var _body: VBoxContainer
var _tabs: HBoxContainer
var _px := 24


func _ready() -> void:
	theme = UiKit.theme()
	_px = UiKit.text_px(get_viewport())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(_px * 0.45))
	add_child(root)
	var head := HBoxContainer.new()
	var tv := VBoxContainer.new()
	tv.add_child(UiKit.label("SETTINGS", int(_px * 1.35), UiKit.OFFWHITE))
	tv.add_child(UiKit.mono("SYSTEM PREFERENCES  ·  SAVED ON THIS DEVICE", maxi(12, int(_px * 0.52)), UiKit.MUTED))
	head.add_child(tv)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var back := UiKit.button("BACK", close, "Back")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(_px * 5.5, UiKit.MIN_TOUCH)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(back)
	root.add_child(head)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	root.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
	scroll.add_child(_body)
	_build()


func close() -> void:
	visible = false
	closed.emit()


func show_tab(tab: String) -> void:
	_tab = tab
	_build()


func _build() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)              # free names now for the new rows
		c.queue_free()
	for t in TABS:
		var b := UiKit.button(t, show_tab.bind(t), "Tab" + t)
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_pressed = t == _tab
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", int(_px * 0.9))
		_tabs.add_child(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _tab:
		"GRAPHICS":
			_stepper("QUALITY", Graphics.MODES, func() -> String: return Graphics.mode,
				func(v: String) -> void: Graphics.set_mode(v), "Quality")
			_note("Active preset: %s." % Graphics.active)
			_note("AUTO measures this device in the command room and steps down below 40 FPS.")
			_note("LOW is for weaker tablets: reduced 3D resolution, no shadows, glow, accent or desk lights.")
		"AUDIO":
			for bus in Settings.BUSES:
				_volume(bus)
			_note("Music is a placeholder ambient bed. Voice: Russian recordings are not produced yet;")
			_note("dialogue shows English subtitles until they exist.")
		"SUBTITLES":
			_stepper("SUBTITLES", ["ON", "OFF"], func() -> String: return "ON" if Settings.subtitles else "OFF",
				func(v: String) -> void: Settings.set_subtitles(v == "ON"), "Subs")
			_stepper("SIZE", Settings.SUBTITLE_SIZES, func() -> String: return Settings.subtitle_size,
				func(v: String) -> void:
					Settings.set_subtitle_size(v)
					Subtitles.clear()
					Subtitles.say("SAMPLE", "Subtitles at this size.", 2.5), "SubSize")
			_note("Language: English subtitles (spoken language Russian, recordings pending).")
			_note("Lines without a recording are always subtitled, even when subtitles are off.")
		"CONTROLS":
			_stepper("CAMERA SENSITIVITY", ["0.5", "0.6", "0.7", "0.8", "0.9", "1.0", "1.2", "1.4", "1.6", "1.8", "2.0"],
				func() -> String: return "%.1f" % Settings.sensitivity,
				func(v: String) -> void: Settings.set_sensitivity(float(v)), "Sens", false, true)
			_stepper("INVERT VERTICAL", ["OFF", "ON"], func() -> String: return "ON" if Settings.invert_vertical else "OFF",
				func(v: String) -> void: Settings.set_invert_vertical(v == "ON"), "Invert")
			_stepper("REDUCED MOTION", ["OFF", "ON"], func() -> String: return "ON" if Settings.reduced_motion else "OFF",
				func(v: String) -> void: Settings.set_reduced_motion(v == "ON"), "Motion")
			_note("Reduced motion removes camera sway and shake, light flicker and the menu's camera drift.")


## A row cycling through `values`; get_value / set_value talk to settings.
## Numeric rows stop at their ends (`wrap` false) instead of cycling;
## `meter` adds a level meter.
func _stepper(title: String, values: Array, get_value: Callable, set_value: Callable, id: String, wrap := true, meter := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = UiKit.MIN_TOUCH + 8.0
	var l := UiKit.label(title, int(_px * 0.95), UiKit.OFFWHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var bar: Meter = null
	if meter:
		bar = Meter.new()
		bar.custom_minimum_size = Vector2(_px * 6.0, _px * 0.6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
	var value := UiKit.mono("", int(_px * 0.85), UiKit.AMBER)
	value.custom_minimum_size.x = _px * 5.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var refresh := func() -> void:
		value.text = get_value.call()
		if bar:
			bar.fraction = float(values.find(get_value.call())) / maxf(values.size() - 1, 1)
			bar.queue_redraw()
	var step := func(dir: int) -> void:
		var i := values.find(get_value.call())
		var j := posmod(i + dir, values.size()) if wrap else clampi(i + dir, 0, values.size() - 1)
		set_value.call(values[j])
		refresh.call()
	var minus := UiKit.button("<", step.bind(-1), id + "Minus")
	var plus := UiKit.button(">", step.bind(1), id + "Plus")
	for b in [minus, plus]:
		b.custom_minimum_size = Vector2(UiKit.MIN_TOUCH * 1.15, UiKit.MIN_TOUCH)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", _px)
	refresh.call()
	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	_body.add_child(row)
	_body.add_child(UiKit.rule(Color(UiKit.STEEL, 0.14), 0.0, 1.0))


func _volume(bus: String) -> void:
	var steps: Array = []
	for i in range(0, 11):
		steps.append("%d%%" % (i * 10))
	var label: String = {"Master": "MASTER VOLUME", "Music": "MUSIC", "SFX": "SOUND EFFECTS", "Voice": "VOICE"}[bus]
	_stepper(label, steps, func() -> String: return "%d%%" % (roundi(Settings.volume[bus] * 10.0) * 10),
		func(v: String) -> void:
			Settings.set_volume(bus, float(v.trim_suffix("%")) / 100.0)
			Sfx.play("switch_click", 0.0, 1.0, bus if bus != "Master" else "SFX"), "Vol" + bus, false, true)


func _note(text: String) -> void:
	var l := UiKit.mono(text, maxi(12, int(_px * 0.55)), Color(UiKit.MUTED, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)


## Segmented level meter (green segments up to the value).
class Meter extends Control:
	var fraction := 0.0

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		for i in range(n):
			var on := (i + 0.5) / n <= fraction + 0.001
			var c := UiKit.GREEN if on else Color(UiKit.STEEL, 0.2)
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), c)
