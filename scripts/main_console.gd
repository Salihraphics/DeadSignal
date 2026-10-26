extends Node3D
## The operator's main desk: desk body, the slanted control panel in
## front of the operator, and CRT light spill. The three CRT monitors are
## child nodes in main.tscn (crt_monitor.gd) so they can be moved in the editor.
## Toggles and the counter knobs give placeholder feedback. The launch
## controls drive the shared StrategicState: AMMUNITION S/M/L select
## buttons, ABORT, the arming KEY and the red MASTER cover + switch.
## Their lamps and positions always follow the state, never the reverse.

const DESK_TOP := 0.76
const DESK_FRONT_Z := -0.45
const DESK_BACK_Z := -1.45

var _blink_lamp: MeshInstance3D
var _crit_lamp: MeshInstance3D
var _arm_lamp: MeshInstance3D
var _key: Node3D
var _cover: Node3D
var _ammo_caps := {}
var state: Node
var _counter: Label3D
var _counter_values := [0, 0, 0]
var _t := 0.0


func _ready() -> void:
	state = get_tree().get_first_node_in_group("strategy")
	_build_desk()
	_build_control_panel()
	_build_desk_props()
	state.selection_changed.connect(_sync_controls)
	_sync_controls()
	var spill := OmniLight3D.new()
	spill.light_color = Color(0.45, 1.0, 0.55)
	spill.light_energy = 0.28
	spill.omni_range = 1.6
	spill.position = Vector3(0, 1.0, -0.7)
	add_child(spill)


func _process(delta: float) -> void:
	_t += delta
	var idle: bool = not state.locked()
	_blink_lamp.material_override = BuildKit.lamp(BuildKit.AMBER, idle and fmod(_t, 1.6) < 0.8)
	_crit_lamp.material_override = BuildKit.lamp(BuildKit.RED, not idle and fmod(_t, 0.5) < 0.25, 3.0)


func _build_desk() -> void:
	var K := BuildKit
	var depth := DESK_FRONT_Z - DESK_BACK_Z
	var mid_z := (DESK_FRONT_Z + DESK_BACK_Z) * 0.5
	K.box(self, Vector3(2.4, 0.05, depth), Vector3(0, DESK_TOP - 0.025, mid_z), K.mat("paint_green"))
	# Rubber bumper on the operator edge.
	K.cyl(self, 0.028, 2.4, Vector3(0, DESK_TOP - 0.025, DESK_FRONT_Z), K.mat("rubber"), Vector3(0, 0, 90), 8)
	# Pedestal cabinets with drawers.
	for s in [-1, 1]:
		var x: float = s * 0.92
		K.box(self, Vector3(0.52, DESK_TOP - 0.05, depth - 0.1), Vector3(x, (DESK_TOP - 0.05) * 0.5, mid_z - 0.05), K.mat("paint_grey"))
		for y in [0.2, 0.45]:
			K.box(self, Vector3(0.5, 0.012, 0.01), Vector3(x, y, DESK_FRONT_Z - 0.045), K.mat("metal_dark"), Vector3.ZERO, false)
		for y in [0.1, 0.33, 0.58]:
			K.box(self, Vector3(0.14, 0.022, 0.025), Vector3(x, y, DESK_FRONT_Z - 0.04), K.mat("steel"))
	K.box(self, Vector3(1.32, 0.62, 0.03), Vector3(0, 0.42, DESK_BACK_Z + 0.12), K.mat("paint_grey"))
	# Low cabinet under the window, filling the gap to the front wall.
	K.box(self, Vector3(2.0, 1.1, 0.5), Vector3(0, 0.55, -2.05), K.mat("paint_grey"))
	for i in range(5):
		K.box(self, Vector3(1.6, 0.015, 0.01), Vector3(0, 0.75 + i * 0.05, -1.795), K.mat("metal_dark"), Vector3.ZERO, false)  # vent slats


