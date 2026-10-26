extends Node
## Holds the state of the current order and records the operator's
## decision. Stations, HUD and screens listen to `state_changed` and read
## `state` / `order`; they never change the state themselves.
##
## In a run the Director delivers each order from OrderCatalog in turn and
## lets an unanswered one lapse (EXPIRED, "NO REPLY"). Opened without a run
## (sandbox / tests) the first order arrives after `arrival_delay`.

signal state_changed(state: State)

enum State { NONE, PENDING, ACCEPTED, REFUSED, EXPIRED }
const WORDS := ["NONE", "PENDING", "ACCEPTED", "REFUSED", "NO REPLY"]

## Seconds after the room loads before the first order arrives (sandbox
## only; negative = never). The Director clears it in a run.
@export var arrival_delay := 10.0

var state: State = State.NONE
var order: Dictionary = {}
var arrived_at := ""            # facility clock "HHMM"
var decided_at := ""
## Every decision made, oldest first: {id, decision, time}.
var history: Array[Dictionary] = []
## True while a saved state is being restored (listeners stay quiet).
var restoring := false


func _enter_tree() -> void:
	add_to_group("orders")   # before any station's _ready looks it up


func _ready() -> void:
	if arrival_delay >= 0.0 and not Run.active:
		get_tree().create_timer(arrival_delay).timeout.connect(func() -> void:
			if state == State.NONE:
				deliver(0))


## A new order replaces a decided one; a pending one must be answered or
## expired first.
func deliver(index: int) -> void:
	if state == State.PENDING:
		return
	order = OrderCatalog.get_order(index)
	arrived_at = Run.hhmm()
	decided_at = ""
	state = State.PENDING
	state_changed.emit(state)


func decide(accept: bool) -> void:
	if state != State.PENDING:
		return
	_close(State.ACCEPTED if accept else State.REFUSED)


## The reply deadline passed without an answer.
func expire() -> void:
	if state == State.PENDING:
		_close(State.EXPIRED)


func _close(s: State) -> void:
	state = s
	decided_at = Run.hhmm()
	history.append({"id": order.id, "decision": WORDS[s], "time": decided_at})
	if Run.active:
		Run.record_decision(order.id, WORDS[s])
	state_changed.emit(state)


func has_order() -> bool:
	return state != State.NONE


func is_pending() -> bool:
	return state == State.PENDING


func word() -> String:
	return WORDS[state]


func snapshot() -> Dictionary:
	return {"id": order.get("id", ""), "state": state, "arrived": arrived_at, "decided": decided_at, "history": history}


## Restores a saved order silently (no arrival cue, no decision replay).
func restore(d: Dictionary) -> void:
	history.clear()
	for h in d.get("history", []):
		history.append(h)
	var i := OrderCatalog.index_of(d.get("id", ""))
	if i < 0:
		return
	order = OrderCatalog.get_order(i)
	state = int(d.get("state", State.NONE)) as State
	arrived_at = d.get("arrived", "")
	decided_at = d.get("decided", "")
	restoring = true
	state_changed.emit(state)
	restoring = false
