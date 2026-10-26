extends Node3D
## "Norvak survives": years later, the former operator on a park bench.
## Seen from behind, no dialogue, wind and birds. About 25 seconds, then
## the after-action report. Tap twice (or back) to continue early.

const LENGTH := 26.0

var t := 0.0
var _cam: Camera3D
var _fade: ColorRect
var _done := false
var _taps := 0


func _ready() -> void:
	name = "Epilogue"
	_build()
	var ui := CanvasLayer.new()
	add_child(ui)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_taps += 1
			if _taps >= 2:
				_finish())
	ui.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 3.0)
	Sfx.loop("park", -10.0, "SFX", 3.0)


func _process(delta: float) -> void:
	t += delta
	# A very slow drift toward the bench.
	var p := Vector3(0.6, 1.45, 5.2).lerp(Vector3(0.45, 1.35, 4.2), smoothstep(0.0, LENGTH, t))
	_cam.look_at_from_position(p, Vector3(0.0, 0.9, 0.0), Vector3.UP)
	if t > LENGTH - 3.0 and _fade.color.a < 0.01:
		create_tween().tween_property(_fade, "color:a", 1.0, 2.8)
	if t > LENGTH:
		_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.stop_all_loops(1.0)
	get_tree().change_scene_to_file("res://scenes/after_action.tscn")


func _build() -> void:
	var K := BuildKit
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.32, 0.4, 0.24)
	grass.roughness = 1.0
	var path := StandardMaterial3D.new()
	path.albedo_color = Color(0.55, 0.52, 0.46)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.25, 0.2, 0.16)
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.36, 0.42, 0.22)
	leaves.roughness = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.3, 0.2)
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.22, 0.22, 0.24)
	K.box(self, Vector3(40, 0.1, 40), Vector3(0, -0.05, 0), grass)
	K.box(self, Vector3(40, 0.02, 1.6), Vector3(0, 0.01, -1.2), path)
	# Bench.
	var b := K.pivot(self, Vector3.ZERO)
	for i in range(3):
		K.box(b, Vector3(1.6, 0.04, 0.1), Vector3(0, 0.45, -0.12 + i * 0.12), wood)
	for i in range(2):
		K.box(b, Vector3(1.6, 0.1, 0.03), Vector3(0, 0.62 + i * 0.14, 0.2), wood, Vector3(-10, 0, 0))
	for x in [-0.7, 0.7]:
		K.box(b, Vector3(0.05, 0.45, 0.4), Vector3(x, 0.225, 0.02), K.mat("metal_dark"))
	# The old man, seen from behind: coat, cap, hands in his lap.
	var m := K.pivot(self, Vector3(-0.25, 0, -0.02))
	K.cyl(m, 0.2, 0.55, Vector3(0, 0.78, 0.05), coat, Vector3(-6, 0, 0), 12, 0.23)
	K.box(m, Vector3(0.44, 0.1, 0.22), Vector3(0, 1.05, 0.06), coat)
	K.sphere(m, 0.1, Vector3(0, 1.2, 0.04), K.mat("paint_beige"))
	K.cyl(m, 0.11, 0.06, Vector3(0, 1.28, 0.04), coat, Vector3.ZERO, 10, 0.1)
	for x in [-0.09, 0.09]:
		K.box(m, Vector3(0.12, 0.12, 0.42), Vector3(x, 0.5, -0.16), coat)
		K.box(m, Vector3(0.11, 0.45, 0.12), Vector3(x, 0.23, -0.36), coat)
	# A folded newspaper beside him.
	K.box(self, Vector3(0.3, 0.02, 0.2), Vector3(0.35, 0.48, -0.02), K.mat("paper"), Vector3(0, 15, 0))
	# Trees.
	for p in [Vector3(-3, 0, -4), Vector3(2.5, 0, -5), Vector3(5, 0, -2), Vector3(-6, 0, -1), Vector3(0.5, 0, -8)]:
		K.cyl(self, 0.16, 3.0, p + Vector3(0, 1.5, 0), bark, Vector3.ZERO, 8)
		K.sphere(self, 1.4, p + Vector3(0, 3.6, 0), leaves)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.shadow_enabled = Graphics.active != "LOW"
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.76, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.76, 0.78)
	env.fog_density = 0.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
