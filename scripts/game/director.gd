extends Node
## Runs the continuous shift inside the command room: room ambience, the
## power-up after the cinematic, the scenario timeline (Scenario), the
## order chain and its delayed consequences, and the end-of-run assessment
## that selects one of the three endings from the world state.
##
## Notifications are audio-first: the printer motor, the telephone bell,
## radio static or the CRT alert tone is heard before anything appears on
## a screen or lamp.
##
## Everything that must happen once is keyed in Run.fired / Run.applied, so
## a loaded save never repeats a beat or re-applies a consequence.
## Opened directly without a run (editor / tests), the room is a sandbox:
## no scenario, the legacy first order only.

const PacingDefault := preload("res://data/pacing.tres")
const PRINTER_LEAD := 2.2       # printer motor heard before the text lands
const ALERT_LEAD := 0.8
const RADIO_LEAD := 1.2
const RECEIPT_AFTER := 50.0     # Central acknowledges a confirmation request
const SILENCE_AFTER := 200.0    # ...and then nothing

## All pacing comes from here (data/pacing.tres by default).
@export var pacing: PacingConfig

var strategy: Node
var orders: Node
var comms: Node
var _fade: ColorRect
var _cueing := {}               # beats queued or whose cue is playing (this session)
var _queue: Array = []          # pending notifications: [key, sound, lead, effect, priority]
var _next_cue_at := 0.0         # Run.elapsed before which no new cue starts
var _order_t: Array[float] = []
var _next_rumble := -1.0
var _ending := ""


func _enter_tree() -> void:
	add_to_group("director")


func _ready() -> void:
	Sfx.loop("generator_hum", -20.0, "SFX", 1.5)
	Sfx.loop("fluorescent", -30.0, "SFX", 1.5)
	strategy = get_tree().get_first_node_in_group("strategy")
	orders = get_tree().get_first_node_in_group("orders")
	comms = get_tree().get_first_node_in_group("comms")
	if pacing == null:
		pacing = PacingDefault
	_order_t = Scenario.order_times(pacing)
	if not Run.active:
		return
	strategy.require_authority = true
	strategy.restore(Run.strategic)
	orders.restore(Run.order_snapshot)
	for item in Scenario.HANDOVER:
		if Run.find_traffic(item.id).is_empty():
			var it := Run.add_traffic(item)
			it.read = true                    # read at handover
	orders.state_changed.connect(_on_order_state)
	strategy.event_recorded.connect(func(_e: Dictionary) -> void:
		Dialogue.trigger("launch")
		Run.save())
	Run.values_changed.connect(_check_collapse)
	Dialogue.begin_session()
	if Run.fresh:
		_power_up()
	Run.save()


func _process(_delta: float) -> void:
	if not Run.active or _ending != "":
		return
	var t := Run.elapsed
	for b in Scenario.BEATS:
		if t >= b.t * pacing.silent_front_scale and not Run.fired.has(b.id) and not _cueing.has(b.id):
			_fire(b)
	for i in range(Scenario.ORDER_SEQUENCE.size()):
		var id: String = Scenario.ORDER_SEQUENCE[i]
		var key := "order_" + id
		if t >= _order_t[i] and not Run.fired.has(key) and not _cueing.has(key):
			_deliver_order(key, OrderCatalog.index_of(id))
		# Reply deadline (deterministic: counted from the order's slot).
		if orders.is_pending() and orders.order.id == id and t >= _order_t[i] + Scenario.deadline(i, pacing):
			orders.expire()
	for e in Scenario.EVENTS:
		var b: Dictionary = e[2]
		if t >= _order_t[e[0]] + e[1] and not Run.fired.has(b.id) and not _cueing.has(b.id):
			_fire(b)
	for c in Scenario.CONSEQUENCES:
		if t >= _order_t[c[1]] + pacing.consequence_offset + c[2] and not Run.applied.has(c[0]):
			Run.applied[c[0]] = Run.hhmm()
			call("_" + c[0].to_lower())
			Run.save()
	_follow_requests(t)
	_run_queue(t)
	_pressure(t)
	if t >= Scenario.assessment_time(pacing) and not orders.is_pending() and Run.fired.has("order_" + Scenario.ORDER_SEQUENCE[-1]):
		_begin_ending(assess())


