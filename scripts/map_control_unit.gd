extends Node3D
## Physical map navigation unit beside the left CRT. Knobs are turned by
## circling them with a finger (or mouse); the trackball pans in two axes.
## Every control writes to the shared StrategicState, never to the map
## renderer directly. Front faces local +Z; base sits on the desk (y 0).

const TEXT := Color(0.1, 0.09, 0.08)
## Cursor travel per knob revolution, as a fraction of the visible map width.
const CURSOR_PER_REV := 0.35
## Zoom factor per radian of ZOOM knob rotation.
const ZOOM_PER_RAD := 0.35
const LAYER_DETENT := PI / 6.0

var state: Node
var _activity_lamp: MeshInstance3D
var _layer_lamp: MeshInstance3D
var _activity_until := 0.0
var _layer_knob: Node3D
var _layer_accum := 0.0
var _t := 0.0


func _ready() -> void:
	state = get_tree().get_first_node_in_group("strategy")
	var K := BuildKit
	K.box(self, Vector3(0.27, 0.42, 0.16), Vector3(0, 0.21, -0.05), K.mat("paint_grey"))
	var face := K.pivot(self, Vector3(0, 0.22, 0.036))
	K.box(face, Vector3(0.25, 0.39, 0.01), Vector3.ZERO, K.mat("paint_beige"))
	K.box(face, Vector3(0.23, 0.035, 0.004), Vector3(0, 0.168, 0.006), K.mat("bakelite"), Vector3.ZERO, false)
	K.label(face, "MAP NAVIGATION", Vector3(0, 0.168, 0.009), 0.016, Color(0.85, 0.83, 0.75))
	K.cyl(face, 0.007, 0.008, Vector3(0.1, 0.168, 0.01), K.lamp(BuildKit.GREEN, true, 1.5), Vector3(90, 0, 0), 8, -1.0, false)

	_knob(face, Vector2(-0.058, 0.098), "CURSOR X", "CursorX", func(d: float) -> void:
		state.move_cursor(Vector2(d / TAU * state.view_rect_km().size.x * CURSOR_PER_REV, 0)))
	_knob(face, Vector2(0.058, 0.098), "CURSOR Y", "CursorY", func(d: float) -> void:
		state.move_cursor(Vector2(0, -d / TAU * state.view_rect_km().size.x * CURSOR_PER_REV)))
	_knob(face, Vector2(-0.058, 0.0), "ZOOM", "Zoom", func(d: float) -> void:
		state.zoom_by(exp(d * ZOOM_PER_RAD)))
	_trackball(face, Vector2(0.058, 0.0))
	_layer_selector(face, Vector2(-0.058, -0.095))
	_layer_button(face, Vector2(0.058, -0.095))
	_confirm_button(face, Vector2(0, -0.158))
	_activity_lamp = K.cyl(face, 0.006, 0.008, Vector3(-0.1, 0.168, 0.01), K.lamp(BuildKit.AMBER, false), Vector3(90, 0, 0), 8, -1.0, false)


func _process(delta: float) -> void:
	_t += delta
	var on := _t < _activity_until and fmod(_t, 0.2) < 0.1
	BuildKit.set_mat(_activity_lamp, BuildKit.lamp(BuildKit.AMBER, on, 1.8))


func _pulse() -> void:
	_activity_until = _t + 0.4


## A rotary knob with a pointer line and skirt ticks; `apply` receives the
## clockwise rotation in radians.
func _knob(face: Node3D, at: Vector2, title: String, id: String, apply: Callable) -> Node3D:
	var K := BuildKit
	var pos := Vector3(at.x, at.y, 0.005)
	for i in range(12):
		var a := i * TAU / 12.0
		K.box(face, Vector3(0.002, 0.006, 0.002), pos + Vector3(sin(a), cos(a), 0) * 0.036, K.mat("needle"), Vector3(0, 0, -rad_to_deg(a)), false)
	var knob := K.pivot(face, pos + Vector3(0, 0, 0.012))
	K.cyl(knob, 0.029, 0.016, Vector3.ZERO, K.mat("bakelite"), Vector3(90, 0, 0), 14, 0.025)
	K.box(knob, Vector3(0.004, 0.022, 0.004), Vector3(0, 0.013, 0.009), K.mat("paper"))
	K.label(face, title, pos + Vector3(0, 0.046, 0.002), 0.012, TEXT)
	var area := Interactable.make(face, Vector3(0.11, 0.09, 0.07), pos + Vector3(0, 0.005, 0.02), id)
	area.drag_mode = "rotary"
	area.always_active = true
	area.turned.connect(func(d: float) -> void:
		knob.rotation.z -= d                       # clockwise as seen by the operator
		apply.call(d)
		_pulse())
	return knob


