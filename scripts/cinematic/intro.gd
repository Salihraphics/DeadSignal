extends Node3D
## Opening cinematic (about 85 s): a dim briefing room, an officer seen
## from behind at a whiteboard of the three enemy fronts, a teleprinter
## report he quietly sets aside, radio traffic that contradicts him. Then
## black, and the operator is alone at Launch Control Post K-4.
##
## Everything happens on one data timeline (TIMELINE / LINES) so recorded
## voice lines can be dropped in later without touching the code: a line
## plays res://assets/audio/voice/ru/<id>.ogg when it exists and always
## shows its English subtitle (forced while the recording is missing).
## Skippable: two taps on SKIP, or the Android back gesture.
##
## Kept light: two lights (shadows only above LOW), no particles, no
## post effects; the board is plain meshes and Label3D text.

const OFFICER := "OFFICER"
const RADIO := "RADIO"
const VOICE_DIR := "res://assets/audio/voice/ru/"
const END_T := 86.0
const BOARD_Z := -2.45
const BOARD_Y := 1.6               # board centre height
const INK := Color(0.08, 0.1, 0.2)
const RED_INK := Color(0.6, 0.08, 0.06)
const PENCIL := Color(0.15, 0.15, 0.15)

## Spoken lines: [time, speaker, english subtitle, voice id].
const LINES := [
	[13.0, OFFICER, "Sit. This will be short.", "intro_officer_01"],
	[19.0, OFFICER, "Three fronts. Three enemies. One picture.", "intro_officer_02"],
	[25.5, OFFICER, "Dravonya. The eastern land front holds along the Lesna. Positions unchanged.", "intro_officer_03"],
	[32.5, OFFICER, "Ostrev. Their mountain works run through the night. Rail traffic toward the passes. We are watching it.", "intro_officer_04"],
	[40.0, OFFICER, "Merovia. Ports active, coastal patrols reinforced. Nothing we did not expect.", "intro_officer_05"],
	[47.5, OFFICER, "All three fronts are under control.", "intro_officer_06"],
	[57.5, OFFICER, "...As I said. Under control.", "intro_officer_07"],
	[60.5, RADIO, "...Karsen sector, no contact with K-2 since twenty-two hundred. Repeat, no contact...", "intro_radio_01"],
	[66.5, OFFICER, "Your post is K-4. Orders arrive by teleprinter. You confirm them.", "intro_officer_08"],
	[72.5, OFFICER, "Questions are forwarded to Central.", "intro_officer_09"],
	[77.0, OFFICER, "Dismissed.", "intro_officer_10"],
]

## Camera keys: [time, position, look-at point, fov]. Eased between keys.
const SHOTS := [
	[0.0, Vector3(0.0, 1.25, 3.3), Vector3(0.0, 1.45, -2.4), 55.0],
	[9.0, Vector3(0.0, 1.25, 3.3), Vector3(0.0, 1.45, -2.4), 55.0],
	[22.0, Vector3(0.15, 1.3, 2.3), Vector3(0.0, 1.5, -2.4), 52.0],
	[27.0, Vector3(-0.55, 1.35, 1.1), Vector3(-1.2, 1.55, BOARD_Z), 50.0],
	[31.0, Vector3(-0.5, 1.35, 1.0), Vector3(-1.15, 1.55, BOARD_Z), 49.0],
	[34.0, Vector3(0.0, 1.35, 1.0), Vector3(0.0, 1.55, BOARD_Z), 50.0],
	[38.5, Vector3(0.05, 1.35, 0.95), Vector3(0.05, 1.55, BOARD_Z), 49.0],
	[41.5, Vector3(0.55, 1.35, 1.1), Vector3(1.2, 1.55, BOARD_Z), 50.0],
	[45.5, Vector3(0.5, 1.35, 1.0), Vector3(1.15, 1.55, BOARD_Z), 49.0],
	[49.0, Vector3(0.1, 1.35, 1.4), Vector3(1.5, 1.0, -1.2), 50.0],
	[58.0, Vector3(0.2, 1.35, 1.2), Vector3(1.55, 1.05, -1.2), 47.0],
	[63.0, Vector3(0.3, 1.32, 1.25), Vector3(1.75, 0.95, -0.85), 47.0],
	[69.0, Vector3(0.0, 1.3, 2.4), Vector3(0.0, 1.5, -2.4), 54.0],
	[80.0, Vector3(0.0, 1.32, 1.6), Vector3(0.0, 1.58, -2.4), 50.0],
	[END_T, Vector3(0.0, 1.32, 1.5), Vector3(0.0, 1.58, -2.4), 50.0],
]