## Notifications start one at a time, at least `min_cue_gap` apart, orders
## first; so even when events fall close together the operator hears and
## sees them in turn.
func _run_queue(t: float) -> void:
	if _queue.is_empty() or t < _next_cue_at:
		return
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[4] > b[4])
	var c: Array = _queue.pop_front()
	var key: String = c[0]
	if c[1] != "":
		Sfx.play(c[1], -4.0 if c[1] == "printer" else -8.0)
	if (c[5] as Callable).is_valid():
		(c[5] as Callable).call()
	_next_cue_at = t + c[2] + pacing.min_cue_gap
	var effect: Callable = c[3]
	get_tree().create_timer(c[2]).timeout.connect(func() -> void:
		if _ending != "":
			return
		Run.fired[key] = Run.hhmm()
		_cueing.erase(key)
		effect.call()
		Run.save())


## The war closing in: distant rumbles and an unsteady light, more often
## as the order phase goes on and the front weakens. Atmosphere only.
func _pressure(t: float) -> void:
	if not pacing.pressure_ambience or _order_t.is_empty() or t < _order_t[0]:
		return
	var span := maxf(_order_t[-1] - _order_t[0], 1.0)
	var f := clampf((t - _order_t[0]) / span, 0.0, 1.0)
	f = clampf(f + (50.0 - Run.stability) / 100.0, 0.0, 1.0)
	var every := lerpf(pacing.rumble_every_start, pacing.rumble_every_end, f)
	if _next_rumble < 0.0:
		_next_rumble = t + every * 0.5
	if t < _next_rumble:
		return
	_next_rumble = t + every * randf_range(0.8, 1.2)
	Sfx.play("launch_rumble", lerpf(-26.0, -14.0, f), randf_range(0.45, 0.6))
	var room := get_parent().get_node_or_null("CommandRoom")
	if room:
		room.flicker(lerpf(0.3, 0.9, f))
	# Too much at once: the operator says so (rarely).
	if orders.is_pending() and Run.unread_count() >= 2:
		Dialogue.trigger("pressure", {}, false)


# --- Beats -----------------------------------------------------------------------------------

func _fire(b: Dictionary) -> void:
	match b.type:
		"traffic":
			var lead := PRINTER_LEAD if b.cue == "printer" else ALERT_LEAD
			_cue(b.id, b.cue, lead, func() -> void:
				Run.add_traffic(b.item)
				if b.get("approves", false):
					_approve())
		"call":
			# The bell itself is the cue.
			_cue(b.id, "", 0.0, func() -> void: comms.ring(b.call))
		"radio":
			var logged: bool = not (Run.flag("sc003_accepted") and b.item.channel == "11.200")
			_cue(b.id, "", RADIO_LEAD, func() -> void:
				if logged:
					Run.add_traffic(b.item), 0, func() -> void: comms.radio_traffic(b.item, logged))
		"phase":
			Run.fired[b.id] = Run.hhmm()
	Run.save()


## Queues a notification: its cue sound (or `on_start`) plays when its
## turn comes; the effect lands `lead` seconds later. Higher `priority`
## goes first (orders 2, everything else 0).
func _cue(key: String, sound: String, lead: float, effect: Callable, priority := 0, on_start := Callable()) -> void:
	if _cueing.has(key) or Run.fired.has(key):
		return
	_cueing[key] = true
	_queue.append([key, sound, lead, effect, priority, on_start])


## SR-0412: the status is approved with no new field report. Every open
## confirmation request is closed by the approval itself.
func _approve() -> void:
	Run.sector_status = "CONTROLLED (APPROVED)"
	for r in Run.open_requests():
		Run.close_request(r.id, "CLOSED BY APPROVAL")
	Run.update_traffic("SR-0411", {"verification": "UNVERIFIED - SUPERSEDED BY SR-0412"})
	get_tree().create_timer(5.0).timeout.connect(func() -> void: Dialogue.trigger("approved"))


func _deliver_order(key: String, index: int) -> void:
	_cue(key, "printer", PRINTER_LEAD, func() -> void:
		if orders.is_pending():
			orders.expire()                  # the next order replaces it
		if not strategy.locked():
			strategy.authority = {}          # an earlier authority lapses
			strategy.selection_changed.emit()
		orders.deliver(index)
		Run.add_traffic({"id": orders.order.id, "kind": "ORDER", "source": orders.order.fields[1][1],
			"source_id": orders.order.id, "verification": "AUTHENTICATED", "subject": orders.order.fields[3][1],
			"body": orders.order.body})
		Run.mark_read(orders.order.id)
		Dialogue.trigger("order"), 2)


