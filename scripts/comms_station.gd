extends Node3D
## Left-side communications station: telephone, radio transceiver with
## microphone, message printer, printed reports, line-status panel and a
## wall clock. The telephone, radio and line switches give placeholder
## feedback when tapped. The teleprinter prints incoming orders (from the
## order manager) and opens the message reader when tapped.
##
## Built in local space: the operator is toward +Z, the wall toward -Z,
## and the desk top is at y = 0.76. main.tscn rotates the node into place.

const TOP := 0.76
const WALL_Z := -0.58
const TEXT_DARK := Color(0.1, 0.09, 0.08)
const INK := Color(0.16, 0.15, 0.14)

var _hour_hand: Node3D
var _minute_hand: Node3D
var _second_hand: Node3D
var _rx_lamp: MeshInstance3D
var _rx_until := 0.0
var _t := 0.0
var _orders: Node
var _printer_lamp: MeshInstance3D
var _sheet: Node3D
var _sheet_text: Label3D
# Telephone: an incoming call rings until answered or it times out.
var _call: Dictionary = {}
var _ring_left := 0.0
var _ring_next := 0.0
var _hook_lamp: MeshInstance3D
var _phone_state := {"lifted": false}
var _lift_phone: Callable
# Radio: a live transmission can be heard while the RX lamp is lit.
var _live: Dictionary = {}
var _live_until := 0.0
var _freq: Label3D
var _channel := 0

const RING_TIMEOUT := 24.0

const CHANNELS := ["07.450", "11.200", "04.875", "09.330"]


func _ready() -> void:
	var K := BuildKit
	_build_desk(self)
	_build_printer(K.pivot(self, Vector3(-0.66, TOP, -0.08)))
	_build_radio(K.pivot(self, Vector3(-0.02, TOP, -0.2)))
	_build_microphone(K.pivot(self, Vector3(0.22, TOP, 0.13), Vector3(0, -20, 0)))
	_build_telephone(K.pivot(self, Vector3(0.62, TOP, 0.06), Vector3(0, -18, 0)))
	_build_reports(K.pivot(self, Vector3(0.82, TOP, -0.25)))
	_build_desk_lamp(K.pivot(self, Vector3(-0.32, TOP, -0.36)))
	_build_wall()
	add_to_group("comms")
	_orders = get_tree().get_first_node_in_group("orders")
	if _orders:
		_orders.state_changed.connect(_on_order_state)
	Run.traffic_added.connect(func(_i: Dictionary) -> void: _feed_paper())


func _process(delta: float) -> void:
	_t += delta
	if (_orders and _orders.is_pending()) or Run.unread_count() > 0:
		# Teleprinter lamp blinks while traffic is unread or a reply is due.
		BuildKit.set_mat(_printer_lamp, BuildKit.lamp(BuildKit.AMBER, fmod(_t, 0.8) < 0.4, 2.2))
	else:
		BuildKit.set_mat(_printer_lamp, BuildKit.lamp(BuildKit.AMBER, true, 1.4))
	# The wall clock shows facility time.
	var hms := Run.clock_hms()
	var sec: float = hms.z
	var minute: float = hms.y + sec / 60.0
	var hour: float = fmod(hms.x, 12.0) + minute / 60.0
	_second_hand.rotation.z = -sec / 60.0 * TAU
	_minute_hand.rotation.z = -minute / 60.0 * TAU
	_hour_hand.rotation.z = -hour / 12.0 * TAU
	# Receive lamp flickers now and then, like faint carrier traffic.
	var rx := (fmod(_t, 5.0) < 0.6 and sin(_t * 31.0) > 0.0) or _t < _rx_until or (_t < _live_until and fmod(_t, 0.3) < 0.2)
	BuildKit.set_mat(_rx_lamp, BuildKit.lamp(BuildKit.GREEN, rx))
	_process_ring(delta)


