extends Control
## Entry point: a 1985 military terminal. CONTINUE appears only when a
## valid run save exists. NEW GAME plays the opening cinematic, which leads
## straight into the command room. Built in code so it adapts to any
## aspect ratio; every control is a large touch target.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

const BOOT_LOG := [
	"K-4 TERMINAL  REV 3.1",
	"MEMORY TEST ........ 64K OK",
	"LINE 1 VARNESK ..... CARRIER",
	"LINE 2 KARSEN ...... NO CARRIER",
	"LINE 3 RESERVE ..... CARRIER",
	"CRYPTO UNIT ........ KEYED",
	"SHAFT 1 ............ LOADED",
	"LAST FIELD REPORT .. 2250",
	"READY.",
]

var _menu: VBoxContainer
var _log: Label
var _cursor: Label
var _settings: PanelContainer
var _credits: PanelContainer
var _confirm: PanelContainer
var _px := 24
var _t := 0.0
var _log_shown := 0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_px = UiKit.text_px(get_viewport())
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build()
	add_child(UiKit.Scanlines.new())
	Sfx.stop_all_loops()
	Sfx.loop("drone", -8.0, "Music", 2.0)
	Sfx.loop("generator_hum", -26.0, "SFX", 2.0)
	Subtitles.clear()
	get_viewport().size_changed.connect(_rebuild)


func _rebuild() -> void:
	var px := UiKit.text_px(get_viewport())
	if px == _px:
		return
	_px = px
	for c in get_children():
		if c != get_child(0) and not (c is UiKit.Scanlines):
			c.queue_free()
	_build()


func _build() -> void:
	var vs := get_viewport().get_visible_rect().size
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := int(minf(vs.x, vs.y) * 0.06)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, m)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", int(vs.x * 0.05))
	margin.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	left.add_child(UiKit.label("NORVAK STRATEGIC COMMAND  /  LAUNCH CONTROL POST K-4", int(_px * 0.7), UiKit.GREEN_DIM))
	var title := UiKit.label("DEAD SIGNAL", int(_px * 2.6))
	left.add_child(title)
	left.add_child(UiKit.label("1985", int(_px * 0.8), UiKit.AMBER))
	var gap := Control.new()
	gap.custom_minimum_size.y = _px * 0.8
	left.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 2)
	left.add_child(_menu)
	if Run.has_save():
		_add("> CONTINUE", _continue, "Continue")
	_add("> NEW GAME", _new_game, "NewGame")
	_add("> SETTINGS", _open_settings, "SettingsButton")
	_add("> CREDITS", _open_credits, "CreditsButton")
	_add("> EXIT", func() -> void: get_tree().quit(), "Exit")
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(fill)
	_cursor = UiKit.label("", int(_px * 0.7), UiKit.GREEN_DIM)
	left.add_child(_cursor)

	# Right column: boot log (hidden on narrow screens).
	if vs.x / vs.y > 1.45:
		var right := VBoxContainer.new()
		right.custom_minimum_size.x = vs.x * 0.32
		cols.add_child(right)
		_log = UiKit.label("", int(_px * 0.72), UiKit.GREEN_DIM)
		right.add_child(_log)
		_log_shown = 0

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: _menu.visible = true)
	_overlay(_settings)
	_credits = _text_panel("CREDITS", [
		"DEAD SIGNAL",
		"Created by Salihraphics.",
		"",
		"Engine: Godot Engine 4.5 (MIT licence).",
		"Sound effects: synthesised placeholders (tools/gen_sounds.py).",
		"Voice: Russian dialogue recordings not yet produced;",
		"English subtitles are shown in their place.",
		"Flags of Norvak, Dravonya, Ostrev and Merovia: project artwork.",
		"",
		"All countries, places, units and weapons are fictional.",
	])
	_credits.visible = false


func _add(text: String, cb: Callable, id: String) -> void:
	var b := UiKit.button(text, cb, id)
	b.add_theme_font_size_override("font_size", int(_px * 1.15))
	b.custom_minimum_size.y = maxf(UiKit.MIN_TOUCH, _px * 2.2)
	_menu.add_child(b)


func _overlay(panel: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	var m := minf(vs.x, vs.y) * 0.05
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = m
	panel.offset_top = m
	panel.offset_right = -m
	panel.offset_bottom = -m
	add_child(panel)


func _text_panel(title: String, lines: Array) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label(title, int(_px * 1.3)))
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(s)
	head.add_child(UiKit.button("[ BACK ]", func() -> void:
		p.visible = false
		_menu.visible = true, "Back"))
	v.add_child(head)
	var body := UiKit.label("\n".join(lines), _px)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	_overlay(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	var c := "CARRIER: NONE   %s" % ("_" if fmod(_t, 1.0) < 0.5 else " ")
	if _cursor and _cursor.text != c:
		_cursor.text = c
	if _log and _log_shown < BOOT_LOG.size() and _t > 0.4 + _log_shown * 0.35:
		_log_shown += 1
		_log.text = "\n".join(BOOT_LOG.slice(0, _log_shown))


func _continue() -> void:
	if not Run.load_run():
		_rebuild_menu()            # the save vanished or is invalid
		return
	_go("res://scenes/main.tscn")


func _new_game() -> void:
	if Run.has_save() and (_confirm == null or not _confirm.visible):
		_ask_overwrite()
		return
	Run.new_run()
	_go("res://scenes/intro.tscn" if ResourceLoader.exists("res://scenes/intro.tscn") else "res://scenes/main.tscn")


func _ask_overwrite() -> void:
	if _confirm == null:
		_confirm = PanelContainer.new()
		var v := VBoxContainer.new()
		_confirm.add_child(v)
		v.add_child(UiKit.label("A SHIFT IS IN PROGRESS.", int(_px * 1.2), UiKit.AMBER))
		v.add_child(UiKit.label("Starting a new game discards it.", _px))
		var b := UiKit.button("> DISCARD AND START NEW GAME", _new_game, "ConfirmNew")
		v.add_child(b)
		v.add_child(UiKit.button("> CANCEL", func() -> void:
			_confirm.visible = false
			_menu.visible = true, "CancelNew"))
		_overlay(_confirm)
	_confirm.visible = true
	_menu.visible = false


func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _open_credits() -> void:
	_menu.visible = false
	_credits.visible = true


func _rebuild_menu() -> void:
	_px = -1
	_rebuild()


func _go(path: String) -> void:
	Sfx.stop_loop("drone", 1.0)
	Sfx.stop_loop("generator_hum", 1.0)
	get_tree().change_scene_to_file(path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for p in [_settings, _credits, _confirm]:
			if p and p.visible:
				p.visible = false
				_menu.visible = true
				return
		get_tree().quit()
