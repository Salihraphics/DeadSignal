extends Node
## The continuous run (autoload "Run"): hidden world values, the traffic
## log (reports, intercepts, calls, orders), confirmation requests, the
## decision history, one-time flags, the operator's habits, and save/load.
##
## There are no days or missions. One run lasts from the start of the shift
## until one of the three endings. Values are hidden from the player; they
## only surface through what the facility receives.
##
## Save/load rule: everything that must happen once (beats, consequences,
## dialogue one-shots, counted habits) is recorded by id here, so loading a
## save never repeats or double counts it.

signal traffic_added(item: Dictionary)
signal traffic_changed(item: Dictionary)
signal values_changed

const SAVE_PATH := "user://run.save"
const SAVE_VERSION := 1
## Shift start on the facility clock (05:40).
const START_CLOCK_S := (5 * 60 + 40) * 60.0
## Facility clock seconds per real second (10 real minutes = 1 hour).
const CLOCK_RATE := 6.0

## A run is in progress (set by NEW GAME / CONTINUE, cleared at an ending).
var active := false
## True until the room's power-up sequence has played once.
var fresh := true
## Real seconds of play in this run (drives the scenario timeline).
var elapsed := 0.0
## Facility clock, seconds since 00:00 of the first day.
var clock := START_CLOCK_S

# Hidden world values, 0..100.
var trust := 60.0          # how Strategic Command regards this post
var stability := 50.0      # the Karsen front
var integrity := 50.0      # how true the post's picture of the front is

var flags := {}            # one-time facts: "sc003_accepted" ...
var fired := {}            # scenario beats that have run
var applied := {}          # consequences that have been applied
var traffic: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var decisions: Array[Dictionary] = []
var said := {}             # dialogue lines already spoken (one-time / no-repeat)
var sector_status := "CONTROLLED"
var sector_basis := "FR-2207"
var beers := 0
var cigarettes := 0
var last_vice := ""
var last_vice_at := -1000.0
var calls_answered := 0
var calls_missed := 0
var ending := ""
## Statistics frozen at the end of the run (after-action report).
var final_stats := {}
var strategic := {}        # StrategicState snapshot (see capture)
var order_snapshot := {}   # OrderManager snapshot

var _autosave_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	clock += delta * CLOCK_RATE
	_autosave_t += delta
	if _autosave_t > 30.0:
		save()


func _notification(what: int) -> void:
	# Android may kill a backgrounded app without warning: save on the way out.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if active:
			save()


# --- Run lifecycle ------------------------------------------------------------------------

func new_run() -> void:
	_reset()
	active = true
	delete_save()


func _reset() -> void:
	active = false
	fresh = true
	elapsed = 0.0
	clock = START_CLOCK_S
	trust = 60.0
	stability = 50.0
	integrity = 50.0
	flags = {}
	fired = {}
	applied = {}
	traffic = []
	requests = []
	decisions = []
	said = {}
	sector_status = "CONTROLLED"
	sector_basis = "FR-2207"
	beers = 0
	cigarettes = 0
	last_vice = ""
	last_vice_at = -1000.0
	calls_answered = 0
	calls_missed = 0
	ending = ""
	strategic = {}
	order_snapshot = {}


## Ends the run: freezes the statistics, then removes the save so
## CONTINUE disappears and the ending cannot be replayed from it.
func finish(ending_id: String) -> void:
	var st := get_tree().get_first_node_in_group("strategy")
	if st and st.has_method("snapshot"):
		strategic = st.snapshot()
	ending = ending_id
	final_stats = stats()
	final_stats.ending = ending_id
	final_stats.decisions = decisions.duplicate(true)
	final_stats.resources_left = int(strategic.get("resources", 0))
	active = false
	Dialogue.enabled = false
	delete_save()


# --- Clock -----------------------------------------------------------------------------------

