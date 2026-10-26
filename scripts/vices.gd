extends Node3D
## Beer bottles, a cigarette pack and an ashtray at the right corner of the
## main desk. Purely atmospheric: no meters, no bonuses or penalties, no
## effect on orders, outcomes or endings. Each completed beer or cigarette
## is counted once in Run (shown only in the after-action report).
##
## First person, no body rig: a sleeve and hand appear for the action and
## carry the object along a path computed every frame from the camera, so
## it reaches the mouth (OperatorCamera.mouth_point) whatever the screen,
## the head turn or the sway. Phases:
##   beer       reach - to the mouth - drink (head tips back) - away - set down
##   cigarette  take - to the mouth - light - inhale - away - exhale - into
##              the ashtray, where it burns down
## Taps during an action are ignored; an action cut short (scene change,
## ending) never counts; nothing here can lock the controls.
## Consecutive beers drive Intoxication (temporary, atmospheric).

const BOTTLES := 6
const BUTTS_SHOWN := 8
const BURN_S := 28.0
const BOTTLE_LEN := 0.232                  # base to the lip of the neck
const CIG_LEN := 0.07

## Phase lengths in seconds.
const BEER_PHASES := {"reach": 0.45, "to_mouth": 0.75, "drink": 1.6, "away": 0.6, "set": 0.45}
const CIG_PHASES := {"take": 0.4, "to_mouth": 0.6, "light": 0.9, "inhale": 1.3, "away": 0.6, "exhale": 1.4, "rest": 0.5}
## Camera-space direction from the bottle's base to its neck while drinking
## (neck in the mouth, base raised and forward).
const DRINK_AXIS := Vector3(0.05, -0.55, 0.83)
## Camera-space direction from the cigarette's filter to its tip at the mouth.
const CIG_AXIS := Vector3(0.18, -0.28, -0.94)
## Where the cigarette is held between draws (camera space, lower right).
const CIG_HOLD := Vector3(0.16, -0.2, -0.32)
## Shoulder in camera space: the sleeve runs from here to the hand.
const SHOULDER := Vector3(0.24, -0.36, 0.06)

var _bottles: Array[Node3D] = []
var _glass_full: StandardMaterial3D
var _glass_empty: StandardMaterial3D
var _cig: Node3D                 # the one resting in the ashtray
var _ember: MeshInstance3D
var _smoke: CPUParticles3D
var _burn := -1.0
var _butts: Array[Node3D] = []
var _pack: Node3D
var _tray: Node3D

# The current action.
var _action := ""                # "", "beer", "cigarette"
var _phase := ""
var _phase_t := 0.0
var _item: Node3D                # bottle or hand cigarette being moved
var _item_rest := Transform3D.IDENTITY
var _hand_cig: Node3D
var _hand_ember: MeshInstance3D
var _flame: MeshInstance3D
var _puff: CPUParticles3D
var _arm: Node3D
var _sleeve: MeshInstance3D
var _hand: MeshInstance3D
var _cam: Camera3D
var _intox: Node
var _from_ashtray := false
## Last pose reached at the mouth (for tests): distance of the neck / filter
## end from the mouth point.
var last_mouth_error := -1.0


func _ready() -> void:
	_glass_full = StandardMaterial3D.new()
	_glass_full.albedo_color = Color(0.22, 0.12, 0.04)
	_glass_full.roughness = 0.15
	_glass_full.metallic_specular = 0.8
	_glass_empty = _glass_full.duplicate()
	_glass_empty.albedo_color = Color(0.42, 0.3, 0.16)
	_build_bottles()
	_build_smokes()
	_build_arm()
	_restore()
	_intox = get_tree().get_first_node_in_group("intoxication")


func is_busy() -> bool:
	return _action != ""


func action() -> String:
	return _action


func phase() -> String:
	return _phase


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


## Starts a drink. Returns false if busy or nothing is left.
func drink() -> bool:
	if is_busy():
		return false
	var b := _next_bottle()
	if b == null:
		get_tree().call_group("hud", "toast", "NO BEER LEFT")
		return false
	_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return false
	_item = b
	_item_rest = b.global_transform
	_start("beer", "reach")
	Sfx.play("bottle_lift", -6.0)
	if _intox:
		_intox.drink_started()
	return true