var t := 0.0
var _events: Array = []
var _next := 0
var _cam: Camera3D
var _fade: ColorRect
var _caption: Label
var _skip: Button
var _skip_armed := 0.0
var _done := false
var _officer: Node3D
var _arm: Node3D
var _sheet: Node3D
var _tube: SpotLight3D
var _tube_mesh: MeshInstance3D
var _tube_energy := 0.85
var _flicker := 0.0
var _radio_lamp: MeshInstance3D


func _ready() -> void:
	name = "Intro"
	_build_room()
	_build_board()
	_build_officer()
	_build_table()
	_build_ui()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_apply_camera(0.0)
	_schedule()
	Sfx.stop_all_loops()
	Subtitles.clear()
	Subtitles.bottom_margin = 34.0
	Sfx.loop("generator_hum", -14.0, "SFX", 3.0)


func _schedule() -> void:
	for l in LINES:
		_at(l[0], _say.bind(l[1], l[2], l[3]))
	_at(1.5, Sfx.loop.bind("static_loop", -30.0, "SFX", 3.0))
	_at(3.5, Sfx.play.bind("printer", -16.0))                 # off-screen, unseen
	_at(7.0, _fade_to.bind(0.0, 4.0))
	_at(7.0, Sfx.loop.bind("fluorescent", -24.0, "SFX", 2.0))
	_at(11.0, _flick.bind(0.5))
	_at(24.0, _point.bind(-1.2))
	_at(31.5, _point.bind(0.0))
	_at(39.0, _point.bind(1.2))
	_at(44.0, _point.bind(-99.0))                            # arm down
	_at(45.5, _printer_runs)
	_at(49.5, _walk_to.bind(Vector3(1.15, 0, -1.25), -60.0, 3.2))
	_at(53.0, _take_sheet)
	_at(56.0, _set_sheet_aside)
	_at(60.0, _radio_traffic)
	_at(63.5, _radio_down)
	_at(65.5, _walk_to.bind(Vector3(-1.78, 0, -1.9), 0.0, 3.2))
	_at(71.0, _flick.bind(0.7))
	_at(79.5, _fade_to.bind(1.0, 2.5))
	_at(80.0, Sfx.stop_loop.bind("fluorescent", 2.0))
	_at(80.0, Sfx.stop_loop.bind("static_loop", 2.0))
	_at(82.0, Sfx.play.bind("footsteps", -6.0))
	_at(83.0, _show_caption.bind("LAUNCH CONTROL POST K-4\n0540"))
	_at(84.5, Sfx.play.bind("door_heavy", -4.0))
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _at(time: float, f: Callable) -> void:
	_events.append([time, f])


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	while _next < _events.size() and _events[_next][0] <= t:
		(_events[_next][1] as Callable).call()
		_next += 1
	_apply_camera(t)
	if _flicker > 0.0:
		_flicker -= delta
		var on := sin(t * 47.0) * sin(t * 13.0) > -0.2
		_tube.light_energy = _tube_energy * (1.0 if on else 0.35)
		if _flicker <= 0.0:
			_tube.light_energy = _tube_energy
	if _skip_armed > 0.0:
		_skip_armed -= delta
		if _skip_armed <= 0.0:
			_skip.text = "SKIP  >>"
	if t >= END_T + 1.5:
		_finish()


# --- Timeline actions -------------------------------------------------------------------

func _say(speaker: String, text: String, voice_id: String) -> void:
	Subtitles.clear()                    # the timeline sets the pace, not a queue
	var length := Sfx.voice(VOICE_DIR + voice_id + ".ogg")
	Subtitles.say(speaker, text, length + 0.5 if length > 0.0 else 0.0, length < 0.0)


func _fade_to(alpha: float, sec: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, sec)


func _flick(sec: float) -> void:
	if not Settings.reduced_motion:
		_flicker = sec


