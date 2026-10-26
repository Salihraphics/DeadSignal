extends Node
## The operator's voice (autoload "Dialogue"). Picks an eligible line for
## an event from DialogueLines and speaks it: the Russian recording if it
## exists, always with an English subtitle (forced on while no recording
## exists, so the line is never lost).
##
## Rules: one-time lines are recorded in Run.said and never repeat (also
## across save/load); repeatable lines have a cooldown and never play twice
## in a row; spontaneous lines (ambient, isolation) respect a global quiet
## gap so the operator stays sparse. Only runs inside an active run.

const QUIET_GAP := 45.0          # seconds between spontaneous lines
const ISOLATION_S := 110.0       # no input for this long -> "isolation"
const AMBIENT_EVERY := Vector2(150.0, 230.0)

var enabled := false             # set by the command room
var _last_line_t := -1000.0
var _last_id := ""
var _cool := {}                  # id -> run time when usable again
var _idle := 0.0
var _isolation_said := false
var _next_ambient := 200.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		_idle = 0.0
		_isolation_said = false


func _process(delta: float) -> void:
	if not enabled or not Run.active:
		return
	_idle += delta
	if _idle > ISOLATION_S and not _isolation_said:
		_isolation_said = true
		trigger("isolation", {}, false)
	if Run.elapsed > _next_ambient:
		_next_ambient = Run.elapsed + randf_range(AMBIENT_EVERY.x, AMBIENT_EVERY.y)
		trigger("ambient", {}, false)


## Speaks one eligible line for `event`. `urgent` lines ignore the quiet
## gap (they answer something that just happened). Returns the line id or "".
func trigger(event: String, ctx := {}, urgent := true) -> String:
	if not Run.active:
		return ""
	var t := Run.elapsed
	if not urgent and t - _last_line_t < QUIET_GAP:
		return ""
	if Subtitles.is_showing() and not urgent:
		return ""
	var line := pick(event, ctx)
	if line.is_empty():
		return ""
	speak(line)
	return line.id


## The first eligible line for the event, in library order.
func pick(event: String, ctx := {}) -> Dictionary:
	var t := Run.elapsed
	for l in DialogueLines.LINES:
		if l.event != event or not _eligible(l, ctx, t):
			continue
		return l
	return {}


func _eligible(l: Dictionary, ctx: Dictionary, t: float) -> bool:
	if l.get("once", true) and Run.said.has(l.id):
		return false
	if l.id == _last_id:
		return false
	if t < float(l.get("min_t", 0.0)) or t < float(_cool.get(l.id, -1.0)):
		return false
	for k in l.get("cond", {}):
		if ctx.get(k) != l.cond[k]:
			return false
	return true


func speak(l: Dictionary) -> void:
	Run.said[l.id] = Run.hhmm()
	_last_id = l.id
	_last_line_t = Run.elapsed
	if not l.get("once", true):
		_cool[l.id] = Run.elapsed + float(l.get("cooldown", 300.0))
	var length := Sfx.voice(DialogueLines.voice_path(l.id))
	# No recording yet: the subtitle carries the line regardless of settings.
	Subtitles.say(DialogueLines.SPEAKER, l.text, maxf(length + 0.6, 0.0) if length > 0.0 else 0.0, length < 0.0)


## Resets per-session timers (not the one-time record, which lives in Run).
func begin_session() -> void:
	enabled = true
	_idle = 0.0
	_isolation_said = false
	_last_line_t = Run.elapsed
	_next_ambient = maxf(Run.elapsed + 120.0, 200.0)
