extends Node2D
## Left CRT: the tactical map, drawn from MapData through the projection
## owned by StrategicState. Nothing here stores its own coordinates: every
## feature, label, cursor and target is projected from map kilometres.
##
## Touch on this screen never moves the cursor or selects a target; the
## physical map navigation unit does that.

const BG := Color(0.01, 0.03, 0.015)
const GREEN := Color(0.35, 1.0, 0.45)
const PALE := Color(0.72, 1.0, 0.76)
const DIM := Color(0.35, 1.0, 0.45, 0.16)
const MID := Color(0.35, 1.0, 0.45, 0.45)
const WATER := Color(0.35, 0.85, 0.75, 0.85)
const AMBER := Color(1.0, 0.65, 0.15)
const HOSTILE := Color(1.0, 0.35, 0.22)
const HEADER_H := 18.0
const FOOTER_H := 36.0
## Zoom thresholds (texture px per km) for medium and close detail.
const MEDIUM := 6.0
const CLOSE := 14.0

var size := Vector2(512, 384)
## Content is drawn inside this margin: the CRT's barrel curvature pushes
## the outer few percent of the texture off the glass.
const SAFE := Vector2(16, 14)
var inner := Vector2(480, 356)
var state: Node
var _font: Font
var _blink := true
## CPU time of the last full redraw (ms), for profiling.
var last_draw_ms := 0.0
## Cursor and footer readouts live on this overlay, so moving the cursor
## or blinking it does not re-record the whole map (2-12 ms per redraw).
var _overlay: Node2D
var _canvas: CanvasItem


func _ready() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Droid Sans Mono", "Courier New", "monospace"])
	_font = mono
	_canvas = self
	state = get_tree().get_first_node_in_group("strategy")
	inner = size - SAFE * 2.0
	state.view_px = Vector2(inner.x, inner.y - HEADER_H - FOOTER_H)
	state.map_zoom = state.min_zoom()
	_overlay = Node2D.new()
	_overlay.position = SAFE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	state.map_changed.connect(_redraw_all)
	state.selection_changed.connect(_redraw_all)
	state.cursor_moved.connect(_overlay.queue_redraw)
	state.launch_changed.connect(func(_s: int) -> void: queue_redraw())
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func() -> void:
		_blink = not _blink
		_overlay.queue_redraw())
	add_child(t)


func _redraw_all() -> void:
	queue_redraw()
	_overlay.queue_redraw()


# --- CRT content API (see crt_monitor.gd) ------------------------------------------

func title() -> String:
	return "TACTICAL MAP"


func actions() -> PackedStringArray:
	return PackedStringArray()


func do_action(_a: String) -> void:
	pass


func poke(_uv: Vector2) -> void:
	get_tree().call_group("hud", "toast", "MAP: USE THE NAVIGATION UNIT TO MOVE THE CURSOR")


# --- Projection ---------------------------------------------------------------------

## Map kilometres -> texture pixel (the only conversion used for drawing).
func px(km: Vector2) -> Vector2:
	return state.km_to_view(km) + Vector2(0, HEADER_H)


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(px(p))
	return out


func _on(layer: String) -> bool:
	return state.layers[layer]


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_map()
	last_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _draw_map() -> void:
	var z: float = state.map_zoom
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_set_transform(SAFE)
	if _on("TERRAIN"):
		_draw_terrain(z)
	if _on("GRID"):
		_draw_grid(z)
	if _on("HYDROGRAPHY"):
		_draw_water(z)
	if _on("ROADS"):
		_draw_roads(z)
	if _on("RAILWAYS"):
		_draw_rails(z)
	if (_on("ROADS") or _on("RAILWAYS")) and z >= MEDIUM:
		_draw_bridges()
	if _on("SETTLEMENTS"):
		_draw_settlements(z)
	if _on("FRONT"):
		_draw_front()
	if _on("UNITS"):
		_draw_units(z)
	if _on("INTELLIGENCE"):
		_draw_intel(z)
	_draw_exits()
	_draw_strikes()
	_draw_target(z)
	_draw_compass_and_scale(z)
	_draw_header()


func _draw_overlay() -> void:
	_canvas = _overlay
	_draw_cursor()
	_draw_footer()
	_canvas = self