func _finish_drink() -> void:
	_set_empty(_item)
	_item.global_transform = _item_rest
	var first := Run.beers == 0
	Run.count_vice("beer")
	var consecutive := false
	if _intox:
		consecutive = _intox.drink_finished()
	Dialogue.trigger("beer", {"first": first, "consecutive": consecutive, "third": _intox != null and _intox.streak == 3})


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
	_tray = K.pivot(self, Vector3(0.02, 0, 0.03))
	K.cyl(_tray, 0.06, 0.018, Vector3(0, 0.009, 0), K.mat("glass"), Vector3.ZERO, 14)
	K.cyl(_tray, 0.045, 0.004, Vector3(0, 0.017, 0), K.mat("metal_dark"), Vector3.ZERO, 14)
	for i in range(BUTTS_SHOWN):
		var a := i * TAU / BUTTS_SHOWN
		var butt := K.pivot(_tray, Vector3(cos(a) * 0.025, 0.021, sin(a) * 0.025), Vector3(0, rad_to_deg(-a), 90))
		K.cyl(butt, 0.0045, 0.022, Vector3.ZERO, K.mat("paper_old"), Vector3.ZERO, 5)
		butt.visible = false
		_butts.append(butt)
	# The cigarette resting on the ashtray rim while it burns.
	_cig = K.pivot(_tray, Vector3(0.04, 0.022, 0), Vector3(0, 0, 80))
	_ember = _cigarette_mesh(_cig)
	_cig.visible = false
	_smoke = _smoke_emitter(10, 3.0, Vector2(0.03, 0.03), 0.18)
	_smoke.position = Vector3(0, 0.072, 0)
	_cig.add_child(_smoke)
	# The cigarette in the hand (origin at the filter end, +Y to the tip).
	_hand_cig = K.pivot(self, Vector3.ZERO)
	_hand_ember = _cigarette_mesh(_hand_cig)
	_flame = K.box(_hand_cig, Vector3(0.012, 0.022, 0.012), Vector3(0, 0.085, 0), K.lamp(Color(1.0, 0.7, 0.3), true, 4.0), Vector3.ZERO, false)
	_flame.visible = false
	_hand_cig.visible = false
	# The exhaled puff: one short burst, few particles (cheap on every preset).
	_puff = _smoke_emitter(10, 1.7, Vector2(0.03, 0.03), 0.16)
	_puff.one_shot = true
	_puff.explosiveness = 0.75
	_puff.initial_velocity_min = 0.12
	_puff.initial_velocity_max = 0.2
	_puff.spread = 18.0
	add_child(_puff)
	# The pack, opened.
	_pack = K.pivot(self, Vector3(0.12, 0, 0.06), Vector3(0, -20, 0))
	K.box(_pack, Vector3(0.055, 0.085, 0.022), Vector3(0, 0.0425, 0), K.mat("red_paint"))
	K.box(_pack, Vector3(0.056, 0.02, 0.023), Vector3(0, 0.07, 0), K.mat("paper"))
	for i in range(3):
		K.cyl(_pack, 0.0045, 0.02, Vector3(-0.012 + i * 0.012, 0.09, 0), K.mat("paper_old"), Vector3.ZERO, 5)
	var area := Interactable.make(self, Vector3(0.22, 0.14, 0.16), Vector3(0.07, 0.05, 0.05), "Cigarettes")
	area.activated.connect(func(_hit: Vector3) -> void: smoke())


func _cigarette_mesh(parent: Node3D) -> MeshInstance3D:
	var K := BuildKit
	K.cyl(parent, 0.0045, CIG_LEN - 0.02, Vector3(0, 0.02 + (CIG_LEN - 0.02) * 0.5, 0), K.mat("paper"), Vector3.ZERO, 6)
	K.cyl(parent, 0.0047, 0.02, Vector3(0, 0.01, 0), K.mat("paper_old"), Vector3.ZERO, 6)        # filter
	return K.cyl(parent, 0.0048, 0.005, Vector3(0, CIG_LEN + 0.001, 0), K.lamp(Color(1.0, 0.35, 0.08), true, 3.0), Vector3.ZERO, 6, -1.0, false)


## A small soft round sprite for smoke (shared, made once).
static var _dot: Texture2D

static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_dot = t
	return _dot


