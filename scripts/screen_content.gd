extends Node2D
## Placeholder CRT content drawn with simple 2D primitives.
## MAP: tactical grid. CONTROL: central status readout. RADAR: sweep.
## All content is placeholder: no real map, targets or procedures.
## In focus mode a tap on the glass marks the touch point (poke) and the
## HUD offers a few harmless placeholder actions per screen.

enum Mode { MAP, CONTROL, RADAR }

const ACTIONS := {
	Mode.MAP: ["ZOOM +", "ZOOM -"],
	Mode.CONTROL: ["SELF TEST"],
	Mode.RADAR: ["RANGE"],
}
const TITLES := {Mode.MAP: "TACTICAL MAP", Mode.CONTROL: "STRATEGIC CONTROL", Mode.RADAR: "AIR SURVEILLANCE"}

const GREEN := Color(0.35, 1.0, 0.45)
const DIM := Color(0.35, 1.0, 0.45, 0.22)
const MID := Color(0.3, 0.85, 0.38, 0.65)
const AMBER := Color(1.0, 0.65, 0.15)
const RED := Color(1.0, 0.25, 0.18)

var mode: Mode = Mode.CONTROL
var size := Vector2(256, 192)

var _t := 0.0
var _sweep := 0.0
var _blips: Array[Dictionary] = []
var _font: Font
var _zoom := 1.0                    # MAP
var _range := 3                     # RADAR range setting 1..3
var _test_t := -100.0               # CONTROL self-test start time
var _poke_uv := Vector2.ZERO
var _poke_t := -100.0
var _orders: Node                   # order manager (CONTROL screen only)


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_orders = get_tree().get_first_node_in_group("orders")
	if _orders:
		_orders.state_changed.connect(func(_s: int) -> void: queue_redraw())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1985
	for i in range(5):
		_blips.append({
			"a": rng.randf() * TAU,
			"r": rng.randf_range(0.3, 0.9),
			"drift": rng.randf_range(-0.02, 0.02),
			"glow": 0.0,
		})


func _process(delta: float) -> void:
	_t += delta
	if mode == Mode.RADAR:
		var prev := _sweep
		_sweep = fmod(_sweep + delta * TAU / 4.0, TAU)
		for b in _blips:
			b.a = fmod(b.a + b.drift * delta + TAU, TAU)
			b.glow = maxf(b.glow - delta * 0.35, 0.0)
			if _angle_between(b.a, prev, _sweep):
				b.glow = 1.0
		queue_redraw()
	elif _t - _poke_t < 1.6 or _t - _test_t < 7.0:
		queue_redraw()
	elif int(_t * 2.0) != int((_t - delta) * 2.0):
		queue_redraw()  # cursor blink / clock: twice a second is enough


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	match mode:
		Mode.MAP: _draw_map()
		Mode.CONTROL: _draw_control()
		Mode.RADAR: _draw_radar()
	_draw_poke()


func actions() -> PackedStringArray:
	return PackedStringArray(ACTIONS[mode])


func title() -> String:
	return TITLES[mode]


func do_action(action_name: String) -> void:
	match action_name:
		"ZOOM +": _zoom = minf(_zoom * 1.5, 3.375)
		"ZOOM -": _zoom = maxf(_zoom / 1.5, 1.0)
		"RANGE": _range = _range % 3 + 1
		"SELF TEST": _test_t = _t
	queue_redraw()


## Marks a touch on the glass. uv is 0..1 across the visible screen.
func poke(uv: Vector2) -> void:
	_poke_uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	_poke_t = _t
	queue_redraw()


func _draw_poke() -> void:
	var age := _t - _poke_t
	if age > 1.6:
		return
	var p := _poke_uv * size
	var col := AMBER
	col.a = 1.0 - age / 1.6
	var r := 6.0 + age * 10.0
	draw_arc(p, r, 0, TAU, 20, col, 1.0)
	draw_line(p - Vector2(r + 5, 0), p - Vector2(r - 3, 0), col, 1.0)
	draw_line(p + Vector2(r - 3, 0), p + Vector2(r + 5, 0), col, 1.0)
	draw_line(p - Vector2(0, r + 5), p - Vector2(0, r - 3), col, 1.0)
	draw_line(p + Vector2(0, r - 3), p + Vector2(0, r + 5), col, 1.0)
	if mode == Mode.MAP:
		var cell := 24.0 * _zoom
		var gx := int(floor((p.x - size.x * 0.5) / cell)) + 5
		var gy := int(floor((p.y - size.y * 0.5) / cell)) + 5
		_text(Vector2(size.x - 70, size.y - 3), "REF %s%d" % [char(65 + clampi(gx, 0, 25)), gy], col, 9)


