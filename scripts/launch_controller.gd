extends Node
## Sequences a launch: countdown -> ignition (irreversible, recorded once by
## StrategicState) -> missile visual and room reaction -> observation delay
## -> abstract outcome report -> shaft reload. All decisions about what is
## allowed live in StrategicState; this node only advances time.

const REPORT_DELAY_S := 6.0
const RELOAD_S := 20.0

@export var camera: Camera3D
@export var room: Node3D
@export var missile: Node3D

var state: Node
var _report_in := -1.0
var _reload_in := -1.0
var _event: Dictionary = {}


func _ready() -> void:
	state = get_tree().get_first_node_in_group("strategy")
	state.launch_changed.connect(_on_launch_state)
	missile.flame_passing.connect(func() -> void:
		camera.shake(0.9, 2.2)
		room.flicker(1.4))
	missile.cleared.connect(_on_cleared)


func _on_launch_state(s: int) -> void:
	room.set_alarm(s in [state.Launch.SEQUENCE, state.Launch.AWAY])
	if s == state.Launch.SEQUENCE:
		_toast("LAUNCH SEQUENCE: %s  %s" % [state.current.grid, state.current.ammo])


func _process(delta: float) -> void:
	if state.launch_state == state.Launch.SEQUENCE:
		state.countdown = maxf(0.0, state.countdown - delta)
		if state.countdown <= 0.0:
			_ignite()
	if _report_in >= 0.0:
		_report_in -= delta
		if _report_in < 0.0:
			_report()
	if _reload_in >= 0.0:
		_reload_in -= delta
		if _reload_in < 0.0:
			state.set_shaft("LOADED")
			_toast("SHAFT RELOADED")


func _ignite() -> void:
	var event: Dictionary = state.missile_away()   # {} if already recorded
	if event.is_empty():
		return
	_event = event
	missile.launch(Ammunition.get_type(event.ammo).designation)
	camera.shake(0.35, 4.0)
	room.flicker(0.6)
	_toast("%s AWAY" % event.launch_id)


func _on_cleared() -> void:
	state.report_pending()
	_report_in = REPORT_DELAY_S


func _report() -> void:
	if _event.is_empty():
		return
	var outcome := OutcomeModel.evaluate(_event.cell, _event.ammo)
	state.complete(outcome)
	_toast("REPORT %s: %s" % [_event.launch_id, outcome.category])
	_event = {}
	state.set_shaft("RELOADING")
	_reload_in = RELOAD_S


func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)
