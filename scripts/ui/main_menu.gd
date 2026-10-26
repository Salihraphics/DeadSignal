extends Control
## Entry point: the main menu over a live 3D backdrop of the missile hall
## (MenuBackdrop). Identity block top left, decorative facility status top
## right, the menu on the left with open space toward the missile, a
## technical strip along the bottom.
##
## CONTINUE is enabled only when a valid run save exists. NEW GAME plays the
## opening cinematic, which leads straight into the command room. SETTINGS
## opens the shared settings panel (the same one as in game); CREDITS a
## credits panel. Layout is built from containers and scales with the
## screen, so it holds on phones and tablets in landscape.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const MenuBackdrop := preload("res://scripts/ui/menu_backdrop.gd")

var _ui: Control
var _menu: VBoxContainer
var _settings: PanelContainer
var _credits: PanelContainer
var _confirm: PanelContainer
var _dim: ColorRect
var _overlay_box: CenterContainer
var _net_led: ColorRect
var _px := 24
var _size := Vector2.ZERO


func _ready() -> void:
	name = "MainMenu"
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(MenuBackdrop.new())
	# One gradient keeps the left of the frame dark enough for the menu.
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.022, 0.024, 0.9))
	g.set_color(1, Color(0.02, 0.022, 0.024, 0.0))
	g.add_point(0.42, Color(0.02, 0.022, 0.024, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	gt.fill_to = Vector2(0.78, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sfx.stop_all_loops()
	Sfx.loop("drone", -10.0, "Music", 2.0)
	Sfx.loop("generator_hum", -24.0, "SFX", 2.0)
	Subtitles.clear()
	get_viewport().size_changed.connect(_rebuild)


func _rebuild() -> void:
	if get_viewport().get_visible_rect().size == _size:
		return
	_ui.queue_free()
	_build()


func _build() -> void:
	_size = get_viewport().get_visible_rect().size
	var vs := _size
	_px = UiKit.text_px(get_viewport())
	_confirm = null
	_ui = Control.new()
	_ui.name = "UI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mx := int(clampf(vs.x * 0.045, 28.0, 90.0))
	var my := int(clampf(vs.y * 0.05, 20.0, 60.0))
	margin.add_theme_constant_override("margin_left", mx)
	margin.add_theme_constant_override("margin_right", mx)
	margin.add_theme_constant_override("margin_top", my)
	margin.add_theme_constant_override("margin_bottom", int(my * 0.6))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	# Header: identity block | facility status.
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_identity())
	var hs := Control.new()
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hs)
	head.add_child(_status_panel())

	# Body: the menu column on the left, open space to the missile.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var menu_col := VBoxContainer.new()
	menu_col.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_col.custom_minimum_size.x = clampf(vs.x * 0.33, 380.0, 560.0)
	body.add_child(menu_col)
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", int(_px * 0.35))
	menu_col.add_child(_menu)
	var cont := _item("CONTINUE", "Resume current operation", "continue", _continue, "Continue")
	cont.disabled_note = "No operation in progress"
	cont.disabled = not Run.has_save()
	_item("NEW GAME", "Begin a new assignment", "new", _new_game, "NewGame")
	_item("SETTINGS", "Configure system preferences", "settings", _open_settings, "SettingsButton")
	_item("CREDITS", "Personnel and acknowledgements", "credits", _open_credits, "CreditsButton")
	if not OS.has_feature("web"):
		_item("EXIT", "Close the terminal", "exit", func() -> void: get_tree().quit(), "Exit")
	var bs := Control.new()
	bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(bs)

	col.add_child(_footer())

	# Overlays share one dim layer and a centring box.
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.012, 0.013, 0.72)
	_dim.visible = false
	_ui.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_box = CenterContainer.new()
	_overlay_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_overlay_box)
	_overlay_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_overlays)
	_fit(_settings, 0.86, 0.88)
	_overlay_box.add_child(_settings)
	_credits = _credits_panel()
	_credits.visible = false
	_focus_first.call_deferred()


## The first usable entry starts selected (keyboard / gamepad navigation).
func _focus_first() -> void:
	if not is_instance_valid(_menu):
		return
	for b in _menu.get_children():
		if b is Button and not b.disabled:
			b.grab_focus()
			return


func _item(t: String, note: String, kind: String, cb: Callable, id: String) -> MenuItem:
	var b := MenuItem.new()
	b.name = id
	b.setup(t, note, kind, _px)
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