func _build_desk(p: Node3D) -> void:
	var K := BuildKit
	K.box(p, Vector3(2.0, 0.05, 0.85), Vector3(0, TOP - 0.025, 0), K.mat("paint_green"))
	K.cyl(p, 0.028, 2.0, Vector3(0, TOP - 0.025, 0.425), K.mat("rubber"), Vector3(0, 0, 90), 8)
	K.box(p, Vector3(1.96, TOP - 0.05, 0.05), Vector3(0, (TOP - 0.05) * 0.5, -0.38), K.mat("paint_grey"))
	for x in [-0.95, 0.95]:
		K.box(p, Vector3(0.05, TOP - 0.05, 0.78), Vector3(x, (TOP - 0.05) * 0.5, 0.0), K.mat("paint_grey"))


func _build_printer(p: Node3D) -> void:
	var K := BuildKit
	K.box(p, Vector3(0.44, 0.17, 0.38), Vector3(0, 0.085, 0), K.mat("paint_beige"))
	K.box(p, Vector3(0.44, 0.05, 0.2), Vector3(0, 0.19, -0.06), K.mat("paint_beige"), Vector3(-12, 0, 0))
	K.box(p, Vector3(0.36, 0.035, 0.03), Vector3(0, 0.18, 0.06), K.mat("bakelite"))           # paper slot
	K.cyl(p, 0.018, 0.4, Vector3(0, 0.185, 0.05), K.mat("rubber"), Vector3(0, 0, 90), 8)      # platen
	K.cyl(p, 0.055, 0.32, Vector3(0, 0.24, -0.16), K.mat("paper"), Vector3(0, 0, 90), 12)     # paper roll
	# Printed sheet emerging from the slot.
	var sheet := K.pivot(p, Vector3(0, 0.2, 0.06), Vector3(-18, 0, 0))
	K.box(sheet, Vector3(0.3, 0.26, 0.003), Vector3(0, 0.13, 0), K.mat("paper"), Vector3.ZERO, false)
	_sheet = sheet
	_sheet_text = K.label(sheet, "MSG 0001  ROUTINE\nLINE CHECK ..... OK\nNO TRAFFIC\n-- END --", Vector3(0, 0.16, 0.003), 0.017, INK)
	# Front controls.
	K.box(p, Vector3(0.12, 0.03, 0.01), Vector3(0.13, 0.08, 0.19), K.mat("bakelite"))
	_printer_lamp = K.cyl(p, 0.008, 0.01, Vector3(-0.15, 0.08, 0.195), K.lamp(BuildKit.AMBER, true, 1.4), Vector3(90, 0, 0), 6, -1.0, false)
	K.label(p, "TELEPRINTER", Vector3(-0.05, 0.13, 0.192), 0.016, TEXT_DARK)
	var area := Interactable.make(p, Vector3(0.48, 0.48, 0.46), Vector3(0, 0.22, 0.02), "Teleprinter")
	area.activated.connect(func(_hit: Vector3) -> void:
		if (_orders and _orders.has_order()) or not Run.traffic.is_empty():
			get_tree().call_group("message_reader", "open_current")
			return
		var tw := create_tween()
		tw.tween_property(sheet, "position:y", 0.225, 0.12)
		tw.tween_property(sheet, "position:y", 0.2, 0.25)
		_toast("TELEPRINTER: NO NEW MESSAGES"))


## Prints the order on the 3D sheet; the reader shows the full text.
func _on_order_state(state: int) -> void:
	if _orders.restoring:
		return
	var o: Dictionary = _orders.order
	var lines := "%s  %s\n%s\n%s" % [o.id, o.fields[0][1], o.fields[3][1], o.fields[1][1]]
	if state == _orders.State.PENDING:
		# Paper feeds out in short jerks as the message prints.
		var tw := create_tween()
		for i in range(4):
			tw.tween_property(_sheet, "position:y", 0.2 + (i + 1) * 0.008, 0.08)
			tw.tween_interval(0.12)
		tw.tween_property(_sheet, "position:y", 0.2, 0.3)
		_sheet_text.text = lines + "\n-- REPLY REQUIRED --"
	elif _orders.has_order():
		var word: String = _orders.word()
		_sheet_text.text = lines + "\n-- %s %s --" % [word, _orders.decided_at]
		_printer_lamp.material_override = BuildKit.lamp(BuildKit.AMBER, true, 1.4)


