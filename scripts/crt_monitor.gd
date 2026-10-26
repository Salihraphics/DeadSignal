extends Node3D
## A heavy CRT monitor: tapered tube body, thick bezel and a live screen.
## The screen shows a low-resolution SubViewport through the CRT shader.
## Front of the monitor faces local +Z (toward the operator).

const ScreenContent := preload("res://scripts/screen_content.gd")
const CRT_SHADER := preload("res://shaders/crt.gdshader")

@export var screen_size := Vector2(0.3, 0.225)
@export var resolution := Vector2i(256, 192)
@export var content: ScreenContent.Mode = ScreenContent.Mode.CONTROL
@export var case_material := "paint_case"


func _ready() -> void:
	var K := BuildKit
	var bezel := 0.06
	var outer := screen_size + Vector2(bezel, bezel) * 2.0
	var body_depth := outer.x * 0.85
	var case_mat := K.mat(case_material)

	# Front bezel: four thick bars around the screen.
	var fz := 0.0
	K.box(self, Vector3(outer.x, bezel, 0.07), Vector3(0, (screen_size.y + bezel) * 0.5, fz), case_mat)
	K.box(self, Vector3(outer.x, bezel * 1.5, 0.07), Vector3(0, -(screen_size.y + bezel * 1.5) * 0.5, fz), case_mat)
	for s in [-1, 1]:
		K.box(self, Vector3(bezel, screen_size.y, 0.07), Vector3(s * (screen_size.x + bezel) * 0.5, 0, fz), case_mat)
	# Tapered tube housing (a 4-sided cylinder reads as a CRT back).
	var r := outer.x * 0.7
	var tube := K.cyl(self, r, body_depth, Vector3(0, 0.0, -body_depth * 0.5 - 0.035), case_mat,
			Vector3.ZERO, 4, r * 0.45)
	# Square it up around its own axis, squash to the bezel aspect,
	# then point the narrow end backward.
	tube.basis = Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(1, 1, outer.y / outer.x)) * Basis(Vector3.UP, PI / 4)
	# Dark recess behind the glass so the bezel reads as thick.
	K.box(self, Vector3(screen_size.x, screen_size.y, 0.02), Vector3(0, 0, -0.03), K.mat("screen_off"), Vector3.ZERO, false)
	# Control strip under the screen: power lamp and two knobs.
	var strip_y := -(screen_size.y * 0.5 + bezel * 0.75)
	K.cyl(self, 0.008, 0.01, Vector3(outer.x * 0.36, strip_y, fz + 0.04), K.lamp(BuildKit.GREEN, true, 1.5), Vector3(90, 0, 0), 6, -1.0, false)
	for i in range(2):
		K.cyl(self, 0.013, 0.018, Vector3(-outer.x * 0.36 + i * 0.04, strip_y, fz + 0.04), K.mat("bakelite"), Vector3(90, 0, 0), 8)

	# Live screen.
	var vp := SubViewport.new()
	vp.size = resolution
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var drawer := ScreenContent.new()
	drawer.mode = content
	drawer.size = Vector2(resolution)
	vp.add_child(drawer)
	add_child(vp)

	var sm := ShaderMaterial.new()
	sm.shader = CRT_SHADER
	sm.set_shader_parameter("screen_tex", vp.get_texture())
	sm.set_shader_parameter("scanlines", float(resolution.y) * 0.5)
	K.quad(self, screen_size, Vector3(0, 0, -0.015), sm)

	# Tap the monitor to lean in; while focused, taps on the glass are
	# passed to the screen as 0..1 coordinates.
	var zone := Interactable.make(self, Vector3(outer.x, outer.y + bezel, 0.14), Vector3(0, 0, 0.03), "ScreenZone")
	zone.focus_zone = true
	zone.focus_title = drawer.title()
	zone.focus_actions = drawer.actions()
	zone.focus_fov = 50.0
	zone.focus_distance = screen_size.y * 0.8 / tan(deg_to_rad(zone.focus_fov * 0.5)) + 0.03
	zone.poked.connect(func(p: Vector3) -> void:
		drawer.poke(Vector2(p.x / screen_size.x + 0.5, 0.5 - p.y / screen_size.y)))
	zone.action_requested.connect(drawer.do_action)
