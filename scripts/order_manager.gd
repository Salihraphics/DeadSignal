extends Node
## Holds the state of the current order and records the operator's
## decision. Stations, HUD and screens listen to `state_changed` and read
## `state` / `order`; they never change the state themselves.
##
## Stage 3: a single self-contained order that arrives after a short
## delay. No campaign, consequences or follow-up orders yet.

signal state_changed(state: State)

enum State { NONE, PENDING, ACCEPTED, REFUSED }

## Seconds after the room loads before the first order arrives.
@export var arrival_delay := 10.0

var state: State = State.NONE
var order: Dictionary = {}
var arrived_at := ""            # device clock "HHMM" (diegetic only)
var decided_at := ""
## Every decision made this session, oldest first: {id, decision, time}.
var history: Array[Dictionary] = []


func _enter_tree() -> void:
	add_to_group("orders")   # before any station's _ready looks it up


func _ready() -> void:
	if arrival_delay >= 0.0:
		get_tree().create_timer(arrival_delay).timeout.connect(deliver.bind(0))


func deliver(index: int) -> void:
	if state != State.NONE:
		return
	order = OrderCatalog.get_order(index)
	arrived_at = _clock()
	state = State.PENDING
	state_changed.emit(state)


func decide(accept: bool) -> void:
	if state != State.PENDING:
		return
	state = State.ACCEPTED if accept else State.REFUSED
	decided_at = _clock()
	history.append({"id": order.id, "decision": "ACCEPTED" if accept else "REFUSED", "time": decided_at})
	state_changed.emit(state)


func has_order() -> bool:
	return state != State.NONE


func is_pending() -> bool:
	return state == State.PENDING


static func _clock() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d%02d" % [t.hour, t.minute]