## Pointer toward a board section (x), or lowered (x = -99).
func _point(x: float) -> void:
	var tw := create_tween().set_parallel()
	if x < -50.0:
		tw.tween_property(_arm, "rotation_degrees", Vector3(8, 0, 6), 1.0).set_trans(Tween.TRANS_SINE)
		return
	var yaw := clampf(-(x - _officer.position.x) * 14.0, -45.0, 45.0)
	tw.tween_property(_arm, "rotation_degrees", Vector3(-100, yaw, 0), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_officer, "rotation_degrees:y", 180.0 + yaw * 0.4, 1.2).set_trans(Tween.TRANS_SINE)


func _printer_runs() -> void:
	Sfx.play("printer", -6.0)
	var tw := create_tween()
	for i in range(6):
		tw.tween_property(_sheet, "position:y", 0.2 + (i + 1) * 0.022, 0.18)
		tw.tween_interval(0.25)


func _walk_to(target: Vector3, facing: float, sec: float) -> void:
	Sfx.play("footsteps", -12.0)
	_point(-99.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_officer, "position", target, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_officer, "rotation_degrees:y", 180.0 + facing, sec * 0.6)
	# A small walking bob on the body.
	var body: Node3D = _officer.get_child(0)
	var bob := create_tween().set_loops(int(sec / 0.5))
	bob.tween_property(body, "position:y", 0.02, 0.25)
	bob.tween_property(body, "position:y", 0.0, 0.25)


## Tears off the report and reads it.
func _take_sheet() -> void:
	Sfx.play("paper", -4.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_sheet, "position", Vector3(-0.32, 0.55, 0.12), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sheet, "rotation_degrees", Vector3(-70, 50, 0), 0.8)
	tw.tween_property(_arm, "rotation_degrees", Vector3(-55, 30, 0), 0.8)


## Folds it and lays it face down, away from the board. No comment.
func _set_sheet_aside() -> void:
	Sfx.play("paper", -8.0, 0.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(_sheet, "position", Vector3(0.28, 0.052, 0.12), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sheet, "rotation_degrees", Vector3(90, 15, 0), 0.9)
	tw.tween_property(_sheet, "scale", Vector3(1, 0.5, 1), 0.9)
	tw.tween_property(_arm, "rotation_degrees", Vector3(8, 0, 6), 1.0).set_delay(0.6)


func _radio_traffic() -> void:
	Sfx.play("radio_burst", -2.0)
	Sfx.loop("static_loop", -16.0, "SFX", 0.3)
	_radio_lamp.material_override = BuildKit.lamp(BuildKit.GREEN, true, 3.0)


## He turns the volume down without looking at it.
func _radio_down() -> void:
	Sfx.play("switch_click", -6.0)
	Sfx.loop("static_loop", -34.0, "SFX", 0.8)
	_radio_lamp.material_override = BuildKit.lamp(BuildKit.GREEN, false)
	var tw := create_tween()
	tw.tween_property(_arm, "rotation_degrees", Vector3(-40, -20, 0), 0.5)
	tw.tween_property(_arm, "rotation_degrees", Vector3(8, 0, 6), 0.7)


func _show_caption(text: String) -> void:
	_caption.text = text
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.8)
	Sfx.play("typewriter", -10.0)


# --- Skip / finish ---------------------------------------------------------------------

func skip() -> void:
	_finish()


func _on_skip() -> void:
	if _skip_armed > 0.0:
		_finish()
		return
	_skip_armed = 2.5
	_skip.text = "TAP AGAIN TO SKIP"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_skip()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_skip()


func _finish() -> void:
	if _done:
		return
	_done = true
	Subtitles.clear()
	Subtitles.bottom_margin = 104.0
	Sfx.stop_voice()
	Sfx.stop_all_loops(0.4)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Camera ------------------------------------------------------------------------------

func _apply_camera(time: float) -> void:
	var i := 0
	while i < SHOTS.size() - 2 and SHOTS[i + 1][0] <= time:
		i += 1
	var a: Array = SHOTS[i]
	var b: Array = SHOTS[i + 1]
	var f := smoothstep(0.0, 1.0, clampf((time - a[0]) / maxf(b[0] - a[0], 0.001), 0.0, 1.0))
	var pos: Vector3 = (a[1] as Vector3).lerp(b[1], f)
	var look: Vector3 = (a[2] as Vector3).lerp(b[2], f)
	_cam.fov = lerpf(a[3], b[3], f)
	_cam.look_at_from_position(pos, look, Vector3.UP)


