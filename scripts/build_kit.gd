class_name BuildKit
extends RefCounted
## Small static helpers for building low-poly room geometry from code,
## plus a shared material palette so every station uses the same look.

static var _materials: Dictionary = {}

# Colour language (see design brief): green = CRT, amber = warnings,
# red = critical. Kept here so later stages reuse identical values.
const GREEN := Color(0.35, 1.0, 0.45)
const AMBER := Color(1.0, 0.62, 0.12)
const RED := Color(1.0, 0.12, 0.08)


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg := Vector3.ZERO, cast_shadow := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, rot_deg, mat, cast_shadow)


## Cylinder along local Y. Use rot_deg (90, 0, 0) to point it along Z.
static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material, rot_deg := Vector3.ZERO, segments := 12,
		top_radius := -1.0, cast_shadow := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add(parent, mesh, pos, rot_deg, mat, cast_shadow)


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _add(parent, mesh, pos, Vector3.ZERO, mat, false)


static func quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, rot_deg, mat, false)


static func label(parent: Node3D, text: String, pos: Vector3, size := 0.018,
		color := Color(0.12, 0.11, 0.1), rot_deg := Vector3.ZERO, shaded := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = size / 48.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = shaded
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot_deg
	parent.add_child(l)
	return l


## Assigns a material only when it differs (avoids redundant per-frame
## updates to the rendering server from animated lamps).
static func set_mat(mi: GeometryInstance3D, m: Material) -> void:
	if mi.material_override != m:
		mi.material_override = m


## Snaps a lever pivot to its up/down position with a small overshoot.
static func flip_lever(hinge: Node3D, up: bool, angle := 28.0) -> void:
	var tw := hinge.create_tween()
	tw.tween_property(hinge, "rotation_degrees:x", angle if up else -angle, 0.09) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A pivot node: lets a station place a tilted panel and then position
## its controls in the panel's own flat coordinate space.
static func pivot(parent: Node3D, pos: Vector3, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	return n


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3,
		mat: Material, cast_shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- Materials -------------------------------------------------------------

## Named surface materials. Textured ones use world-space triplanar mapping
## so texel density stays consistent on every box without UV work.
static func mat(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]
	var m: StandardMaterial3D
	match name:
		"concrete": m = _textured("concrete", 0.55, 0.95)
		"floor": m = _textured("floor", 0.5, 0.85)
		"paint_green": m = _textured("paint_green", 1.6, 0.7, 0.15)
		"paint_beige":
			m = _textured("paint_beige", 1.6, 0.75, 0.1)
			m.albedo_color = Color(0.78, 0.77, 0.74)
		"paint_grey": m = _textured("paint_grey", 1.6, 0.7, 0.2)
		"paint_case":
			m = _textured("paint_grey", 1.6, 0.6, 0.2)
			m.albedo_color = Color(0.55, 0.57, 0.56)
		"metal_dark": m = _textured("metal_dark", 2.0, 0.55, 0.55)
		"hazard": m = _textured("hazard", 2.5, 0.8)
		"bakelite": m = _plain(Color(0.05, 0.05, 0.05), 0.35)
		"rubber": m = _plain(Color(0.07, 0.07, 0.07), 0.9)
		"steel": m = _plain(Color(0.55, 0.56, 0.57), 0.4, 0.8)
		"brass": m = _plain(Color(0.55, 0.42, 0.2), 0.45, 0.8)
		"paper": m = _plain(Color(0.86, 0.84, 0.76), 1.0)
		"paper_old": m = _plain(Color(0.78, 0.74, 0.6), 1.0)
		"gauge_face": m = _plain(Color(0.88, 0.85, 0.74), 0.8)
		"needle": m = _plain(Color(0.08, 0.06, 0.05), 0.6)
		"screen_off": m = _plain(Color(0.03, 0.05, 0.04), 0.2)
		"cable": m = _plain(Color(0.04, 0.04, 0.04), 0.7)
		"red_paint": m = _plain(Color(0.5, 0.06, 0.04), 0.6)
		"glass":
			m = StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.55, 0.65, 0.62, 0.14)
			m.roughness = 0.3
			m.metallic_specular = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			push_warning("Unknown material '%s'" % name)
			m = _plain(Color.MAGENTA, 1.0)
	_materials[name] = m
	return m


## Self-lit indicator lamp. `lit` false gives the dim, unpowered cap.
static func lamp(color: Color, lit := true, energy := 2.2) -> StandardMaterial3D:
	var key := [color, lit, energy]          # value key: no string building per frame
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	if lit:
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
	else:
		m.albedo_color = color.darkened(0.75)
		m.roughness = 0.3
	_materials[key] = m
	return m


static func image(path: String, unshaded := false) -> StandardMaterial3D:
	if _materials.has(path):
		return _materials[path]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[path] = m
	return m


static func _textured(tex: String, scale: float, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % tex)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	m.metallic = metal
	# Nearest filtering keeps the low-res, slightly chunky texel character.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m


static func _plain(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
