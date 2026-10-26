extends Camera3D
## Seated operator camera. The head turns within fixed limits only:
## no walking, no free look. Three preset views (left / forward / right).
##
## Touch: drag to look, tap to interact, double-tap empty space to
##        return forward (or to leave focus mode).
## Mouse: the same with the left button.
## Keys: A / Left = turn to the next view left, D / Right = next view right,
##       R / Space / Home = return forward (or leave focus mode).
##
## Focus mode: the operator leans in toward a station element. Dragging
## is disabled until focus is released.

signal view_changed(view_name: String)
signal unfocus_requested

const VIEWS := {"left": 72.0, "forward": 0.0, "right": -72.0}
const VIEW_ORDER := ["left", "forward", "right"]

@export var yaw_limit_deg := 80.0
## A little vertical tilt so the desk and window can both be inspected.
## Set both to default_pitch_deg to lock the view to horizontal only.
@export var pitch_min_deg := -24.0
@export var pitch_max_deg := 6.0
@export var default_pitch_deg := -7.0
## Dragging the full screen height turns the head this many degrees.
@export var drag_degrees_per_screen := 100.0
## Off: the view turns the way the finger moves. On: drag the scene instead.
@export var invert_drag := false
## Flips only the vertical drag direction (player setting).
@export var invert_vertical := false
## No breathing sway or shake (player setting "reduced motion").
@export var reduced_motion := false
@export var smoothing := 9.0
@export var double_tap_ms := 300
## A press that moves less than this (pixels) and is released is a tap.
@export var tap_slop_px := 14.0

## Called with the screen position of each tap; return true if used.
var tap_handler: Callable
## Called on press; return true to capture the touch for a control. While
## captured, moves go to drag_handler(pos, relative) and the release to
## release_handler(pos, moved). The view never turns during a capture.
var press_handler: Callable
var drag_handler: Callable
var release_handler: Callable
var _captured := false

var _target := Vector2.ZERO         # x = yaw, y = pitch (degrees)
var _current := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _last_tap_ms := -10000
var _dragged := false
var _t := 0.0
var _home_pos := Vector3.ZERO
var _home_fov := 62.0
var _focus_on := false
var _focus_pose := Transform3D.IDENTITY
var _focus_fov := 50.0
var _focus_w := 0.0                 # 0 = seated view, 1 = fully focused
var _shake_amp := 0.0               # degrees, decays over time
var _shake_decay := 1.0
## Additive head turns in degrees (pitch, yaw, roll): `action_tilt` for the
## operator's own movements (drinking), `react_tilt` for bodily reactions.
## They never touch the look target, so input is never taken away.
var action_tilt := Vector3.ZERO
var react_tilt := Vector3.ZERO
## Intoxication sway, 0..1 (set by Intoxication). Scaled down with reduced motion.
var drunk := 0.0
## Mouth position in camera space (for drinking / smoking animations).
const MOUTH := Vector3(0.0, -0.085, -0.05)


func _ready() -> void:
	_apply_settings()
	Settings.changed.connect(func(_k: String) -> void: _apply_settings())
	_home_pos = position
	_home_fov = fov
	_target = Vector2(0.0, default_pitch_deg)
	_current = _target
	_apply()


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-smoothing * delta)
	_current = _current.lerp(_target, k)
	_focus_w = lerpf(_focus_w, 1.0 if _focus_on else 0.0, 1.0 - exp(-7.0 * delta))
	_shake_amp = maxf(0.0, _shake_amp - _shake_decay * delta)
	_apply()


func _apply_settings() -> void:
	drag_degrees_per_screen = 100.0 * Settings.sensitivity
	invert_vertical = Settings.invert_vertical
	reduced_motion = Settings.reduced_motion
	if reduced_motion:
		_shake_amp = 0.0


## Room vibration: `amplitude` degrees, fading out over `duration` seconds.
## A stronger shake replaces a weaker one; it never moves the seat and
## never blocks input. Skipped entirely with reduced motion.
func shake(amplitude: float, duration: float) -> void:
	if reduced_motion:
		return
	if amplitude >= _shake_amp:
		_shake_amp = amplitude
		_shake_decay = amplitude / maxf(duration, 0.01)