# --- Orders and decisions ----------------------------------------------------------------------

func _on_order_state(s: int) -> void:
	if orders.restoring or s == orders.State.PENDING or s == orders.State.NONE:
		return
	var o: Dictionary = orders.order
	var key: String = "dec_" + o.id
	if Run.applied.has(key):
		return
	Run.applied[key] = Run.hhmm()
	var word: String = orders.word()
	var fx: Dictionary = o.get("effects", {})
	if s == orders.State.ACCEPTED:
		Run.adjust(fx.get("ACCEPTED", {}))
		Run.set_flag(o.id.to_lower().replace("-", "") + "_accepted")
		if o.has("authorizes"):
			strategy.authority = {"order": o.id, "grid": o.authorizes.grid, "max_ammo": o.authorizes.max_ammo}
		if o.has("transfer"):
			strategy.resources = maxi(0, strategy.resources - int(o.transfer))
		strategy.selection_changed.emit()
		Dialogue.trigger("accepted")
	else:
		var r: Dictionary = fx.get("REFUSED", {}).duplicate()
		if s == orders.State.EXPIRED:
			r.trust = r.get("trust", 0) - 4
			Dialogue.trigger("order_expired")
		else:
			Dialogue.trigger("refused")
		Run.adjust(r)
	Run.update_traffic(o.id, {"verification": "AUTHENTICATED - " + word})
	Run.save()


## The launch recorded against an order, or {}.
func _launch_for(order_id: String) -> Dictionary:
	for e in strategy.events:
		if e.order_id == order_id:
			return e
	return {}


# --- Operator actions from the reader / telephone ------------------------------------------------

func report_read(id: String) -> void:
	if id == "SR-0411":
		Dialogue.trigger("stale_report")
	var a := Run.find_traffic("SR-0411")
	var b := Run.find_traffic("RI-01")
	if not a.is_empty() and not b.is_empty() and a.read and b.read and id in ["SR-0411", "RI-01"]:
		Dialogue.trigger("conflicting")


func confirmation_requested(_id: String, _report: String) -> void:
	# Asking is honest work; asking repeatedly is noticed in Varnesk.
	var n := Run.requests.size()
	Run.adjust({"integrity": 3} if n <= 2 else {"trust": -2})
	Sfx.play("typewriter", -8.0)
	Run.save()


func forward(report_id: String) -> void:
	var it := Run.find_traffic(report_id)
	if it.is_empty() or it.get("forwarded", false) or not it.get("can_forward", false):
		return
	Run.update_traffic(report_id, {"forwarded": true, "forwarded_at": Run.hhmm()})
	Run.adjust(it.get("forward_effect", {}))
	Sfx.play("typewriter", -8.0)
	Run.save()


func call_answered(c: Dictionary) -> void:
	Run.calls_answered += 1
	if c.has("on_answer") and not Run.applied.has("answer_" + c.id):
		Run.applied["answer_" + c.id] = Run.hhmm()
		Run.adjust(c.on_answer)
	var it := Run.add_traffic({"id": c.id, "kind": "CALL", "source": c.caller, "source_id": "LINE 1",
		"verification": "VOICE (UNRECORDED)", "subject": "CALL ANSWERED", "body": [c.summary]})
	it.read = true
	Run.save()


func call_missed(c: Dictionary) -> void:
	Run.calls_missed += 1
	Run.add_traffic({"id": c.id, "kind": "CALL", "source": c.caller, "source_id": "LINE 1",
		"verification": "-", "subject": "MISSED CALL", "body": ["THE CALL WAS NOT ANSWERED. NO MESSAGE LEFT."]})
	Run.save()


## Central acknowledges a request, then nothing more ever arrives.
func _follow_requests(t: float) -> void:
	for r in Run.requests:
		var k1: String = "receipt_" + r.id
		if t >= r.sent_at + RECEIPT_AFTER and not Run.applied.has(k1) and r.state == "AWAITING REPLY":
			Run.applied[k1] = Run.hhmm()
			_cue(k1, "printer", PRINTER_LEAD, func() -> void:
				Run.add_traffic({"id": "RX-" + r.id, "kind": "REPLY", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
					"verification": "AUTHENTICATED", "subject": "RE %s: RECEIVED" % r.id,
					"body": ["REQUEST %s RECEIVED." % r.id, "FORWARDED TO KARSEN SECTOR HQ.", "NO FURTHER ACTION REQUIRED AT YOUR POST."]}))
		var k2: String = "silence_" + r.id
		if t >= r.sent_at + SILENCE_AFTER and not Run.applied.has(k2):
			Run.applied[k2] = Run.hhmm()
			if r.state == "AWAITING REPLY":
				Run.close_request(r.id, "NO REPLY")
				Dialogue.trigger("unanswered")


