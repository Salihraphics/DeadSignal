extends Node3D
## Beer bottles, a cigarette pack and an ashtray at the right corner of the
## main desk. Purely atmospheric: no meters, no bonuses or penalties, no
## effect on orders, outcomes or endings. Each completed beer or cigarette
## is counted once in Run (shown only in the after-action report).
##
## A drink or a smoke counts when its short animation completes; taps
## during the animation are ignored, and an animation cut short (scene
## change, ending) never counts. A second beer in a row gives one very
## slight, brief camera shake (none with reduced motion).

const BOTTLES := 6
const BUTTS_SHOWN := 8
const BURN_S := 28.0

var _bottles: Array[Node3D] = []
var _busy := false
var _glass_full: StandardMaterial3D
var _glass_empty: StandardMaterial3D
var _cig: Node3D
var _ember: MeshInstance3D
var _smoke: CPUParticles3D
var _burn := -1.0
var _butts: Array[Node3D] = []


func _ready() -> void:
	_glass_full = StandardMaterial3D.new()
	_glass_full.albedo_color = Color(0.22, 0.12, 0.04)
	_glass_full.roughness = 0.15
	_glass_full.metallic_specular = 0.8
	_glass_empty = _glass_full.duplicate()
	_glass_empty.albedo_color = Color(0.42, 0.3, 0.16)
	_build_bottles()
	_build_smokes()
	_restore()


# --- Beer -------------------------------------------------------------------------------------

func _build_bottles() -> void:
	var K := BuildKit
	for i in range(BOTTLES):
		var b := K.pivot(self, Vector3(0.0 + (i % 3) * 0.065, 0, -0.14 - (i / 3) * 0.065))
		K.cyl(b, 0.029, 0.15, Vector3(0, 0.075, 0), _glass_full, Vector3.ZERO, 10)
		K.cyl(b, 0.012, 0.07, Vector3(0, 0.185, 0), _glass_full, Vector3.ZERO, 8, 0.029)
		K.cyl(b, 0.0135, 0.012, Vector3(0, 0.226, 0), K.mat("brass"), Vector3.ZERO, 8)     # crown cap
		K.box(b, Vector3(0.046, 0.05, 0.002), Vector3(0, 0.08, 0.029), K.mat("paper_old"), Vector3.ZERO, false)
		b.set_meta("full", true)
		_bottles.append(b)
	var area := Interactable.make(self, Vector3(0.24, 0.3, 0.2), Vector3(0.065, 0.13, -0.17), "Beer")
	area.activated.connect(func(_hit: Vector3) -> void: drink())


func _next_bottle() -> Node3D:
	for b in _bottles:
		if b.get_meta("full"):
			return b
	return null


