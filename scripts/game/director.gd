extends Node
## Runs the continuous shift inside the command room: room ambience, the
## power-up after the cinematic, and (when a run is active) the scenario
## timeline. Opened directly without a run (editor / tests), the room is a
## sandbox: no scenario, the legacy first order only.

var _fade: ColorRect


func _ready() -> void:
	Sfx.loop("generator_hum", -20.0, "SFX", 1.5)
	Sfx.loop("fluorescent", -30.0, "SFX", 1.5)
	if not Run.active:
		return
	Dialogue.begin_session()
	if Run.fresh:
		_power_up()


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
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
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