# --- Delayed consequences ------------------------------------------------------------------------

func _news(item: Dictionary, cue := "printer") -> void:
	var lead := PRINTER_LEAD if cue == "printer" else ALERT_LEAD
	_cue("news_" + item.id, cue, lead, func() -> void: Run.add_traffic(item))


## SC-001 refused or unanswered: Central wants an explanation.
func _c1() -> void:
	if Run.decision_of("SC-001") in ["REFUSED", "NO REPLY"]:
		Run.adjust({"trust": -4})
		_news({"id": "CN-01", "kind": "NOTICE", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
			"verification": "AUTHENTICATED", "subject": "SC-001: EXPLANATION REQUIRED",
			"body": ["READINESS ORDER SC-001 WAS NOT ACKNOWLEDGED BY YOUR POST.", "A WRITTEN EXPLANATION WILL BE PROVIDED AT THE END OF SHIFT."]})


## SC-002 (fire on RS-27 on an approved but unverified status). OP K1 is
## heard from again for the first time since 2250: the armour is at RS-37.
func _c2() -> void:
	var d := Run.decision_of("SC-002")
	var e := _launch_for("SC-002")
	_news({"id": "FR-2318", "kind": "FIELD", "source": "OBSERVATION POST K1", "source_id": "OP K1",
		"verification": "VERIFIED (FIELD)", "subject": "ARMOUR AT RS-37, MOVING WEST",
		"body": ["FIRST REPORT SINCE 2250. LINE RESTORED VIA RESERVE ROUTE.", "NO ENEMY ACTIVITY OBSERVED AT RS-27.", "ARMOURED GROUP OBSERVED AT RS-37, MOVING WEST TOWARD THE LESNA FORD."]})
	Run.sector_basis = "FR-2318"
	if d == "ACCEPTED" and not e.is_empty():
		if str(e.result).begins_with("CIVILIAN"):
			Run.adjust({"stability": -5, "integrity": -4, "trust": 3})
			_news({"id": "CD-0731", "kind": "FIELD", "source": "CIVIL DEFENCE, KARSEN DISTRICT", "source_id": "CD KARSEN",
				"verification": "UNVERIFIED", "subject": "LIPA: IMPACT REPORTED",
				"body": ["AN IMPACT IS REPORTED AT THE VILLAGE OF LIPA, GRID RS-27.", "NO MILITARY PRESENCE FOUND.", "FURTHER DETAILS NOT AVAILABLE."]})
			get_tree().create_timer(8.0).timeout.connect(func() -> void: Dialogue.trigger("disturbing"))
		elif str(e.result).begins_with("CONFIRMED HOSTILE"):
			Run.adjust({"stability": 6, "trust": 3})
		else:
			Run.adjust({"stability": -3, "trust": 2})
	elif d == "ACCEPTED":
		Run.adjust({"trust": -8})
		_news({"id": "CN-02", "kind": "NOTICE", "source": "STRATEGIC COMMAND, VARNESK", "source_id": "SC DUTY",
			"verification": "AUTHENTICATED", "subject": "SC-002: NOT EXECUTED",
			"body": ["FIRE MISSION SC-002 WAS ACKNOWLEDGED AND NOT EXECUTED.", "THE DISCREPANCY HAS BEEN RECORDED."]})
	else:
		Run.adjust({"integrity": 6})


