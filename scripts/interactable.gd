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
## A tap on the zone surface itself while focused (local position).
signal poked(local_position: Vector3)
signal action_requested(action_name: String)

@export var focus_zone := false
@export var focus_title := ""
@export var focus_distance := 0.5
@export var focus_fov := 50.0
@export var focus_actions: PackedStringArray = []


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
	var eye := global_position + global_basis.z.normalized() * focus_distance
	return Transform3D(Basis.looking_at(global_position - eye, Vector3.UP), eye)


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