func _text(pos: Vector2, s: String, col: Color, fsize := 11, centered := false) -> void:
	if centered:
		pos.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x * 0.5
	_canvas.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _draw_terrain(z: float) -> void:
	var d := MapData.derived()
	# Thousands of contour segments: draw them in map km through one
	# km->pixel transform (the same projection as px()) instead of
	# converting every point in script. Width -1 keeps them 1 px hairlines.
	draw_set_transform(SAFE + px(Vector2.ZERO), 0.0, Vector2(z, z))
	for c in d.contours:
		var index: bool = MapData.INDEX_LEVELS.has(c.level)
		if not index and z < MEDIUM:
			continue
		draw_multiline(c.segments, Color(0.35, 1.0, 0.45, 0.42 if index else 0.24), -1.0)
	for f in _forest_outlines():
		draw_polyline(f, Color(0.35, 1.0, 0.45, 0.32), -1.0)
	draw_set_transform(SAFE)
	if z >= MEDIUM:
		var tick := PackedVector2Array()
		for m in d.forest_marks:
			var p := px(m)
			tick.append_array([p + Vector2(-2.5, 2), p + Vector2(0, -2.5), p + Vector2(0, -2.5), p + Vector2(2.5, 2)])
		draw_multiline(tick, Color(0.35, 1.0, 0.45, 0.45), 1.0)
	for r in MapData.RIDGES:
		if r.name != "":
			_text(px(r.pts[r.pts.size() / 2]) + Vector2(0, -6), r.name, Color(0.35, 1.0, 0.45, 0.5), 10, true)
	if z >= MEDIUM:
		for p in MapData.PASSES:
			var q := px(p.pos)
			draw_arc(q, 4.0, PI * 0.15, PI * 0.85, 6, MID, 1.0)
			draw_arc(q + Vector2(0, 6), 4.0, -PI * 0.85, -PI * 0.15, 6, MID, 1.0)
			_text(q + Vector2(6, 3), p.name, MID, 10)


static var _outlines: Array[PackedVector2Array] = []

static func _forest_outlines() -> Array[PackedVector2Array]:
	if _outlines.is_empty():
		for f in MapData.FORESTS:
			var closed := PackedVector2Array(f)
			closed.append(f[0])
			_outlines.append(closed)
	return _outlines


func _draw_grid(z: float) -> void:
	var minor := Color(0.35, 1.0, 0.45, 0.12)
	var major := Color(0.35, 1.0, 0.45, 0.4)
	var top := HEADER_H
	var bottom := inner.y - FOOTER_H
	var fine := 1.0 if z >= CLOSE * 1.6 else (MapGrid.CELL if z >= MEDIUM else MapGrid.MAJOR)
	var x := 0.0
	while x <= MapGrid.EXTENT.x:
		var is_major := fmod(x, MapGrid.MAJOR) == 0.0
		var sx := px(Vector2(x, 0)).x
		if sx >= -1 and sx <= inner.x + 1:
			draw_line(Vector2(sx, maxf(top, px(Vector2(0, 0)).y)), Vector2(sx, minf(bottom, px(MapGrid.EXTENT).y)), major if is_major else minor, 1.0)
		x += fine
	var y := 0.0
	while y <= MapGrid.EXTENT.y:
		var is_major := fmod(y, MapGrid.MAJOR) == 0.0
		var sy := px(Vector2(0, y)).y
		if sy >= top and sy <= bottom:
			draw_line(Vector2(maxf(0, px(Vector2.ZERO).x), sy), Vector2(minf(inner.x, px(MapGrid.EXTENT).x), sy), major if is_major else minor, 1.0)
		y += fine
	# Major square names, and easting/northing digits along the edges.
	for cx in range(4):
		for cy in range(3):
			var corner := px(Vector2(cx, cy) * MapGrid.MAJOR)
			_text(corner + Vector2(3, 11), MapGrid.COLS[cx] + MapGrid.ROWS[cy], Color(0.35, 1.0, 0.45, 0.6), 11)
	if z >= MEDIUM:
		var label_col := Color(0.35, 1.0, 0.45, 0.55)
		for cx in range(MapGrid.CELLS.x):
			var sx := px(Vector2((cx + 0.5) * MapGrid.CELL, 0)).x
			if sx > 4 and sx < inner.x - 4:
				_text(Vector2(sx - 3, top + 22), str(cx % 10), label_col, 10)
		for cy in range(MapGrid.CELLS.y):
			var sy := px(Vector2(0, (cy + 0.5) * MapGrid.CELL)).y
			if sy > top + 26 and sy < bottom - 4:
				_text(Vector2(3, sy + 4), str(9 - cy % 10), label_col, 10)


