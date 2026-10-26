extends Node3D
## Builds the enclosed command room shell: walls, ceiling, floor,
## the reinforced observation window, the launch shaft behind it,
## room lighting and the WorldEnvironment.
##
## Interior: x -2.2..2.2, z -2.3 (front wall) .. 2.4 (back), y 0..2.85.
## The operator's eye sits at roughly (0, 1.2, 0) looking toward -Z.

const HALF_W := 2.2
const FRONT_Z := -2.3
const BACK_Z := 2.4
const HEIGHT := 2.85
const WALL := 0.3
const FRONT_WALL := 0.6           # reinforced wall around the window

const WIN_HALF_W := 0.95
const WIN_BOTTOM := 1.35
const WIN_TOP := 2.25

const SHAFT_HALF_W := 1.8
const SHAFT_BACK_Z := -5.4

var _shaft_beacon: MeshInstance3D
var _key_light: SpotLight3D
var _key_energy := 0.0
var _flicker_until := 0.0
var _alarm := false
var _t := 0.0


func _ready() -> void:
	_build_shell()
	_build_window()
	_build_shaft()
	_build_ceiling_details()
	_build_wall_details()
	_build_lights()
	_build_environment()


func _process(delta: float) -> void:
	# Slow rotating-beacon pulse in the shaft: a hint that the facility is live.
	_t += delta
	if _shaft_beacon:
		var on := fmod(_t, 0.5) < 0.25 if _alarm else fmod(_t, 2.4) < 0.25
		_shaft_beacon.material_override = BuildKit.lamp(BuildKit.RED, on, 3.0)
	if _t < _flicker_until:
		_key_light.light_energy = _key_energy * (0.55 + 0.45 * absf(sin(_t * 41.0) * sin(_t * 17.0)))
	elif _key_light and _key_light.light_energy != _key_energy:
		_key_light.light_energy = _key_energy


## Brief unsteady lighting (launch vibration through the fittings).
func flicker(duration: float) -> void:
	_flicker_until = _t + duration


## Launch alarm: the shaft beacon flashes fast while active.
func set_alarm(on: bool) -> void:
	_alarm = on


func _build_shell() -> void:
	var K := BuildKit
	var depth := BACK_Z - FRONT_Z
	var mid_z := (BACK_Z + FRONT_Z) * 0.5
	# Floor and ceiling slabs.
	K.box(self, Vector3(HALF_W * 2, 0.2, depth), Vector3(0, -0.1, mid_z), K.mat("floor"))
	K.box(self, Vector3(HALF_W * 2 + WALL * 2, 0.3, depth + WALL), Vector3(0, HEIGHT + 0.15, mid_z), K.mat("concrete"))
	# Side and back walls.
	for s in [-1, 1]:
		K.box(self, Vector3(WALL, HEIGHT, depth), Vector3(s * (HALF_W + WALL * 0.5), HEIGHT * 0.5, mid_z), K.mat("concrete"))
	K.box(self, Vector3(HALF_W * 2, HEIGHT, WALL), Vector3(0, HEIGHT * 0.5, BACK_Z + WALL * 0.5), K.mat("concrete"))

	# Front wall assembled around the window opening.
	var fz := FRONT_Z - FRONT_WALL * 0.5
	var side_w := HALF_W - WIN_HALF_W
	for s in [-1, 1]:
		K.box(self, Vector3(side_w, HEIGHT, FRONT_WALL), Vector3(s * (WIN_HALF_W + side_w * 0.5), HEIGHT * 0.5, fz), K.mat("concrete"))
	K.box(self, Vector3(WIN_HALF_W * 2, WIN_BOTTOM, FRONT_WALL), Vector3(0, WIN_BOTTOM * 0.5, fz), K.mat("concrete"))
	K.box(self, Vector3(WIN_HALF_W * 2, HEIGHT - WIN_TOP, FRONT_WALL), Vector3(0, (HEIGHT + WIN_TOP) * 0.5, fz), K.mat("concrete"))

	# Painted lower band (dado) on the walls: maintained, not derelict.
	var band_h := 1.05
	for s in [-1, 1]:
		K.box(self, Vector3(0.02, band_h, depth), Vector3(s * (HALF_W - 0.01), band_h * 0.5, mid_z), K.mat("paint_green"), Vector3.ZERO, false)
	K.box(self, Vector3(HALF_W * 2, band_h, 0.02), Vector3(0, band_h * 0.5, FRONT_Z - 0.01), K.mat("paint_green"), Vector3.ZERO, false)
	K.box(self, Vector3(HALF_W * 2, band_h, 0.02), Vector3(0, band_h * 0.5, BACK_Z - 0.01), K.mat("paint_green"), Vector3.ZERO, false)
	# Thin dark stripe capping the band.
	for s in [-1, 1]:
		K.box(self, Vector3(0.025, 0.04, depth), Vector3(s * (HALF_W - 0.012), band_h, mid_z), K.mat("metal_dark"), Vector3.ZERO, false)
	K.box(self, Vector3(HALF_W * 2, 0.04, 0.025), Vector3(0, band_h, FRONT_Z - 0.012), K.mat("metal_dark"), Vector3.ZERO, false)

	# Heavy steel door on the back wall (out of the normal view range,
	# reserved for later scenes).
	K.box(self, Vector3(1.0, 2.05, 0.08), Vector3(1.3, 1.025, BACK_Z - 0.04), K.mat("paint_grey"))
	K.box(self, Vector3(0.06, 0.3, 0.06), Vector3(0.9, 1.05, BACK_Z - 0.11), K.mat("steel"))