## Paper feeds out in short jerks whenever new traffic prints.
func _feed_paper() -> void:
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(_sheet, "position:y", 0.2 + (i + 1) * 0.008, 0.08)
		tw.tween_interval(0.12)
	tw.tween_property(_sheet, "position:y", 0.2, 0.3)
	if not Run.traffic.is_empty():
		var it: Dictionary = Run.traffic[-1]
		_sheet_text.text = "%s  %s\n%s\n%s\n-- %s --" % [it.id, it.time, it.subject.substr(0, 28), it.source.substr(0, 28), it.verification]


# --- Telephone ----------------------------------------------------------------------------

## Incoming call (from the Director). The bell is heard first; the hook
## lamp only starts blinking after the first ring.
func ring(call: Dictionary) -> void:
	_call = call
	_ring_left = RING_TIMEOUT
	_ring_next = 0.0


func is_ringing() -> bool:
	return not _call.is_empty()


func _process_ring(delta: float) -> void:
	if _call.is_empty():
		return
	_ring_left -= delta
	_ring_next -= delta
	if _ring_next <= 0.0:
		Sfx.play("phone_ring", -3.0)
		_ring_next = 4.0
	if _ring_left < RING_TIMEOUT - 1.0:
		BuildKit.set_mat(_hook_lamp, BuildKit.lamp(BuildKit.AMBER, fmod(_t, 0.5) < 0.25, 2.4))
	if _ring_left <= 0.0:
		var c := _call
		_call = {}
		BuildKit.set_mat(_hook_lamp, BuildKit.lamp(BuildKit.AMBER, false))
		get_tree().call_group("director", "call_missed", c)


func _answer() -> void:
	var c := _call
	_call = {}
	Subtitles.clear()                    # the caller speaks over everything
	var total := 0.0
	for i in range(c.lines.size()):
		Subtitles.say(c.caller, c.lines[i], 0.0, true)
		total += Subtitles.reading_time(c.lines[i])
	get_tree().call_group("director", "call_answered", c)
	# The caller rings off; the handset goes back on the cradle.
	get_tree().create_timer(total + 0.5).timeout.connect(func() -> void:
		if _phone_state.lifted and _call.is_empty():
			_lift_phone.call(false))


## Simulated tap (tests and the Director's answer helper).
func answer_phone() -> void:
	if not _phone_state.lifted:
		_lift_phone.call(true)
		if not _call.is_empty():
			_answer()


# --- Radio --------------------------------------------------------------------------------------

## A transmission on `item.channel`, audible for a while. Logged by the
## Director (unless intercept logging on that channel was ordered off).
func radio_traffic(item: Dictionary, logged: bool) -> void:
	_live = item.duplicate()
	_live.logged = logged
	_live_until = _t + 40.0
	Sfx.play("radio_burst", -4.0)


func _on_radio(_hit: Vector3) -> void:
	_rx_until = _t + 0.5
	Sfx.play("switch_click", -10.0)
	if not _live.is_empty() and _t < _live_until:
		# Tune straight to the live channel and listen.
		_channel = CHANNELS.find(_live.channel) if CHANNELS.has(_live.channel) else _channel
		_freq.text = CHANNELS[_channel]
		Sfx.play("radio_burst", -6.0, 0.9)
		Subtitles.clear()
		for l in _live.get("lines", []):
			Subtitles.say("RADIO %s" % _live.channel, l, 0.0, true)
		if not _live.logged:
			Subtitles.say("", "(Not logged: channel %s, standing order.)" % _live.channel, 3.0, true)
		_live = {}
		return
	_channel = (_channel + 1) % CHANNELS.size()
	_freq.text = CHANNELS[_channel]
	Sfx.play("static_loop", -18.0)
	_toast("CHANNEL %d  %s  -  NO TRAFFIC" % [_channel + 1, CHANNELS[_channel]])