func _smoke_emitter(amount: int, life: float, size: Vector2, alpha: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.06
	p.gravity = Vector3(0, 0.01, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.damping_min = 0.05
	p.damping_max = 0.12
	var mesh := QuadMesh.new()
	mesh.size = size
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.75, 0.75, 0.78, alpha)
	sm.albedo_texture = _soft_dot()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = sm
	p.mesh = mesh
	return p


## Takes a fresh cigarette (or the one burning in the ashtray) for a smoke.
## No fixed limit; each completed smoke counts once.
func smoke() -> bool:
	if is_busy():
		return false
	_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return false
	_from_ashtray = _burn >= 0.0
	var from := _cig if _from_ashtray else _pack
	_item = _hand_cig
	_item_rest = from.global_transform
	if _from_ashtray:
		_cig.visible = false
		_smoke.emitting = false
		_burn = -1.0
	_hand_cig.global_transform = _item_rest
	_hand_cig.visible = true
	_hand_ember.visible = _from_ashtray
	_start("cigarette", "take")
	return true


func _finish_smoke() -> void:
	_hand_cig.visible = false
	_cig.visible = true
	_cig.scale = Vector3.ONE
	_smoke.emitting = Graphics.active != "LOW"     # the idle trail is off on LOW
	_burn = BURN_S
	var first := Run.cigarettes == 0
	Run.count_vice("cigarette")
	Dialogue.trigger("cigarette", {"first": first})


func _show_butts() -> void:
	for i in range(_butts.size()):
		_butts[i].visible = i < Run.cigarettes


# --- The arm --------------------------------------------------------------------------------

func _build_arm() -> void:
	var K := BuildKit
	_arm = K.pivot(self, Vector3.ZERO)
	var wool := StandardMaterial3D.new()
	wool.albedo_color = Color(0.2, 0.22, 0.16)
	wool.roughness = 1.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.66, 0.5, 0.41)
	skin.roughness = 0.8
	_sleeve = K.cyl(_arm, 0.042, 1.0, Vector3.ZERO, wool, Vector3.ZERO, 8, 0.036)
	_hand = K.box(_arm, Vector3(0.05, 0.085, 0.045), Vector3.ZERO, skin)
	for m in [_sleeve, _hand]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm.visible = false


## Hand at `grip` holding along `axis`; sleeve from the shoulder to the wrist.
func _pose_arm(grip: Vector3, axis: Vector3) -> void:
	var shoulder := _cam.global_transform * SHOULDER
	var wrist := grip + (shoulder - grip).normalized() * 0.05
	_hand.global_transform = Transform3D(_basis_along(axis), grip)
	var d := wrist - shoulder
	var b := _basis_along(d)
	b.y *= d.length()                     # stretch along the arm (local Y)
	_sleeve.global_transform = Transform3D(b, (shoulder + wrist) * 0.5)


static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))


# --- Action runner -------------------------------------------------------------------------

func _start(kind: String, first_phase: String) -> void:
	_action = kind
	_phase = first_phase
	_phase_t = 0.0
	_arm.visible = true


func _phases() -> Dictionary:
	return BEER_PHASES if _action == "beer" else CIG_PHASES


func _next_phase() -> void:
	var keys: Array = _phases().keys()
	var i := keys.find(_phase)
	_phase_t = 0.0
	if i + 1 >= keys.size():
		_end()
		return
	_phase = keys[i + 1]
	_on_phase_start(_phase)


func _on_phase_start(p: String) -> void:
	match [_action, p]:
		["beer", "drink"]:
			if not _item.get_meta("opened", false):
				_item.set_meta("opened", true)
				Sfx.play("beer_open", -8.0)
			Sfx.play("gulp", -4.0)
			_tilt(Vector3(14.0, 0, 0), 0.4)
		["beer", "away"]:
			_tilt(Vector3.ZERO, 0.5)
		["beer", "set"]:
			Sfx.play("bottle_set", -6.0)
		["cigarette", "light"]:
			if not _from_ashtray:
				Sfx.play("lighter", -4.0)
				_flame.visible = true
		["cigarette", "inhale"]:
			_flame.visible = false
			_hand_ember.visible = true
			Sfx.play("inhale", -8.0)
		["cigarette", "exhale"]:
			Sfx.play("exhale", -8.0)
			# Just ahead of the mouth, drifting out and up into view.
			_puff.global_position = _cam.global_transform * Vector3(0.0, -0.07, -0.14)
			_puff.direction = _cam.global_basis * Vector3(0.2, 0.25, -1.0)
			_puff.emitting = true


## Head movement while drinking (a smaller nod with reduced motion).
func _tilt(to: Vector3, sec: float) -> void:
	if _cam and "action_tilt" in _cam:
		var k := 0.4 if Settings.reduced_motion else 1.0
		create_tween().tween_property(_cam, "action_tilt", to * k, sec).set_trans(Tween.TRANS_SINE)