func _trackball(face: Node3D, at: Vector2) -> void:
	var K := BuildKit
	var pos := Vector3(at.x, at.y, 0.005)
	K.cyl(face, 0.034, 0.012, pos, K.mat("metal_dark"), Vector3(90, 0, 0), 16)
	var ball := K.pivot(face, pos + Vector3(0, 0, 0.012))
	K.sphere(ball, 0.026, Vector3.ZERO, K.mat("rubber"))
	K.box(ball, Vector3(0.03, 0.003, 0.003), Vector3(0, 0, 0.024), K.mat("needle"))   # wear mark shows rotation
	K.label(face, "PAN", pos + Vector3(0, 0.046, 0.002), 0.012, TEXT)
	var area := Interactable.make(face, Vector3(0.11, 0.09, 0.07), pos + Vector3(0, 0.005, 0.02), "PanBall")
	area.drag_mode = "pad"
	area.always_active = true
	area.dragged.connect(func(rel: Vector2) -> void:
		ball.rotate_x(rel.y * 0.03)
		ball.rotate_y(rel.x * 0.03)
		# Rolling the ball drags the map with it.
		state.pan_km(-rel / state.map_zoom * 1.5)
		_pulse())


func _layer_selector(face: Node3D, at: Vector2) -> void:
	var K := BuildKit
	var pos := Vector3(at.x, at.y, 0.005)
	var n: int = state.LAYERS.size()
	for i in range(n):
		var a := i * LAYER_DETENT - (n - 1) * LAYER_DETENT * 0.5
		K.box(face, Vector3(0.003, 0.007, 0.002), pos + Vector3(sin(a), cos(a), 0) * 0.036, K.mat("needle"), Vector3(0, 0, -rad_to_deg(a)), false)
	_layer_knob = K.pivot(face, pos + Vector3(0, 0, 0.012))
	K.cyl(_layer_knob, 0.024, 0.016, Vector3.ZERO, K.mat("bakelite"), Vector3(90, 0, 0), 6, 0.022)  # hex: a selector
	K.box(_layer_knob, Vector3(0.005, 0.026, 0.004), Vector3(0, 0.01, 0.009), K.mat("paper"))
	K.label(face, "LAYER", pos + Vector3(0, 0.046, 0.002), 0.012, TEXT)
	_snap_layer_knob()
	var area := Interactable.make(face, Vector3(0.11, 0.09, 0.07), pos + Vector3(0, 0.005, 0.02), "LayerSelect")
	area.drag_mode = "rotary"
	area.always_active = true
	area.turned.connect(func(d: float) -> void:
		# Detented: one layer per 30 degrees of travel.
		_layer_accum += d
		while absf(_layer_accum) >= LAYER_DETENT:
			var step := signi(int(signf(_layer_accum)))
			_layer_accum -= step * LAYER_DETENT
			state.set_layer_index(state.layer_index + step)
		_snap_layer_knob(_layer_accum)
		_pulse())
	area.activated.connect(func(_p: Vector3) -> void:
		state.set_layer_index(state.layer_index + 1)
		_snap_layer_knob())


func _snap_layer_knob(extra := 0.0) -> void:
	var n: int = state.LAYERS.size()
	_layer_knob.rotation.z = -(state.layer_index * LAYER_DETENT - (n - 1) * LAYER_DETENT * 0.5 + extra)


func _layer_button(face: Node3D, at: Vector2) -> void:
	var K := BuildKit
	var pos := Vector3(at.x, at.y, 0.005)
	K.box(face, Vector3(0.06, 0.045, 0.01), pos, K.mat("metal_dark"))
	var cap := K.box(face, Vector3(0.048, 0.034, 0.014), pos + Vector3(0, 0, 0.01), K.mat("steel"))
	K.label(face, "ON / OFF", pos + Vector3(0, 0.046, 0.002), 0.012, TEXT)
	_layer_lamp = K.cyl(face, 0.006, 0.008, pos + Vector3(0.036, 0.0, 0.006), K.lamp(BuildKit.GREEN, true, 1.6), Vector3(90, 0, 0), 8, -1.0, false)
	state.map_changed.connect(func() -> void:
		_layer_lamp.material_override = BuildKit.lamp(BuildKit.GREEN, state.layers[state.LAYERS[state.layer_index]], 1.6))
	var area := Interactable.make(face, Vector3(0.11, 0.09, 0.07), pos + Vector3(0, 0.005, 0.02), "LayerToggle")
	area.always_active = true
	area.activated.connect(func(_p: Vector3) -> void:
		_press(cap)
		state.toggle_layer())


func _confirm_button(face: Node3D, at: Vector2) -> void:
	var K := BuildKit
	var pos := Vector3(at.x, at.y, 0.005)
	K.box(face, Vector3(0.2, 0.048, 0.01), pos, K.mat("metal_dark"))
	var cap := K.box(face, Vector3(0.186, 0.036, 0.014), pos + Vector3(0, 0, 0.01), K.lamp(BuildKit.AMBER, true, 1.1))
	K.label(face, "CONFIRM GRID", pos + Vector3(0, 0, 0.0185), 0.016, TEXT)
	var area := Interactable.make(face, Vector3(0.22, 0.06, 0.07), pos + Vector3(0, 0, 0.02), "ConfirmGrid")
	area.always_active = true
	area.activated.connect(func(_p: Vector3) -> void:
		_press(cap)
		if state.confirm_target():
			_toast("TARGET GRID %s CONFIRMED" % state.target_ref())
		else:
			_toast("GRID LOCKED: LAUNCH SEQUENCE IN PROGRESS"))


func _press(cap: MeshInstance3D) -> void:
	var z := cap.position.z
	var tw := create_tween()
	tw.tween_property(cap, "position:z", z - 0.006, 0.05)
	tw.tween_property(cap, "position:z", z, 0.1)


func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)
