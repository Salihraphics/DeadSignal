extends CanvasLayer
## Full-screen paper view of the current order. Opened from the
## teleprinter or the HUD order notice; can be reopened at any time.
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


func is_open() -> bool:
	return visible


func open_current() -> void:
	if not orders.has_order():
		return
	_armed = ""
	_refresh()
	_scroll.scroll_vertical = 0
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_armed = ""
	closed.emit()


func _refresh() -> void:
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