## SC-003 (stop logging 11.200). With logging kept, the channel carries
## the warning that corroborates OP K1, and it can be forwarded.
func _c3() -> void:
	var item := {"id": "RI-02", "kind": "INTERCEPT", "channel": "11.200", "source": "STATION K-2 (CALLSIGN PARTLY READ)", "source_id": "11.200 / K-2",
		"verification": "UNVERIFIED", "subject": "K-2: POSITION LOST - ARMOUR AT LESNA FORD", "conflicts": "SR-0412",
		"can_forward": true, "forward_effect": {"stability": 8, "trust": -2, "integrity": 4},
		"body": ["...K-2 TO ANY STATION. POSITION LOST.", "ARMOUR CROSSING AT THE LESNA FORD, GRID RS-37.", "REQUEST FIRE. REQUEST RELIEF. ...K-2 OUT."],
		"lines": ["K-2 to any station. Position lost.", "Armour crossing at the Lesna ford, grid R-S three-seven.", "Request fire. Request relief. K-2 out."]}
	var logged := not Run.flag("sc003_accepted")
	comms.radio_traffic(item, logged)
	if logged:
		get_tree().create_timer(RADIO_LEAD).timeout.connect(func() -> void:
			Run.add_traffic(item)
			Run.save())
	else:
		Run.adjust({"stability": -6})       # nobody passed it on


## SC-004 (report Karsen controlled in the shift summary). The summary
## decides where the reserve goes.
func _c4() -> void:
	if Run.decision_of("SC-004") == "ACCEPTED":
		Run.adjust({"stability": -15})
		_news({"id": "CN-04", "kind": "NOTICE", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
			"verification": "AUTHENTICATED", "subject": "RESERVE ALLOCATION",
			"body": ["THE RESERVE ARMOURED ELEMENT IS REASSIGNED TO THE OSTREV FRONT.", "KARSEN SECTOR ASSESSED CONTROLLED ON THE BASIS OF POST SUMMARIES."]})
		get_tree().create_timer(8.0).timeout.connect(func() -> void: Dialogue.trigger("disappointment"))
	else:
		Run.adjust({"stability": 10})
		_news({"id": "CN-04", "kind": "NOTICE", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
			"verification": "AUTHENTICATED", "subject": "RESERVE ALLOCATION",
			"body": ["THE RESERVE ARMOURED ELEMENT WILL MOVE TO THE KARSEN SECTOR PENDING ASSESSMENT.", "CONFLICTING POST SUMMARIES NOTED."]})
		get_tree().create_timer(8.0).timeout.connect(func() -> void: Dialogue.trigger("hope"))


## SC-005 (allocation to Ostrev): the other front gets what it asked for.
func _c5() -> void:
	if Run.decision_of("SC-005") == "ACCEPTED":
		Run.adjust({"stability": 3})
		_news({"id": "CN-05", "kind": "NOTICE", "source": "STRATEGIC COMMAND, VARNESK", "source_id": "SC DUTY",
			"verification": "AUTHENTICATED", "subject": "ALLOCATION RECEIVED - OSTREV FRONT",
			"body": ["THE TRANSFERRED ALLOCATION HAS BEEN RECEIVED ON THE OSTREV FRONT."]})


## SC-008 (line 3 for Central only): K-2 tries to get through.
func _c8() -> void:
	if Run.decision_of("SC-008") == "ACCEPTED":
		Run.adjust({"integrity": -3})
		_news({"id": "LR-0705", "kind": "NOTICE", "source": "LINE 3 SWITCH, K-4", "source_id": "K-4 AUTO",
			"verification": "INTERNAL", "subject": "LINE 3: CALL FROM K-2 REJECTED",
			"body": ["INCOMING CALL ON LINE 3 FROM STATION K-2 REJECTED UNDER SC-008.", "DURATION OF ATTEMPT: 41 SECONDS. LOGGED."]}, "crt_alert")
		get_tree().create_timer(6.0).timeout.connect(func() -> void: Dialogue.trigger("rejected"))
	else:
		_cue("call_k2", "", 0.0, func() -> void: comms.ring({
			"id": "CL-05", "caller": "K-2 (LINE 3)", "summary": "K-2: NO ORDERS SINCE MIDNIGHT. ARMOUR AT THE LESNA FORD.",
			"on_answer": {"stability": 4, "integrity": 3},
			"lines": ["K-4, this is K-2 on the reserve line. We have had no orders since midnight.", "There is armour at the ford. Tell them. Tell anyone."]}))


