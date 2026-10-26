class_name UiKit
extends RefCounted
## Shared look for the 1985 terminal screens (menu, settings, pause,
## after-action report): phosphor green on black, monospaced text, large
## touch targets. Sizes scale with the screen height so the same layout
## works on phones and tablets of any aspect ratio.

const GREEN := Color(0.42, 1.0, 0.5)
const GREEN_DIM := Color(0.42, 1.0, 0.5, 0.45)
const AMBER := Color(1.0, 0.68, 0.2)
const BG := Color(0.012, 0.03, 0.016)
const MIN_TOUCH := 64.0

static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Sans Mono", "Droid Sans Mono", "Courier New", "monospace"])
		_font = f
	return _font


## Base size for body text, from the visible height (720 logical -> 24).
static func text_px(vp: Viewport) -> int:
	return clampi(int(vp.get_visible_rect().size.y / 30.0), 18, 34)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	var normal := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	var hover := _box(Color(0.42, 1.0, 0.5, 0.08), GREEN_DIM)
	var pressed := _box(Color(0.42, 1.0, 0.5, 0.22), GREEN)
	var disabled := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for k in ["normal", "focus"]:
		t.set_stylebox(k, "Button", normal if k == "normal" else hover)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", GREEN)
	t.set_color("font_hover_color", "Button", GREEN)
	t.set_color("font_pressed_color", "Button", Color(0.85, 1.0, 0.85))
	t.set_color("font_focus_color", "Button", GREEN)
	t.set_color("font_disabled_color", "Button", GREEN_DIM)
	t.set_color("font_color", "Label", GREEN)
	t.set_color("default_color", "RichTextLabel", GREEN)
	var panel := _box(BG, GREEN_DIM)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	_theme = t
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


static func button(text: String, on_press: Callable, name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, MIN_TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if name != "":
		b.name = name
	b.pressed.connect(func() -> void:
		Sfx.play("ui_select", -6.0)
		on_press.call())
	return b


static func label(text: String, size := 0, color := GREEN) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Static scanlines and a dark vignette drawn once (no per-frame shader).
class Scanlines extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var y := 0.0
		while y < h:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.28), 1.0)
			y += 3.0
		# Vignette: a few nested translucent frames.
		for i in range(10):
			var m := i * minf(size.x, size.y) * 0.012
			draw_rect(Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), Color(0, 0, 0, 0.05), false, minf(size.x, size.y) * 0.012)
