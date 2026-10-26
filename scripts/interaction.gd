extends Node
## Routes taps to Interactables and manages focus mode.
##
## The camera decides what a tap is (press + release without dragging)
## and hands it here first. GUI buttons consume their own input before it
## ever reaches the camera, so HUD taps never turn the view.

@export var camera: Camera3D
@export var hud: CanvasLayer

var _zone: Interactable = null
var _drag: Interactable = null
var _drag_center := Vector2.ZERO
var _drag_angle := NAN


func _ready() -> void:
	camera.tap_handler = _on_tap
	camera.press_handler = _on_press
	camera.drag_handler = _on_drag
	camera.release_handler = _on_release
	camera.unfocus_requested.connect(exit_focus)
	hud.back_pressed.connect(exit_focus)
	hud.action_pressed.connect(_on_action)


func is_focused() -> bool:
	return _zone != null


func enter_focus(zone: Interactable) -> void:
	_zone = zone
	camera.focus(zone.focus_pose(), zone.focus_fov)
	hud.show_focus(zone.focus_title, zone.focus_actions)


func exit_focus() -> void:
	if _zone == null:
		return
	_zone = null
	camera.unfocus()
	hud.hide_focus()


## Returns true when the tap was used (so the camera skips double-tap).
func _on_tap(screen_pos: Vector2) -> bool:
	var hits := _hits(screen_pos)
	if _zone == null:
		if hits.is_empty():
			return false
		var hit := _best(hits, screen_pos)
		var target: Interactable = hit.collider
		var zone := target if target.focus_zone else target.parent_zone()
		if zone:
			enter_focus(zone)
		else:
			target.activated.emit(hit.position)
		return true

	# Focused: controls inside the zone first, then the zone surface.
	var inner: Array[Dictionary] = []
	for h in hits:
		var c: Interactable = h.collider
		if c != _zone and not c.focus_zone and (_zone._contains(c) or c.always_active):
			inner.append(h)
	if not inner.is_empty():
		var hit := _best(inner, screen_pos)
		hit.collider.activated.emit(hit.position)
		return true
	for h in hits:
		if h.collider == _zone:
			var p: Variant = _zone.surface_point(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
			if p != null:
				_zone.poked.emit(p)
			return true
	return false


## Capture a press that lands on a draggable control usable right now.
func _on_press(screen_pos: Vector2) -> bool:
	var usable: Array[Dictionary] = []
	for h in _hits(screen_pos):
		var c: Interactable = h.collider
		if c.focus_zone:
			continue
		if c.always_active or (_zone == null and c.parent_zone() == null) or (_zone and _zone._contains(c)):
			usable.append(h)
	if usable.is_empty():
		return false
	var best: Interactable = _best(usable, screen_pos).collider
	if best.drag_mode == "":
		return false
	_drag = best
	_drag_center = camera.unproject_position(best.global_position)
	_drag_angle = NAN
	_update_angle(screen_pos)
	return true


func _on_drag(screen_pos: Vector2, relative: Vector2) -> void:
	if _drag == null:
		return
	if _drag.drag_mode == "pad":
		_drag.dragged.emit(relative)
		return
	var before := _drag_angle
	_update_angle(screen_pos)
	if not is_nan(before) and not is_nan(_drag_angle):
		_drag.turned.emit(wrapf(_drag_angle - before, -PI, PI))


func _on_release(screen_pos: Vector2, moved: bool) -> void:
	if _drag and not moved:
		_drag.activated.emit(_drag.global_position)   # a tap on the control
	_drag = null


## Angle of the finger around the control's centre (screen y points down,
## so increasing angle is clockwise). Ignored very near the centre.
func _update_angle(screen_pos: Vector2) -> void:
	var v := screen_pos - _drag_center
	_drag_angle = v.angle() if v.length() > 12.0 else NAN


## Every Interactable along the tap ray, nearest first. Generous touch
## boxes overlap when seen at an angle, so a ray can pass through several.
func _hits(screen_pos: Vector2) -> Array[Dictionary]:
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * 6.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := camera.get_world_3d().direct_space_state
	var found: Array[Dictionary] = []
	for i in range(6):
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		if hit.collider is Interactable:
			found.append(hit)
		query.exclude = query.exclude + [hit.rid]
	return found


## The nearest hit decides: a focus zone is taken as is; among small
## controls, the one whose centre appears closest to the finger wins.
func _best(hits: Array[Dictionary], screen_pos: Vector2) -> Dictionary:
	var best: Dictionary = hits[0]
	if best.collider.focus_zone:
		return best
	var best_d := INF
	for h in hits:
		if h.collider.focus_zone:
			continue
		var d := camera.unproject_position(h.collider.global_position).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = h
	return best


func _on_action(action_name: String) -> void:
	if _zone:
		_zone.action_requested.emit(action_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _zone:
		exit_focus()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Android back gesture / button: close the message reader, then leave
	# focus, otherwise quit.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var reader := get_tree().get_first_node_in_group("message_reader")
		if reader and reader.is_open():
			reader.close()
		elif _zone:
			exit_focus()
		else:
			get_tree().quit()