func _draw_water(z: float) -> void:
	for r in MapData.RIVERS:
		if r.cls == 2 and z < MEDIUM:
			continue
		var pts := _poly(r.pts)
		if r.cls == 0:
			# The main river widens downstream.
			for i in range(pts.size() - 1):
				var w := lerpf(1.2, 3.2, float(i) / pts.size()) * (1.0 if z < MEDIUM else 1.4)
				draw_line(pts[i], pts[i + 1], WATER, w)
		else:
			draw_polyline(pts, WATER * Color(1, 1, 1, 0.8), 1.4 if r.cls == 1 else 1.0)
		if z >= MEDIUM or r.cls == 0:
			var mid := pts[pts.size() / 2]
			_text(mid + Vector2(4, -4), r.name, Color(WATER, 0.7), 9)


func _draw_roads(z: float) -> void:
	for r in MapData.ROADS:
		var pts := _poly(r.pts)
		match r.cls:
			0:
				draw_polyline(pts, Color(0.72, 1.0, 0.76, 0.75), 2.0)
			1:
				if z >= MEDIUM:
					draw_polyline(pts, Color(0.72, 1.0, 0.76, 0.5), 1.0)
			2:
				if z >= CLOSE:
					_dashed(pts, Color(0.72, 1.0, 0.76, 0.4), 4.0, 3.0)


func _draw_rails(z: float) -> void:
	for r in MapData.RAILS:
		if r.cls == 2 and z < MEDIUM:
			continue
		var pts := _poly(r.pts)
		draw_polyline(pts, GREEN, 1.5 if r.cls == 0 else 1.0)
		# Cross ticks: the classic railway signature.
		var ticks := PackedVector2Array()
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var length := a.distance_to(b)
			if length < 1.0:
				continue
			var d := (b - a) / length
			var n := Vector2(-d.y, d.x) * 2.5
			var s := 5.0
			while s < length:
				var p := a + d * s
				ticks.append_array([p - n, p + n])
				s += 9.0
		if ticks.size() > 0:
			draw_multiline(ticks, Color(GREEN, 0.7), 1.0)
	# Karsen Junction is always marked: it is the scenario's landmark.
	var j := px(MapData.KARSEN_JN)
	draw_arc(j, 5.0, 0, TAU, 14, GREEN, 1.5)
	draw_circle(j, 1.8, GREEN)
	if state.map_zoom >= MEDIUM:
		_text(j + Vector2(-64, 12), "KARSEN JN", GREEN, 11)


func _draw_bridges() -> void:
	for b in MapData.derived().bridges:
		if (b.kind == "rail" and not _on("RAILWAYS")) or (b.kind == "road" and not _on("ROADS")):
			continue
		var p := px(b.pos)
		var d: Vector2 = b.dir
		var n := Vector2(-d.y, d.x) * 3.5
		var col := Color(0.72, 1.0, 0.76, 0.9)
		draw_line(p - d * 5 + n, p + d * 5 + n, col, 1.0)
		draw_line(p - d * 5 - n, p + d * 5 - n, col, 1.0)
		if state.map_zoom >= CLOSE:
			_text(p + n * 2 + Vector2(2, 0), b.id, Color(col, 0.6), 9)


