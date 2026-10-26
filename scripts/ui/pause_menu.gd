extends CanvasLayer
## In-game menu: RESUME, SETTINGS, SAVE AND EXIT TO MENU. Opened from the
## HUD's MENU button or the Android back gesture when nothing else is open.
## Pauses the scene tree (clock, scenario, dialogue) while visible; ambient
## loops keep playing.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _root: Control
var _list: VBoxContainer
var _settings: PanelContainer
var _opened_frame := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var px := UiKit.text_px(get_viewport())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = px * 18
	panel.add_child(_list)
	_list.add_child(UiKit.label("SHIFT PAUSED", int(px * 1.3)))
	_list.add_child(UiKit.label("FACILITY CLOCK %s" % Run.hhmm(), int(px * 0.8), UiKit.GREEN_DIM))
	for item in [["> RESUME", close, "Resume"], ["> SETTINGS", _open_settings, "SettingsButton"],
			["> SAVE AND EXIT TO MENU", _exit_to_menu, "ExitMenu"]]:
		var b := UiKit.button(item[0], item[1], item[2])
		b.add_theme_font_size_override("font_size", px)
		_list.add_child(b)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: panel.visible = true)
	var m := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.05
	_root.add_child(_settings)
	_settings.anchor_right = 1.0
	_settings.anchor_bottom = 1.0
	_settings.offset_left = m
	_settings.offset_top = m
	_settings.offset_right = -m
	_settings.offset_bottom = -m
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	(_list.get_child(1) as Label).text = "FACILITY CLOCK %s" % Run.hhmm()
	_opened_frame = Engine.get_process_frames()
	_root.visible = true
	_settings.visible = false
	_list.get_parent().visible = true
	get_tree().paused = true


func close() -> void:
	_root.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	_list.get_parent().visible = false
	_settings.visible = true


func _exit_to_menu() -> void:
	Run.save()
	get_tree().paused = false
	Subtitles.clear()
	Sfx.stop_all_loops(0.5)
	Dialogue.enabled = false
	Run.active = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	# The same back press may have just opened the menu: ignore it here.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _root and _root.visible and Engine.get_process_frames() != _opened_frame:
		if _settings.visible:
			_settings.close()
		else:
			close()


func _input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("ui_cancel"):
		if _settings.visible:
			_settings.close()
		else:
			close()
		get_viewport().set_input_as_handled()
