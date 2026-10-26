extends Node
## Routes taps to Interactables and manages focus mode.
##
## The camera decides what a tap is (press + release without dragging)
## and hands it here first. GUI buttons consume their own input before it
## ever reaches the camera, so HUD taps never turn the view.

@export var camera: Camera3D
@export var hud: CanvasLayer

var _zone: Interactable = null


func _ready() -> void:
	camera.tap_handler = _on_tap
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
		if h.collider != _zone and not h.collider.focus_zone and _zone._contains(h.collider):
			inner.append(h)
	if not inner.is_empty():
		var hit := _best(inner, screen_pos)
		hit.collider.activated.emit(hit.position)
		return true
	for h in hits:
		if h.collider == _zone:
			_zone.poked.emit(_zone.to_local(h.position))
			return true
	return false


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