func _build_radio(p: Node3D) -> void:
	var K := BuildKit
	var w := 0.56
	var h := 0.3
	var d := 0.34
	var front := d * 0.5 + 0.002
	K.box(p, Vector3(w, h, d), Vector3(0, h * 0.5, 0), K.mat("paint_green"))
	K.box(p, Vector3(w - 0.04, 0.14, d - 0.04), Vector3(0, h + 0.07, -0.01), K.mat("paint_grey"))   # stacked unit
	# Carry handles.
	for s in [-1, 1]:
		K.cyl(p, 0.009, h - 0.06, Vector3(s * (w * 0.5 - 0.02), h * 0.5, front + 0.03), K.mat("steel"), Vector3.ZERO, 6)
		for y in [0.04, h - 0.04]:
			K.box(p, Vector3(0.016, 0.016, 0.035), Vector3(s * (w * 0.5 - 0.02), y, front + 0.015), K.mat("steel"))
	# Signal meter.
	K.box(p, Vector3(0.13, 0.08, 0.01), Vector3(-0.15, 0.21, front), K.mat("gauge_face"))
	K.box(p, Vector3(0.003, 0.06, 0.004), Vector3(-0.16, 0.2, front + 0.008), K.mat("needle"), Vector3(0, 0, -25))
	# Frequency readout (placeholder value).
	K.box(p, Vector3(0.16, 0.05, 0.01), Vector3(0.1, 0.22, front), K.mat("bakelite"))
	_freq = K.label(p, CHANNELS[0], Vector3(0.1, 0.22, front + 0.007), 0.034, BuildKit.AMBER)
	var area := Interactable.make(p, Vector3(w + 0.06, h + 0.2, d + 0.08), Vector3(0, (h + 0.14) * 0.5, 0.04), "Radio")
	area.activated.connect(_on_radio)
	# Knobs and small switches.
	for i in range(4):
		K.cyl(p, 0.022, 0.025, Vector3(-0.19 + i * 0.1, 0.09, front + 0.012), K.mat("bakelite"), Vector3(90, 0, 0), 10)
	_rx_lamp = K.cyl(p, 0.01, 0.01, Vector3(0.21, 0.16, front + 0.004), K.lamp(BuildKit.GREEN, false), Vector3(90, 0, 0), 8, -1.0, false)
	K.label(p, "RX", Vector3(0.21, 0.135, front + 0.003), 0.014, TEXT_DARK)
	K.label(p, "TRANSCEIVER R-12", Vector3(0, h - 0.025, front + 0.003), 0.016, TEXT_DARK)
	# Upper unit: channel lamps.
	var lamps := [BuildKit.GREEN, BuildKit.GREEN, BuildKit.AMBER, BuildKit.RED]
	for i in range(lamps.size()):
		K.cyl(p, 0.009, 0.01, Vector3(-0.18 + i * 0.06, h + 0.07, d * 0.5 - 0.008), K.lamp(lamps[i], i != 3, 1.6), Vector3(90, 0, 0), 8, -1.0, false)


func _build_microphone(p: Node3D) -> void:
	var K := BuildKit
	K.cyl(p, 0.055, 0.025, Vector3(0, 0.0125, 0), K.mat("bakelite"), Vector3.ZERO, 12, 0.045)
	K.box(p, Vector3(0.03, 0.008, 0.02), Vector3(0, 0.028, 0.03), K.mat("steel"))          # talk bar
	K.cyl(p, 0.007, 0.17, Vector3(0, 0.11, 0), K.mat("steel"), Vector3.ZERO, 6)
	var head := K.pivot(p, Vector3(0, 0.2, 0.015), Vector3(65, 0, 0))
	K.cyl(head, 0.028, 0.07, Vector3.ZERO, K.mat("metal_dark"), Vector3.ZERO, 10)
	K.cyl(head, 0.024, 0.006, Vector3(0, 0.037, 0), K.mat("bakelite"), Vector3.ZERO, 10)     # grille
	_cable(p, [Vector3(0, 0.01, -0.05), Vector3(-0.05, 0.004, -0.12), Vector3(-0.1, 0.004, -0.2), Vector3(-0.12, 0.05, -0.3)])


