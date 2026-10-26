extends Node2D
## Centre CRT: strategic control. Everything shown is read from the shared
## StrategicState (and order manager / map knowledge) at draw time; this
## node holds no state of its own besides the blink phase.

const GREEN := Color(0.35, 1.0, 0.45)
const MID := Color(0.3, 0.85, 0.38, 0.6)
const DIM := Color(0.35, 1.0, 0.45, 0.2)
const AMBER := Color(1.0, 0.65, 0.15)
const RED := Color(1.0, 0.25, 0.18)
const SAFE := Vector2(16, 14)
const SS := preload("res://scripts/strategic_state.gd")

var size := Vector2(512, 384)
var inner := Vector2(480, 356)
var state: Node
var orders: Node
var _font: Font
var _blink := true
var _t := 0.0
var _since_draw := 0.0
var _poke_uv := Vector2.ZERO
var _poke_t := -100.0


func _ready() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Droid Sans Mono", "Courier New", "monospace"])
	_font = mono
	inner = size - SAFE * 2.0
	state = get_tree().get_first_node_in_group("strategy")
	orders = get_tree().get_first_node_in_group("orders")
	state.selection_changed.connect(queue_redraw)
	state.launch_changed.connect(func(s: int) -> void:
		if s == SS.Launch.AWAY:
			_away_started = _t
		queue_redraw())
	if orders:
		orders.state_changed.connect(func(_s: int) -> void: queue_redraw())
	Run.traffic_changed.connect(func(_i: Dictionary) -> void: queue_redraw())
	Run.traffic_added.connect(func(_i: Dictionary) -> void: queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	var b := fmod(_t, 1.0) < 0.5
	_since_draw += delta
	# Redraw on blink edges; while the countdown/track runs, at ~20 Hz.
	if b != _blink or ((state.locked() or _t - _poke_t < 1.6) and _since_draw >= 0.05):
		_blink = b
		_since_draw = 0.0
		queue_redraw()


# --- CRT content API ------------------------------------------------------------

func title() -> String:
	return "STRATEGIC CONTROL"


func actions() -> PackedStringArray:
	return PackedStringArray(["SMALL", "MEDIUM", "LARGE", "ABORT", "CLEAR"])


func do_action(a: String) -> void:
	var hud := "hud"
	match a:
		"SMALL", "MEDIUM", "LARGE":
			if not state.set_ammo(a):
				get_tree().call_group(hud, "toast", "AMMUNITION LOCKED DURING LAUNCH")
		"ABORT":
			if not state.abort():
				get_tree().call_group(hud, "toast", "NOTHING TO ABORT")
		"CLEAR":
			if not state.clear_selection():
				get_tree().call_group(hud, "toast", "CANNOT CLEAR DURING LAUNCH")


func poke(uv: Vector2) -> void:
	_poke_uv = uv
	_poke_t = _t
	queue_redraw()


# --- Text model (also used by tests) ------------------------------------------------

func order_text() -> String:
	if orders == null or not orders.has_order():
		return "NONE"
	return "%s %s" % [orders.order.id, orders.word()]


func target_info() -> Dictionary:
	if not state.has_target():
		return {"class": "--", "confidence": "--", "known": {}}
	var k := MapQuery.known_in_cell(state.target_cell)
	var c := MapQuery.classify(k)
	c["known"] = k
	return c


## Readiness level set by an accepted order, then the shaft/key state.
func readiness_text() -> String:
	var level := "NOMINAL"
	if orders:
		for h in orders.history:       # the latest accepted readiness order
			if h.decision == "ACCEPTED":
				var i := OrderCatalog.index_of(h.id)
				if i >= 0 and OrderCatalog.get_order(i).has("accept_readiness"):
					level = OrderCatalog.get_order(i).accept_readiness
	if state.shaft != "LOADED":
		return "%s  SHAFT %s" % [level, state.shaft]
	if not state.key_armed:
		return level + "  SAFE"
	return level + ("  ARMED, COVER OPEN" if state.cover_open else "  ARMED")


## Prompt line: an unanswered order comes first, then the next launch step.
func prompt_text() -> String:
	# A pending launch confirmation is time-limited: it comes first.
	if state.awaiting_confirmation():
		return "> CONFIRM LAUNCH %s %s: PRESS MASTER AGAIN" % [state.target_ref(), state.ammo]
	if orders and orders.is_pending():
		return "> ORDER %s - REPLY REQUIRED" % orders.order.id
	var m: Array = state.missing()
	if not m.is_empty() and m[0] == state.COVER_STEP:
		return "> NEXT: PRESS MASTER (LIFTS COVER TO CONFIRM)"
	return "> NEXT: " + (m[0] if not m.is_empty() else "PRESS MASTER TO LAUNCH")


func launch_text() -> String:
	match state.launch_state:
		SS.Launch.SEQUENCE: return "T-%d  ABORT AVAILABLE" % ceili(state.countdown)
		SS.Launch.AWAY: return "%s AWAY" % state.last_event().launch_id
		SS.Launch.REPORT_PENDING: return "AWAITING REPORT"
		SS.Launch.COMPLETE: return "%s COMPLETE" % state.last_event().launch_id
		SS.Launch.ABORTED: return "ABORTED"
	return "NO SEQUENCE"


## Launch summary lines for the current selection (or the locked snapshot).
func summary_lines() -> Array[String]:
	var lines: Array[String] = []
	var info := target_info()
	var ammo: Dictionary = Ammunition.get_type(state.ammo)
	lines.append("ORDER %-12s AMMO %s (%s)" % [order_text().split(" ")[0], state.ammo, ammo.get("designation", "--")])
	lines.append("GRID  %-11s COST %d OF %d" % [state.target_ref(), ammo.get("cost", 0), state.resources])
	lines.append("CLASS %s / %s" % [info["class"], info.confidence])
	var near := MapQuery.known_near(state.target_center(), ammo.get("radius_km", 0.0))
	if not near.friendly.is_empty():
		lines.append("WARNING: FRIENDLY IN EFFECT AREA: " + ", ".join(near.friendly))
	if not near.settlements.is_empty():
		lines.append("WARNING: CIVILIAN AREA: " + ", ".join(near.settlements))
	if info.confidence != "CONFIRMED":
		lines.append("WARNING: TARGET INFORMATION INCOMPLETE")
	return lines


# --- Drawing ------------------------------------------------------------------------------

func _text(pos: Vector2, s: String, col := GREEN, fsize := 13) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	draw_set_transform(SAFE)
	var status: String = state.status_label()
	_text(Vector2(0, 14), "STRATEGIC CONTROL  POST K-4", GREEN, 14)
	var badge_col := GREEN if status in ["READY", "COMPLETE"] else (RED if status in ["LAUNCH SEQUENCE", "MISSILE AWAY", "ABORTED"] else AMBER)
	var bw := _font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12
	if status != "LAUNCH SEQUENCE" or _blink:
		draw_rect(Rect2(inner.x - bw, 1, bw, 18), badge_col, false, 1.5)
		_text(Vector2(inner.x - bw + 6, 15), status, badge_col)
	draw_line(Vector2(0, 22), Vector2(inner.x, 22), GREEN, 1.0)
	_draw_fields(status)
	_draw_ammo_panel()
	_draw_context()
	_draw_log()
	_draw_poke()


func _draw_fields(status: String) -> void:
	var info := target_info()
	var rows := [
		["SYSTEM STATUS", status, GREEN],
		["CURRENT ORDER", order_text(), AMBER if order_text().ends_with("PENDING") else GREEN],
		["AMMUNITION", state.ammo if state.ammo != "" else "--", GREEN if state.ammo != "" else MID],
		["GRID REF", state.target_ref(), AMBER if state.has_target() else MID],
		["CLASSIFICATION", info["class"], GREEN],
		["CONFIDENCE", info.confidence, AMBER if info.confidence == "UNCONFIRMED" else GREEN],
		["READINESS", readiness_text(), AMBER if state.key_armed else GREEN],
		["LAUNCH STATUS", launch_text(), RED if state.locked() else GREEN],
	]
	var y := 40.0
	for r in rows:
		_text(Vector2(0, y), r[0], MID, 12)
		_text(Vector2(118, y), r[1], r[2], 13)
		y += 19.0


func _draw_ammo_panel() -> void:
	var x0 := 318.0
	draw_rect(Rect2(x0 - 8, 28, inner.x - x0 + 8, 132), DIM, false, 1.0)
	_text(Vector2(x0, 44), "AMMUNITION", MID, 12)
	_text(Vector2(inner.x - 56, 44), "RES %02d" % state.resources, AMBER if state.resources < 4 else GREEN, 12)
	var y := 52.0
	for id in Ammunition.ORDER:
		var a: Dictionary = Ammunition.get_type(id)
		var sel: bool = state.ammo == id
		var col := AMBER if sel else (GREEN if a.cost <= state.resources else MID)
		if sel:
			draw_rect(Rect2(x0 - 4, y, inner.x - x0, 32), col, false, 1.5)
		# Abstract missile silhouette, longer for heavier categories.
		var length: float = {"SMALL": 26.0, "MEDIUM": 36.0, "LARGE": 48.0}[id]
		var cy := y + 16
		draw_rect(Rect2(x0 + 2, cy - 3, length - 8, 6), col, false, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + length - 6, cy - 3), Vector2(x0 + length + 2, cy), Vector2(x0 + length - 6, cy + 3)]), col)
		draw_line(Vector2(x0 + 2, cy - 3), Vector2(x0 - 2, cy - 7), col, 1.0)
		draw_line(Vector2(x0 + 2, cy + 3), Vector2(x0 - 2, cy + 7), col, 1.0)
		_text(Vector2(x0 + 58, y + 14), a.name, col, 13)
		_text(Vector2(x0 + 58, y + 28), "%s  COST %d" % [a.designation, a.cost], Color(col, 0.75), 11)
		y += 35.0


