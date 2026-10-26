extends Node3D
## The missile and its launch visuals inside the existing shaft. The node
## stands on the shaft's centre lane; local y is height in room metres.
## Only the section between the window sill (~1.4 m) and the window top
## (~3 m) is visible from the seat; the missile starts below it and leaves
## through the opening hatch at the top of the shaft (y 8).

signal ignition
signal flame_passing          # exhaust crossing the window: peak shake
signal cleared                # missile and flame have left the window
signal finished               # smoke settled; shaft is quiet and empty

const LENGTH := 8.5
const START_NOSE_Y := 0.6     # hidden below the sill
const V0 := 0.6               # m/s as it leaves the cell
const ACCEL := 1.4            # m/s^2
const FLAME_LEN := 3.0
const WINDOW_TOP := 3.2
const SETTLE_S := 6.0

var _missile: Node3D
var _flame: Node3D
var _flame_core: Node3D
var _light: OmniLight3D
var _glow: OmniLight3D
var _smoke: CPUParticles3D
var _label: Label3D
var _hatch: Array[MeshInstance3D] = []
var _t := -1.0                # seconds since ignition; < 0 = idle
var _flame_sent := false
var _cleared_sent := false
var _settle := -1.0


func _ready() -> void:
	_build_missile()
	_build_effects()
	_build_hatch()
	_reset()


func is_running() -> bool:
	return _t >= 0.0 or _settle >= 0.0


## Height of the nose tip (room metres), for tests and sequencing.
func nose_y() -> float:
	return _missile.position.y + LENGTH


func launch(designation: String) -> void:
	if is_running():
		return
	_label.text = designation
	_t = 0.0
	_flame_sent = false
	_cleared_sent = false
	_missile.visible = true
	_flame.visible = true
	_light.visible = true
	_glow.visible = true
	_smoke.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_hatch[0], "position:x", -2.7, 1.2)
	tw.tween_property(_hatch[1], "position:x", 2.7, 1.2)
	ignition.emit()


func _process(delta: float) -> void:
	if _t >= 0.0:
		_t += delta
		var travel := V0 * _t + 0.5 * ACCEL * _t * _t
		var tail := START_NOSE_Y + travel - LENGTH
		_missile.position.y = tail
		var flick := 0.85 + 0.3 * absf(sin(_t * 37.0) * cos(_t * 23.0))
		_flame.scale = Vector3(1.0, flick, 1.0)
		_light.position.y = tail - 0.8
		_light.light_energy = 7.0 * flick
		# Light spilling through the window peaks as the exhaust passes it.
		var near := 1.0 - clampf(absf(tail - 2.0) / 5.0, 0.0, 1.0)
		_glow.light_energy = 2.2 * near * flick
		_smoke.position.y = tail - 0.4
		if not _flame_sent and tail > 1.0:
			_flame_sent = true
			flame_passing.emit()
		if not _cleared_sent and tail - FLAME_LEN > WINDOW_TOP:
			_cleared_sent = true
			cleared.emit()
		if tail > 10.0:
			# Gone through the hatch: the shaft keeps only drifting smoke.
			_t = -1.0
			_missile.visible = false
			_flame.visible = false
			_light.visible = false
			_glow.visible = false
			_smoke.emitting = false
			_settle = 0.0
	elif _settle >= 0.0:
		_settle += delta
		if _settle >= SETTLE_S:
			_settle = -1.0
			var tw := create_tween().set_parallel()
			tw.tween_property(_hatch[0], "position:x", -0.9, 2.0)
			tw.tween_property(_hatch[1], "position:x", 0.9, 2.0)
			finished.emit()


func _reset() -> void:
	_t = -1.0
	_settle = -1.0
	_missile.position.y = START_NOSE_Y - LENGTH
	_missile.visible = false
	_flame.visible = false
	_light.visible = false
	_glow.visible = false


