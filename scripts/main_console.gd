extends Node3D
## The operator's main desk: desk body, the slanted control panel in
## front of the operator, and CRT light spill. The three CRT monitors are
## child nodes in main.tscn (crt_monitor.gd) so they can be moved in the editor.
## Controls are visual only in this stage.

const DESK_TOP := 0.76
const DESK_FRONT_Z := -0.45
const DESK_BACK_Z := -1.45

var _blink_lamp: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_build_desk()
	_build_control_panel()
	_build_desk_props()
	var spill := OmniLight3D.new()
	spill.light_color = Color(0.45, 1.0, 0.55)
	spill.light_energy = 0.28
	spill.omni_range = 1.6
	spill.position = Vector3(0, 1.0, -0.7)
	add_child(spill)


func _process(delta: float) -> void:
	_t += delta
	var on := fmod(_t, 1.6) < 0.8
	_blink_lamp.material_override = BuildKit.lamp(BuildKit.AMBER, on)


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
		_toggle(p, Vector3(x, 0.004, 0.02), i % 3 != 1)
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
		K.cyl(p, 0.019, 0.006, Vector3(x, 0.004, -0.06), K.mat("steel"), Vector3.ZERO, 10)
		K.label(p, lamps[i][2], Vector3(x, 0.006, -0.1), 0.013, Color(0.1, 0.09, 0.08), text)
	# Red flip cover over the master switch (closed).
	K.box(p, Vector3(0.08, 0.012, 0.09), Vector3(-0.05, 0.006, 0.045), K.mat("bakelite"))
	K.box(p, Vector3(0.07, 0.03, 0.08), Vector3(-0.05, 0.027, 0.045), K.mat("red_paint"))
	K.cyl(p, 0.006, 0.08, Vector3(-0.05, 0.03, 0.002), K.mat("steel"), Vector3(0, 0, 90), 6)  # hinge
	K.label(p, "MASTER", Vector3(-0.05, 0.006, 0.105), 0.015, Color(0.45, 0.04, 0.02), text)
	# Key switch.
	K.cyl(p, 0.026, 0.01, Vector3(0.1, 0.006, 0.045), K.mat("steel"), Vector3.ZERO, 12)
	K.cyl(p, 0.014, 0.018, Vector3(0.1, 0.014, 0.045), K.mat("brass"), Vector3.ZERO, 10)
	K.box(p, Vector3(0.004, 0.006, 0.018), Vector3(0.1, 0.024, 0.045), K.mat("bakelite"))
	K.label(p, "KEY", Vector3(0.1, 0.006, 0.105), 0.013, Color(0.1, 0.09, 0.08), text)

	# Right group: amber counter readout, rotary knobs, push buttons.
	K.box(p, Vector3(0.2, 0.01, 0.06), Vector3(0.48, 0.006, -0.05), K.mat("bakelite"))
	K.label(p, "00 00 00", Vector3(0.48, 0.0125, -0.05), 0.03, BuildKit.AMBER, text)
	for i in range(3):
		var x := 0.4 + i * 0.08
		K.cyl(p, 0.022, 0.026, Vector3(x, 0.014, 0.05), K.mat("bakelite"), Vector3.ZERO, 10)
		K.box(p, Vector3(0.004, 0.004, 0.02), Vector3(x, 0.028, 0.042), K.mat("paper"), Vector3(0, i * 40.0 - 40.0, 0))
	var caps := [K.lamp(BuildKit.GREEN, true, 1.2), K.lamp(BuildKit.AMBER, true, 1.2), K.lamp(BuildKit.RED, false),
			K.mat("steel"), K.lamp(BuildKit.GREEN, false), K.lamp(BuildKit.AMBER, false)]
	for i in range(caps.size()):
		var x := 0.7 + (i % 3) * 0.075
		var z := -0.04 + (i / 3) * 0.075
		K.box(p, Vector3(0.052, 0.008, 0.052), Vector3(x, 0.004, z), K.mat("metal_dark"))
		K.box(p, Vector3(0.04, 0.016, 0.04), Vector3(x, 0.014, z), caps[i])


func _toggle(parent: Node3D, pos: Vector3, up: bool) -> void:
	var K := BuildKit
	K.box(parent, Vector3(0.035, 0.004, 0.05), pos, K.mat("steel"))
	K.cyl(parent, 0.01, 0.012, pos + Vector3(0, 0.008, 0), K.mat("steel"), Vector3.ZERO, 8)
	var lever := K.cyl(parent, 0.0045, 0.04, pos + Vector3(0, 0.022, 0), K.mat("steel"), Vector3.ZERO, 6)
	lever.rotation_degrees.x = 28.0 if up else -28.0
	lever.position += Vector3(0, 0, 0.009 if up else -0.009)


func _build_desk_props() -> void:
	var K := BuildKit
	# Thick procedures binder at the left corner of the desk.
	var b := K.pivot(self, Vector3(-0.98, DESK_TOP, -1.05), Vector3(0, 12, 0))
	K.box(b, Vector3(0.26, 0.07, 0.33), Vector3(0, 0.035, 0), K.mat("paint_green"))
	K.box(b, Vector3(0.245, 0.06, 0.32), Vector3(0.008, 0.035, 0), K.mat("paper_old"), Vector3.ZERO, false)
	K.box(b, Vector3(0.02, 0.074, 0.33), Vector3(-0.125, 0.035, 0), K.mat("bakelite"))
	K.box(b, Vector3(0.12, 0.002, 0.05), Vector3(0.0, 0.071, -0.08), K.mat("paper"), Vector3.ZERO, false)
	# Pencil.
	K.cyl(self, 0.004, 0.16, Vector3(0.75, DESK_TOP + 0.004, -0.95), K.lamp(BuildKit.AMBER, false), Vector3(0, 35, 90), 6)