func _draw_settlements(z: float) -> void:
	for s in MapData.SETTLEMENTS:
		var p := px(s.pos)
		var col := PALE if s.side == "N" else Color(1.0, 0.8, 0.6)
		if s.cls == "town":
			if z >= CLOSE:
				# Building clusters at close range (deterministic per town).
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(s.name)
				for i in range(9):
					var o := Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.0, 1.0)) * z
					draw_rect(Rect2(p + o - Vector2(2, 2), Vector2(4, 3)), Color(col, 0.7))
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), col, false, 1.5)
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
			_text(p + Vector2(7, -5), s.name, col, 11)
		elif z >= MEDIUM:
			draw_circle(p, 2.5, col)
			_text(p + Vector2(5, -3), s.name, Color(col, 0.85), 10)
	if z < MEDIUM:
		return
	for f in MapData.FACILITIES:
		if f.military or f.type == "junction":
			continue
		var p := px(f.pos)
		var col := Color(0.72, 1.0, 0.76, 0.85)
		match f.type:
			"freight":
				draw_rect(Rect2(p - Vector2(6, 3), Vector2(12, 6)), col, false, 1.0)
				for i in range(3):
					draw_line(p + Vector2(-4 + i * 4, -3), p + Vector2(-2 + i * 4, 3), col, 1.0)
			"factory":
				draw_rect(Rect2(p - Vector2(5, 2), Vector2(10, 6)), col, false, 1.0)
				draw_polyline(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(-2, -6), p + Vector2(0, -2), p + Vector2(3, -6), p + Vector2(5, -2)]), col, 1.0)
			"power":
				draw_arc(p, 5.0, 0, TAU, 12, col, 1.0)
				draw_polyline(PackedVector2Array([p + Vector2(-1, -4), p + Vector2(2, -1), p + Vector2(-2, 1), p + Vector2(1, 4)]), col, 1.0)
		if z >= CLOSE * 0.8:
			_text(p + Vector2(8, 10), f.name, Color(col, 0.7), 9)


func _draw_front() -> void:
	_dashed(_poly(MapData.BORDER), Color(0.72, 1.0, 0.76, 0.7), 8.0, 4.0, 1.5)
	var pts := _poly(MapData.FRONT)
	draw_polyline(pts, AMBER, 2.0)
	# Teeth point toward the Dravonyan side (east / south).
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var d := (b - a) / length
		var n := Vector2(-d.y, d.x)
		if n.x + n.y < 0:
			n = -n
		var s := 7.0
		while s < length - 3.0:
			var p := a + d * s
			draw_colored_polygon(PackedVector2Array([p - d * 3, p + d * 3, p + n * 4]), AMBER)
			s += 16.0
	if state.map_zoom >= MEDIUM:
		_text(px(Vector2(95, 76)), "FRONT", AMBER, 10)
		_text(px(Vector2(132, 31)), "NORVAK / DRAVONYA", Color(PALE, 0.7), 10)


func _draw_units(z: float) -> void:
	for f in MapData.FACILITIES:
		if f.military and z >= MEDIUM:
			var p := px(f.pos)
			var col := PALE if f.side == "N" else HOSTILE
			draw_polyline(PackedVector2Array([p + Vector2(-6, 4), p + Vector2(0, -6), p + Vector2(6, 4), p + Vector2(-6, 4)]), col, 1.0)
			_text(p + Vector2(-3, 3), "L", col, 8)
			_text(p + Vector2(8, 4), f.name, Color(col, 0.75), 9)
	for o in MapData.OBSERVATION:
		var p := px(o.pos)
		draw_polyline(PackedVector2Array([p + Vector2(-5, 4), p + Vector2(0, -5), p + Vector2(5, 4), p + Vector2(-5, 4)]), PALE, 1.0)
		draw_circle(p + Vector2(0, 1), 1.2, PALE)
		if z >= MEDIUM:
			_text(p + Vector2(7, -2), o.id, Color(PALE, 0.8), 9)
	for u in MapData.UNITS:
		var p := px(u.pos)
		var col: Color = {"F": PALE, "H": HOSTILE, "U": AMBER}[u.side]
		if z < MEDIUM:
			draw_circle(p, 2.5, col)          # broad picture only
			continue
		match u.side:
			"F":
				draw_rect(Rect2(p - Vector2(8, 5.5), Vector2(16, 11)), col, false, 1.2)
			"H":
				draw_polyline(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0), p + Vector2(0, -8)]), col, 1.2)
			"U":
				draw_arc(p, 7.0, 0, TAU, 16, col, 1.2)
				_text(p + Vector2(-3, 4), "?", col, 10)
		_unit_mark(p, u.type, col)
		_text(p + Vector2(10, 4), u.id, Color(col, 0.9), 10)


