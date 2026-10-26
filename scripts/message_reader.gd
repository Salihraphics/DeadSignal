extends CanvasLayer
## Full-screen paper view of the current order and of all other traffic
## (status reports, field reports, intercepts, calls, notices). Opened from
## the teleprinter or the HUD notices; can be reopened at any time.
##
## Three views: ORDER (reply with ACCEPT / REFUSE), REPORT (one traffic
## item: time, source, source id, verification, basis, conflicts and the
## confirmation state, with REQUEST CONFIRMATION / FORWARD where allowed)
## and LOG (every item, newest first, unread marked).
##
## ACCEPT / REFUSE need two taps (arm, then confirm) so a stray touch
## cannot decide an order. While open, the backdrop swallows all touch
## input, so the camera behind it never moves.

signal closed

@export var orders: Node

@onready var _source: Label = %Source
@onready var _text: RichTextLabel = %Text
@onready var _scroll: ScrollContainer = %Scroll
@onready var _status: Label = %Status
@onready var _decision: HBoxContainer = %Decision
@onready var _accept: Button = %AcceptButton
@onready var _refuse: Button = %RefuseButton
@onready var _close: Button = %CloseButton
@onready var _stamp: Label = %Stamp

var _armed := ""   # "", "accept" or "refuse"
var _mode := "order"   # order, report, log
var _report_id := ""
var _log_btn: Button
var _actions: HBoxContainer
var _confirm_btn: Button
var _forward_btn: Button
var _log_scroll: ScrollContainer
var _log_list: VBoxContainer


func _ready() -> void:
	add_to_group("message_reader")
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Courier New", "Courier", "Cutive Mono", "Droid Sans Mono", "DejaVu Sans Mono", "monospace"])
	_text.add_theme_font_override("normal_font", mono)
	_text.add_theme_font_override("bold_font", mono)
	_close.pressed.connect(close)
	_accept.pressed.connect(_on_choice.bind("accept"))
	_refuse.pressed.connect(_on_choice.bind("refuse"))
	orders.state_changed.connect(func(_s: int) -> void:
		if visible:
			_refresh())
	_build_extras()
	Run.traffic_changed.connect(func(_i: Dictionary) -> void:
		if visible:
			_refresh())
	Run.traffic_added.connect(func(_i: Dictionary) -> void:
		if visible and _mode == "log":
			_refresh())


## Log button, report actions and the log list (added to the scene's sheet).
func _build_extras() -> void:
	var top := _close.get_parent()
	_log_btn = _close.duplicate(0) as Button
	_log_btn.name = "LogButton"
	_log_btn.unique_name_in_owner = false
	_log_btn.text = "LOG"
	_log_btn.custom_minimum_size.x = 110
	top.add_child(_log_btn)
	top.move_child(_log_btn, _close.get_index())
	_log_btn.pressed.connect(open_log)
	_actions = HBoxContainer.new()
	_actions.name = "ReportActions"
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 16)
	_status.get_parent().add_child(_actions)
	_status.get_parent().move_child(_actions, _status.get_index() + 1)
	_confirm_btn = _accept.duplicate(0) as Button
	_confirm_btn.name = "ConfirmButton"
	_confirm_btn.unique_name_in_owner = false
	_confirm_btn.text = "REQUEST CONFIRMATION"
	_confirm_btn.custom_minimum_size.x = 340
	_confirm_btn.pressed.connect(_on_confirm)
	_actions.add_child(_confirm_btn)
	_forward_btn = _accept.duplicate(0) as Button
	_forward_btn.name = "ForwardButton"
	_forward_btn.unique_name_in_owner = false
	_forward_btn.text = "FORWARD TO COMMAND"
	_forward_btn.custom_minimum_size.x = 340
	_forward_btn.pressed.connect(_on_forward)
	_actions.add_child(_forward_btn)
	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "LogScroll"
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_parent().add_child(_log_scroll)
	_scroll.get_parent().move_child(_log_scroll, _scroll.get_index() + 1)
	_log_list = VBoxContainer.new()
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_list)
	_log_scroll.visible = false
	_actions.visible = false


func is_open() -> bool:
	return visible


## Pending order first, then the newest unread item, then the current
## order for review, then the log.
func open_current() -> void:
	if orders.is_pending():
		_open("order")
		return
	for i in range(Run.traffic.size() - 1, -1, -1):
		var it: Dictionary = Run.traffic[i]
		if not it.read and it.kind != "ORDER":
			open_report(it.id)
			return
	if orders.has_order() and not Run.active:
		_open("order")
	elif not Run.traffic.is_empty() or orders.has_order():
		open_log()


