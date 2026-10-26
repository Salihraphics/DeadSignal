extends Node2D
## Right CRT: air-surveillance radar (placeholder sweep and contacts).
## The Mode enum selects each monitor's content in crt_monitor.gd: the
## MAP and CONTROL screens use tactical_map.gd and strategic_display.gd.
## In focus mode a tap on the glass marks the touch point (poke).

enum Mode { MAP, CONTROL, RADAR }

const GREEN := Color(0.35, 1.0, 0.45)
const DIM := Color(0.35, 1.0, 0.45, 0.22)
const MID := Color(0.3, 0.85, 0.38, 0.65)
const AMBER := Color(1.0, 0.65, 0.15)

var mode: Mode = Mode.RADAR
var size := Vector2(256, 192)

var _t := 0.0
var _sweep := 0.0
var _blips: Array[Dictionary] = []
var _font: Font
var _range := 3                     # range setting 1..3
var _poke_uv := Vector2.ZERO
var _poke_t := -100.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
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
	var prev := _sweep
	_sweep = fmod(_sweep + delta * TAU / 4.0, TAU)
	for b in _blips:
		b.a = fmod(b.a + b.drift * delta + TAU, TAU)
		b.glow = maxf(b.glow - delta * 0.35, 0.0)
		if _angle_between(b.a, prev, _sweep):
			b.glow = 1.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	_draw_radar()
	_draw_poke()


func actions() -> PackedStringArray:
	return PackedStringArray(["RANGE"])


func title() -> String:
	return "AIR SURVEILLANCE"


func do_action(action_name: String) -> void:
	if action_name == "RANGE":
		_range = _range % 3 + 1
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


func _text(pos: Vector2, s: String, col := GREEN, fsize := 11) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


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
