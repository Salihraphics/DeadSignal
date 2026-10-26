extends Node3D
## Main menu backdrop: an underground missile hall. A strategic missile
## stands in its cradle on the right; a control gallery with a few dim CRTs
## sits high on the back wall; concrete, steel ribs, a catwalk and
## fluorescent fittings set the depth. The left of the frame stays dark for
## the menu.
##
## Cost is kept low on purpose: one spot light on the missile (shadows only
## above LOW), one dim fill, emissive fittings instead of lights, no
## particles or post effects. The only per-frame work is a very slow camera
## drift (off with reduced motion) and a slow drift of the key light.
## A CRT flickers now and then and a lamp blinks, on timers.

const MissileLaunch := preload("res://scripts/missile_launch.gd")

const HALL_W := 22.0
const BACK_Z := -9.0
const CEIL := 12.0
const MISSILE_POS := Vector3(3.4, 0.55, -3.6)
const CAM_POS := Vector3(-1.2, 3.3, 10.8)
const CAM_LOOK := Vector3(0.6, 4.1, -3.6)

var _cam: Camera3D
var _key: SpotLight3D
var _key_energy := 4.2
var _screens: Array[MeshInstance3D] = []
var _screen_mat: StandardMaterial3D
var _screen_dim: StandardMaterial3D
var _lamp: MeshInstance3D
var _lamp_on: StandardMaterial3D
var _lamp_off: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	_build_hall()
	_build_gallery()
	_build_missile()
	_build_lights()
	_cam = Camera3D.new()
	_cam.fov = 41.0
	add_child(_cam)
	_cam.current = true
	_cam.look_at_from_position(CAM_POS, CAM_LOOK, Vector3.UP)
	_apply_quality()
	Graphics.preset_changed.connect(func(_m: String, _a: String) -> void: _apply_quality())
	# A tube on the gallery flickers now and then; a status lamp blinks slowly.
	var flicker := Timer.new()
	flicker.wait_time = 4.0
	flicker.autostart = true
	flicker.timeout.connect(_flicker)
	add_child(flicker)
	var blink := Timer.new()
	blink.wait_time = 1.4
	blink.autostart = true
	blink.timeout.connect(func() -> void:
		_lamp.material_override = _lamp_off if _lamp.material_override == _lamp_on else _lamp_on)
	add_child(blink)


func _process(delta: float) -> void:
	_t += delta
	if Settings.reduced_motion:
		return
	# Almost still: a slow, small drift (about 30 cm over a minute).
	var drift := Vector3(sin(_t * 0.09) * 0.32, sin(_t * 0.13) * 0.07, cos(_t * 0.07) * 0.18)
	_cam.look_at_from_position(CAM_POS + drift, CAM_LOOK + drift * 0.25, Vector3.UP)
	_key.light_energy = _key_energy * (1.0 + 0.05 * sin(_t * 0.4))


func _apply_quality() -> void:
	_key.shadow_enabled = Graphics.active != "LOW"


func _flicker() -> void:
	if Settings.reduced_motion or _screens.is_empty():
		return
	var s: MeshInstance3D = _screens[randi() % _screens.size()]
	s.material_override = _screen_dim
	get_tree().create_timer(randf_range(0.06, 0.16)).timeout.connect(func() -> void:
		s.material_override = _screen_mat)


