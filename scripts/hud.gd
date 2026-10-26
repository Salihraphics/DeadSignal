extends CanvasLayer
## Minimal touch HUD: three view buttons along the bottom edge, a
## short control hint that fades out, and a small FPS readout for
## on-device performance testing. In focus mode the view buttons are
## replaced by a BACK button, a title and optional placeholder actions.

signal back_pressed
signal action_pressed(action_name: String)

@export var camera: Camera3D

@onready var _left: Button = %LeftButton
@onready var _forward: Button = %ForwardButton
@onready var _right: Button = %RightButton
@onready var _hint: Label = %Hint
@onready var _fps: Label = %Fps
@onready var _back: Button = %BackButton
@onready var _title: Label = %FocusTitle
@onready var _actions: HBoxContainer = %Actions
@onready var _toast: Label = %Toast

var _toast_tween: Tween


func _ready() -> void:
	add_to_group("hud")
	_left.pressed.connect(camera.snap_to.bind("left"))
	_forward.pressed.connect(camera.reset_view)
	_right.pressed.connect(camera.snap_to.bind("right"))
	_back.pressed.connect(back_pressed.emit)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(_hint, "modulate:a", 0.0, 1.5)


func _process(_delta: float) -> void:
	_fps.text = "%d FPS" % Engine.get_frames_per_second()


func show_focus(title: String, actions: PackedStringArray) -> void:
	for b in [_left, _forward, _right]:
		b.visible = false
	_hint.visible = false
	_back.visible = true
	_title.text = title
	_title.visible = true
	for c in _actions.get_children():
		c.queue_free()
	for a in actions:
		var b := _back.duplicate(0) as Button   # style only, no signals
		b.unique_name_in_owner = false
		b.text = a
		b.custom_minimum_size = Vector2(150, 62)
		b.pressed.connect(action_pressed.emit.bind(a))
		_actions.add_child(b)
	_actions.visible = actions.size() > 0


func hide_focus() -> void:
	for b in [_left, _forward, _right]:
		b.visible = true
	_back.visible = false
	_title.visible = false
	_actions.visible = false


## Short placeholder status message, e.g. after lifting the telephone.
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