func open_report(id: String) -> void:
	if Run.find_traffic(id).is_empty():
		return
	_report_id = id
	Run.mark_read(id)
	get_tree().call_group("director", "report_read", id)
	_open("report")


func open_log() -> void:
	_open("log")


func open_order() -> void:
	if orders.has_order():
		_open("order")


func _open(mode: String) -> void:
	_mode = mode
	_armed = ""
	_refresh()
	_scroll.scroll_vertical = 0
	visible = true


func mode() -> String:
	return _mode if visible else ""


func close() -> void:
	if not visible:
		return
	visible = false
	_armed = ""
	closed.emit()


func _refresh() -> void:
	_log_btn.visible = Run.active or not Run.traffic.is_empty()
	_scroll.visible = _mode != "log"
	_log_scroll.visible = _mode == "log"
	_actions.visible = false
	if _mode == "log":
		_refresh_log()
		return
	if _mode == "report":
		_refresh_report()
		return
	var o: Dictionary = orders.order
	_source.text = "TELEPRINTER  -  RECEIVED %s" % orders.arrived_at
	_text.text = _format(o)
	var pending: bool = orders.is_pending()
	_decision.visible = pending
	_accept.text = "CONFIRM ACCEPT" if _armed == "accept" else "ACCEPT"
	_refuse.text = "CONFIRM REFUSE" if _armed == "refuse" else "REFUSE"
	_style_armed(_accept, _armed == "accept")
	_style_armed(_refuse, _armed == "refuse")
	if pending:
		_stamp.visible = false
		_status.text = "TAP AGAIN TO CONFIRM. THIS CANNOT BE UNDONE." if _armed else "REPLY REQUIRED"
	else:
		var accepted: bool = orders.state == orders.State.ACCEPTED
		_stamp.visible = true
		var ink := Color(0.1, 0.4, 0.15, 0.85) if accepted else Color(0.6, 0.06, 0.04, 0.85)
		_stamp.text = "%s  %s" % ["ACCEPTED" if accepted else "REFUSED", orders.decided_at]
		_stamp.add_theme_color_override("font_color", ink)
		var box: StyleBoxFlat = _stamp.get_theme_stylebox("normal").duplicate()
		box.border_color = ink
		_stamp.add_theme_stylebox_override("normal", box)
		if orders.state == orders.State.EXPIRED:
			ink = Color(0.35, 0.33, 0.3, 0.85)
			_stamp.text = "NO REPLY  %s" % orders.decided_at
			_stamp.add_theme_color_override("font_color", ink)
			box.border_color = ink
			_status.text = "REPLY DEADLINE PASSED %s  -  RECORDED AS NO REPLY" % orders.decided_at
			return
		_status.text = "REPLY SENT %s  -  %s" % [orders.decided_at, "ACKNOWLEDGED" if accepted else "REFUSAL REPORTED TO COMMAND"]


func _format(o: Dictionary) -> String:
	var lines: PackedStringArray = []
	for h in o.header:
		lines.append("[b]%s[/b]" % h)
	lines.append("-".repeat(46))
	lines.append("ORDER NO.    %s" % o.id)
	for f in o.fields:
		lines.append("%s%s" % [(f[0] + " ").rpad(13), f[1]])
	lines.append("")
	for i in range(o.body.size()):
		lines.append("%d. %s" % [i + 1, o.body[i]])
		lines.append("")
	lines.append(o.footer)
	return "\n".join(lines)


const KIND_NAMES := {"STATUS": "STATUS REPORT", "FIELD": "FIELD REPORT", "INTERCEPT": "RADIO INTERCEPT",
	"CALL": "TELEPHONE CALL", "NOTICE": "NOTICE", "REPLY": "REPLY", "ORDER": "ORDER"}