func _build_hall() -> void:
	var K := BuildKit
	var depth := 20.0
	var mid_z := BACK_Z + depth * 0.5
	K.box(self, Vector3(HALL_W, 0.2, depth), Vector3(0, -0.1, mid_z), K.mat("floor"))
	K.box(self, Vector3(HALL_W, 0.4, depth), Vector3(0, CEIL + 0.2, mid_z), K.mat("concrete"))
	K.box(self, Vector3(HALL_W, CEIL, 0.4), Vector3(0, CEIL * 0.5, BACK_Z - 0.2), K.mat("concrete"))
	for s in [-1, 1]:
		K.box(self, Vector3(0.4, CEIL, depth), Vector3(s * HALL_W * 0.5, CEIL * 0.5, mid_z), K.mat("concrete"))
	# Painted dado on the back wall and a hazard band at its foot.
	K.box(self, Vector3(HALL_W, 1.6, 0.02), Vector3(0, 0.8, BACK_Z + 0.01), K.mat("paint_green"), Vector3.ZERO, false)
	K.box(self, Vector3(HALL_W, 0.18, 0.03), Vector3(0, 0.09, BACK_Z + 0.02), K.mat("hazard"), Vector3.ZERO, false)
	# Steel ribs (columns) along the back wall, beams across the ceiling.
	for i in range(9):
		var x := -10.0 + i * 2.5
		K.box(self, Vector3(0.36, CEIL, 0.5), Vector3(x, CEIL * 0.5, BACK_Z + 0.25), K.mat("metal_dark"))
	for z in [-7.0, -3.5, 0.0, 3.5]:
		K.box(self, Vector3(HALL_W, 0.6, 0.4), Vector3(0, CEIL - 0.3, z), K.mat("paint_grey"))
	# Catwalk with railing along the back wall.
	var cw_y := 5.2
	K.box(self, Vector3(HALL_W, 0.12, 1.4), Vector3(0, cw_y, BACK_Z + 1.1), K.mat("metal_dark"))
	for y in [0.55, 1.05]:
		K.box(self, Vector3(HALL_W, 0.05, 0.05), Vector3(0, cw_y + y, BACK_Z + 1.78), K.mat("paint_grey"))
	for i in range(23):
		K.box(self, Vector3(0.05, 1.05, 0.05), Vector3(-11.0 + i, cw_y + 0.52, BACK_Z + 1.78), K.mat("paint_grey"))
	# Fluorescent fittings: emissive only, no extra lights.
	for p in [Vector3(-4, CEIL - 0.7, -2.0), Vector3(1.5, CEIL - 0.7, -5.5), Vector3(-6.5, CEIL - 0.7, -6.0), Vector3(6, CEIL - 0.7, -1.0)]:
		K.box(self, Vector3(2.0, 0.1, 0.32), p, K.mat("paint_grey"))
		K.box(self, Vector3(1.85, 0.03, 0.18), p + Vector3(0, -0.07, 0), K.lamp(Color(0.86, 0.92, 0.96), true, 1.6), Vector3.ZERO, false)
	# Cable trays and conduits down the right wall.
	for x in [9.8, 9.5]:
		K.cyl(self, 0.08, CEIL, Vector3(x, CEIL * 0.5, -6.0), K.mat("cable"), Vector3.ZERO, 6)
	K.box(self, Vector3(0.12, 0.3, 14.0), Vector3(-10.7, 7.5, -2.0), K.mat("metal_dark"))
	# Stencils.
	K.label(self, "BAY 1", Vector3(0.6, 7.6, BACK_Z + 0.03), 0.9, Color(0.78, 0.76, 0.68, 0.85), Vector3.ZERO, true)
	# Caged wall lamps along the back wall: small warm points for depth.
	for x in [3.0, 9.5]:
		K.box(self, Vector3(0.42, 0.34, 0.2), Vector3(x, 4.3, BACK_Z + 0.5), K.mat("metal_dark"))
		K.box(self, Vector3(0.3, 0.2, 0.06), Vector3(x, 4.3, BACK_Z + 0.62), K.lamp(Color(1.0, 0.72, 0.4), true, 1.1), Vector3.ZERO, false)
		for dx in [-0.08, 0.0, 0.08]:
			K.box(self, Vector3(0.02, 0.24, 0.02), Vector3(x + dx, 4.3, BACK_Z + 0.67), K.mat("metal_dark"), Vector3.ZERO, false)