func _apply() -> void:
	# Barely perceptible breathing sway keeps the seated view alive.
	var sway := Vector2.ZERO if reduced_motion else Vector2(sin(_t * 0.37) * 0.12, sin(_t * 0.61) * 0.09)
	if _shake_amp > 0.0:
		sway += Vector2(sin(_t * 61.0) * cos(_t * 23.0), sin(_t * 53.0 + 1.3)) * _shake_amp
	var roll := 0.0
	var fov_off := 0.0
	if drunk > 0.001:
		# Slow, low-frequency drift; never fast enough to read as shaking.
		var d := drunk * (0.25 if reduced_motion else 1.0)
		sway += Vector2(sin(_t * 0.53) * 1.9 + sin(_t * 1.27) * 0.5, sin(_t * 0.41 + 1.1) * 1.2) * d
		roll = (0.0 if reduced_motion else sin(_t * 0.33) * 2.2 * d)
		fov_off = sin(_t * 0.29) * 1.6 * d
	var tilt := action_tilt + react_tilt
	var euler := Vector3(_current.y + sway.y + tilt.x, _current.x + sway.x + tilt.y, roll + tilt.z) * (PI / 180.0)
	var seated := Transform3D(Basis.from_euler(euler), _home_pos)
	if _focus_w < 0.001:
		transform = seated
		fov = _home_fov + fov_off
		return
	var w := smoothstep(0.0, 1.0, _focus_w)
	transform = seated.interpolate_with(_focus_pose, w)
	fov = lerpf(_home_fov, _focus_fov, w) + fov_off * (1.0 - w)


## The operator's mouth in world space (follows head turns and sway).
func mouth_point() -> Vector3:
	return global_transform * MOUTH


## Leans in toward `pose` (a camera transform) until unfocus() is called.
func focus(pose: Transform3D, focus_fov: float) -> void:
	_focus_pose = pose
	_focus_fov = focus_fov
	_focus_on = true


func unfocus() -> void:
	_focus_on = false


func is_focused() -> bool:
	return _focus_on


func snap_to(view_name: String) -> void:
	if not VIEWS.has(view_name):
		return
	_target = Vector2(VIEWS[view_name], default_pitch_deg)
	view_changed.emit(view_name)


func reset_view() -> void:
	snap_to("forward")


## Steps one preset view toward `dir` (-1 = left, +1 = right).
func step_view(dir: int) -> void:
	var i := VIEW_ORDER.find(nearest_view())
	snap_to(VIEW_ORDER[clampi(i + dir, 0, VIEW_ORDER.size() - 1)])


func nearest_view() -> String:
	var best := "forward"
	for v in VIEWS:
		if absf(VIEWS[v] - _target.x) < absf(VIEWS[best] - _target.x):
			best = v
	return best


func _unhandled_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse events (project setting), so one path
	# serves both phone and desktop. GUI buttons consume their own events.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_dragged = false
			_captured = press_handler.is_valid() and press_handler.call(event.position)
		elif _captured:
			_captured = false
			release_handler.call(event.position, _dragged)
		elif not _dragged:
			_on_tap(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if event.position.distance_to(_press_pos) > tap_slop_px:
			_dragged = true
		if _captured:
			drag_handler.call(event.position, event.relative)
			return
		if _focus_on:
			return
		var deg_per_px := drag_degrees_per_screen / get_viewport().get_visible_rect().size.y
		if invert_drag:
			deg_per_px = -deg_per_px
		_target.x = clampf(_target.x - event.relative.x * deg_per_px, -yaw_limit_deg, yaw_limit_deg)
		var dy: float = -event.relative.y * deg_per_px * (-1.0 if invert_vertical else 1.0)
		_target.y = clampf(_target.y + dy, pitch_min_deg, pitch_max_deg)
	elif event is InputEventKey and event.pressed and not event.echo:
		if _focus_on:
			if event.keycode in [KEY_R, KEY_SPACE, KEY_HOME]:
				unfocus_requested.emit()
			return
		match event.keycode:
			KEY_A, KEY_LEFT: step_view(-1)
			KEY_D, KEY_RIGHT: step_view(1)
			KEY_R, KEY_SPACE, KEY_HOME: reset_view()


func _on_tap(pos: Vector2) -> void:
	if tap_handler.is_valid() and tap_handler.call(pos):
		_last_tap_ms = -10000
		return
	# Double-tap on empty space: leave focus, or face the console.
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < double_tap_ms:
		_last_tap_ms = -10000
		if _focus_on:
			unfocus_requested.emit()
		else:
			reset_view()
	else:
		_last_tap_ms = now