func _build_window() -> void:
	var K := BuildKit
	var w := WIN_HALF_W * 2
	var h := WIN_TOP - WIN_BOTTOM
	var cy := (WIN_TOP + WIN_BOTTOM) * 0.5
	var inner_z := FRONT_Z
	var outer_z := FRONT_Z - FRONT_WALL
	# Steel reveal lining the opening through the thick wall.
	K.box(self, Vector3(w, 0.04, FRONT_WALL), Vector3(0, WIN_BOTTOM + 0.02, (inner_z + outer_z) * 0.5), K.mat("metal_dark"))
	K.box(self, Vector3(w, 0.04, FRONT_WALL), Vector3(0, WIN_TOP - 0.02, (inner_z + outer_z) * 0.5), K.mat("metal_dark"))
	for s in [-1, 1]:
		K.box(self, Vector3(0.04, h, FRONT_WALL), Vector3(s * (WIN_HALF_W - 0.02), cy, (inner_z + outer_z) * 0.5), K.mat("metal_dark"))
	# Heavy inner frame with bolts.
	var f := 0.09
	K.box(self, Vector3(w + f * 2, f, 0.06), Vector3(0, WIN_TOP + f * 0.5, inner_z + 0.03), K.mat("paint_grey"))
	K.box(self, Vector3(w + f * 2, f, 0.06), Vector3(0, WIN_BOTTOM - f * 0.5, inner_z + 0.03), K.mat("paint_grey"))
	for s in [-1, 1]:
		K.box(self, Vector3(f, h, 0.06), Vector3(s * (WIN_HALF_W + f * 0.5), cy, inner_z + 0.03), K.mat("paint_grey"))
	var bolt_mat := K.mat("steel")
	for i in range(7):
		var x := lerpf(-WIN_HALF_W - 0.045, WIN_HALF_W + 0.045, i / 6.0)
		K.cyl(self, 0.012, 0.02, Vector3(x, WIN_TOP + 0.045, inner_z + 0.065), bolt_mat, Vector3(90, 0, 0), 6)
		K.cyl(self, 0.012, 0.02, Vector3(x, WIN_BOTTOM - 0.045, inner_z + 0.065), bolt_mat, Vector3(90, 0, 0), 6)
	for i in range(4):
		var y := lerpf(WIN_BOTTOM, WIN_TOP, i / 3.0)
		for s in [-1, 1]:
			K.cyl(self, 0.012, 0.02, Vector3(s * (WIN_HALF_W + 0.045), y, inner_z + 0.065), bolt_mat, Vector3(90, 0, 0), 6)
	# Hazard-striped sill.
	K.box(self, Vector3(w + 0.18, 0.05, 0.22), Vector3(0, WIN_BOTTOM - 0.115, inner_z + 0.1), K.mat("hazard"))
	# Two layers of thick glass, set back into the reveal.
	K.quad(self, Vector2(w, h), Vector3(0, cy, inner_z - 0.12), K.mat("glass"))
	K.quad(self, Vector2(w, h), Vector3(0, cy, outer_z + 0.08), K.mat("glass"))
	# Stencilled plate under the window.
	K.box(self, Vector3(0.5, 0.07, 0.01), Vector3(0, WIN_BOTTOM - 0.2, inner_z + 0.005), K.mat("paint_beige"), Vector3.ZERO, false)
	K.label(self, "OBSERVATION - SHAFT", Vector3(0, WIN_BOTTOM - 0.2, inner_z + 0.012), 0.028)


