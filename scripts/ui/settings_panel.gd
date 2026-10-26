extends PanelContainer
## Settings screen shared by the main menu and the in-game pause menu.
## Every row writes straight through to Settings / Graphics, which persist
## immediately; there is no separate "apply" step to forget.
##
## Rows are steppers ([<] value [>]) rather than sliders: large, precise
## targets on a touch screen.

signal closed

const TABS := ["GRAPHICS", "AUDIO", "SUBTITLES", "CONTROLS"]

var _tab := "GRAPHICS"
var _body: VBoxContainer
var _tabs: HBoxContainer
var _px := 24


func _ready() -> void:
	theme = UiKit.theme()
	_px = UiKit.text_px(get_viewport())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("SETTINGS", int(_px * 1.3)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var back := UiKit.button("[ BACK ]", close, "Back")
	head.add_child(back)
	root.add_child(head)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	root.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
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
		var b := UiKit.button(("> %s" if t == _tab else "  %s") % t, show_tab.bind(t), "Tab" + t)
		b.add_theme_font_size_override("font_size", _px)
		_tabs.add_child(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _tab:
		"GRAPHICS":
			_stepper("QUALITY", Graphics.MODES, func() -> String: return Graphics.mode,
				func(v: String) -> void: Graphics.set_mode(v), "Quality")
			_note("ACTIVE PRESET: %s" % Graphics.active)
			_note("AUTO measures this device in the command room and steps down below 40 FPS.")
			_note("LOW is meant for weak tablets: reduced 3D resolution, no shadows, glow or accent lights.")
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
			_note("LANGUAGE: ENGLISH SUBTITLES (spoken language: Russian, recordings pending).")
			_note("Lines without a recording are always subtitled, even when subtitles are off.")
		"CONTROLS":
			_stepper("CAMERA SENSITIVITY", ["0.5", "0.6", "0.7", "0.8", "0.9", "1.0", "1.2", "1.4", "1.6", "1.8", "2.0"],
				func() -> String: return "%.1f" % Settings.sensitivity,
				func(v: String) -> void: Settings.set_sensitivity(float(v)), "Sens", false)
			_stepper("INVERT VERTICAL", ["OFF", "ON"], func() -> String: return "ON" if Settings.invert_vertical else "OFF",
				func(v: String) -> void: Settings.set_invert_vertical(v == "ON"), "Invert")
			_stepper("REDUCED MOTION", ["OFF", "ON"], func() -> String: return "ON" if Settings.reduced_motion else "OFF",
				func(v: String) -> void: Settings.set_reduced_motion(v == "ON"), "Motion")
			_note("Reduced motion removes camera sway and shake and light flicker.")


## A row cycling through `values`; get_value / set_value talk to settings.
## Numeric rows stop at their ends (`wrap` false) instead of cycling.
func _stepper(title: String, values: Array, get_value: Callable, set_value: Callable, id: String, wrap := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiKit.label(title, _px)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var value := UiKit.label("", _px, UiKit.AMBER)
	value.custom_minimum_size.x = _px * 6.5
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var step := func(dir: int) -> void:
		var i := values.find(get_value.call())
		var j := posmod(i + dir, values.size()) if wrap else clampi(i + dir, 0, values.size() - 1)
		set_value.call(values[j])
		value.text = get_value.call()
	var minus := UiKit.button(" < ", step.bind(-1), id + "Minus")
	var plus := UiKit.button(" > ", step.bind(1), id + "Plus")
	for b in [minus, plus]:
		b.custom_minimum_size = Vector2(UiKit.MIN_TOUCH * 1.2, UiKit.MIN_TOUCH)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", _px)
	value.text = get_value.call()
	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	_body.add_child(row)


func _volume(bus: String) -> void:
	var steps: Array = []
	for i in range(0, 11):
		steps.append("%d%%" % (i * 10))
	_stepper(bus.to_upper(), steps, func() -> String: return "%d%%" % (roundi(Settings.volume[bus] * 10.0) * 10),
		func(v: String) -> void:
			Settings.set_volume(bus, float(v.trim_suffix("%")) / 100.0)
			Sfx.play("switch_click", 0.0, 1.0, bus if bus != "Master" else "SFX"), "Vol" + bus, false)


func _note(text: String) -> void:
	var l := UiKit.label(text, int(_px * 0.75), UiKit.GREEN_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
