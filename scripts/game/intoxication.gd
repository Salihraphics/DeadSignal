extends Node
## Temporary intoxication from consecutive beers. Purely atmospheric: it
## never touches orders, launches, outcomes, scoring or endings, and never
## blocks input. Nothing here is saved; a loaded shift starts sober.
##
## States:
##   NORMAL    no effect
##   DRINKING  a drink animation is running (Vices reports start / finish)
##   MILD      second beer in a row: gentle sway for `mild_duration`
##   STRONG    third beer in a row: stronger sway for `strong_duration`
##   VOMIT     fourth in a row: a brief, non-graphic reaction, then MILD
##   RECOVERY  the effect fades out over `recovery_time`, then NORMAL
##
## "In a row" = each beer finished within `consecutive_window` seconds of
## the previous one. The streak, not the timers, decides the level, and a
## new drink only ever extends a timer to the level's duration (never
## stacks it), so states cannot run away. After vomiting the streak falls
## back to `streak_after_vomit`, so further drinks repeat the same cycle.

signal state_changed(state: State)

enum State { NORMAL, DRINKING, MILD, STRONG, VOMIT, RECOVERY }

@export var consecutive_window := 150.0
@export var mild_duration := 30.0
@export var strong_duration := 40.0
@export var recovery_time := 8.0
@export var mild_intensity := 0.45
@export var strong_intensity := 0.8
@export var vomit_streak := 4
@export var streak_after_vomit := 2
@export var vomit_time := 3.2
## Intensity rises / falls at this rate per second (no sudden jumps).
@export var ramp := 0.25

var state: State = State.NORMAL
var streak := 0
var _last_drink := -1000.0
var _timer := 0.0            # time left in MILD / STRONG / VOMIT / RECOVERY
var _level: State = State.NORMAL   # the effect level behind DRINKING
var _intensity := 0.0
var _clock := 0.0
var camera: Camera3D


func _enter_tree() -> void:
	add_to_group("intoxication")


func _ready() -> void:
	camera = get_viewport().get_camera_3d()


func intensity() -> float:
	return _intensity


## The effect level (ignoring a drink in progress).
func level() -> State:
	return _level if state == State.DRINKING else state


func drink_started() -> void:
	if state == State.VOMIT:
		return
	_level = state if state != State.RECOVERY else State.RECOVERY
	_enter(State.DRINKING)


## A drink completed. Returns true when it was part of a streak (2nd+).
func drink_finished() -> bool:
	if _clock - _last_drink <= consecutive_window:
		streak += 1
	else:
		streak = 1
	_last_drink = _clock
	var target := _level if state == State.DRINKING else state
	if streak >= vomit_streak:
		_vomit()
		return true
	if streak == 3:
		_timer = maxf(_timer if target == State.STRONG else 0.0, strong_duration)
		_enter(State.STRONG)
	elif streak == 2:
		if target == State.STRONG:
			_enter(State.STRONG)          # already stronger: keep it
		else:
			_timer = maxf(_timer if target == State.MILD else 0.0, mild_duration)
			_enter(State.MILD)
	else:
		_enter(target if target in [State.MILD, State.STRONG, State.RECOVERY] else State.NORMAL)
	return streak >= 2


## Cancels a drink that did not complete (no streak change).
func drink_cancelled() -> void:
	if state == State.DRINKING:
		_enter(_level)


func _vomit() -> void:
	_enter(State.VOMIT)
	_timer = vomit_time
	streak = streak_after_vomit
	Sfx.play("retch", -4.0)
	if camera:
		# Head turns down and aside, then comes back. Small with reduced motion.
		var k := 0.35 if Settings.reduced_motion else 1.0
		var tw := create_tween()
		tw.tween_property(camera, "react_tilt", Vector3(-34.0, 22.0, -4.0) * k, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(vomit_time - 1.2)
		tw.tween_property(camera, "react_tilt", Vector3.ZERO, 0.75).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(vomit_time + 1.0).timeout.connect(func() -> void: Dialogue.trigger("vomit"))


func _enter(s: State) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)
	if s == State.STRONG:
		Dialogue.trigger("drunk")


func _process(delta: float) -> void:
	_clock += delta
	var lvl := level()
	if lvl in [State.MILD, State.STRONG, State.VOMIT, State.RECOVERY] and state != State.DRINKING:
		_timer -= delta
		if _timer <= 0.0:
			match state:
				State.VOMIT:
					_timer = mild_duration
					_enter(State.MILD)
				State.MILD, State.STRONG:
					_timer = recovery_time
					_enter(State.RECOVERY)
				State.RECOVERY:
					_enter(State.NORMAL)
	var goal := 0.0
	match lvl:
		State.MILD: goal = mild_intensity
		State.STRONG, State.VOMIT: goal = strong_intensity
		State.RECOVERY: goal = mild_intensity * clampf(_timer / maxf(recovery_time, 0.01), 0.0, 1.0)
	_intensity = move_toward(_intensity, goal, ramp * delta)
	if camera and "drunk" in camera:
		camera.drunk = _intensity


## Seconds left at the current level (tests / debugging).
func time_left() -> float:
	return _timer
