extends Control
## After-action report: a cold archival sheet listing only what the game
## actually tracked during the run (Run.final_stats). No casualty figures,
## no invented numbers. RETURN TO MENU ends it.

const OUTCOME := {
	"EXECUTED": "OPERATOR RELIEVED OF DUTY. RECORD TRANSFERRED TO MILITARY TRIBUNAL. FILE CLOSED.",
	"FALL": "VARNESK: CONTACT LOST. POST K-4: CONTACT LOST. RECORD INCOMPLETE.",
	"SURVIVED": "SHIFT CLOSED. OPERATOR STOOD DOWN. SERVICE RECORD ARCHIVED.",
}


func _ready() -> void:
	name = "AfterAction"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var px := UiKit.text_px(get_viewport())
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vs := get_viewport().get_visible_rect().size
	var sheet := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.83, 0.82, 0.77)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	sheet.add_theme_stylebox_override("panel", sb)
	var m := minf(vs.x, vs.y) * 0.04
	add_child(sheet)
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = m
	sheet.offset_top = m
	sheet.offset_right = -m
	sheet.offset_bottom = -m
	var col := VBoxContainer.new()
	sheet.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var text := RichTextLabel.new()
	text.name = "Report"
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", UiKit.font())
	text.add_theme_font_override("bold_font", UiKit.font())
	text.add_theme_font_size_override("normal_font_size", int(px * 0.78))
	text.add_theme_font_size_override("bold_font_size", int(px * 0.78))
	text.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	text.text = report_text(Run.final_stats)
	scroll.add_child(text)
	var b := UiKit.button("> RETURN TO MENU", func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), "ReturnMenu")
	b.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1))
	b.add_theme_font_size_override("font_size", px)
	col.add_child(b)
	Sfx.play("typewriter", -6.0)


static func report_text(s: Dictionary) -> String:
	if s.is_empty():
		return "NO RECORD."
	var L: PackedStringArray = []
	L.append("[b]NORVAK STRATEGIC COMMAND  -  ARCHIVE[/b]")
	L.append("AFTER-ACTION REPORT  /  LAUNCH CONTROL POST K-4")
	L.append("-".repeat(56))
	L.append("SHIFT              %s" % s.shift)
	L.append("OUTCOME            %s" % OUTCOME.get(s.ending, s.ending))
	L.append("")
	L.append("[b]ORDERS[/b]")
	L.append("RECEIVED %d   FOLLOWED %d   REFUSED %d   NO REPLY %d" % [s.orders_received, s.followed, s.refused, s.no_reply])
	for d in s.get("decisions", []):
		L.append("  %s  %-8s %s" % [d.time, d.id, d.decision])
	L.append("")
	L.append("[b]INFORMATION[/b]")
	L.append("REPORTS RECEIVED            %d" % s.reports)
	L.append("OF WHICH UNVERIFIED         %d" % s.unverified)
	L.append("CONFIRMATIONS REQUESTED     %d" % s.requests)
	L.append("CONFIRMATIONS ANSWERED      %d" % s.requests_answered)
	L.append("RADIO INTERCEPTS LOGGED     %d" % s.intercepts)
	L.append("ITEMS FORWARDED TO COMMAND  %d" % s.forwarded)
	L.append("CALLS ANSWERED / MISSED     %d / %d" % [s.calls_answered, s.calls_missed])
	L.append("")
	L.append("[b]MUNITIONS[/b]")
	if s.launches.is_empty():
		L.append("NO LAUNCHES RECORDED.")
	for e in s.launches:
		L.append("  %s  %s  ORDER %s  GRID %s  %s" % [e.time, e.launch_id, e.order_id, e.grid, e.ammo])
		L.append("        RESULT: %s" % e.result)
	L.append("ALLOCATION UNITS EXPENDED   %d" % s.units_expended)
	L.append("ALLOCATION UNITS REMAINING  %d" % s.get("resources_left", 0))
	L.append("")
	L.append("[b]PERSONAL[/b]")
	L.append("BEERS                       %d" % s.beers)
	L.append("CIGARETTES                  %d" % s.cigarettes)
	L.append("")
	L.append("-".repeat(56))
	L.append("FIGURES ABOVE ARE THE POST'S OWN RECORD. NO OTHER RECORD EXISTS.")
	return "\n".join(L)
