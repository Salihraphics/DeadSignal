extends CanvasLayer
## The three endings. Which one plays is decided by the Director from the
## world state; there is no way to pick one.
##
##   EXECUTED  relieved of duty: a knock, an order through the door, black,
##             a single shot heard off-screen.
##   FALL      Varnesk falls: the door opens on a backlit enemy silhouette,
##             a shot, and the cut to black comes before anything is seen.
##   SURVIVED  Norvak survives: years later, a park bench, quiet.
##
## Input to the room is blocked for the whole sequence. No gore, no
## casualty figures; the after-action report follows each ending.

const SILHOUETTE_DIST := 0.35

var _block: ColorRect
var _black: ColorRect
var _caption: Label
var _running := ""


func _ready() -> void:
	add_to_group("endings")
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_block = ColorRect.new()
	_block.color = Color(0, 0, 0, 0)
	_block.mouse_filter = Control.MOUSE_FILTER_STOP     # swallow all touches
	_block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_block.visible = false
	add_child(_block)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	_caption = Label.new()
	_caption.theme = UiKit.theme()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.modulate.a = 0.0
	add_child(_caption)


func running() -> String:
	return _running


func begin(id: String) -> void:
	if _running != "":
		return
	_running = id
	Run.finish(id)
	_block.visible = true
	get_tree().paused = false
	get_tree().call_group("message_reader", "close")
	var ui := get_parent().get_node_or_null("Interaction")
	if ui:
		ui.exit_focus()
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		hud.visible = false
	Subtitles.clear()
	match id:
		"EXECUTED": _executed()
		"FALL": _fall()
		_: _survived()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _fade(alpha: float, sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, sec)
	await tw.finished


func _executed() -> void:
	var cam: Camera3D = get_parent().get_node("OperatorCamera")
	cam.reset_view()
	Sfx.stop_loop("fluorescent", 2.0)
	await _wait(2.0)
	Sfx.play("knock", -2.0)
	await _wait(1.6)
	Sfx.play("door_heavy", -2.0)
	await _wait(1.5)
	Sfx.play("footsteps", -4.0)
	Subtitles.say("OFFICER", "Operator. Stand up.", 2.6, true)
	await _wait(3.0)
	Subtitles.say("OFFICER", "By order of Strategic Command, you are relieved of duty.", 3.8, true)
	await _wait(4.2)
	Subtitles.say("OFFICER", "Leave everything as it is.", 2.6, true)
	await _wait(2.6)
	await _fade(1.0, 2.0)
	Sfx.stop_all_loops(1.5)
	Sfx.play("footsteps", -10.0, 0.9)
	await _wait(5.0)
	Sfx.play("gunshot_far", -3.0)
	await _wait(4.0)
	_report()


func _fall() -> void:
	var room: Node3D = get_parent().get_node("CommandRoom")
	var cam: Camera3D = get_parent().get_node("OperatorCamera")
	Sfx.play("launch_rumble", -8.0, 0.6)
	room.flicker(2.0)
	await _wait(2.5)
	Subtitles.say("RADIO", "...all posts, Varnesk... no further contact...", 3.0, true)
	await _wait(3.5)
	Sfx.play("door_heavy", 0.0)
	# The operator turns in the chair toward the door behind him.
	var door_pos := Vector3(1.3, 1.2, CommandRoomRef.BACK_Z)
	var pose := cam.global_transform.looking_at(door_pos, Vector3.UP)
	cam.focus(pose, 55.0)
	room.door_light.visible = true
	var figure := _silhouette(room)
	var tw := create_tween()
	tw.tween_property(room.door, "rotation_degrees:y", -100.0, 1.8).set_trans(Tween.TRANS_SINE)
	await _wait(2.6)
	figure.visible = true
	await _wait(1.8)
	Sfx.play("gunshot_near", 0.0)
	_black.color.a = 1.0                # cut before anything else is seen
	Sfx.stop_all_loops()
	await _wait(5.0)
	_report()


## A dark, featureless figure in the doorway, lit from behind.
func _silhouette(room: Node3D) -> Node3D:
	var K := BuildKit
	var dark := K.mat("rubber")
	var f := K.pivot(room, Vector3(1.3, 0, CommandRoomRef.BACK_Z - SILHOUETTE_DIST))
	for x in [-0.09, 0.09]:
		K.cyl(f, 0.065, 0.85, Vector3(x, 0.425, 0), dark, Vector3.ZERO, 8)
	K.cyl(f, 0.19, 0.7, Vector3(0, 1.2, 0), dark, Vector3.ZERO, 10, 0.21)
	K.box(f, Vector3(0.48, 0.12, 0.22), Vector3(0, 1.52, 0), dark)
	K.sphere(f, 0.11, Vector3(0, 1.7, 0), dark)
	K.cyl(f, 0.14, 0.09, Vector3(0, 1.8, 0), dark, Vector3.ZERO, 10, 0.12)       # helmet
	K.cyl(f, 0.03, 0.75, Vector3(0.22, 1.25, -0.12), dark, Vector3(60, 0, 0), 6)  # rifle, lowered
	f.visible = false
	return f


func _survived() -> void:
	Sfx.stop_loop("fluorescent", 3.0)
	await _wait(1.5)
	Subtitles.say("CENTRAL", "K-4, Central. Relief is on the stairs. Hand over and stand down.", 4.5, true)
	await _wait(5.5)
	await _fade(1.0, 3.0)
	Sfx.stop_all_loops(2.0)
	_caption.text = "YEARS LATER"
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 1.2)
	await _wait(3.5)
	get_tree().change_scene_to_file("res://scenes/epilogue.tscn")


func _report() -> void:
	get_tree().change_scene_to_file("res://scenes/after_action.tscn")


## Constants of the room without a hard script dependency.
class CommandRoomRef:
	const BACK_Z := 2.4