func _text(pos: Vector2, s: String, col := GREEN, fsize := 11) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _draw_map() -> void:
	var cell := 24.0 * _zoom
	var top := 18.0
	var mid := size * 0.5
	for i in range(-12, 13):
		var x := mid.x + i * cell
		var y := mid.y + i * cell
		if x >= 0.0 and x <= size.x:
			draw_line(Vector2(x, top), Vector2(x, size.y - 14), DIM, 1.0)
		if y >= top and y <= size.y - 14:
			draw_line(Vector2(0, y), Vector2(size.x, y), DIM, 1.0)
	# Generic placeholder front trace (dashed), not a real geography.
	var pts := [Vector2(0.55, 0.12), Vector2(0.5, 0.3), Vector2(0.58, 0.45),
			Vector2(0.52, 0.62), Vector2(0.6, 0.78), Vector2(0.56, 0.95)]
	for i in range(pts.size() - 1):
		var a: Vector2 = _mz(pts[i])
		var b: Vector2 = _mz(pts[i + 1])
		var n := 6
		for k in range(n):
			if k % 2 == 0:
				draw_line(a.lerp(b, k / float(n)), a.lerp(b, (k + 1) / float(n)), AMBER, 2.0)
	# Friendly unit boxes (green) and unknown contacts (amber diamonds).
	for p in [Vector2(0.3, 0.3), Vector2(0.36, 0.6), Vector2(0.24, 0.8)]:
		var c: Vector2 = _mz(p)
		draw_rect(Rect2(c - Vector2(9, 6), Vector2(18, 12)), GREEN, false, 1.0)
		draw_line(c - Vector2(9, 6), c + Vector2(9, 6), GREEN, 1.0)
		draw_line(c + Vector2(-9, 6), c + Vector2(9, -6), GREEN, 1.0)
	for p in [Vector2(0.74, 0.25), Vector2(0.8, 0.55), Vector2(0.7, 0.85)]:
		var c: Vector2 = _mz(p)
		var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0), c + Vector2(0, -7)])
		draw_polyline(d, AMBER, 1.0)
	draw_rect(Rect2(0, size.y - 13, size.x, 13), Color.BLACK)
	draw_rect(Rect2(0, 0, size.x, 17), Color.BLACK)
	_text(Vector2(4, 12), "TACTICAL MAP")
	_text(Vector2(size.x - 64, 12), "ZOOM x%.1f" % _zoom if _zoom > 1.0 else "GRID 04", MID)
	_text(Vector2(4, size.y - 3), "NO LIVE FEED - PLACEHOLDER", MID, 9)


## Normalised map point, zoomed about the screen centre.
func _mz(p: Vector2) -> Vector2:
	return size * 0.5 + (p * size - size * 0.5) * _zoom


func _draw_control() -> void:
	_text(Vector2(8, 16), "STRATEGIC CONTROL", GREEN, 14)
	draw_line(Vector2(8, 22), Vector2(size.x - 8, 22), GREEN, 1.0)
	var c := control_rows()
	var y := 44.0
	for r in c.rows:
		_text(Vector2(10, y), r[0], GREEN, 12)
		_text(Vector2(10 + 92, y), ". . .", MID, 12)
		_text(Vector2(150, y), r[1], r[2], 12)
		y += 20.0
	draw_line(Vector2(8, y - 8), Vector2(size.x - 8, y - 8), DIM, 1.0)
	var secs := int(_t)
	var up := "UPTIME %02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	_text(Vector2(10, y + 10), up, MID, 11)
	var cursor := "_" if int(_t * 2.0) % 2 == 0 else " "
	_text(Vector2(10, size.y - 12), c.prompt + cursor, GREEN, 12)


## Rows of the strategic-control readout ([label, value, colour]) and the
## prompt line, reflecting self-test and the current order state.
func control_rows() -> Dictionary:
	var test_age := _t - _test_t
	var status := ["STATUS", "STANDBY", AMBER]
	var readiness := ["READINESS", "NOMINAL", GREEN]
	var orders_row := ["ORDERS", "NONE RECEIVED", GREEN]
	var prompt := "> AWAITING INPUT "
	if _orders and _orders.has_order():
		var id: String = _orders.order.id
		if _orders.is_pending():
			var blink_on := int(_t * 2.0) % 2 == 0
			orders_row = ["ORDERS", "%s PENDING" % id, AMBER if blink_on else MID]
			prompt = "> ORDER %s - REPLY REQUIRED " % id
		elif _orders.state == _orders.State.ACCEPTED:
			orders_row = ["ORDERS", "%s ACCEPTED" % id, GREEN]
			readiness = ["READINESS", _orders.order.accept_readiness, AMBER]
		else:
			orders_row = ["ORDERS", "%s REFUSED" % id, RED]
	if test_age < 2.5:
		status = ["STATUS", "SELF TEST" + ".".repeat(int(test_age * 3.0) % 4), AMBER]
	elif test_age < 7.0:
		status = ["STATUS", "SELF TEST: PASS", GREEN]
	return {
		"rows": [
			["SYSTEM", "ONLINE", GREEN],
			status,
			["SHAFT", "SEALED", GREEN],
			readiness,
			orders_row,
			["TARGET", "--", MID],
		],
		"prompt": prompt,
	}


func _draw_radar() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.54)
	var r := size.y * 0.42
	for k in range(1, 4):
		draw_arc(c, r * k / 3.0, 0, TAU, 48, DIM, 1.0)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), DIM, 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), DIM, 1.0)
	# Sweep with a fading trail.
	for i in range(14):
		var a := _sweep - i * 0.045
		var col := GREEN
		col.a = 0.9 * (1.0 - i / 14.0) * (0.35 if i > 0 else 1.0)
		draw_line(c, c + Vector2(cos(a), sin(a)) * r, col, 2.0 if i == 0 else 1.5)
	for b in _blips:
		if b.glow <= 0.01:
			continue
		var dist: float = b.r * 3.0 / _range
		if dist > 1.0:
			continue
		var p: Vector2 = c + Vector2(cos(b.a), sin(b.a)) * r * dist
		var col := GREEN
		col.a = b.glow
		draw_circle(p, 2.5, col)
	_text(Vector2(4, 12), "AIR SURVEILLANCE")
	_text(Vector2(size.x - 52, size.y - 4), "RNG %d" % _range, MID, 10)


func _angle_between(a: float, from: float, to: float) -> bool:
	if to >= from:
		return a >= from and a < to
	return a >= from or a < to  # wrapped past TAU
