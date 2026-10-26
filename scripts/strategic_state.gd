extends Node
## The single authoritative state shared by the tactical map, the desk
## controls, the strategic-control CRT, the launch controller and reports.
##
## Map positions are MapGrid kilometres. The map view (centre + zoom) and
## its projection to the map screen live here too, so every consumer uses
## the same conversion. A launch always uses the confirmed target cell
## snapshot, never a screen position.

signal map_changed
signal selection_changed
signal launch_changed(state: Launch)
signal event_recorded(event: Dictionary)

enum Launch { IDLE, SEQUENCE, AWAY, REPORT_PENDING, COMPLETE, ABORTED }

const LAYERS := ["TERRAIN", "HYDROGRAPHY", "ROADS", "RAILWAYS", "SETTLEMENTS", "FRONT", "UNITS", "INTELLIGENCE", "GRID"]
const LAYER_TAGS := ["TER", "HYD", "RDS", "RLY", "SET", "FRT", "UNT", "INT", "GRD"]
## Map screen drawing area in texture pixels (set by the map renderer).
var view_px := Vector2(512, 330)
const MAX_ZOOM := 40.0                     # texture px per km
const PAN_MARGIN_KM := 6.0
const COUNTDOWN_S := 5.0

var map_center := MapGrid.EXTENT * 0.5
var map_zoom := 1.0                        # set to the fit-all zoom in _ready
var cursor := Vector2(70, 48)
var target_cell := Vector2i(-1, -1)
var ammo := ""
var key_armed := false
var cover_open := false
var launch_state: Launch = Launch.IDLE
var countdown := 0.0
var shaft := "LOADED"                      # LOADED, OPEN, EMPTY, RELOADING
var resources := Ammunition.STARTING_RESOURCES
var layers := {}
var layer_index := 0
var events: Array[Dictionary] = []
var current: Dictionary = {}               # snapshot of the launch in progress
var abort_reason := ""


func _enter_tree() -> void:
	add_to_group("strategy")
	for l in LAYERS:
		layers[l] = true


func _ready() -> void:
	map_zoom = min_zoom()


# --- Map view -----------------------------------------------------------------

func min_zoom() -> float:
	return minf(view_px.x / MapGrid.EXTENT.x, view_px.y / MapGrid.EXTENT.y)


## Kilometres -> pixels inside the map drawing area.
func km_to_view(km: Vector2) -> Vector2:
	return view_px * 0.5 + (km - map_center) * map_zoom


## Pixels inside the map drawing area -> kilometres.
func view_to_km(px: Vector2) -> Vector2:
	return map_center + (px - view_px * 0.5) / map_zoom


func view_rect_km() -> Rect2:
	var half := view_px * 0.5 / map_zoom
	return Rect2(map_center - half, half * 2.0)


func pan_km(delta: Vector2) -> void:
	map_center += delta
	_clamp_view()
	_keep_cursor_in_view()
	map_changed.emit()


func zoom_by(factor: float) -> void:
	map_zoom = clampf(map_zoom * factor, min_zoom(), MAX_ZOOM)
	_clamp_view()
	_keep_cursor_in_view()
	map_changed.emit()


## Moves the cursor; the view follows if the cursor would leave it.
func move_cursor(delta_km: Vector2) -> void:
	cursor = (cursor + delta_km).clamp(Vector2.ZERO, MapGrid.EXTENT - Vector2(0.001, 0.001))
	var r := view_rect_km().grow(-1.0 / map_zoom * 8.0)
	if not r.has_point(cursor):
		var shift := Vector2(
			minf(0.0, cursor.x - r.position.x) + maxf(0.0, cursor.x - r.end.x),
			minf(0.0, cursor.y - r.position.y) + maxf(0.0, cursor.y - r.end.y))
		map_center += shift
		_clamp_view()
	map_changed.emit()


func _clamp_view() -> void:
	var half := view_px * 0.5 / map_zoom
	for axis in [0, 1]:
		var lo: float = half[axis] - PAN_MARGIN_KM
		var hi: float = MapGrid.EXTENT[axis] - half[axis] + PAN_MARGIN_KM
		map_center[axis] = MapGrid.EXTENT[axis] * 0.5 if lo > hi else clampf(map_center[axis], lo, hi)


func _keep_cursor_in_view() -> void:
	var r := view_rect_km().grow(-8.0 / map_zoom)
	if r.size.x > 0.0 and r.size.y > 0.0:
		cursor = cursor.clamp(r.position, r.end)


func set_layer_index(i: int) -> void:
	layer_index = posmod(i, LAYERS.size())
	map_changed.emit()


func toggle_layer() -> void:
	var l: String = LAYERS[layer_index]
	layers[l] = not layers[l]
	map_changed.emit()


# --- Selection ------------------------------------------------------------------

func locked() -> bool:
	return launch_state in [Launch.SEQUENCE, Launch.AWAY, Launch.REPORT_PENDING]


func has_target() -> bool:
	return target_cell.x >= 0


func target_ref() -> String:
	return MapGrid.ref_of_cell(target_cell) if has_target() else "--"


func target_center() -> Vector2:
	return MapGrid.cell_center(target_cell)