## "HHMM" on the facility clock.
func hhmm(at_clock := -1.0) -> String:
	var c := clock if at_clock < 0.0 else at_clock
	var m := int(c / 60.0) % 1440
	return "%02d%02d" % [m / 60, m % 60]


## Hours, minutes, seconds as floats for the wall clock hands.
func clock_hms() -> Vector3:
	var c := fmod(clock, 86400.0)
	return Vector3(floorf(c / 3600.0), floorf(fmod(c, 3600.0) / 60.0), fmod(c, 60.0))


# --- World values ------------------------------------------------------------------------------

## Applies {trust: +5, stability: -3, integrity: ...} once.
func adjust(effects: Dictionary) -> void:
	for k in ["trust", "stability", "integrity"]:
		if effects.has(k):
			set(k, clampf(get(k) + float(effects[k]), 0.0, 100.0))
	values_changed.emit()


func flag(name: String) -> bool:
	return flags.get(name, false)


func set_flag(name: String, value := true) -> void:
	flags[name] = value


# --- Traffic -----------------------------------------------------------------------------------

## Adds an item to the log. Keys: id, kind (STATUS / FIELD / INTERCEPT /
## CALL / ORDER / REPLY / NOTICE), source, source_id, verification,
## subject, body (Array of lines), time ("HHMM", defaults to now), plus
## optional basis, channel, can_confirm, can_forward.
func add_traffic(item: Dictionary) -> Dictionary:
	for t in traffic:
		if t.id == item.id:
			return t                         # never duplicated
	var it := item.duplicate(true)
	if not it.has("time"):
		it.time = hhmm()
	it.read = false
	it.received = hhmm()
	if not it.has("confirm"):
		it.confirm = ""
	traffic.append(it)
	traffic_added.emit(it)
	return it


func find_traffic(id: String) -> Dictionary:
	for t in traffic:
		if t.id == id:
			return t
	return {}


func mark_read(id: String) -> void:
	var t := find_traffic(id)
	if not t.is_empty() and not t.read:
		t.read = true
		traffic_changed.emit(t)


func unread_count() -> int:
	var n := 0
	for t in traffic:
		if not t.read and t.kind != "ORDER":
			n += 1
	return n


func update_traffic(id: String, changes: Dictionary) -> void:
	var t := find_traffic(id)
	if t.is_empty():
		return
	for k in changes:
		t[k] = changes[k]
	traffic_changed.emit(t)


# --- Confirmation requests ---------------------------------------------------------------

## The operator asks for confirmation of a report. Returns the request id,
## or "" if one is already open for that report.
func request_confirmation(report_id: String) -> String:
	for r in requests:
		if r.report == report_id and r.state == "AWAITING REPLY":
			return ""
	var id := "CR-%02d" % (requests.size() + 1)
	requests.append({"id": id, "report": report_id, "sent": hhmm(), "sent_at": elapsed, "state": "AWAITING REPLY"})
	update_traffic(report_id, {"confirm": "REQUESTED %s (%s)" % [hhmm(), id]})
	return id


func open_requests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in requests:
		if r.state == "AWAITING REPLY":
			out.append(r)
	return out


func close_request(id: String, state: String) -> void:
	for r in requests:
		if r.id == id:
			r.state = state
			r.closed = hhmm()
			update_traffic(r.report, {"confirm": "%s %s (%s)" % [state, hhmm(), id]})


# --- Decisions -----------------------------------------------------------------------------------

func record_decision(order_id: String, decision: String) -> void:
	for d in decisions:
		if d.id == order_id:
			return
	decisions.append({"id": order_id, "decision": decision, "time": hhmm()})


func decision_of(order_id: String) -> String:
	for d in decisions:
		if d.id == order_id:
			return d.decision
	return ""


# --- Habits (atmosphere only: no effect on outcomes) --------------------------------------

## Counts one completed beer or cigarette. Returns true when the beer
## follows another beer (no cigarette in between, within two minutes).
func count_vice(kind: String) -> bool:
	var consecutive := kind == "beer" and last_vice == "beer" and elapsed - last_vice_at < 120.0
	if kind == "beer":
		beers += 1
	else:
		cigarettes += 1
	last_vice = kind
	last_vice_at = elapsed
	save()
	return consecutive