# --- Set building --------------------------------------------------------------------------

func _build_room() -> void:
	var K := BuildKit
	var w := 3.0
	var back := 3.8
	var h := 2.7
	K.box(self, Vector3(w * 2, 0.1, back - BOARD_Z + 0.4), Vector3(0, -0.05, (back + BOARD_Z) * 0.5), K.mat("floor"))
	K.box(self, Vector3(w * 2, 0.1, back - BOARD_Z + 0.4), Vector3(0, h + 0.05, (back + BOARD_Z) * 0.5), K.mat("concrete"))
	K.box(self, Vector3(w * 2, h, 0.2), Vector3(0, h * 0.5, BOARD_Z - 0.15), K.mat("concrete"))
	for s in [-1, 1]:
		K.box(self, Vector3(0.2, h, back - BOARD_Z), Vector3(s * w, h * 0.5, (back + BOARD_Z) * 0.5), K.mat("concrete"))
	K.box(self, Vector3(w * 2, h, 0.2), Vector3(0, h * 0.5, back), K.mat("concrete"))
	K.box(self, Vector3(w * 2, 1.0, 0.02), Vector3(0, 0.5, BOARD_Z - 0.04), K.mat("paint_green"), Vector3.ZERO, false)
	# Rows of empty chairs: the briefing has an audience of one.
	for row in range(2):
		for i in range(4):
			var x := -1.35 + i * 0.9
			if row == 1 and absf(x - 0.0) < 0.5:
				continue
			_chair(Vector3(x, 0, 1.3 + row * 1.0))
	# Fluorescent fitting over the board and the teleprinter table.
	var fit := K.pivot(self, Vector3(0.3, h - 0.08, -1.2))
	K.box(fit, Vector3(1.4, 0.06, 0.18), Vector3.ZERO, K.mat("paint_grey"))
	_tube_mesh = K.box(fit, Vector3(1.3, 0.025, 0.06), Vector3(0, -0.04, 0), K.lamp(Color(0.85, 0.95, 1.0), true, 1.2), Vector3.ZERO, false)
	_tube = SpotLight3D.new()
	_tube.light_color = Color(0.82, 0.92, 1.0)
	_tube.light_energy = _tube_energy
	_tube.spot_range = 5.0
	_tube.spot_angle = 62.0
	_tube.spot_attenuation = 0.9
	_tube.shadow_enabled = Graphics.active != "LOW"
	_tube.position = Vector3(0, -0.06, 0)
	_tube.rotation_degrees = Vector3(-42, 0, 0)          # onto the board
	fit.add_child(_tube)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.5, 0.55, 0.65)
	fill.light_energy = 0.25
	fill.omni_range = 6.0
	fill.position = Vector3(0, 2.0, 2.5)
	add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)


func _chair(pos: Vector3) -> void:
	var K := BuildKit
	var c := K.pivot(self, pos, Vector3(0, 180, 0))
	K.box(c, Vector3(0.44, 0.04, 0.42), Vector3(0, 0.45, 0), K.mat("paint_grey"))
	K.box(c, Vector3(0.44, 0.42, 0.04), Vector3(0, 0.68, 0.2), K.mat("paint_grey"))
	for x in [-0.2, 0.2]:
		for z in [-0.18, 0.18]:
			K.cyl(c, 0.015, 0.45, Vector3(x, 0.225, z), K.mat("steel"), Vector3.ZERO, 5)