func _refresh_report() -> void:
	var it := Run.find_traffic(_report_id)
	_decision.visible = false
	_stamp.visible = false
	_source.text = "%s  -  RECEIVED %s" % [KIND_NAMES.get(it.kind, it.kind), it.received]
	var lines: PackedStringArray = []
	lines.append("[b]NORVAK STRATEGIC COMMAND  -  TRAFFIC LOG[/b]")
	lines.append("-".repeat(46))
	var rows := [["REF", it.id], ["TYPE", KIND_NAMES.get(it.kind, it.kind)], ["TIME", it.time],
		["SOURCE", it.source], ["SOURCE ID", it.source_id], ["VERIFICATION", it.verification]]
	if it.has("channel"):
		rows.append(["CHANNEL", it.channel])
	if it.has("basis"):
		rows.append(["BASIS", it.basis])
	if it.has("conflicts"):
		rows.append(["CONFLICTS", "[color=#8a1a10]%s[/color]" % it.conflicts])
	if it.confirm != "":
		rows.append(["CONFIRMATION", it.confirm])
	if it.get("forwarded", false):
		rows.append(["FORWARDED", it.forwarded_at])
	for r in rows:
		lines.append("%s%s" % [(r[0] + " ").rpad(14), r[1]])
	lines.append("")
	lines.append("[b]%s[/b]" % it.subject)
	lines.append("")
	for b in it.body:
		lines.append(b)
	_text.text = "\n".join(lines)
	var ver: String = it.verification
	_status.text = "AGE: %s  -  %s" % [_age(it.time), "UNCONFIRMED BY ANY FIELD SOURCE" if not ver.begins_with("VERIFIED") else "FIELD VERIFIED"]
	var can_confirm: bool = it.get("can_confirm", false) and Run.active
	var can_forward: bool = it.get("can_forward", false) and not it.get("forwarded", false) and Run.active
	_actions.visible = can_confirm or can_forward
	_confirm_btn.visible = can_confirm
	_forward_btn.visible = can_forward
	if can_confirm:
		var open := false
		for r in Run.open_requests():
			if r.report == it.id:
				open = true
		_confirm_btn.disabled = open or ver.begins_with("APPROVED")
		_confirm_btn.text = "AWAITING REPLY" if open else "REQUEST CONFIRMATION"


## Hours and minutes between an item's time and the facility clock.
static func _age(hhmm: String) -> String:
	var now := int(Run.hhmm())
	var m_now := (now / 100) * 60 + now % 100
	var t := int(hhmm)
	var m_then := (t / 100) * 60 + t % 100
	var d := posmod(m_now - m_then, 1440)
	return "%dH %02dM" % [d / 60, d % 60]


func _refresh_log() -> void:
	_decision.visible = false
	_stamp.visible = false
	_source.text = "TRAFFIC LOG  -  %d ITEMS  -  %s" % [Run.traffic.size(), Run.hhmm()]
	_status.text = "TAP AN ENTRY TO READ IT.  * = UNREAD"
	for c in _log_list.get_children():
		_log_list.remove_child(c)
		c.queue_free()
	if orders.has_order():
		var ob := _entry("%s  %-8s %-10s %s" % [orders.arrived_at, orders.order.id, "ORDER", orders.word()], func() -> void: open_order())
		ob.name = "LogOrder"
	for i in range(Run.traffic.size() - 1, -1, -1):
		var it: Dictionary = Run.traffic[i]
		var mark := "*" if not it.read else " "
		var b := _entry("%s%s  %-8s %-10s %s" % [mark, it.time, it.id, it.kind, it.verification], open_report.bind(it.id))
		b.name = "Log_" + it.id


func _entry(text: String, cb: Callable) -> Button:
	var b := _close.duplicate(0) as Button
	b.unique_name_in_owner = false
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_font_override("font", _text.get_theme_font("normal_font"))
	b.pressed.connect(cb)
	_log_list.add_child(b)
	return b


func _on_confirm() -> void:
	var id := Run.request_confirmation(_report_id)
	if id != "":
		get_tree().call_group("director", "confirmation_requested", id, _report_id)
	_refresh()


func _on_forward() -> void:
	get_tree().call_group("director", "forward", _report_id)
	_refresh()


func _on_choice(choice: String) -> void:
	if _armed != choice:
		_armed = choice           # first tap arms; the other button disarms
		_refresh()
		return
	_armed = ""
	orders.decide(choice == "accept")
	_refresh()


func _style_armed(b: Button, armed: bool) -> void:
	if armed:
		var sb: StyleBox = _close.get_theme_stylebox("pressed").duplicate()
		sb.bg_color = Color(0.45, 0.27, 0.04, 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	else:
		b.add_theme_stylebox_override("normal", _close.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("hover", _close.get_theme_stylebox("normal"))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()   # keep keys off the camera
