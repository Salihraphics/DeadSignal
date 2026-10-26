class_name MenuItem
extends Button
## One main-menu entry: a dark rectangular panel with a status bar on the
## left, a simple line icon, a title and a line of supporting text.
## States: default (steel), selected / hovered (green indicator, brighter
## border), pressed (green tint), disabled (dimmed, amber note).
## A real Button: tap, keyboard and gamepad all work.

var title := ""
var note := ""
var icon_kind := ""          # continue, new, settings, credits, exit
var disabled_note := ""
var px := 24


func setup(t: String, n: String, kind: String, size_px: int) -> MenuItem:
	title = t
	note = n
	icon_kind = kind
	px = size_px
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, maxf(UiKit.MIN_TOUCH + 6.0, px * 2.9))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	pressed.connect(func() -> void: Sfx.play("ui_select", -6.0))
	return self


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var mode := get_draw_mode()
	var lit := has_focus() or mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED
	var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var off := disabled
	var bg := Color(0.05, 0.056, 0.058, 0.86)
	if down:
		bg = Color(0.09, 0.14, 0.09, 0.94)
	elif lit:
		bg = Color(0.07, 0.085, 0.075, 0.92)
	draw_rect(r, bg)
	var edge := UiKit.STEEL_DIM if not lit else Color(UiKit.GREEN, 0.55)
	if off:
		edge = Color(UiKit.STEEL, 0.14)
	draw_rect(r, edge, false, 1.0)
	# Status bar on the left edge.
	var bar := UiKit.GREEN if (lit or down) else Color(UiKit.STEEL, 0.5)
	if off:
		bar = Color(UiKit.STEEL, 0.18)
	draw_rect(Rect2(0, 0, 4, size.y), bar)
	# Icon in a square cell, then a hairline divider.
	var cell := size.y
	var ic := Color(UiKit.OFFWHITE, 0.85) if not off else Color(UiKit.MUTED, 0.35)
	if lit or down:
		ic = UiKit.GREEN
	_icon(Rect2(4, 0, cell - 4, size.y).grow(-size.y * 0.3), ic)
	draw_line(Vector2(cell, size.y * 0.22), Vector2(cell, size.y * 0.78), Color(UiKit.STEEL, 0.25), 1.0)
	# Title and note.
	var x := cell + px * 0.7
	var tf := UiKit.display()
	var nf := UiKit.font()
	var ts := int(px * 1.08)
	var ns := maxi(12, int(px * 0.52))
	var tc := UiKit.OFFWHITE if not off else Color(UiKit.MUTED, 0.45)
	var title_y := size.y * 0.5 + ts * 0.12
	draw_string(tf, Vector2(x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, tc)
	var n := disabled_note if off and disabled_note != "" else note
	var nc := Color(UiKit.MUTED, 0.9) if not off else Color(UiKit.AMBER, 0.55)
	draw_string(nf, Vector2(x, title_y + ns * 1.55), n.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 12, ns, nc)
	# Small chevron on the right when selected.
	if lit and not off:
		var cx := size.x - px * 0.9
		var cy := size.y * 0.5
		var s := px * 0.22
		draw_polyline(PackedVector2Array([Vector2(cx - s * 0.5, cy - s), Vector2(cx + s * 0.5, cy), Vector2(cx - s * 0.5, cy + s)]), UiKit.GREEN, 2.0)


## Simple line icons, drawn (no emoji, no image assets).
func _icon(b: Rect2, c: Color) -> void:
	var w := 2.0
	var p := b.position
	var s := minf(b.size.x, b.size.y)
	p += (b.size - Vector2(s, s)) * 0.5
	var q := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match icon_kind:
		"continue":
			# Resume: a play triangle after a bar.
			draw_line(q.call(0.15, 0.15), q.call(0.15, 0.85), c, w + 1.0)
			draw_polyline(PackedVector2Array([q.call(0.38, 0.15), q.call(0.9, 0.5), q.call(0.38, 0.85), q.call(0.38, 0.15)]), c, w)
		"new":
			# New assignment: a document with a folded corner and lines.
			draw_polyline(PackedVector2Array([q.call(0.18, 0.05), q.call(0.62, 0.05), q.call(0.84, 0.27), q.call(0.84, 0.95), q.call(0.18, 0.95), q.call(0.18, 0.05)]), c, w)
			draw_polyline(PackedVector2Array([q.call(0.62, 0.05), q.call(0.62, 0.27), q.call(0.84, 0.27)]), c, w)
			for y in [0.48, 0.63, 0.78]:
				draw_line(q.call(0.32, y), q.call(0.7, y), c, w * 0.75)
		"settings":
			# Preferences: three sliders.
			for i in range(3):
				var y: float = 0.2 + i * 0.3
				var k: float = [0.65, 0.3, 0.5][i]
				draw_line(q.call(0.05, y), q.call(0.95, y), c, w * 0.75)
				draw_rect(Rect2(q.call(k - 0.08, y - 0.1), Vector2(0.16, 0.2) * s), c)
		"credits":
			# Personnel: an identity card.
			draw_rect(Rect2(q.call(0.02, 0.15), Vector2(0.96, 0.7) * s), c, false, w)
			draw_arc(q.call(0.3, 0.42), s * 0.1, 0, TAU, 16, c, w * 0.8)
			draw_arc(q.call(0.3, 0.72), s * 0.16, PI, TAU, 16, c, w * 0.8)
			for y in [0.38, 0.52, 0.66]:
				draw_line(q.call(0.55, y), q.call(0.86, y), c, w * 0.75)
		"exit":
			# Power off.
			draw_arc(q.call(0.5, 0.55), s * 0.38, deg_to_rad(-60), deg_to_rad(240), 24, c, w)
			draw_line(q.call(0.5, 0.05), q.call(0.5, 0.5), c, w)
