extends CanvasLayer
## Speaker-labelled subtitles (autoload "Subtitles"). One line at a time,
## queued, in the lower part of the screen above the HUD buttons so they
## never cover the CRTs or the cinematic's key visuals.
##
## Dialogue is written to be voiced in Russian with English subtitles.
## While no voice recording exists for a line, the subtitle is the fallback
## and is shown even with subtitles switched off (`force`), otherwise the
## line would be lost entirely.

var _panel: PanelContainer
var _label: RichTextLabel
var _queue: Array[Dictionary] = []
var _left := 0.0
var _current: Dictionary = {}
## Lift the subtitles (e.g. the cinematic has no HUD bar to clear).
var bottom_margin := 104.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(func(_k: String) -> void: _layout())


## Queues a line. `duration` <= 0 picks a reading time from its length.
func say(speaker: String, text: String, duration := 0.0, force := false) -> void:
	if not force and not Settings.subtitles:
		return
	if duration <= 0.0:
		duration = reading_time(text)
	_queue.append({"speaker": speaker, "text": text, "duration": duration})
	if _current.is_empty():
		_next()


static func reading_time(text: String) -> float:
	return clampf(1.6 + text.length() * 0.055, 2.2, 7.0)


func clear() -> void:
	_queue.clear()
	_current = {}
	_panel.visible = false


func is_showing() -> bool:
	return not _current.is_empty()


## The line on screen now ({} if none). Used by tests.
func current() -> Dictionary:
	return _current


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		_panel.visible = false
		return
	_current = _queue.pop_front()
	_left = _current.duration
	var who: String = _current.speaker
	_label.text = ("[color=#e8b04a]%s:[/color] %s" % [who, _current.text]) if who != "" else _current.text
	_panel.visible = true
	_layout()
	_layout.call_deferred()          # after the label has measured its text


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_left -= delta
	if _left <= 0.0:
		_next()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var px := Settings.subtitle_px()
	_label.add_theme_font_size_override("normal_font_size", px)
	var w := minf(vs.x * 0.72, 1100.0)
	_label.custom_minimum_size.x = w - 36
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.position = Vector2((vs.x - w) * 0.5, vs.y - bottom_margin - _panel.size.y)