func _unit_mark(p: Vector2, type: String, col: Color) -> void:
	match type:
		"armour":
			_ellipse(p, Vector2(5, 2.5), col)
		"motor":
			_ellipse(p, Vector2(5, 2.5), col)
			draw_line(p + Vector2(-5, -3), p + Vector2(5, 3), col, 1.0)
		"artillery":
			draw_circle(p, 1.8, col)
		"airdef":
			draw_arc(p + Vector2(0, 3), 4.0, PI, TAU, 8, col, 1.0)
		"engineer":
			draw_polyline(PackedVector2Array([p + Vector2(-4, 2), p + Vector2(-4, -2), p + Vector2(4, -2), p + Vector2(4, 2)]), col, 1.0)
			draw_line(p + Vector2(0, -2), p + Vector2(0, 2), col, 1.0)


func _draw_intel(z: float) -> void:
	for i in MapData.INTEL:
		var p := px(i.pos)
		var r: float = i.radius * z
		_dashed_circle(p, r, AMBER, 1.0)
		var dia := PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0), p + Vector2(0, -8)])
		_dashed(dia, AMBER, 3.0, 2.0, 1.2)
		_text(p + Vector2(-3, 4), "?", AMBER, 10)
		if z >= MEDIUM * 0.8:
			_text(p + Vector2(-r * 0.7, -r - 12), i.id, AMBER, 10)
			_text(p + Vector2(-r * 0.7, -r - 2), "UNCONFIRMED", Color(AMBER, 0.7), 9)


func _draw_exits() -> void:
	for e in MapData.EXITS:
		var p := px(e.pos)
		var d: Vector2 = e.dir
		var tip := p + d * 2
		draw_line(tip - d * 14, tip, PALE, 1.0)
		draw_line(tip, tip - d * 5 + Vector2(-d.y, d.x) * 4, PALE, 1.0)
		draw_line(tip, tip - d * 5 - Vector2(-d.y, d.x) * 4, PALE, 1.0)
		var w := _font.get_string_size(e.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var at := p + Vector2(4, 14) if d.x < 0 else p + Vector2(-w - 4, 14)
		_text(at, e.label, Color(PALE, 0.8), 10)


func _draw_strikes() -> void:
	for e in state.events:
		var p := px(MapGrid.cell_center(e.cell))
		draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), HOSTILE, 1.5)
		draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), HOSTILE, 1.5)
		_text(p + Vector2(7, 12), e.launch_id, Color(HOSTILE, 0.85), 9)


func _draw_target(z: float) -> void:
	if not state.has_target():
		return
	var rect: Rect2 = MapGrid.cell_rect(state.target_cell)
	var a := px(rect.position)
	var b := px(rect.end)
	draw_rect(Rect2(a, b - a), Color(AMBER, 0.12))
	draw_rect(Rect2(a, b - a), AMBER, false, 1.5)
	var c := px(state.target_center())
	if state.ammo != "":
		_dashed_circle(c, Ammunition.get_type(state.ammo).radius_km * z, Color(AMBER, 0.8), 1.0)
	draw_polyline(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)]), AMBER, 1.5)
	_text(Vector2(b.x + 3, a.y + 10), "TGT " + state.target_ref(), AMBER, 11)


func _draw_cursor() -> void:
	var o := _canvas
	var c := px(state.cursor)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		o.draw_line(c + d * 4, c + d * 14, GREEN, 1.0)
	o.draw_arc(c, 9.0, 0, TAU, 20, Color(GREEN, 0.5), 1.0)
	o.draw_rect(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), AMBER if _blink else Color(AMBER, 0.5))