# --- Statistics for the after-action report -------------------------------------------------

func stats() -> Dictionary:
	var s := {
		"orders_received": 0, "followed": 0, "refused": 0, "no_reply": 0,
		"reports": 0, "unverified": 0, "requests": requests.size(), "requests_answered": 0,
		"intercepts": 0, "forwarded": 0, "calls_answered": calls_answered, "calls_missed": calls_missed,
		"launches": [], "units_expended": 0, "beers": beers, "cigarettes": cigarettes,
		"shift": "%s - %s" % [hhmm(START_CLOCK_S), hhmm()],
	}
	for d in decisions:
		s.orders_received += 1
		match d.decision:
			"ACCEPTED": s.followed += 1
			"REFUSED": s.refused += 1
			_: s.no_reply += 1
	for t in traffic:
		if t.kind in ["STATUS", "FIELD", "NOTICE", "INTERCEPT"]:
			s.reports += 1
			if str(t.get("verification", "")).begins_with("UNVERIFIED") or t.get("verification", "") == "APPROVED (CENTRAL)":
				s.unverified += 1
		if t.kind == "INTERCEPT":
			s.intercepts += 1
		if t.get("forwarded", false):
			s.forwarded += 1
	for r in requests:
		if r.state in ["CONFIRMED", "DENIED"]:
			s.requests_answered += 1
	for e in strategic.get("events", []):
		s.launches.append(e)
		s.units_expended += int(e.cost)
	return s


# --- Save / load -----------------------------------------------------------------------------

func has_save() -> bool:
	return not _read_save().is_empty()


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION or data.get("ending", "") != "":
		return {}
	return data


## Collects the scene-side state, then writes everything.
func save() -> void:
	_autosave_t = 0.0
	if not active:
		return
	var tree := get_tree()
	var st := tree.get_first_node_in_group("strategy")
	if st and st.has_method("snapshot"):
		strategic = st.snapshot()
	var om := tree.get_first_node_in_group("orders")
	if om and om.has_method("snapshot"):
		order_snapshot = om.snapshot()
	var data := {
		"version": SAVE_VERSION, "fresh": fresh, "elapsed": elapsed, "clock": clock,
		"trust": trust, "stability": stability, "integrity": integrity,
		"flags": flags, "fired": fired, "applied": applied, "traffic": traffic, "requests": requests,
		"decisions": decisions, "said": said, "sector_status": sector_status, "sector_basis": sector_basis,
		"beers": beers, "cigarettes": cigarettes, "last_vice": last_vice, "last_vice_at": last_vice_at,
		"calls_answered": calls_answered, "calls_missed": calls_missed, "ending": ending,
		"strategic": strategic, "orders": order_snapshot,
	}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)   # never leave a half-written save


## Loads the save into this node. Returns false if there is no valid save.
func load_run() -> bool:
	var d := _read_save()
	if d.is_empty():
		return false
	_reset()
	fresh = d.get("fresh", false)
	elapsed = float(d.elapsed)
	clock = float(d.clock)
	trust = float(d.trust)
	stability = float(d.stability)
	integrity = float(d.integrity)
	flags = d.flags
	fired = d.fired
	applied = d.applied
	for t in d.traffic:
		traffic.append(t)
	for r in d.requests:
		requests.append(r)
	for x in d.decisions:
		decisions.append(x)
	said = d.said
	sector_status = d.sector_status
	sector_basis = d.sector_basis
	beers = int(d.beers)
	cigarettes = int(d.cigarettes)
	last_vice = d.last_vice
	last_vice_at = float(d.last_vice_at)
	calls_answered = int(d.calls_answered)
	calls_missed = int(d.calls_missed)
	strategic = d.strategic
	order_snapshot = d.orders
	active = true
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