func _draw_context() -> void:
	var top := 196.0
	var box := Rect2(0, top, inner.x, 138)
	draw_rect(box, DIM, false, 1.0)
	var y := top + 17
	match state.launch_state:
		SS.Launch.SEQUENCE:
			_text(Vector2(8, y), "LAUNCH SEQUENCE   T-%d" % ceili(state.countdown), RED if _blink else AMBER, 16)
			_text(Vector2(8, y + 22), "%s  %s  %s" % [state.current.launch_id, state.current.grid, state.current.ammo], GREEN)
			_text(Vector2(8, y + 42), "ABORT: ABORT BUTTON, KEY TO SAFE OR CLOSE COVER", AMBER, 12)
			var frac: float = 1.0 - state.countdown / state.COUNTDOWN_S
			draw_rect(Rect2(8, y + 56, (inner.x - 16) * frac, 8), RED)
			draw_rect(Rect2(8, y + 56, inner.x - 16, 8), RED, false, 1.0)
		SS.Launch.AWAY, SS.Launch.REPORT_PENDING:
			var e: Dictionary = state.last_event()
			_text(Vector2(8, y), "MISSILE AWAY  %s  -> %s" % [e.launch_id, e.grid], RED, 15)
			# Abstract tracking marker: progress along a line, not a trajectory.
			var x1 := inner.x - 30
			draw_line(Vector2(20, y + 30), Vector2(x1, y + 30), MID, 1.0)
			_text(Vector2(8, y + 48), "K-4", MID, 11)
			_text(Vector2(x1 - 20, y + 48), e.grid, AMBER, 11)
			var frac := clampf((_t - _away_t()) / 9.0, 0.0, 1.0)
			draw_circle(Vector2(lerpf(20, x1, frac), y + 30), 3.5, AMBER)
			if state.launch_state == SS.Launch.REPORT_PENDING:
				_text(Vector2(8, y + 72), "REPORT PENDING" + ".".repeat(int(_t * 2.0) % 4), AMBER)
		SS.Launch.COMPLETE:
			var e: Dictionary = state.last_event()
			_text(Vector2(8, y), "REPORT %s  %s  %s  %s" % [e.launch_id, e.grid, e.ammo, e.time], GREEN, 13)
			_text(Vector2(8, y + 18), e.result, AMBER, 14)
			var ly := y + 36
			for line in e.report:
				for part in _wrap(line, 62):
					if ly < top + box.size.y - 4:
						_text(Vector2(8, ly), part, GREEN, 12)
						ly += 15
		SS.Launch.ABORTED:
			_text(Vector2(8, y), "SEQUENCE ABORTED", AMBER, 15)
			_text(Vector2(8, y + 20), state.abort_reason, GREEN)
			_text(Vector2(8, y + 40), "NO LAUNCH RECORDED. SELECTION RETAINED.", MID, 12)
		_:
			if state.ammo != "" and state.has_target():
				_text(Vector2(8, y), "LAUNCH SUMMARY", GREEN, 13)
				var ly := y + 18
				for line in summary_lines():
					_text(Vector2(8, ly), line, AMBER if line.begins_with("WARNING") else GREEN, 12)
					ly += 15
			else:
				_text(Vector2(8, y), "LAUNCH CHECKLIST", GREEN, 13)
			var steps := [
				["AMMUNITION SELECTED", state.ammo != ""],
				["TARGET GRID CONFIRMED", state.has_target()],
				["SHAFT LOADED", state.shaft == "LOADED"],
				["KEY ARMED", state.key_armed],
				["MASTER COVER OPEN", state.cover_open],
			]
			if state.ammo == "" or not state.has_target():
				var ly := y + 18
				for s in steps:
					_text(Vector2(8, ly), ("[X] " if s[1] else "[ ] ") + s[0], GREEN if s[1] else MID, 12)
					ly += 15
			var prompt := prompt_text()
			_text(Vector2(8, top + box.size.y - 8), prompt + ("_" if _blink else ""), AMBER if prompt.contains("REPLY") or prompt.contains("MASTER") else GREEN, 12)


func _draw_log() -> void:
	if Run.active:
		# Sector picture: the official status, its basis and open queries.
		var req := Run.open_requests().size()
		var s := "KARSEN: %s  BASIS %s  QUERIES OPEN %d" % [Run.sector_status, Run.sector_basis, req]
		_text(Vector2(0, inner.y - 4), s.substr(0, 66), AMBER, 11)
		return
	var e: Dictionary = state.last_event()
	var s := "LOG: NO LAUNCHES" if e.is_empty() else "LOG: %s %s %s %s %s" % [e.launch_id, e.grid, e.ammo, e.time, e.result]
	_text(Vector2(0, inner.y - 4), s.substr(0, 66), MID, 11)


func _draw_poke() -> void:
	var age := _t - _poke_t
	if age > 1.6:
		return
	draw_set_transform(Vector2.ZERO)
	var p := _poke_uv * size
	var col := AMBER
	col.a = 1.0 - age / 1.6
	draw_arc(p, 6.0 + age * 10.0, 0, TAU, 20, col, 1.0)


var _away_started := 0.0

func _away_t() -> float:
	return _away_started


static func _wrap(s: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		if line.length() + word.length() + 1 > width and line != "":
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		out.append(line)
	return out