func _build_control_panel() -> void:
	var K := BuildKit
	# Slanted panel; children are placed on its flat top (local y = 0).
	var p := K.pivot(self, Vector3(0, DESK_TOP + 0.035, DESK_FRONT_Z - 0.17), Vector3(14, 0, 0))
	K.box(p, Vector3(1.9, 0.07, 0.28), Vector3(0, -0.035, 0), K.mat("metal_dark"))
	for x in [-0.65, 0.0, 0.65]:
		K.box(p, Vector3(0.6, 0.004, 0.24), Vector3(x, 0.002, 0), K.mat("paint_beige"), Vector3.ZERO, false)
	var text := Vector3(-90, 0, 0)   # labels lie flat on the panel

	# Left group: toggle switches.
	var names := ["MAIN BUS", "AUX BUS", "COMMS", "RADAR", "SHAFT VNT"]
	for i in range(names.size()):
		var x := -0.88 + i * 0.115
		_toggle(p, Vector3(x, 0.004, 0.02), i % 3 != 1, names[i])
		K.label(p, names[i], Vector3(x, 0.006, -0.07), 0.014, Color(0.1, 0.09, 0.08), text)
	K.label(p, "POWER DISTRIBUTION", Vector3(-0.65, 0.006, 0.095), 0.016, Color(0.1, 0.09, 0.08), text)

	# Centre group: indicator row, guarded master switch, key.
	var lamps := [[BuildKit.GREEN, true, "PWR"], [BuildKit.GREEN, true, "COM"],
			[BuildKit.AMBER, true, "STBY"], [BuildKit.RED, false, "CRIT"]]
	for i in range(lamps.size()):
		var x := -0.2 + i * 0.07
		var m := K.cyl(p, 0.014, 0.014, Vector3(x, 0.01, -0.06), K.lamp(lamps[i][0], lamps[i][1]), Vector3.ZERO, 10, -1.0, false)
		if lamps[i][2] == "STBY":
			_blink_lamp = m
		elif lamps[i][2] == "CRIT":
			_crit_lamp = m
		K.cyl(p, 0.019, 0.006, Vector3(x, 0.004, -0.06), K.mat("steel"), Vector3.ZERO, 10)
		K.label(p, lamps[i][2], Vector3(x, 0.006, -0.1), 0.013, Color(0.1, 0.09, 0.08), text)
	# MASTER: red guard cover over a red launch switch. First tap lifts
	# the cover; with the cover open, a tap operates the switch.
	K.box(p, Vector3(0.08, 0.012, 0.09), Vector3(-0.05, 0.006, 0.045), K.mat("bakelite"))
	K.cyl(p, 0.01, 0.012, Vector3(-0.05, 0.016, 0.05), K.mat("steel"), Vector3.ZERO, 8)
	K.cyl(p, 0.006, 0.035, Vector3(-0.05, 0.03, 0.05), K.lamp(BuildKit.RED, true, 1.4), Vector3(-20, 0, 0), 6)
	_cover = K.pivot(p, Vector3(-0.05, 0.042, 0.002))
	K.box(_cover, Vector3(0.07, 0.03, 0.08), Vector3(0, -0.015, 0.043), K.mat("red_paint"))
	K.cyl(p, 0.006, 0.08, Vector3(-0.05, 0.042, 0.002), K.mat("steel"), Vector3(0, 0, 90), 6)  # hinge
	K.label(p, "MASTER", Vector3(-0.05, 0.006, 0.105), 0.015, Color(0.45, 0.04, 0.02), text)
	var master := Interactable.make(p, Vector3(0.11, 0.08, 0.14), Vector3(-0.05, 0.03, 0.045), "Master")
	master.activated.connect(_on_master)
	# KEY: a quarter turn arms the launch circuit.
	K.cyl(p, 0.026, 0.01, Vector3(0.1, 0.006, 0.045), K.mat("steel"), Vector3.ZERO, 12)
	_key = K.pivot(p, Vector3(0.1, 0.014, 0.045))
	K.cyl(_key, 0.014, 0.018, Vector3.ZERO, K.mat("brass"), Vector3.ZERO, 10)
	K.box(_key, Vector3(0.004, 0.006, 0.026), Vector3(0, 0.01, 0), K.mat("bakelite"))
	K.label(p, "SAFE", Vector3(0.1, 0.006, 0.0), 0.011, Color(0.1, 0.09, 0.08), text)
	K.label(p, "ARM", Vector3(0.142, 0.006, 0.045), 0.011, Color(0.45, 0.04, 0.02), text)
	_arm_lamp = K.cyl(p, 0.009, 0.01, Vector3(0.142, 0.01, 0.075), K.lamp(BuildKit.AMBER, false), Vector3.ZERO, 8, -1.0, false)
	K.label(p, "KEY", Vector3(0.1, 0.006, 0.105), 0.013, Color(0.1, 0.09, 0.08), text)
	var key_area := Interactable.make(p, Vector3(0.1, 0.07, 0.13), Vector3(0.105, 0.03, 0.045), "Key")
	key_area.activated.connect(func(_hit: Vector3) -> void:
		state.set_key(not state.key_armed)
		_toast("KEY: ARMED" if state.key_armed else "KEY: SAFE"))

	# Right group: amber counter readout, rotary knobs, push buttons.
	K.box(p, Vector3(0.2, 0.01, 0.06), Vector3(0.48, 0.006, -0.05), K.mat("bakelite"))
	_counter = K.label(p, "00 00 00", Vector3(0.48, 0.0125, -0.05), 0.03, BuildKit.AMBER, text)
	# Each knob steps one digit pair of the counter (placeholder).
	for i in range(3):
		var x := 0.4 + i * 0.08
		var knob := K.pivot(p, Vector3(x, 0.014, 0.05), Vector3(0, i * 40.0 - 40.0, 0))
		K.cyl(knob, 0.022, 0.026, Vector3.ZERO, K.mat("bakelite"), Vector3.ZERO, 10)
		K.box(knob, Vector3(0.004, 0.004, 0.02), Vector3(0, 0.014, -0.008), K.mat("paper"))
		var area := Interactable.make(p, Vector3(0.078, 0.07, 0.1), Vector3(x, 0.03, 0.05), "Knob%d" % (i + 1))
		area.activated.connect(_turn_knob.bind(knob, i))
	# Top row: ammunition select (lit = selected). Bottom row: ABORT and
	# two spare placeholder buttons.
	var caps := [[BuildKit.GREEN, true], [BuildKit.AMBER, true], [BuildKit.RED, false],
			[Color(0.75, 0.76, 0.78), false], [BuildKit.GREEN, false], [BuildKit.AMBER, false]]
	var ammo_ids := ["SMALL", "MEDIUM", "LARGE"]
	K.label(p, "AMMUNITION", Vector3(0.775, 0.006, -0.1), 0.013, Color(0.1, 0.09, 0.08), text)
	for i in range(caps.size()):
		var x := 0.7 + (i % 3) * 0.075
		var z := -0.04 + (i / 3) * 0.075
		var color: Color = caps[i][0]
		var rest: Material = K.lamp(color, caps[i][1], 1.2) if i != 3 else K.mat("steel")
		K.box(p, Vector3(0.052, 0.008, 0.052), Vector3(x, 0.004, z), K.mat("metal_dark"))
		var cap := K.box(p, Vector3(0.04, 0.016, 0.04), Vector3(x, 0.014, z), rest)
		var area := Interactable.make(p, Vector3(0.073, 0.06, 0.073), Vector3(x, 0.025, z), "PushButton%d" % (i + 1))
		if i < 3:
			var id: String = ammo_ids[i]
			_ammo_caps[id] = {"cap": cap, "color": color}
			K.label(p, id.substr(0, 1), Vector3(x, 0.023, z), 0.022, Color(0.1, 0.09, 0.08), text)
			area.activated.connect(func(_hit: Vector3) -> void:
				_press(cap)
				if state.set_ammo(id):
					_toast("AMMUNITION: " + id)
				else:
					_toast("AMMUNITION LOCKED DURING LAUNCH"))
		elif i == 3:
			K.label(p, "ABORT", Vector3(x, 0.006, z + 0.04), 0.012, Color(0.45, 0.04, 0.02), text)
			area.activated.connect(func(_hit: Vector3) -> void:
				_press(cap)
				_toast("SEQUENCE ABORTED" if state.abort() else "NO SEQUENCE TO ABORT"))
		else:
			area.activated.connect(_press_button.bind(cap, rest, K.lamp(color, true, 2.6)))