func _build_shaft() -> void:
	# The visible section of the vertical launch shaft. Its lower part is
	# below the window sill and cannot be seen from the seat.
	var K := BuildKit
	var near_z := FRONT_Z - FRONT_WALL
	var depth := near_z - SHAFT_BACK_Z
	var mid_z := (near_z + SHAFT_BACK_Z) * 0.5
	var bottom := -12.0     # deep enough to hold the whole missile below the sill
	var top := 8.0
	var h := top - bottom
	var cy := (top + bottom) * 0.5
	var concrete := K.mat("concrete")
	K.box(self, Vector3(SHAFT_HALF_W * 2, h, 0.3), Vector3(0, cy, SHAFT_BACK_Z - 0.15), concrete)
	for s in [-1, 1]:
		K.box(self, Vector3(0.3, h, depth), Vector3(s * (SHAFT_HALF_W + 0.15), cy, mid_z), concrete)
	# The shaft top is closed by hatch doors owned by MissileLaunch.
	K.box(self, Vector3(SHAFT_HALF_W * 2, 0.2, depth), Vector3(0, bottom, mid_z), K.mat("metal_dark"))

	# Vertical guide rails on the back wall.
	for s in [-1, 1]:
		K.box(self, Vector3(0.14, h, 0.16), Vector3(s * 0.7, cy, SHAFT_BACK_Z + 0.08), K.mat("metal_dark"))
		K.box(self, Vector3(0.05, h, 0.1), Vector3(s * 0.7, cy, SHAFT_BACK_Z + 0.2), K.mat("steel"))
	# Ring beams at regular intervals.
	for i in range(8):
		var y := -5.0 + i * 1.6
		K.box(self, Vector3(SHAFT_HALF_W * 2, 0.12, 0.12), Vector3(0, y, SHAFT_BACK_Z + 0.06), K.mat("paint_grey"))
	# Cable conduits and a hazard band.
	for x in [-1.3, -1.2, 1.25]:
		K.cyl(self, 0.035, h, Vector3(x, cy, SHAFT_BACK_Z + 0.06), K.mat("cable"), Vector3.ZERO, 6)
	K.box(self, Vector3(SHAFT_HALF_W * 2, 0.25, 0.02), Vector3(0, 2.75, SHAFT_BACK_Z + 0.01), K.mat("hazard"), Vector3.ZERO, false)
	# Stencilled marking on the shaft wall.
	K.label(self, "KEEP CLEAR", Vector3(0, 2.2, SHAFT_BACK_Z + 0.02), 0.16, Color(0.8, 0.76, 0.66), Vector3.ZERO, true)
	# Caged service lamps (warm) and a red beacon.
	for s in [-1, 1]:
		K.box(self, Vector3(0.14, 0.2, 0.08), Vector3(s * 1.35, 3.3, SHAFT_BACK_Z + 0.04), K.mat("metal_dark"))
		K.box(self, Vector3(0.1, 0.12, 0.04), Vector3(s * 1.35, 3.3, SHAFT_BACK_Z + 0.1), K.lamp(Color(1.0, 0.85, 0.6), true, 1.6), Vector3.ZERO, false)
	_shaft_beacon = K.sphere(self, 0.07, Vector3(-1.35, 2.15, SHAFT_BACK_Z + 0.1), K.lamp(BuildKit.RED, false))

	var shaft_light := SpotLight3D.new()
	shaft_light.light_color = Color(0.75, 0.82, 0.9)
	shaft_light.light_energy = 3.0
	shaft_light.spot_range = 12.0
	shaft_light.spot_angle = 40.0
	shaft_light.position = Vector3(0, 7.5, mid_z + 0.4)
	shaft_light.rotation_degrees = Vector3(-90, 0, 0)
	add_child(shaft_light)
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.8, 0.55)
	lamp_light.light_energy = 0.8
	lamp_light.omni_range = 3.0
	lamp_light.position = Vector3(0, 3.1, SHAFT_BACK_Z + 0.6)
	add_child(lamp_light)


