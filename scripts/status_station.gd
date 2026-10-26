extends Node3D
## Right-side facility status station: an upright analogue instrument
## panel (power, readiness, cooling), warning lamps, breaker handles,
## and a logbook on the desk. Needles drift slightly so the facility
## reads as running. Tapping the panel leans in to read it; the breakers
## then open and close, moving their power meter (placeholder only).
##
## Built in local space: the operator is toward +Z, the wall toward -Z.

const TOP := 0.76
const TEXT_DARK := Color(0.1, 0.09, 0.08)

var _needles: Array[Dictionary] = []
var _filter_lamp: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	var K := BuildKit
	# Desk (same footprint as the comms side).
	K.box(self, Vector3(2.0, 0.05, 0.85), Vector3(0, TOP - 0.025, 0), K.mat("paint_green"))
	K.cyl(self, 0.028, 2.0, Vector3(0, TOP - 0.025, 0.425), K.mat("rubber"), Vector3(0, 0, 90), 8)
	K.box(self, Vector3(1.96, TOP - 0.05, 0.05), Vector3(0, (TOP - 0.05) * 0.5, -0.38), K.mat("paint_grey"))
	for x in [-0.95, 0.95]:
		K.box(self, Vector3(0.05, TOP - 0.05, 0.78), Vector3(x, (TOP - 0.05) * 0.5, 0.0), K.mat("paint_grey"))
	_build_panel(K.pivot(self, Vector3(0, TOP, -0.3), Vector3(-8, 0, 0)))
	_build_desk_props()


func _process(delta: float) -> void:
	_t += delta
	for n in _needles:
		var wobble: float = sin(_t * n.speed + n.phase) * 0.6 + sin(_t * n.speed * 2.7) * 0.25
		n.cur = lerpf(n.cur, n.base, 1.0 - exp(-4.0 * delta))
		n.node.rotation.z = deg_to_rad(n.cur + wobble * n.range)
	var on := fmod(_t, 2.0) < 1.0
	BuildKit.set_mat(_filter_lamp, BuildKit.lamp(BuildKit.AMBER, on))