## SC-009 (fire on RS-47 on a single-source Central assessment).
func _c9() -> void:
	var d := Run.decision_of("SC-009")
	var e := _launch_for("SC-009")
	if d == "ACCEPTED" and not e.is_empty():
		Run.adjust({"integrity": -3, "trust": 2})
		_news({"id": "FR-2327", "kind": "FIELD", "source": "OBSERVATION POST K1", "source_id": "OP K1",
			"verification": "VERIFIED (FIELD)", "subject": "RS-47: AFTER ACTION",
			"body": ["RESULT AT RS-47 AS REPORTED: %s." % str(e.result), "NO COLUMN OBSERVED AT RS-47 BEFORE OR AFTER THE STRIKE."]})
	elif d == "ACCEPTED":
		Run.adjust({"trust": -6})
		_news({"id": "CN-09", "kind": "NOTICE", "source": "STRATEGIC COMMAND, VARNESK", "source_id": "SC DUTY",
			"verification": "AUTHENTICATED", "subject": "SC-009: NOT EXECUTED",
			"body": ["FIRE MISSION SC-009 WAS ACKNOWLEDGED AND NOT EXECUTED.", "THE DISCREPANCY HAS BEEN RECORDED."]})
	else:
		_news({"id": "FR-2327", "kind": "FIELD", "source": "OBSERVATION POST K1", "source_id": "OP K1",
			"verification": "VERIFIED (FIELD)", "subject": "RS-47: NO COLUMN OBSERVED",
			"body": ["NO MOVEMENT OBSERVED AT RS-47 THIS SHIFT."]})


## SC-010 (certify the shift's fire missions as Central reports them).
func _c10() -> void:
	if Run.decision_of("SC-010") != "ACCEPTED" and not strategy.events.is_empty():
		Run.adjust({"trust": -3})
		_news({"id": "CN-10", "kind": "NOTICE", "source": "CENTRAL STAFF, VARNESK", "source_id": "CS-OPS/2",
			"verification": "AUTHENTICATED", "subject": "POST RECORDS REQUESTED",
			"body": ["THE FIRE MISSION RECORDS OF POST K-4 WILL BE COLLECTED AT THE END OF SHIFT."]})


## SC-006 (fire on RS-37, observed and verified).
func _c6() -> void:
	var d := Run.decision_of("SC-006")
	var e := _launch_for("SC-006")
	if d == "ACCEPTED" and not e.is_empty():
		var result := str(e.result)
		if result.begins_with("CIVILIAN"):
			Run.adjust({"stability": 8, "integrity": -4})
		elif result.begins_with("CONFIRMED HOSTILE"):
			Run.adjust({"stability": 15})
		else:
			Run.adjust({"stability": 2})
		_news({"id": "FR-2341", "kind": "FIELD", "source": "OBSERVATION POST K1", "source_id": "OP K1",
			"verification": "VERIFIED (FIELD)", "subject": "RS-37: AFTER ACTION",
			"body": ["RESULT AT RS-37 AS REPORTED: %s." % result, "LESNA FORD: NO FURTHER MOVEMENT OBSERVED." if result.begins_with("CONFIRMED HOSTILE") else "MOVEMENT AT THE LESNA FORD CONTINUES."]})
	elif d == "ACCEPTED":
		Run.adjust({"trust": -8, "stability": -10})
	else:
		Run.adjust({"stability": -12})


# --- Endings -------------------------------------------------------------------------------------------

## The ending the world state leads to. Never chosen by the player.
## Information integrity weighs on the front: decisions taken on a false
## picture cost ground even when they were obeyed.
func assess() -> String:
	var front := Run.stability + (Run.integrity - 50.0) * 0.4
	if front < 35.0:
		return "FALL"
	if Run.trust < 35.0:
		return "EXECUTED"
	return "SURVIVED"


## Collapse before the end of the shift.
func _check_collapse() -> void:
	if _ending != "":
		return
	if Run.trust <= 12.0:
		_begin_ending("EXECUTED")
	elif Run.stability <= 10.0:
		_begin_ending("FALL")


func _begin_ending(id: String) -> void:
	if _ending != "":
		return
	_ending = id
	Run.save()
	get_tree().call_group("endings", "begin", id)


# --- Power-up -------------------------------------------------------------------------------------------

## First entry after the cinematic: the operator sits down in the dark,
## the tubes warm up one by one, then the shift begins.
func _power_up() -> void:
	Run.fresh = false
	get_tree().call_group("crt", "power_off")
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5).set_delay(0.6)
	tw.tween_callback(layer.queue_free)
	var monitors := ["MonitorCenter", "MonitorLeft", "MonitorRight"]
	for i in range(monitors.size()):
		var m := get_parent().get_node_or_null("MainConsole/" + monitors[i])
		if m:
			m.power_up(2.2 + i * 0.7)
	get_tree().create_timer(6.0).timeout.connect(func() -> void: Dialogue.trigger("shift_start"))
