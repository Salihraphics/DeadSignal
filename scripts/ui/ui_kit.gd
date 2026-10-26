class_name UiKit
extends RefCounted
## Shared look for the facility's screens (menu, settings, pause, credits,
## after-action report): charcoal and steel panels, muted off-white text,
## Norvak green for active systems, amber for secondary information, red
## only for rare critical warnings. Rectangular industrial panels, no
## rounded cards, no glow.
##
## Typefaces (bundled, see assets/fonts/LICENSE-*):
##   display  Liberation Sans Bold, condensed and tracked - titles, controls
##   mono     JetBrains Mono - technical metadata only
## Sizes scale with the screen height so layouts hold on phones and tablets.

const CHARCOAL := Color(0.045, 0.05, 0.052)
const PANEL := Color(0.06, 0.068, 0.07, 0.94)
const STEEL := Color(0.44, 0.47, 0.48)
const STEEL_DIM := Color(0.44, 0.47, 0.48, 0.35)
const OFFWHITE := Color(0.87, 0.86, 0.81)
const MUTED := Color(0.6, 0.61, 0.58)
const GREEN := Color(0.47, 0.72, 0.42)          # Norvak green, active systems
const GREEN_DIM := Color(0.47, 0.72, 0.42, 0.45)
const AMBER := Color(0.93, 0.66, 0.26)
const RED := Color(0.78, 0.2, 0.14)
const BG := CHARCOAL
const MIN_TOUCH := 64.0

const DISPLAY_FONT := "res://assets/fonts/LiberationSans-Bold.ttf"
const MONO_FONT := "res://assets/fonts/JetBrainsMono-Regular.ttf"

static var _mono: Font
static var _display: Font
static var _wide: Font
static var _theme: Theme


## Monospaced, for technical metadata.
static func font() -> Font:
	if _mono == null:
		_mono = _load(MONO_FONT, ["JetBrains Mono", "DejaVu Sans Mono", "Droid Sans Mono", "monospace"])
	return _mono


## Condensed bold display face for titles and controls.
static func display() -> Font:
	if _display == null:
		var v := FontVariation.new()
		v.base_font = _load(DISPLAY_FONT, ["sans-serif-condensed", "Liberation Sans", "sans-serif"])
		v.variation_transform = Transform2D(Vector2(0.84, 0), Vector2(0, 1), Vector2.ZERO)
		v.spacing_glyph = 1
		_display = v
	return _display


## The title face: the display face with wide tracking.
static func title_font() -> Font:
	if _wide == null:
		var v := FontVariation.new()
		v.base_font = display()
		v.spacing_glyph = 6
		_wide = v
	return _wide


static func _load(path: String, fallback: Array) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f:
			return f
	var s := SystemFont.new()
	s.font_names = PackedStringArray(fallback)
	return s


## Base size for body text, from the visible height (720 logical -> 24).
static func text_px(vp: Viewport) -> int:
	return clampi(int(vp.get_visible_rect().size.y / 30.0), 18, 34)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = display()
	t.default_font_size = 24
	var normal := box(PANEL, STEEL_DIM, 1, 3)
	var hover := box(Color(0.08, 0.095, 0.085, 0.96), GREEN_DIM, 1, 3)
	var pressed := box(Color(0.1, 0.15, 0.1, 0.98), GREEN, 1, 3)
	var disabled := box(Color(0.05, 0.055, 0.057, 0.8), Color(0.44, 0.47, 0.48, 0.15), 1, 3)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", OFFWHITE)
	t.set_color("font_hover_color", "Button", OFFWHITE)
	t.set_color("font_pressed_color", "Button", GREEN)
	t.set_color("font_hover_pressed_color", "Button", GREEN)
	t.set_color("font_focus_color", "Button", OFFWHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.45))
	# Tab buttons: flat, the selected one underlined in green.
	t.set_type_variation("TabButton", "Button")
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(0, 0, 0, 0)
	tab.content_margin_left = 16
	tab.content_margin_right = 16
	tab.content_margin_top = 8
	tab.content_margin_bottom = 8
	tab.border_width_bottom = 2
	tab.border_color = Color(0.44, 0.47, 0.48, 0.25)
	var tab_on := tab.duplicate() as StyleBoxFlat
	tab_on.border_width_bottom = 3
	tab_on.border_color = GREEN
	tab_on.bg_color = Color(0.47, 0.72, 0.42, 0.06)
	for k in ["normal", "hover", "disabled"]:
		t.set_stylebox(k, "TabButton", tab)
	t.set_stylebox("pressed", "TabButton", tab_on)
	t.set_stylebox("hover_pressed", "TabButton", tab_on)
	t.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	t.set_color("font_color", "TabButton", MUTED)
	t.set_color("font_hover_color", "TabButton", OFFWHITE)
	t.set_color("font_pressed_color", "TabButton", OFFWHITE)
	t.set_color("font_hover_pressed_color", "TabButton", OFFWHITE)
	t.set_color("font_color", "Label", OFFWHITE)
	t.set_color("default_color", "RichTextLabel", OFFWHITE)
	var panel := box(Color(0.05, 0.056, 0.058, 0.97), STEEL_DIM, 1, 1)
	panel.border_width_top = 3
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 22
	panel.content_margin_bottom = 22
	t.set_stylebox("panel", "PanelContainer", panel)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = STEEL_DIM
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(k, "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


## Flat rectangular box: `width` px border, `left` px accent on the left.
static func box(bg: Color, border: Color, width := 1, left := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.border_width_left = left
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 8
	b.content_margin_bottom = 8
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


static func label(text: String, size := 0, color := OFFWHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A label in the monospaced technical face.
static func mono(text: String, size: int, color := MUTED) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font())
	return l


## A thin horizontal rule.
static func rule(color := STEEL_DIM, width := 0.0, thickness := 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