func _build_panel(p: Node3D) -> void:
	var K := BuildKit
	var w := 1.9
	var h := 1.12
	K.box(p, Vector3(w, h, 0.1), Vector3(0, h * 0.5, -0.05), K.mat("paint_grey"))
	K.box(p, Vector3(w - 0.08, h - 0.1, 0.01), Vector3(0, h * 0.5 + 0.01, 0.005), K.mat("paint_beige"))
	var fz := 0.012
	K.box(p, Vector3(0.6, 0.06, 0.004), Vector3(0, h - 0.06, fz), K.mat("bakelite"), Vector3.ZERO, false)
	K.label(p, "FACILITY STATUS", Vector3(0, h - 0.06, fz + 0.004), 0.032, Color(0.85, 0.83, 0.75))
	var zone := Interactable.make(p, Vector3(w + 0.04, h + 0.04, 0.12), Vector3(0, h * 0.5, 0.07), "StatusPanel")
	zone.focus_zone = true
	zone.focus_title = "FACILITY STATUS"
	zone.focus_fov = 55.0
	zone.focus_distance = 1.15

	# Row 1: round cooling gauges.
	var gauges := [["COOLANT T", -40.0], ["COOLANT P", 10.0], ["VENT FLOW", 30.0], ["SHAFT T", -15.0]]
	for i in range(gauges.size()):
		var x := -0.72 + i * 0.48
		_round_gauge(p, Vector3(x, 0.83, fz), gauges[i][0], gauges[i][1])
	K.label(p, "COOLING", Vector3(-0.48, 0.97, fz + 0.002), 0.02, TEXT_DARK)
	K.label(p, "ENVIRONMENT", Vector3(0.48, 0.97, fz + 0.002), 0.02, TEXT_DARK)

	# Row 2: edge meters for the power buses + readiness lamp matrix.
	var meters := [["BUS A", 5.0], ["BUS B", 0.0], ["RESERVE", -30.0]]
	for i in range(meters.size()):
		_edge_meter(p, Vector3(-0.72 + i * 0.27, 0.52, fz), meters[i][0], meters[i][1])
	K.label(p, "POWER", Vector3(-0.45, 0.64, fz + 0.002), 0.02, TEXT_DARK)
	var ready := K.pivot(p, Vector3(0.48, 0.52, fz))
	K.box(ready, Vector3(0.6, 0.2, 0.01), Vector3.ZERO, K.mat("bakelite"))
	K.label(ready, "SYSTEM READINESS", Vector3(0, 0.125, 0.002), 0.02, TEXT_DARK)
	for row in range(3):
		for col in range(6):
			var lit := not (row == 2 and col >= 4)
			var c := BuildKit.AMBER if (row == 1 and col == 3) else BuildKit.GREEN
			K.box(ready, Vector3(0.06, 0.035, 0.01), Vector3(-0.225 + col * 0.09, 0.055 - row * 0.055, 0.008), K.lamp(c, lit, 1.4), Vector3.ZERO, false)

	# Row 3: breaker handles and warning lamps. CB-1..3 feed the meters
	# above (needles 4..6); vertical handle = closed.
	var meter_on := [5.0, 0.0, 15.0]
	var meter_off := [-40.0, -40.0, -30.0]
	for i in range(4):
		var x := -0.78 + i * 0.16
		K.cyl(p, 0.04, 0.025, Vector3(x, 0.2, fz + 0.012), K.mat("metal_dark"), Vector3(90, 0, 0), 10)
		var handle := K.pivot(p, Vector3(x, 0.2, fz + 0.035), Vector3(0, 0, 0 if i != 2 else 90))
		K.box(handle, Vector3(0.022, 0.09, 0.03), Vector3.ZERO, K.mat("bakelite"))
		K.label(p, "CB-%d" % (i + 1), Vector3(x, 0.125, fz + 0.002), 0.016, TEXT_DARK)
		var area := Interactable.make(p, Vector3(0.15, 0.2, 0.09), Vector3(x, 0.18, 0.07), "Breaker%d" % (i + 1))
		var state := {"closed": i != 2}
		area.activated.connect(func(_hit: Vector3) -> void:
			state.closed = not state.closed
			var tw := create_tween()
			tw.tween_property(handle, "rotation_degrees:z", 0.0 if state.closed else 90.0, 0.15) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if i < 3:
				_needles[4 + i].base = meter_on[i] if state.closed else meter_off[i]
			get_tree().call_group("hud", "toast", "CB-%d: %s" % [i + 1, "CLOSED" if state.closed else "OPEN"]))
	var warns := [["FILTER", BuildKit.AMBER], ["FIRE", BuildKit.RED], ["FLOOD", BuildKit.RED], ["DOOR", BuildKit.RED], ["GEN", BuildKit.AMBER]]
	for i in range(warns.size()):
		var x := 0.12 + i * 0.15
		K.box(p, Vector3(0.11, 0.07, 0.03), Vector3(x, 0.22, fz + 0.015), K.mat("metal_dark"))
		var lamp := K.box(p, Vector3(0.09, 0.05, 0.01), Vector3(x, 0.22, fz + 0.033), K.lamp(warns[i][1], false), Vector3.ZERO, false)
		if warns[i][0] == "FILTER":
			_filter_lamp = lamp
		K.label(p, warns[i][0], Vector3(x, 0.145, fz + 0.002), 0.017, TEXT_DARK)

	# Warm instrument light above the panel for readability.
	var hood := K.pivot(p, Vector3(0, h + 0.05, 0.08))
	K.box(hood, Vector3(1.2, 0.06, 0.18), Vector3.ZERO, K.mat("paint_grey"))
	K.box(hood, Vector3(1.1, 0.01, 0.12), Vector3(0, -0.032, 0.0), K.lamp(Color(1.0, 0.88, 0.7), true, 1.3), Vector3.ZERO, false)
	var light := SpotLight3D.new()
	light.add_to_group("minor_light")        # off on LOW (graphics preset)
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_energy = 1.6
	light.spot_range = 2.0
	light.spot_angle = 70.0
	light.position = Vector3(0, -0.05, 0.25)
	light.rotation_degrees = Vector3(-66, 0, 0)   # down and back onto the panel
	hood.add_child(light)


