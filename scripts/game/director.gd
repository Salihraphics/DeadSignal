extends Node
## Runs the continuous shift inside the command room: room ambience, the
## power-up after the cinematic, and (when a run is active) the scenario
## timeline. Opened directly without a run (editor / tests), the room is a
## sandbox: no scenario, the legacy first order only.


func _ready() -> void:
	Sfx.loop("generator_hum", -20.0, "SFX", 1.5)
	Sfx.loop("fluorescent", -30.0, "SFX", 1.5)
	if not Run.active:
		return
	Dialogue.begin_session()