func _on_master(_hit: Vector3) -> void:
	if not state.cover_open:
		if state.locked():
			return
		state.set_cover(true)
		_toast("MASTER COVER OPEN")
		return
	var why: String = state.request_launch()
	if why == "":
		_toast("LAUNCH SEQUENCE STARTED")
	elif why != "SEQUENCE ALREADY RUNNING":
		_toast("LAUNCH INHIBITED: " + why)


## Moves key, cover and lamps to match the shared state.
func _sync_controls() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_key, "rotation_degrees:y", -90.0 if state.key_armed else 0.0, 0.15)
	tw.tween_property(_cover, "rotation_degrees:x", -115.0 if state.cover_open else 0.0, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arm_lamp.material_override = BuildKit.lamp(BuildKit.AMBER, state.key_armed, 2.2)
	for id in _ammo_caps:
		var c: Dictionary = _ammo_caps[id]
		c.cap.material_override = BuildKit.lamp(c.color, state.ammo == id, 2.0)


func _press(cap: MeshInstance3D) -> void:
	var tw := create_tween()
	tw.tween_property(cap, "position:y", 0.008, 0.05)
	tw.tween_property(cap, "position:y", 0.014, 0.1)


func _toggle(parent: Node3D, pos: Vector3, up: bool, title: String) -> void:
	var K := BuildKit
	K.box(parent, Vector3(0.035, 0.004, 0.05), pos, K.mat("steel"))
	K.cyl(parent, 0.01, 0.012, pos + Vector3(0, 0.008, 0), K.mat("steel"), Vector3.ZERO, 8)
	var hinge := K.pivot(parent, pos + Vector3(0, 0.008, 0), Vector3(28.0 if up else -28.0, 0, 0))
	K.cyl(hinge, 0.0045, 0.04, Vector3(0, 0.02, 0), K.mat("steel"), Vector3.ZERO, 6)
	# Touch target covers the switch and its label (spacing is 0.115 m).
	var area := Interactable.make(parent, Vector3(0.105, 0.07, 0.15), pos + Vector3(0, 0.03, 0.0), "Toggle " + title)
	var state := {"up": up}
	area.activated.connect(func(_hit: Vector3) -> void:
		state.up = not state.up
		BuildKit.flip_lever(hinge, state.up)
		_toast("%s: %s" % [title, "ON" if state.up else "OFF"]))



func _press_button(_hit: Vector3, cap: MeshInstance3D, rest: Material, lit: Material) -> void:
	cap.material_override = lit
	var tw := create_tween()
	tw.tween_property(cap, "position:y", 0.008, 0.05)
	tw.tween_interval(0.18)
	tw.tween_property(cap, "position:y", 0.014, 0.08)
	tw.tween_callback(func() -> void: cap.material_override = rest)


func _turn_knob(_hit: Vector3, knob: Node3D, index: int) -> void:
	var tw := create_tween()
	tw.tween_property(knob, "rotation_degrees:y", knob.rotation_degrees.y - 36.0, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_counter_values[index] = (_counter_values[index] + 1) % 100
	_counter.text = "%02d %02d %02d" % _counter_values


func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)


func _build_desk_props() -> void:
	var K := BuildKit
	# Thick procedures binder at the left corner of the desk.
	var b := K.pivot(self, Vector3(-1.03, DESK_TOP, -1.24), Vector3(0, 12, 0))
	K.box(b, Vector3(0.26, 0.07, 0.33), Vector3(0, 0.035, 0), K.mat("paint_green"))
	K.box(b, Vector3(0.245, 0.06, 0.32), Vector3(0.008, 0.035, 0), K.mat("paper_old"), Vector3.ZERO, false)
	K.box(b, Vector3(0.02, 0.074, 0.33), Vector3(-0.125, 0.035, 0), K.mat("bakelite"))
	K.box(b, Vector3(0.12, 0.002, 0.05), Vector3(0.0, 0.071, -0.08), K.mat("paper"), Vector3.ZERO, false)
	# Pencil.
	K.cyl(self, 0.004, 0.16, Vector3(0.75, DESK_TOP + 0.004, -0.95), K.lamp(BuildKit.AMBER, false), Vector3(0, 35, 90), 6)