## Whiteboard: three equal sections, one per enemy front, each with its
## flag, a hand-drawn sketch map and pinned reports. Norvak's flag is a
## small pin at the top edge, smaller than any enemy flag.
func _build_board() -> void:
	var K := BuildKit
	var b := K.pivot(self, Vector3(0, BOARD_Y, BOARD_Z + 0.06))
	K.box(b, Vector3(3.9, 1.62, 0.04), Vector3(0, 0, -0.02), K.mat("steel"))
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.6, 0.61, 0.58)
	board.roughness = 0.55
	K.box(b, Vector3(3.8, 1.52, 0.01), Vector3(0, 0, 0.005), board, Vector3.ZERO, false)
	K.box(b, Vector3(3.9, 0.05, 0.1), Vector3(0, -0.83, 0.04), K.mat("steel"))     # marker tray
	for x in [-0.633, 0.633]:
		_stroke(b, Vector2(x, -0.72), Vector2(x, 0.72), INK, 0.008)
	var flags := ["dravonya", "ostrev", "merovia"]
	var titles := ["DRAVONYA\nEASTERN LAND FRONT", "OSTREV\nMOUNTAINS / INDUSTRY / RAIL", "MEROVIA\nCOAST / PORTS / NAVAL"]
	for i in range(3):
		var cx := (i - 1) * 1.266
		var s := K.pivot(b, Vector3(cx, 0, 0.012))
		K.quad(s, Vector2(0.33, 0.22), Vector3(-0.42, 0.57, 0.001), K.image("res://assets/flags/flag_%s.png" % flags[i]))
		var title := K.label(s, titles[i], Vector3(-0.22, 0.6, 0.002), 0.042, INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		match i:
			0: _sketch_dravonya(s)
			1: _sketch_ostrev(s)
			2: _sketch_merovia(s)
	# Norvak: a small pinned flag, deliberately less prominent.
	K.quad(b, Vector2(0.15, 0.1), Vector3(1.78, 0.69, 0.014), K.image("res://assets/flags/flag_norvak.png"))
	K.label(b, "K-4", Vector3(1.78, 0.6, 0.014), 0.022, PENCIL)


func _sketch_dravonya(s: Node3D) -> void:
	# River Lesna, the front line as a zigzag, the Karsen salient.
	_polyline(s, [Vector2(-0.55, 0.38), Vector2(-0.35, 0.2), Vector2(-0.2, 0.22), Vector2(0.0, 0.05), Vector2(0.1, -0.2), Vector2(0.05, -0.5)], Color(0.1, 0.25, 0.6), 0.008)
	_polyline(s, [Vector2(0.45, 0.4), Vector2(0.3, 0.25), Vector2(0.38, 0.1), Vector2(0.15, 0.02), Vector2(0.3, -0.15), Vector2(0.25, -0.5)], RED_INK, 0.012)
	BuildKit.label(s, "KARSEN", Vector3(-0.22, 0.1, 0.002), 0.04, INK)
	BuildKit.label(s, "K-2 ?", Vector3(0.2, -0.05, 0.002), 0.05, RED_INK)
	_report(s, Vector2(-0.38, -0.28), "FIELD RPT FR-2207\n2250 PREV DAY\nLINE HOLDING", 3.0)
	_report(s, Vector2(-0.12, -0.42), "STATUS: CONTROLLED\nSRC: CENTRAL\n(NO NEW FIELD RPT)", -2.0)
	_report(s, Vector2(0.42, -0.3), "14 TK DIV AT RS-27\nSINGLE SOURCE", 4.0)
	_report(s, Vector2(0.44, -0.55), "RS-27: NO ACTIVITY\nOBSERVED (OP K1)", -5.0)
	_stroke(s, Vector2(0.32, -0.36), Vector2(0.52, -0.5), RED_INK, 0.006)      # the two disagree


func _sketch_ostrev(s: Node3D) -> void:
	# Mountain chain, a rail line through a pass, works chimneys.
	for i in range(5):
		var x := -0.5 + i * 0.2
		_polyline(s, [Vector2(x - 0.08, 0.15), Vector2(x, 0.32), Vector2(x + 0.08, 0.15)], PENCIL, 0.007)
	var rail := [Vector2(-0.55, -0.1), Vector2(-0.2, -0.05), Vector2(0.05, 0.12), Vector2(0.3, 0.05), Vector2(0.55, 0.1)]
	_polyline(s, rail, INK, 0.006)
	for i in range(rail.size() - 1):
		var a: Vector2 = rail[i]
		var c: Vector2 = rail[i + 1]
		for k in range(4):
			var p := a.lerp(c, (k + 0.5) / 4.0)
			var n := (c - a).orthogonal().normalized() * 0.018
			_stroke(s, p - n, p + n, INK, 0.004)
	for x in [-0.35, -0.27]:
		_stroke(s, Vector2(x, -0.32), Vector2(x, -0.18), PENCIL, 0.02)
	BuildKit.label(s, "WORKS", Vector3(-0.31, -0.37, 0.002), 0.036, INK)
	_report(s, Vector2(0.2, -0.28), "RAIL: 14 TRAINS\nOVERNIGHT\nTOWARD PASSES", 2.0)
	_report(s, Vector2(0.43, -0.48), "WORKS ON\n3 SHIFTS\n(AIR RECCE)", -3.0)
	_report(s, Vector2(-0.05, -0.5), "AIR ACTIVITY\nHIGH. OWN\nRECCE LIMITED", 5.0)


func _sketch_merovia(s: Node3D) -> void:
	# Coastline, two ports, surface groups offshore.
	_polyline(s, [Vector2(-0.55, 0.38), Vector2(-0.3, 0.3), Vector2(-0.25, 0.1), Vector2(-0.05, 0.0), Vector2(0.0, -0.25), Vector2(0.2, -0.45)], Color(0.1, 0.25, 0.6), 0.01)
	for p in [Vector2(-0.3, 0.22), Vector2(-0.08, -0.08)]:
		_stroke(s, p + Vector2(-0.03, 0), p + Vector2(0.03, 0), INK, 0.008)
		_stroke(s, p + Vector2(0, -0.03), p + Vector2(0, 0.04), INK, 0.008)
	for p in [Vector2(0.15, 0.25), Vector2(0.3, 0.12), Vector2(0.22, 0.0)]:
		_stroke(s, p + Vector2(-0.04, 0), p + Vector2(0.04, 0), RED_INK, 0.014)
	BuildKit.label(s, "SURFACE GROUPS", Vector3(0.3, 0.33, 0.002), 0.034, RED_INK)
	_report(s, Vector2(-0.35, -0.3), "PORT ACTIVITY\nHIGH (2 PORTS)", -4.0)
	_report(s, Vector2(0.38, -0.36), "PATROL CRAFT x6\nCOASTAL", 3.0)
	_report(s, Vector2(0.1, -0.55), "NO CHANGE\nREPORTED SINCE\n0400", -1.0)


## A pinned sheet with a few typed lines.
func _report(parent: Node3D, at: Vector2, text: String, tilt: float) -> void:
	var p := BuildKit.pivot(parent, Vector3(at.x, at.y, 0.003), Vector3(0, 0, tilt))
	BuildKit.box(p, Vector3(0.3, 0.18, 0.002), Vector3.ZERO, BuildKit.mat("paper_old"), Vector3.ZERO, false)
	BuildKit.label(p, text, Vector3(0, -0.005, 0.002), 0.026, Color(0.1, 0.09, 0.08))
	BuildKit.sphere(p, 0.01, Vector3(0, 0.078, 0.004), BuildKit.lamp(RED_INK, false))


func _polyline(parent: Node3D, pts: Array, color: Color, width: float) -> void:
	for i in range(pts.size() - 1):
		_stroke(parent, pts[i], pts[i + 1], color, width)


## One marker stroke on the board plane.
func _stroke(parent: Node3D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var m := BuildKit.lamp(color, false)
	var d := b - a
	var mi := BuildKit.box(parent, Vector3(d.length(), width, 0.002), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.002), m, Vector3(0, 0, rad_to_deg(d.angle())), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The officer: a dark greatcoat silhouette, always seen from behind.
func _build_officer() -> void:
	var K := BuildKit
	var coat := K.mat("bakelite")
	_officer = K.pivot(self, Vector3(-1.78, 0, -1.9), Vector3(0, 180, 0))
	var body := K.pivot(_officer, Vector3.ZERO)
	for x in [-0.09, 0.09]:
		K.cyl(body, 0.06, 0.82, Vector3(x, 0.41, 0), coat, Vector3.ZERO, 10)
	K.cyl(body, 0.2, 0.75, Vector3(0, 1.05, 0), coat, Vector3.ZERO, 14, 0.24)         # greatcoat
	K.box(body, Vector3(0.5, 0.12, 0.24), Vector3(0, 1.43, 0), coat)                  # shoulders
	K.cyl(body, 0.055, 0.1, Vector3(0, 1.52, 0), coat, Vector3.ZERO, 6)               # neck
	K.sphere(body, 0.11, Vector3(0, 1.64, 0), K.mat("rubber"))
	K.cyl(body, 0.13, 0.07, Vector3(0, 1.76, 0), coat, Vector3.ZERO, 10, 0.15)       # peaked cap
	K.box(body, Vector3(0.2, 0.012, 0.1), Vector3(0, 1.73, -0.1), coat)
	for s in [-1, 1]:
		K.box(body, Vector3(0.1, 0.02, 0.18), Vector3(s * 0.2, 1.5, 0), K.mat("brass"))   # epaulettes
	# Left arm hangs; right arm holds a pointer and moves.
	K.cyl(body, 0.045, 0.6, Vector3(-0.27, 1.12, 0), coat, Vector3(0, 0, -6), 10)
	_arm = K.pivot(body, Vector3(0.26, 1.42, 0), Vector3(8, 0, 6))
	K.cyl(_arm, 0.045, 0.6, Vector3(0, -0.3, 0), coat, Vector3.ZERO, 10)
	K.cyl(_arm, 0.006, 0.5, Vector3(0, -0.72, 0.04), K.mat("steel"), Vector3(-20, 0, 0), 4)


func _build_table() -> void:
	var K := BuildKit
	var tb := K.pivot(self, Vector3(1.75, 0.75, -1.1), Vector3(0, -15, 0))
	K.box(tb, Vector3(1.1, 0.04, 0.6), Vector3.ZERO, K.mat("paint_green"))
	for x in [-0.5, 0.5]:
		for z in [-0.26, 0.26]:
			K.cyl(tb, 0.02, 0.75, Vector3(x, -0.375, z), K.mat("steel"), Vector3.ZERO, 5)
	# Teleprinter with its emerging sheet.
	var pr := K.pivot(tb, Vector3(-0.22, 0.02, 0.0))
	K.box(pr, Vector3(0.4, 0.16, 0.34), Vector3(0, 0.08, 0), K.mat("paint_beige"))
	K.box(pr, Vector3(0.32, 0.03, 0.03), Vector3(0, 0.17, 0.05), K.mat("bakelite"))
	_sheet = K.pivot(pr, Vector3(0, 0.2, 0.05), Vector3(-15, 0, 0))
	K.box(_sheet, Vector3(0.24, 0.2, 0.002), Vector3(0, 0.0, 0), K.mat("paper"), Vector3.ZERO, false)
	K.label(_sheet, "FLASH  KARSEN SECTOR\nFR-2311  0518\nCONTACT LOST K-2\nUNVERIFIED", Vector3(0, 0.02, 0.002), 0.012, Color(0.12, 0.11, 0.1))
	# Radio set.
	var rd := K.pivot(tb, Vector3(0.3, 0.02, -0.05))
	K.box(rd, Vector3(0.34, 0.2, 0.24), Vector3(0, 0.1, 0), K.mat("paint_grey"))
	K.box(rd, Vector3(0.12, 0.06, 0.01), Vector3(-0.07, 0.13, 0.121), K.mat("gauge_face"))
	K.cyl(rd, 0.02, 0.02, Vector3(0.09, 0.09, 0.125), K.mat("bakelite"), Vector3(90, 0, 0), 8)
	_radio_lamp = K.cyl(rd, 0.008, 0.01, Vector3(0.12, 0.15, 0.123), K.lamp(BuildKit.GREEN, false), Vector3(90, 0, 0), 6, -1.0, false)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_fade)
	_caption = Label.new()
	_caption.theme = UiKit.theme()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.modulate.a = 0.0
	ui.add_child(_caption)
	_skip = Button.new()
	_skip.theme = UiKit.theme()
	_skip.text = "SKIP  >>"
	_skip.name = "SkipButton"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 20)
	_skip.modulate.a = 0.7
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -250
	_skip.offset_right = -16
	_skip.offset_top = 16
	_skip.offset_bottom = 76
	_skip.pressed.connect(_on_skip)
	ui.add_child(_skip)