func _fit(panel: Control, wf: float, hf: float) -> void:
	panel.custom_minimum_size = Vector2(minf(_size.x * wf, 1100.0), _size.y * hf)


# --- Header ------------------------------------------------------------------------------------

func _identity() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var title := UiKit.label("DEAD SIGNAL", int(_px * 2.9), UiKit.OFFWHITE)
	title.name = "Title"
	title.add_theme_font_override("font", UiKit.title_font())
	v.add_child(title)
	var accent := HBoxContainer.new()
	accent.add_theme_constant_override("separation", 6)
	accent.add_child(UiKit.rule(UiKit.GREEN, _px * 2.6, 3.0))
	accent.add_child(UiKit.rule(UiKit.STEEL_DIM, _px * 7.0, 1.0))
	for c in accent.get_children():
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(accent)
	var gap := Control.new()
	gap.custom_minimum_size.y = _px * 0.45
	v.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_px * 0.6))
	var flag_path := "res://assets/flags/flag_norvak.png"
	if ResourceLoader.exists(flag_path):
		var flag := TextureRect.new()
		flag.name = "NorvakFlag"
		flag.texture = load(flag_path)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.custom_minimum_size = Vector2(_px * 2.1, _px * 1.4)
		flag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(flag)
	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 0)
	var ms := maxi(12, int(_px * 0.56))
	meta.add_child(UiKit.mono("NORVAK STRATEGIC COMMAND", ms, UiKit.OFFWHITE))
	meta.add_child(UiKit.mono("VARNESK · 1985", ms, UiKit.MUTED))
	meta.add_child(UiKit.mono("STRATEGIC CONTROL FACILITY", ms, UiKit.MUTED))
	row.add_child(meta)
	v.add_child(row)
	return v


## Decorative facility status. Fixed values: nothing here implies events.
func _status_panel() -> Control:
	var p := PanelContainer.new()
	p.name = "StatusPanel"
	var sb := UiKit.box(Color(0.04, 0.045, 0.047, 0.82), UiKit.STEEL_DIM, 1, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var ms := maxi(11, int(_px * 0.5))
	v.add_child(UiKit.mono("FACILITY STATUS", ms, Color(UiKit.MUTED, 0.75)))
	v.add_child(UiKit.rule(UiKit.STEEL_DIM, _px * 11.0, 1.0))
	_net_led = _status_row(v, "COMMAND NETWORK", "STANDBY", UiKit.AMBER, ms)
	_status_row(v, "INTERNAL SYSTEMS", "NOMINAL", UiKit.GREEN, ms)
	_status_row(v, "TERMINAL", "K-4", UiKit.OFFWHITE, ms)
	# The network lamp blinks slowly (standby); a timer, not a per-frame script.
	var t := Timer.new()
	t.wait_time = 1.2
	t.autostart = true
	t.timeout.connect(func() -> void: _net_led.modulate.a = 0.25 if _net_led.modulate.a > 0.5 else 1.0)
	p.add_child(t)
	return p


func _status_row(parent: Control, key: String, value: String, c: Color, ms: int) -> ColorRect:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var led := ColorRect.new()
	led.color = c
	led.custom_minimum_size = Vector2(ms * 0.55, ms * 0.55)
	led.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(led)
	var k := UiKit.mono(key, ms, UiKit.MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(UiKit.mono(value, ms, c))
	parent.add_child(h)
	return led


func _footer() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_px * 0.4))
	v.add_child(UiKit.rule(UiKit.STEEL_DIM, 0.0, 1.0))
	var h := HBoxContainer.new()
	h.name = "Footer"
	h.add_theme_constant_override("separation", int(_px * 0.7))
	var fs := maxi(11, int(_px * 0.48))
	var items := ["NORVAK STRATEGIC COMMAND", "TERMINAL K-4", "SYSTEM BUILD 1985.04", "SECURE FACILITY"]
	for i in range(items.size()):
		if i > 0:
			var sep := UiKit.rule(UiKit.STEEL_DIM, 1.0, fs)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(sep)
		h.add_child(UiKit.mono(items[i], fs, Color(UiKit.MUTED, 0.8)))
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	h.add_child(UiKit.mono("V%s" % ProjectSettings.get_setting("application/config/version", "0"), fs, Color(UiKit.MUTED, 0.55)))
	v.add_child(h)
	return v