## Control gallery high on the back wall: a slanted window with a few
## distant CRTs glowing behind it.
func _build_gallery() -> void:
	var K := BuildKit
	var g := K.pivot(self, Vector3(-0.6, 1.2, BACK_Z + 0.6))
	K.box(g, Vector3(6.2, 2.4, 1.0), Vector3(0, 1.1, -0.1), K.mat("paint_grey"))
	K.box(g, Vector3(5.6, 1.0, 0.06), Vector3(0, 1.35, 0.42), K.mat("screen_off"))
	_screen_mat = K.lamp(Color(0.42, 0.85, 0.48), true, 0.32)
	_screen_dim = K.lamp(Color(0.42, 0.85, 0.48), true, 0.12)
	for i in range(5):
		var s := K.box(g, Vector3(0.38, 0.28, 0.02), Vector3(-2.1 + i * 1.05, 1.3, 0.47), _screen_mat, Vector3.ZERO, false)
		_screens.append(s)
	K.box(g, Vector3(0.4, 0.29, 0.02), Vector3(1.05, 1.3, 0.475), K.lamp(Color(0.95, 0.65, 0.25), true, 0.28), Vector3.ZERO, false)
	for x in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		K.box(g, Vector3(0.08, 1.0, 0.1), Vector3(x, 1.35, 0.46), K.mat("metal_dark"))     # mullions


func _build_missile() -> void:
	var K := BuildKit
	var stand := K.pivot(self, MISSILE_POS)
	# Plinth with hazard edge and the cradle ring around the body.
	K.cyl(stand, 1.9, 0.55, Vector3(0, -0.275, 0), K.mat("concrete"), Vector3.ZERO, 20)
	K.cyl(stand, 1.95, 0.08, Vector3(0, -0.05, 0), K.mat("hazard"), Vector3.ZERO, 20)
	var m := MissileLaunch.build_body(stand)
	m.position.y = 0.3
	K.label(m, "NV-L9", Vector3(0, 3.6, 0.505), 0.34, Color(0.82, 0.8, 0.72), Vector3(0, 0, 90), true)
	for y in [1.6, 5.2]:
		K.cyl(stand, 0.72, 0.14, Vector3(0, y, 0), K.mat("paint_grey"), Vector3.ZERO, 16)
	# Service gantry beside it: two posts and platforms.
	# Service gantry behind it (kept off the silhouette): posts and platforms.
	for x in [0.9, 2.5]:
		K.box(stand, Vector3(0.18, 9.6, 0.18), Vector3(x, 4.8, -1.5), K.mat("paint_grey"))
	for y in [2.6, 6.0]:
		K.box(stand, Vector3(2.0, 0.08, 1.0), Vector3(1.7, y, -1.25), K.mat("metal_dark"))
		K.box(stand, Vector3(2.0, 0.9, 0.04), Vector3(1.7, y + 0.45, -0.78), K.mat("paint_grey"))
	# Umbilical cable from the gantry.
	K.cyl(stand, 0.05, 1.2, Vector3(0.6, 6.4, -0.8), K.mat("cable"), Vector3(55, 0, 0), 6)
	# Status lamp on the plinth (blinks slowly).
	_lamp_on = K.lamp(Color(0.95, 0.66, 0.25), true, 2.6)
	_lamp_off = K.lamp(Color(0.95, 0.66, 0.25), false)
	_lamp = K.box(stand, Vector3(0.12, 0.12, 0.06), Vector3(0.0, -0.25, 1.92), _lamp_on, Vector3.ZERO, false)


func _build_lights() -> void:
	# Key: a hard top light falling on the missile from the left.
	_key = SpotLight3D.new()
	_key.light_color = Color(0.95, 0.92, 0.86)
	_key.light_energy = _key_energy
	_key.spot_range = 16.0
	_key.spot_angle = 24.0
	_key.spot_attenuation = 0.7
	_key.shadow_blur = 2.0
	_key.position = MISSILE_POS + Vector3(-4.5, 10.5, 3.0)
	add_child(_key)
	_key.look_at(MISSILE_POS + Vector3(0.0, 3.6, 0.0), Vector3.UP)
	# Dim cool fill along the back wall for depth.
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.55, 0.62, 0.7)
	fill.light_energy = 0.55
	fill.omni_range = 13.0
	fill.position = Vector3(6.5, 5.0, -6.5)     # behind and right: a cool rim
	add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.013)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.44)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.065)
	env.fog_density = 0.018
	we.environment = env
	add_child(we)