## The missile's body (8.5 m, nozzle at y = -0.27, nose at 8.5), shared
## with the main menu backdrop. Returns its root node.
static func build_body(parent: Node3D) -> Node3D:
	var K := BuildKit
	var _missile := K.pivot(parent, Vector3.ZERO)
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color(0.3, 0.34, 0.26)
	olive.roughness = 0.65
	olive.metallic = 0.2
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.62, 0.62, 0.58)
	band.roughness = 0.6
	K.cyl(_missile, 0.5, 6.0, Vector3(0, 3.4, 0), olive, Vector3.ZERO, 16)                        # body
	K.cyl(_missile, 0.5, 1.0, Vector3(0, 6.9, 0), olive, Vector3.ZERO, 16, 0.32)                  # ogive base
	K.cyl(_missile, 0.32, 1.1, Vector3(0, 7.95, 0), band, Vector3.ZERO, 16, 0.02)                 # nose
	for y in [2.0, 4.8]:
		K.cyl(_missile, 0.508, 0.14, Vector3(0, y, 0), band, Vector3.ZERO, 16)
	K.cyl(_missile, 0.56, 0.45, Vector3(0, 0.2, 0), K.mat("metal_dark"), Vector3.ZERO, 16, 0.5)  # flared skirt
	K.cyl(_missile, 0.22, 0.3, Vector3(0, -0.12, 0), K.mat("bakelite"), Vector3.ZERO, 12, 0.28)  # nozzle
	for i in range(4):
		var a := PI * 0.25 + i * PI * 0.5
		K.box(_missile, Vector3(0.45, 1.1, 0.04), Vector3(cos(a) * 0.7, 0.75, sin(a) * 0.7), K.mat("metal_dark"), Vector3(0, -rad_to_deg(a), 0))
	return _missile


func _build_missile() -> void:
	_missile = build_body(self)
	# Stencilled designation on the side facing the window.
	_label = BuildKit.label(_missile, "NV-M4", Vector3(0, 3.6, 0.505), 0.32, Color(0.85, 0.83, 0.75), Vector3(0, 0, 90), true)


func _build_effects() -> void:
	var K := BuildKit
	_flame = K.pivot(_missile, Vector3(0, -0.27, 0))
	var outer := StandardMaterial3D.new()
	outer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	outer.albedo_color = Color(1.0, 0.45, 0.12, 0.85)
	outer.cull_mode = BaseMaterial3D.CULL_DISABLED
	var core := outer.duplicate()
	core.albedo_color = Color(1.0, 0.85, 0.55, 0.95)
	K.cyl(_flame, 0.34, FLAME_LEN, Vector3(0, -FLAME_LEN * 0.5, 0), outer, Vector3.ZERO, 12, -1.0, false).mesh.bottom_radius = 0.06
	_flame_core = K.cyl(_flame, 0.2, FLAME_LEN * 0.55, Vector3(0, -FLAME_LEN * 0.27, 0), core, Vector3.ZERO, 10, -1.0, false)
	_flame_core.mesh.bottom_radius = 0.03

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.28)
	_light.omni_range = 12.0
	add_child(_light)
	# Orange spill into the room through the window glass.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.62, 0.3)
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.9, 1.75)
	add_child(_glow)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 56
	_smoke.lifetime = 4.0
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.5
	_smoke.direction = Vector3(0, -1, 0)
	_smoke.spread = 70.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.5
	_smoke.gravity = Vector3(0, 0.25, 0)
	_smoke.damping_min = 0.8
	_smoke.damping_max = 1.2
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 2.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.6, 0.58, 0.55, 0.45))
	fade.set_color(1, Color(0.4, 0.4, 0.4, 0.0))
	_smoke.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.vertex_color_use_as_albedo = true
	quad.material = smoke_mat
	_smoke.mesh = quad
	add_child(_smoke)


func _build_hatch() -> void:
	# Two sliding doors over the shaft top (closed until ignition).
	var K := BuildKit
	for s in [-1, 1]:
		_hatch.append(K.box(self, Vector3(1.8, 0.35, 2.5), Vector3(s * 0.9, 8.2, -0.1), K.mat("metal_dark")))