# --- Overlays ---------------------------------------------------------------------------------

func _show_overlay(panel: Control) -> void:
	for p in [_settings, _credits, _confirm]:
		if p:
			p.visible = p == panel
	_dim.visible = true
	_menu.visible = false


func _close_overlays() -> void:
	for p in [_settings, _credits, _confirm]:
		if p:
			p.visible = false
	_dim.visible = false
	_menu.visible = true
	_focus_first()


func _panel_header(v: VBoxContainer, title: String, sub: String) -> void:
	var head := HBoxContainer.new()
	var tv := VBoxContainer.new()
	tv.add_child(UiKit.label(title, int(_px * 1.35), UiKit.OFFWHITE))
	tv.add_child(UiKit.mono(sub, maxi(12, int(_px * 0.52)), UiKit.MUTED))
	head.add_child(tv)
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(s)
	var back := UiKit.button("BACK", _close_overlays, "Back")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(_px * 5.5, UiKit.MIN_TOUCH)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(back)
	v.add_child(head)
	v.add_child(UiKit.rule(UiKit.STEEL_DIM, 0.0, 1.0))


func _credits_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "CreditsPanel"
	_fit(p, 0.7, 0.8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_px * 0.5))
	p.add_child(v)
	_panel_header(v, "CREDITS", "PERSONNEL AND ACKNOWLEDGEMENTS")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(_px * 0.55))
	scroll.add_child(list)
	var rows := [
		["DESIGN AND DIRECTION", "Salihraphics"],
		["ENGINE", "Godot Engine 4.5 (MIT licence)"],
		["TYPEFACES", "Liberation Sans (SIL Open Font Licence 1.1), JetBrains Mono (Apache 2.0)"],
		["SOUND", "Synthesised placeholder effects (tools/gen_sounds.py)"],
		["VOICE", "Russian dialogue recordings not yet produced; English subtitles stand in"],
		["FLAGS", "Norvak, Dravonya, Ostrev and Merovia: project artwork"],
		["NOTE", "All countries, places, units and weapons are fictional."],
	]
	for r in rows:
		var e := VBoxContainer.new()
		e.add_child(UiKit.mono(r[0], maxi(11, int(_px * 0.5)), UiKit.AMBER))
		var l := UiKit.label(r[1], int(_px * 0.85), UiKit.OFFWHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_child(l)
		list.add_child(e)
	_overlay_box.add_child(p)
	return p


func _ask_overwrite() -> void:
	if _confirm == null:
		_confirm = PanelContainer.new()
		_confirm.name = "ConfirmPanel"
		_confirm.custom_minimum_size = Vector2(minf(_size.x * 0.56, 760.0), 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", int(_px * 0.5))
		_confirm.add_child(v)
		v.add_child(UiKit.mono("CONFIRMATION REQUIRED", maxi(12, int(_px * 0.52)), UiKit.AMBER))
		v.add_child(UiKit.label("An operation is in progress.", int(_px * 1.2), UiKit.OFFWHITE))
		var info := UiKit.label("Beginning a new assignment discards the saved shift.", int(_px * 0.8), UiKit.MUTED)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(info)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(_px * 0.5))
		var yes := UiKit.button("DISCARD AND BEGIN", _new_game, "ConfirmNew")
		var no := UiKit.button("CANCEL", _close_overlays, "CancelNew")
		for b in [yes, no]:
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(b)
		v.add_child(h)
		_overlay_box.add_child(_confirm)
	_show_overlay(_confirm)


# --- Actions ------------------------------------------------------------------------------------

func _continue() -> void:
	if not Run.load_run():
		_ui.queue_free()          # the save vanished or is invalid
		_build()
		return
	_go("res://scenes/main.tscn")


func _new_game() -> void:
	if Run.has_save() and (_confirm == null or not _confirm.visible):
		_ask_overwrite()
		return
	Run.new_run()
	_go("res://scenes/intro.tscn")


func _open_settings() -> void:
	_show_overlay(_settings)


func _open_credits() -> void:
	_show_overlay(_credits)


func _go(path: String) -> void:
	Sfx.stop_loop("drone", 1.0)
	Sfx.stop_loop("generator_hum", 1.0)
	get_tree().change_scene_to_file(path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _dim and _dim.visible:
			_close_overlays()
			return
		get_tree().quit()
