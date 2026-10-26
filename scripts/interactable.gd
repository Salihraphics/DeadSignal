class_name Interactable
extends Area3D
## An invisible tap target. Stations create these around props and
## connect `activated` to their own placeholder feedback.
##
## A *focus zone* (focus_zone = true) does not activate directly: tapping
## it makes the operator lean in toward it. Interactables inside a zone
## only respond while that zone is focused, so small or distant controls
## are never tapped at an awkward size. The zone's local +Z must face the
## operator; the camera looks at its origin from `focus_distance` away.

signal activated(hit_position: Vector3)
## A tap on the zone surface itself while focused: the local position
## where the tap ray meets the plane z = surface_z (e.g. a CRT's glass).
signal poked(local_position: Vector3)
signal action_requested(action_name: String)
## Rotary controls: change of angle (radians, clockwise positive) as the
## finger circles the control's on-screen centre.
signal turned(delta_rad: float)
## Two-axis controls (trackball): finger movement in screen pixels.
signal dragged(delta_px: Vector2)

@export var focus_zone := false
@export var focus_title := ""
@export var focus_distance := 0.5
@export var focus_fov := 50.0
@export var focus_actions: PackedStringArray = []
## Local z of the visible surface behind the (deliberately deep) tap box.
## Pokes are measured on this plane, not on the box face, so there is no
## parallax between where a finger lands and what is drawn there.
@export var surface_z := 0.0
## "" = tap only, "rotary" = knob turned by circling, "pad" = 2-axis drag.
## Draggable controls capture the whole touch so the camera never moves.
@export var drag_mode := ""
## Usable whether or not a focus zone is active (e.g. the map navigation
## unit, which sits beside the map screen it controls).
@export var always_active := false
## Shifts the focus look-at point (zone-local metres) to frame neighbours.
@export var focus_offset := Vector3.ZERO
## Raises the eye above the zone's normal so the view looks down onto it.
@export var focus_elevation_deg := 0.0


## Creates a box-shaped tap target. `size` should be generous: touch
## targets are deliberately larger than the visible control.
static func make(parent: Node3D, size: Vector3, pos := Vector3.ZERO, id := "") -> Interactable:
	var area := Interactable.new()
	if id:
		area.name = id
	area.position = pos
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	return area


func focus_pose() -> Transform3D:
	var target := to_global(focus_offset)
	var axis := global_basis.x.normalized()
	var dir := global_basis.z.normalized().rotated(axis, -deg_to_rad(focus_elevation_deg))
	var eye := target + dir * focus_distance
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


## Local point where a world-space ray meets the surface plane, or null.
func surface_point(origin: Vector3, dir: Vector3) -> Variant:
	var o := to_local(origin)
	var d := to_local(origin + dir) - o
	if absf(d.z) < 1e-6:
		return null
	var t := (surface_z - o.z) / d.z
	return o + d * t if t > 0.0 else null


## Nearest enclosing focus zone (excluding self), or null.
func parent_zone() -> Interactable:
	var n := get_parent()
	while n:
		for c in n.get_children():
			if c is Interactable and c != self and c.focus_zone and c._contains(self):
				return c
		n = n.get_parent()
	return null


func _contains(other: Node) -> bool:
	# A zone owns the interactables built under the same parent node.
	return get_parent().is_ancestor_of(other)