## Starts a drink. Returns false if busy or nothing left.
func drink() -> bool:
	if _busy:
		return false
	var b := _next_bottle()
	if b == null:
		get_tree().call_group("hud", "toast", "NO BEER LEFT")
		return false
	_busy = true
	Sfx.play("beer_open", -6.0)
	var rest := b.transform
	var cam := get_viewport().get_camera_3d()
	var tw := create_tween()
	if cam:
		# Toward the operator, just below his line of sight, tilted.
		var to_cam := (cam.global_position - b.global_position) * 0.55
		var lifted := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55)), rest.origin + global_basis.inverse() * (to_cam + Vector3(0, 0.1, 0)))
		tw.tween_interval(0.9)
		tw.tween_property(b, "transform", lifted, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(Sfx.play.bind("gulp", -4.0))
		tw.tween_interval(1.3)
		tw.tween_property(b, "transform", rest, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(Sfx.play.bind("bottle_set", -6.0))
	tw.tween_callback(_finish_drink.bind(b))
	return true


func _finish_drink(b: Node3D) -> void:
	_set_empty(b)
	var consecutive := Run.count_vice("beer")
	_busy = false
	if consecutive:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.18, 0.6)        # very slight; skipped with reduced motion
	Dialogue.trigger("beer", {"first": Run.beers == 1, "consecutive": consecutive})


func _set_empty(b: Node3D) -> void:
	b.set_meta("full", false)
	for c in b.get_children():
		if c is MeshInstance3D and c.material_override == _glass_full:
			c.material_override = _glass_empty
	if b.get_child_count() > 2:
		b.get_child(2).visible = false      # cap is gone


# --- Cigarettes ---------------------------------------------------------------------------

func _build_smokes() -> void:
	var K := BuildKit
	# Ashtray.
	var tray := K.pivot(self, Vector3(0.02, 0, 0.03))
	K.cyl(tray, 0.06, 0.018, Vector3(0, 0.009, 0), K.mat("glass"), Vector3.ZERO, 14)
	K.cyl(tray, 0.045, 0.004, Vector3(0, 0.017, 0), K.mat("metal_dark"), Vector3.ZERO, 14)
	for i in range(BUTTS_SHOWN):
		var a := i * TAU / BUTTS_SHOWN
		var butt := K.pivot(tray, Vector3(cos(a) * 0.025, 0.021, sin(a) * 0.025), Vector3(0, rad_to_deg(-a), 90))
		K.cyl(butt, 0.0045, 0.022, Vector3.ZERO, K.mat("paper_old"), Vector3.ZERO, 5)
		butt.visible = false
		_butts.append(butt)
	# The cigarette resting on the ashtray rim while it burns.
	_cig = K.pivot(tray, Vector3(0.04, 0.022, 0), Vector3(0, 0, 80))
	K.cyl(_cig, 0.0045, 0.07, Vector3(0, 0.035, 0), K.mat("paper"), Vector3.ZERO, 6)
	K.cyl(_cig, 0.0047, 0.02, Vector3(0, 0.01, 0), K.mat("paper_old"), Vector3.ZERO, 6)   # filter
	_ember = K.cyl(_cig, 0.0048, 0.005, Vector3(0, 0.071, 0), K.lamp(Color(1.0, 0.35, 0.08), true, 3.0), Vector3.ZERO, 6, -1.0, false)
	_cig.visible = false
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 10
	_smoke.lifetime = 3.0
	_smoke.local_coords = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.03
	_smoke.initial_velocity_max = 0.06
	_smoke.gravity = Vector3(0, 0.01, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.6
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.75, 0.75, 0.78, 0.18)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = sm
	_smoke.mesh = mesh
	_smoke.position = Vector3(0, 0.072, 0)
	_cig.add_child(_smoke)
	# The pack, opened.
	var pack := K.pivot(self, Vector3(0.12, 0, 0.06), Vector3(0, -20, 0))
	K.box(pack, Vector3(0.055, 0.085, 0.022), Vector3(0, 0.0425, 0), K.mat("red_paint"))
	K.box(pack, Vector3(0.056, 0.02, 0.023), Vector3(0, 0.07, 0), K.mat("paper"))
	for i in range(3):
		K.cyl(pack, 0.0045, 0.02, Vector3(-0.012 + i * 0.012, 0.09, 0), K.mat("paper_old"), Vector3.ZERO, 5)
	var area := Interactable.make(self, Vector3(0.22, 0.14, 0.16), Vector3(0.07, 0.05, 0.05), "Cigarettes")
	area.activated.connect(func(_hit: Vector3) -> void: smoke())


## Lights a cigarette. Counts once the lighter has done its work.
func smoke() -> bool:
	if _busy or _burn >= 0.0:
		return false
	_busy = true
	Sfx.play("lighter", -4.0)
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(_lit)
	return true


func _lit() -> void:
	_cig.visible = true
	_cig.scale = Vector3.ONE
	_smoke.emitting = Graphics.active != "LOW"     # no particles on LOW
	_burn = BURN_S
	Sfx.play("inhale", -10.0)
	Run.count_vice("cigarette")
	_busy = false
	Dialogue.trigger("cigarette", {"first": Run.cigarettes == 1})


func _process(delta: float) -> void:
	if _burn < 0.0:
		return
	_burn -= delta
	_cig.scale.y = lerpf(0.45, 1.0, clampf(_burn / BURN_S, 0.0, 1.0))
	_ember.material_override = BuildKit.lamp(Color(1.0, 0.35, 0.08), true, 2.2 + sin(_burn * 3.0))
	if _burn <= 0.0:
		_burn = -1.0
		_cig.visible = false
		_smoke.emitting = false
		_show_butts()


func _show_butts() -> void:
	for i in range(_butts.size()):
		_butts[i].visible = i < Run.cigarettes


## After loading a save: empties and butts as they were.
func _restore() -> void:
	for i in range(mini(Run.beers, BOTTLES)):
		_set_empty(_bottles[i])
	_show_butts()


func is_busy() -> bool:
	return _busy