## Confirms the cell under the cursor as the target candidate.
func confirm_target() -> bool:
	if locked():
		return false
	target_cell = MapGrid.cell_of(cursor)
	_leave_finished_state()
	selection_changed.emit()
	return true


func set_ammo(id: String) -> bool:
	if locked() or not Ammunition.TYPES.has(id):
		return false
	ammo = id
	_leave_finished_state()
	selection_changed.emit()
	return true


func clear_selection() -> bool:
	if locked():
		return false
	ammo = ""
	target_cell = Vector2i(-1, -1)
	_leave_finished_state()
	selection_changed.emit()
	return true


func _leave_finished_state() -> void:
	if launch_state in [Launch.COMPLETE, Launch.ABORTED]:
		_set_launch(Launch.IDLE)


# --- Arming and launch ----------------------------------------------------------------

func set_key(on: bool) -> void:
	key_armed = on
	if not on:
		cover_open = false
		if launch_state == Launch.SEQUENCE:
			abort("KEY RETURNED TO SAFE")
	selection_changed.emit()


func set_cover(open: bool) -> void:
	if not open and launch_state == Launch.SEQUENCE:
		abort("MASTER COVER CLOSED")
	cover_open = open
	selection_changed.emit()


## Reasons a launch cannot start, in the order the operator should act.
func missing() -> Array[String]:
	var m: Array[String] = []
	if ammo == "":
		m.append("SELECT AMMUNITION")
	if not has_target():
		m.append("CONFIRM TARGET GRID")
	if shaft != "LOADED":
		m.append("SHAFT %s" % shaft)
	if ammo != "" and Ammunition.get_type(ammo).cost > resources:
		m.append("INSUFFICIENT RESOURCES")
	if not key_armed:
		m.append("TURN KEY TO ARM")
	if not cover_open:
		m.append("LIFT MASTER COVER")
	return m


## The physical MASTER switch. Returns "" if the sequence started,
## otherwise why not. Repeated presses never start a second launch.
func request_launch() -> String:
	if locked():
		return "SEQUENCE ALREADY RUNNING"
	var m := missing()
	if not m.is_empty():
		return m[0]
	var orders := get_tree().get_first_node_in_group("orders")
	current = {
		"launch_id": "L-%03d" % (events.size() + 1),
		"order_id": orders.order.id if orders and orders.has_order() else "NONE",
		"ammo": ammo,
		"cell": target_cell,
		"grid": target_ref(),
		"cost": Ammunition.get_type(ammo).cost,
		"recorded": false,
	}
	countdown = COUNTDOWN_S
	abort_reason = ""
	_set_launch(Launch.SEQUENCE)
	return ""


func abort(reason := "ABORTED BY OPERATOR") -> bool:
	if launch_state != Launch.SEQUENCE:
		return false
	abort_reason = reason
	cover_open = false
	current = {}
	_set_launch(Launch.ABORTED)
	return true


## Called by the launch controller at ignition. Irreversible: spends the
## resources and records the launch event exactly once.
func missile_away() -> Dictionary:
	if launch_state != Launch.SEQUENCE or current.get("recorded", true):
		return {}
	current.recorded = true
	resources -= current.cost
	shaft = "EMPTY"
	var event := {
		"launch_id": current.launch_id, "order_id": current.order_id, "ammo": current.ammo,
		"grid": current.grid, "cell": current.cell, "time": _clock(), "cost": current.cost,
		"result": "PENDING", "report": [],
	}
	events.append(event)
	_set_launch(Launch.AWAY)
	event_recorded.emit(event)
	return event


func report_pending() -> void:
	if launch_state == Launch.AWAY:
		_set_launch(Launch.REPORT_PENDING)


## Attaches the outcome to the launch's single event record.
func complete(outcome: Dictionary) -> void:
	if launch_state != Launch.REPORT_PENDING:
		return
	var event: Dictionary = events[-1]
	event.result = outcome.category
	event.report = outcome.lines
	key_armed = false
	cover_open = false
	current = {}
	_set_launch(Launch.COMPLETE)


func set_shaft(value: String) -> void:
	shaft = value
	selection_changed.emit()


func last_event() -> Dictionary:
	return events[-1] if not events.is_empty() else {}


## SYSTEM STATUS as shown on the strategic-control CRT.
func status_label() -> String:
	match launch_state:
		Launch.SEQUENCE: return "LAUNCH SEQUENCE"
		Launch.AWAY: return "MISSILE AWAY"
		Launch.REPORT_PENDING: return "REPORT PENDING"
		Launch.COMPLETE: return "COMPLETE"
		Launch.ABORTED: return "ABORTED"
	if missing().is_empty():
		return "READY"
	if has_target():
		return "TARGET SELECTED"
	if ammo != "":
		return "AMMUNITION SELECTED"
	var orders := get_tree().get_first_node_in_group("orders")
	if orders and orders.has_order():
		return "ORDER RECEIVED"
	return "STANDBY"


func _set_launch(s: Launch) -> void:
	launch_state = s
	launch_changed.emit(s)
	selection_changed.emit()


static func _clock() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d%02d" % [t.hour, t.minute]