func _build_telephone(p: Node3D) -> void:
	var K := BuildKit
	var black := K.mat("bakelite")
	K.box(p, Vector3(0.22, 0.07, 0.24), Vector3(0, 0.035, 0), black)
	K.box(p, Vector3(0.2, 0.06, 0.13), Vector3(0, 0.085, 0.035), black, Vector3(22, 0, 0))
	K.box(p, Vector3(0.2, 0.06, 0.1), Vector3(0, 0.09, -0.07), black)
	# Rotary dial on the sloped face.
	var face := K.pivot(p, Vector3(0, 0.118, 0.04), Vector3(22, 0, 0))
	K.cyl(face, 0.052, 0.008, Vector3.ZERO, K.mat("steel"), Vector3.ZERO, 16)
	K.cyl(face, 0.02, 0.01, Vector3(0, 0.003, 0), K.mat("paper"), Vector3.ZERO, 12)
	for i in range(10):
		var a := deg_to_rad(40 + i * 28.0)
		K.cyl(face, 0.006, 0.01, Vector3(cos(a) * 0.036, 0.002, sin(a) * 0.036), black, Vector3.ZERO, 6)
	# Handset resting on the cradle.
	var rest := Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -0.06))
	var lifted := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-25), 0, deg_to_rad(18))), Vector3(0.02, 0.29, 0.06))
	var hs := K.pivot(p, rest.origin)
	K.box(hs, Vector3(0.22, 0.03, 0.045), Vector3.ZERO, black)
	for s in [-1, 1]:
		K.cyl(hs, 0.03, 0.05, Vector3(s * 0.1, -0.012, 0), black, Vector3.ZERO, 10)
	K.label(p, "LINE 1", Vector3(0, 0.035, 0.121), 0.012, Color(0.7, 0.68, 0.6))
	var hook_lamp := K.cyl(p, 0.008, 0.01, Vector3(0.08, 0.035, 0.121), K.lamp(BuildKit.AMBER, false), Vector3(90, 0, 0), 8, -1.0, false)
	_hook_lamp = hook_lamp
	# Coiled cord, simplified to a sagging run; rebuilt when the handset moves.
	var cord := [_phone_cord(p, rest)]
	var area := Interactable.make(p, Vector3(0.3, 0.3, 0.34), Vector3(0, 0.13, 0.0), "Telephone")
	var state := _phone_state
	_lift_phone = func(up: bool) -> void:
		state.lifted = up
		var pose: Transform3D = lifted if up else rest
		var tw := create_tween()
		tw.tween_property(hs, "transform", pose, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cord[0].queue_free()
		cord[0] = _phone_cord(p, pose)
		hook_lamp.material_override = BuildKit.lamp(BuildKit.AMBER, up)
		Sfx.play("switch_click", -8.0, 0.7)
	area.activated.connect(func(_hit: Vector3) -> void:
		var up: bool = not state.lifted
		_lift_phone.call(up)
		if up and not _call.is_empty():
			_answer()
		elif up:
			_toast("LINE 1: NO CALL - DIAL TONE ONLY")
		else:
			_toast("HANDSET REPLACED"))


func _phone_cord(p: Node3D, handset: Transform3D) -> Node3D:
	var start := handset * Vector3(-0.1, -0.03, 0)
	var mid := start.lerp(Vector3(-0.17, 0.006, 0.05), 0.5) + Vector3(-0.03, -0.02, 0)
	return _cable(p, [start, mid, Vector3(-0.17, 0.006, 0.05), Vector3(-0.13, 0.006, 0.11), Vector3(-0.1, 0.03, 0.12)], 0.007)


func _build_reports(p: Node3D) -> void:
	var K := BuildKit
	for i in range(4):
		K.box(p, Vector3(0.21, 0.004, 0.29), Vector3(i * 0.006, 0.002 + i * 0.004, i * -0.004), K.mat("paper" if i % 2 else "paper_old"), Vector3(0, i * 4.0 - 6.0, 0), false)
	var top := K.pivot(p, Vector3(0.02, 0.019, 0.0), Vector3(-90, 4, 0))
	K.label(top, "STATION REPORT\n\nFORM 7-B\n________________\n________________\n________________", Vector3(0, 0.03, 0), 0.016, INK)
	K.box(p, Vector3(0.15, 0.004, 0.02), Vector3(0.02, 0.022, -0.12), K.mat("steel"), Vector3(0, 4, 0))   # clip


func _build_desk_lamp(p: Node3D) -> void:
	var K := BuildKit
	K.cyl(p, 0.07, 0.03, Vector3(0, 0.015, 0), K.mat("paint_grey"), Vector3.ZERO, 10)
	K.cyl(p, 0.009, 0.32, Vector3(0, 0.17, 0), K.mat("steel"), Vector3.ZERO, 6)
	K.cyl(p, 0.009, 0.24, Vector3(0, 0.36, 0.09), K.mat("steel"), Vector3(55, 0, 0), 6)
	var shade := K.pivot(p, Vector3(0, 0.42, 0.2), Vector3(150, 0, 0))
	K.cyl(shade, 0.035, 0.1, Vector3.ZERO, K.mat("paint_green"), Vector3.ZERO, 10, 0.075)
	K.cyl(shade, 0.06, 0.004, Vector3(0, 0.05, 0), K.lamp(Color(1.0, 0.85, 0.6), true, 2.0), Vector3.ZERO, 10, -1.0, false)
	var light := SpotLight3D.new()
	light.add_to_group("minor_light")        # off on LOW (graphics preset)
	light.light_color = Color(1.0, 0.82, 0.58)
	light.light_energy = 1.8
	light.spot_range = 1.3
	light.spot_angle = 50.0
	light.position = Vector3(0, 0.07, 0)
	light.rotation_degrees = Vector3(90, 0, 0)   # shade's +Y is its open end
	shade.add_child(light)


func _build_wall() -> void:
	var K := BuildKit
	var z := WALL_Z
	# Line status panel.
	var lp := K.pivot(self, Vector3(-0.1, 1.5, z + 0.03))
	K.box(lp, Vector3(0.62, 0.3, 0.06), Vector3.ZERO, K.mat("paint_grey"))
	K.box(lp, Vector3(0.56, 0.05, 0.004), Vector3(0, 0.105, 0.031), K.mat("paint_beige"), Vector3.ZERO, false)
	K.label(lp, "COMMUNICATION LINES", Vector3(0, 0.105, 0.034), 0.022, TEXT_DARK)
	# Too small to tap from the chair: tapping the panel leans in first.
	var zone := Interactable.make(lp, Vector3(0.68, 0.36, 0.1), Vector3(0, 0, 0.05), "LinePanel")
	zone.focus_zone = true
	zone.focus_title = "COMMUNICATION LINES"
	zone.focus_distance = 0.55
	var states := [true, true, true, false, true, false]
	for i in range(6):
		var x := -0.225 + i * 0.09
		var col := BuildKit.AMBER if i == 4 else BuildKit.GREEN
		var lamp := K.cyl(lp, 0.014, 0.014, Vector3(x, 0.03, 0.035), K.lamp(col, states[i], 1.6), Vector3(90, 0, 0), 10, -1.0, false)
		K.label(lp, str(i + 1), Vector3(x, -0.01, 0.031), 0.018, Color(0.85, 0.83, 0.75))
		var hinge := K.pivot(lp, Vector3(x, -0.07, 0.04), Vector3(-25 if states[i] else 25, 0, 0))
		K.box(hinge, Vector3(0.012, 0.035, 0.012), Vector3.ZERO, K.mat("steel"))
		var area := Interactable.make(lp, Vector3(0.085, 0.2, 0.08), Vector3(x, -0.035, 0.07), "Line%d" % (i + 1))
		var state := {"on": states[i]}
		area.activated.connect(func(_hit: Vector3) -> void:
			state.on = not state.on
			BuildKit.flip_lever(hinge, not state.on, 25.0)
			lamp.material_override = BuildKit.lamp(col, state.on, 1.6)
			_toast("LINE %d: %s" % [i + 1, "OPEN" if state.on else "CLOSED"]))
	# Wall clock (shows the device's real time).
	var clk := K.pivot(self, Vector3(0.6, 1.9, z + 0.03))
	K.cyl(clk, 0.15, 0.05, Vector3.ZERO, K.mat("bakelite"), Vector3(90, 0, 0), 20)
	K.cyl(clk, 0.13, 0.01, Vector3(0, 0, 0.022), K.mat("gauge_face"), Vector3(90, 0, 0), 20)
	for i in range(12):
		var a := i * TAU / 12.0
		var tick := 0.03 if i % 3 == 0 else 0.016
		K.box(clk, Vector3(0.006, tick, 0.004), Vector3(sin(a) * (0.115 - tick * 0.5), cos(a) * (0.115 - tick * 0.5), 0.028), K.mat("needle"), Vector3(0, 0, -rad_to_deg(a)))
	_hour_hand = _clock_hand(clk, 0.06, 0.008, 0.031, K.mat("needle"))
	_minute_hand = _clock_hand(clk, 0.095, 0.005, 0.033, K.mat("needle"))
	_second_hand = _clock_hand(clk, 0.1, 0.002, 0.035, K.mat("red_paint"))
	# Intercom speaker and a clipboard.
	K.box(self, Vector3(0.2, 0.2, 0.08), Vector3(-0.72, 1.62, z + 0.04), K.mat("paint_grey"))
	for i in range(5):
		K.box(self, Vector3(0.14, 0.008, 0.004), Vector3(-0.72, 1.57 + i * 0.025, z + 0.082), K.mat("bakelite"), Vector3.ZERO, false)
	K.box(self, Vector3(0.22, 0.3, 0.008), Vector3(0.95, 1.4, z + 0.006), K.mat("metal_dark"))
	K.box(self, Vector3(0.2, 0.27, 0.004), Vector3(0.95, 1.39, z + 0.012), K.mat("paper_old"), Vector3.ZERO, false)
	K.label(self, "DUTY ROSTER", Vector3(0.95, 1.49, z + 0.016), 0.016, INK)
	# Wall lamp fixture with a small warm light for readability.
	K.box(self, Vector3(0.24, 0.1, 0.1), Vector3(-0.3, 2.25, z + 0.05), K.mat("metal_dark"))
	K.box(self, Vector3(0.2, 0.02, 0.07), Vector3(-0.3, 2.195, z + 0.06), K.lamp(Color(1.0, 0.86, 0.65), true, 1.5), Vector3.ZERO, false)
	var light := OmniLight3D.new()
	light.add_to_group("accent_light")
	light.light_color = Color(1.0, 0.84, 0.62)
	light.light_energy = 0.7
	light.omni_range = 2.4
	light.position = Vector3(-0.3, 2.05, z + 0.3)
	add_child(light)


func _clock_hand(parent: Node3D, length: float, width: float, z: float, m: Material) -> Node3D:
	var pivot := BuildKit.pivot(parent, Vector3(0, 0, z))
	BuildKit.box(pivot, Vector3(width, length, 0.003), Vector3(0, length * 0.4, 0), m, Vector3.ZERO, false)
	return pivot


## A cable drawn as straight segments through the given local points.
func _cable(parent: Node3D, pts: Array, radius := 0.005) -> Node3D:
	var holder := BuildKit.pivot(parent, Vector3.ZERO)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := BuildKit.cyl(holder, radius, a.distance_to(b), (a + b) * 0.5, BuildKit.mat("cable"), Vector3.ZERO, 5)
		seg.basis = _basis_along(b - a)
	return holder


func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)


static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)