func _build_ceiling_details() -> void:
	var K := BuildKit
	# Steel beams across the ceiling.
	for z in [-1.6, 0.0, 1.6]:
		K.box(self, Vector3(HALF_W * 2, 0.22, 0.14), Vector3(0, HEIGHT - 0.11, z), K.mat("paint_grey"))
	# Pipe runs along the ceiling toward the front wall.
	var depth := BACK_Z - FRONT_Z
	var mid_z := (BACK_Z + FRONT_Z) * 0.5
	K.cyl(self, 0.06, depth, Vector3(-1.7, HEIGHT - 0.3, mid_z), K.mat("paint_green"), Vector3(90, 0, 0), 10)
	K.cyl(self, 0.035, depth, Vector3(-1.52, HEIGHT - 0.28, mid_z), K.mat("metal_dark"), Vector3(90, 0, 0), 8)
	K.box(self, Vector3(0.3, 0.16, depth), Vector3(1.75, HEIGHT - 0.32, mid_z), K.mat("paint_grey"))  # air duct
	# Ceiling lamp housing above the desk.
	K.box(self, Vector3(1.2, 0.12, 0.3), Vector3(0, HEIGHT - 0.36, -0.85), K.mat("paint_grey"))
	K.box(self, Vector3(1.1, 0.02, 0.22), Vector3(0, HEIGHT - 0.43, -0.85), K.lamp(Color(1.0, 0.9, 0.72), true, 1.3), Vector3.ZERO, false)
	for s in [-1, 1]:
		K.cyl(self, 0.01, 0.3, Vector3(s * 0.5, HEIGHT - 0.15, -0.85), K.mat("steel"), Vector3.ZERO, 4)


func _build_wall_details() -> void:
	var K := BuildKit
	# Approved Norvak flag, framed on the front wall left of the window.
	var flag := K.pivot(self, Vector3(-1.55, 1.85, FRONT_Z + 0.02))
	K.box(flag, Vector3(0.84, 0.58, 0.03), Vector3.ZERO, K.mat("metal_dark"))
	K.quad(flag, Vector2(0.78, 0.52), Vector3(0, 0, 0.017), K.image("res://assets/flags/flag_norvak.png"))
	# Vertical cable tray on the front wall, right of the window.
	K.box(self, Vector3(0.18, HEIGHT, 0.06), Vector3(1.55, HEIGHT * 0.5, FRONT_Z + 0.03), K.mat("metal_dark"))
	for x in [1.5, 1.56, 1.61]:
		K.cyl(self, 0.016, HEIGHT, Vector3(x, HEIGHT * 0.5, FRONT_Z + 0.08), K.mat("cable"), Vector3.ZERO, 5)
	# Junction box with a warning lamp on the front wall.
	K.box(self, Vector3(0.36, 0.42, 0.12), Vector3(1.55, 1.85, FRONT_Z + 0.09), K.mat("paint_grey"))
	K.label(self, "400V", Vector3(1.55, 1.97, FRONT_Z + 0.152), 0.035, Color(0.1, 0.08, 0.06))
	K.box(self, Vector3(0.16, 0.12, 0.01), Vector3(1.55, 1.78, FRONT_Z + 0.152), K.mat("hazard"), Vector3.ZERO, false)
	# Floor skirting kick-plate along the walls.
	var depth := BACK_Z - FRONT_Z
	var mid_z := (BACK_Z + FRONT_Z) * 0.5
	for s in [-1, 1]:
		K.box(self, Vector3(0.03, 0.12, depth), Vector3(s * (HALF_W - 0.015), 0.06, mid_z), K.mat("metal_dark"), Vector3.ZERO, false)


func _build_lights() -> void:
	# Few lights on purpose: the Compatibility renderer draws an extra pass
	# per light per object, so every light has a small range and a job.
	var key := SpotLight3D.new()                      # ceiling lamp over desk
	_key_light = key
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 2.1
	key.spot_range = 4.5
	key.spot_angle = 58.0
	key.spot_attenuation = 0.8
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.position = Vector3(0, HEIGHT - 0.45, -0.85)
	key.rotation_degrees = Vector3(-72, 0, 0)
	add_child(key)
	_key_energy = key.light_energy

	var fill := OmniLight3D.new()                     # soft cool fill, readability
	fill.light_color = Color(0.62, 0.7, 0.8)
	fill.light_energy = 0.38
	fill.omni_range = 5.5
	fill.position = Vector3(0, 2.3, 1.0)
	add_child(fill)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.38, 0.4)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
