extends CanvasLayer
## Minimal touch HUD: three view buttons along the bottom edge, a
## short control hint that fades out, and a small FPS readout for
## on-device performance testing.

@export var camera: Camera3D

@onready var _left: Button = %LeftButton
@onready var _forward: Button = %ForwardButton
@onready var _right: Button = %RightButton
@onready var _hint: Label = %Hint
@onready var _fps: Label = %Fps


func _ready() -> void:
	_left.pressed.connect(camera.snap_to.bind("left"))
	_forward.pressed.connect(camera.reset_view)
	_right.pressed.connect(camera.snap_to.bind("right"))
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(_hint, "modulate:a", 0.0, 1.5)


func _process(_delta: float) -> void:
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