func _round_gauge(parent: Node3D, pos: Vector3, title: String, base_deg: float) -> void:
	var K := BuildKit
	var g := K.pivot(parent, pos)
	K.cyl(g, 0.11, 0.04, Vector3(0, 0, 0.02), K.mat("metal_dark"), Vector3(90, 0, 0), 16)
	K.cyl(g, 0.095, 0.01, Vector3(0, 0, 0.037), K.mat("gauge_face"), Vector3(90, 0, 0), 16)
	# Scale: ticks across 240 degrees with an amber and a red zone.
	for i in range(9):
		var a := deg_to_rad(-120.0 + i * 30.0)
		var col := K.mat("needle")
		if i == 7:
			col = K.lamp(BuildKit.AMBER, false)
		elif i == 8:
			col = K.mat("red_paint")
		K.box(g, Vector3(0.006, 0.018, 0.003), Vector3(sin(a) * 0.075, cos(a) * 0.075, 0.043), col, Vector3(0, 0, -rad_to_deg(a)), false)
	var needle := K.pivot(g, Vector3(0, 0, 0.046))
	K.box(needle, Vector3(0.005, 0.07, 0.003), Vector3(0, 0.03, 0), K.mat("needle"), Vector3.ZERO, false)
	K.cyl(g, 0.01, 0.01, Vector3(0, 0, 0.048), K.mat("bakelite"), Vector3(90, 0, 0), 8)
	K.label(g, title, Vector3(0, -0.045, 0.044), 0.014, TEXT_DARK)
	_needles.append({"node": needle, "base": base_deg, "cur": base_deg, "range": 3.0, "speed": randf_range(0.4, 0.9), "phase": randf() * TAU})


func _edge_meter(parent: Node3D, pos: Vector3, title: String, base_deg: float) -> void:
	var K := BuildKit
	var m := K.pivot(parent, pos)
	K.box(m, Vector3(0.22, 0.16, 0.04), Vector3(0, 0, 0.02), K.mat("metal_dark"))
	K.box(m, Vector3(0.19, 0.12, 0.01), Vector3(0, 0.005, 0.037), K.mat("gauge_face"))
	for i in range(7):
		var a := deg_to_rad(-45.0 + i * 15.0)
		K.box(m, Vector3(0.004, 0.012, 0.003), Vector3(sin(a) * 0.08, -0.045 + cos(a) * 0.08, 0.043), K.mat("needle"), Vector3(0, 0, -rad_to_deg(a)), false)
	var needle := K.pivot(m, Vector3(0, -0.045, 0.045))
	K.box(needle, Vector3(0.003, 0.085, 0.003), Vector3(0, 0.042, 0), K.mat("needle"), Vector3.ZERO, false)
	K.label(m, title, Vector3(0, -0.035, 0.043), 0.014, TEXT_DARK)
	_needles.append({"node": needle, "base": base_deg, "cur": base_deg, "range": 1.5, "speed": randf_range(0.8, 1.6), "phase": randf() * TAU})


func _build_desk_props() -> void:
	var K := BuildKit
	# Open logbook with a pen.
	var book := K.pivot(self, Vector3(-0.35, TOP, 0.12), Vector3(0, 8, 0))
	K.box(book, Vector3(0.44, 0.012, 0.3), Vector3(0, 0.006, 0), K.mat("paint_green"))
	for s in [-1, 1]:
		K.box(book, Vector3(0.2, 0.01, 0.28), Vector3(s * 0.108, 0.016, 0), K.mat("paper_old"), Vector3(0, 0, s * -2.0), false)
	var lines := K.pivot(book, Vector3(0.11, 0.024, 0), Vector3(-90, 0, 0))
	K.label(lines, "0600 SYS CHECK  OK\n0615 COOLANT   OK\n0630 LINE 5   AMBER\n0645 FILTER  AMBER\n", Vector3.ZERO, 0.013, Color(0.15, 0.17, 0.3))
	K.cyl(book, 0.004, 0.14, Vector3(-0.1, 0.026, 0.03), K.mat("bakelite"), Vector3(0, 30, 90), 6)
	# Enamel mug: someone is on shift.
	K.cyl(self, 0.04, 0.09, Vector3(0.35, TOP + 0.045, 0.1), K.mat("paper"), Vector3.ZERO, 12)
	K.cyl(self, 0.034, 0.005, Vector3(0.35, TOP + 0.085, 0.1), K.mat("needle"), Vector3.ZERO, 12)
	K.box(self, Vector3(0.012, 0.05, 0.035), Vector3(0.395, TOP + 0.05, 0.1), K.mat("paper"))