func _end() -> void:
	var kind := _action
	_action = ""
	_phase = ""
	_arm.visible = false
	if _cam and "action_tilt" in _cam:
		_cam.action_tilt = Vector3.ZERO
	if kind == "beer":
		_finish_drink()
	else:
		_finish_smoke()


func _process(delta: float) -> void:
	if _burn >= 0.0:
		_burn -= delta
		_cig.scale.y = lerpf(0.45, 1.0, clampf(_burn / BURN_S, 0.0, 1.0))
		BuildKit.set_mat(_ember, BuildKit.lamp(Color(1.0, 0.35, 0.08), true, 2.2 + sin(_burn * 3.0)))
		if _burn <= 0.0:
			_burn = -1.0
			_cig.visible = false
			_smoke.emitting = false
			_show_butts()
	if _action == "":
		return
	if not is_instance_valid(_cam):
		_abort()
		return
	_phase_t += delta
	var dur: float = _phases()[_phase]
	var f := clampf(_phase_t / dur, 0.0, 1.0)
	var e := f * f * (3.0 - 2.0 * f)
	if _action == "beer":
		_animate_beer(e)
	else:
		_animate_cigarette(e)
	if f >= 1.0:
		_next_phase()


## Bottle pose with its neck lip in the mouth.
func _beer_mouth_pose() -> Transform3D:
	var mouth: Vector3 = _cam.mouth_point()
	var axis := (_cam.global_basis * DRINK_AXIS).normalized()
	return Transform3D(_basis_along(axis), mouth - axis * BOTTLE_LEN)


func _animate_beer(e: float) -> void:
	var lifted := _item_rest.translated(Vector3(0, 0.07, 0))
	var mouth := _beer_mouth_pose()
	var t := _item.global_transform
	match _phase:
		"reach":
			t = _item_rest.interpolate_with(lifted, e)
		"to_mouth":
			t = lifted.interpolate_with(mouth, e)
			t.origin += Vector3(0, sin(e * PI) * 0.05, 0)      # a slight arc
		"drink":
			t = mouth
			last_mouth_error = (t * Vector3(0, BOTTLE_LEN, 0)).distance_to(_cam.mouth_point())
		"away":
			t = mouth.interpolate_with(lifted, e)
		"set":
			t = lifted.interpolate_with(_item_rest, e)
	_item.global_transform = t
	_pose_arm(t * Vector3(0, 0.08, 0), t.basis.y)


func _animate_cigarette(e: float) -> void:
	var mouth: Vector3 = _cam.mouth_point()
	var axis := (_cam.global_basis * CIG_AXIS).normalized()
	var at_mouth := Transform3D(_basis_along(axis), mouth)
	var hold := Transform3D(_basis_along(_cam.global_basis * Vector3(0.1, 0.3, -0.95)), _cam.global_transform * CIG_HOLD)
	var lifted := _item_rest.translated(Vector3(0, 0.06, 0))
	var t := _item.global_transform
	match _phase:
		"take":
			t = _item_rest.interpolate_with(lifted, e)
		"to_mouth":
			t = lifted.interpolate_with(at_mouth, e)
		"light", "inhale":
			t = at_mouth
			last_mouth_error = t.origin.distance_to(_cam.mouth_point())
			if _phase == "inhale":
				BuildKit.set_mat(_hand_ember, BuildKit.lamp(Color(1.0, 0.35, 0.08), true, 3.0 + 3.0 * sin(e * PI)))
		"away":
			t = at_mouth.interpolate_with(hold, e)
		"exhale":
			t = hold
		"rest":
			var tray := _cig.global_transform
			t = hold.interpolate_with(tray, e)
	_item.global_transform = t
	_pose_arm(t * Vector3(0, 0.03, 0), t.basis.y)


## The camera went away mid-action (scene change): drop it, count nothing.
func _abort() -> void:
	_action = ""
	_phase = ""
	_arm.visible = false
	if _item and _item != _hand_cig:
		_item.global_transform = _item_rest
	_hand_cig.visible = false
	if _intox:
		_intox.drink_cancelled()


## After loading a save: empties and butts as they were.
func _restore() -> void:
	for i in range(mini(Run.beers, BOTTLES)):
		_set_empty(_bottles[i])
	_show_butts()