func _draw_compass_and_scale(z: float) -> void:
	var c := Vector2(inner.x - 18, HEADER_H + 26)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(4, 2), c + Vector2(0, -1), c + Vector2(-4, 2)]), GREEN)
	_text(c + Vector2(0, 14), "N", GREEN, 11, true)
	var km := 1.0
	for nice in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]:
		if nice * z >= 36.0:
			km = nice
			break
	var y := inner.y - FOOTER_H - 8
	var x0 := 8.0
	var w := km * z
	draw_rect(Rect2(x0 - 2, y - 12, w + 52, 16), Color(BG, 0.85))
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), GREEN, 1.5)
	for t in [x0, x0 + w * 0.5, x0 + w]:
		draw_line(Vector2(t, y - 3), Vector2(t, y), GREEN, 1.0)
	_text(Vector2(x0 + w + 5, y + 3), "%d KM" % km, GREEN, 10)


func _draw_header() -> void:
	draw_rect(Rect2(-SAFE.x, -SAFE.y, size.x, HEADER_H + SAFE.y), BG)
	draw_line(Vector2(0, HEADER_H - 0.5), Vector2(inner.x, HEADER_H - 0.5), Color(GREEN, 0.5), 1.0)
	_text(Vector2(4, 13), "TACTICAL MAP  SHEET 4  NORVAK-DRAVONYA BORDER", GREEN, 11)
	_text(Vector2(inner.x - 70, 13), "ZOOM x%.1f" % (state.map_zoom / state.min_zoom()), Color(GREEN, 0.7), 11)


func _draw_footer() -> void:
	var o := _canvas
	var y0 := inner.y - FOOTER_H
	o.draw_rect(Rect2(-SAFE.x, y0, size.x, FOOTER_H + SAFE.y), BG)
	o.draw_line(Vector2(0, y0 + 0.5), Vector2(inner.x, y0 + 0.5), Color(GREEN, 0.5), 1.0)
	_text(Vector2(6, y0 + 14), "CUR " + MapGrid.ref_of(state.cursor), GREEN, 12)
	_text(Vector2(110, y0 + 14), "TGT " + state.target_ref(), AMBER if state.has_target() else MID, 12)
	if state.has_target():
		var k := MapQuery.known_in_cell(state.target_cell)
		var tags := []
		if not k.reported.is_empty(): tags.append("RPT HOSTILE?")
		if not k.hostile.is_empty(): tags.append("HOSTILE")
		if not k.friendly.is_empty(): tags.append("FRIENDLY")
		if not k.settlements.is_empty(): tags.append("CIVILIAN")
		if not k.infrastructure.is_empty(): tags.append("INFRA")
		_text(Vector2(210, y0 + 14), " ".join(tags) if tags else "NO KNOWN OBJECT", Color(AMBER, 0.85), 11)
	var x := 6.0
	for i in range(state.LAYERS.size()):
		var tag: String = state.LAYER_TAGS[i]
		var on: bool = state.layers[state.LAYERS[i]]
		var col := GREEN if on else Color(GREEN, 0.25)
		if i == state.layer_index:
			o.draw_rect(Rect2(x - 3, y0 + 19, 34, 14), AMBER, false, 1.0)
		_text(Vector2(x, y0 + 30), tag, col, 11)
		x += 40.0
	_text(Vector2(x + 4, y0 + 30), state.LAYERS[state.layer_index] + (" ON" if state.layers[state.LAYERS[state.layer_index]] else " OFF"), AMBER, 10)


# --- Line helpers ----------------------------------------------------------------------------

func _dashed(pts: PackedVector2Array, col: Color, dash: float, gap: float, width := 1.0) -> void:
	var segs := PackedVector2Array()
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var d := (b - a) / length
		var s := 0.0
		while s < length:
			segs.append(a + d * s)
			segs.append(a + d * minf(s + dash, length))
			s += dash + gap
	if segs.size() > 0:
		draw_multiline(segs, col, width)


func _dashed_circle(c: Vector2, r: float, col: Color, width: float) -> void:
	var n := clampi(int(r / 3.0), 12, 96)
	var segs := PackedVector2Array()
	for i in range(0, n, 2):
		segs.append(c + Vector2.from_angle(TAU * i / n) * r)
		segs.append(c + Vector2.from_angle(TAU * (i + 1) / n) * r)
	draw_multiline(segs, col, width)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(13):
		pts.append(c + Vector2(cos(TAU * i / 12.0) * r.x, sin(TAU * i / 12.0) * r.y))
	draw_polyline(pts, col, 1.0)
