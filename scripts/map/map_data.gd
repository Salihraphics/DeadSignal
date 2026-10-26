class_name MapData
extends RefCounted
## Fixed geography of map sheet 4: a fictional section of the
## Norvak-Dravonya border. Coordinates are MapGrid kilometres (x east,
## y south). Norvak holds the north and west, Dravonya the south-east.
##
## Base geography (terrain, water, transport, settlements) is separate
## from the military overlay (border, front, units, intelligence) and from
## TRUTH, which only the outcome model reads. Derived layers (contours,
## forest symbols, bridges) are computed once, deterministically.
## All names and units are fictional and provisional.

# --- Terrain ---------------------------------------------------------------
## Ridgelines that raise the heightfield. Gaps between the northern
## ridges are the two passes used by the north rail line and road.
const RIDGES := [
	{"name": "KOLDEN UPLANDS", "pts": [Vector2(4, 10), Vector2(18, 6), Vector2(34, 7), Vector2(48, 12)], "amp": 1.0, "w": 6.5},
	{"name": "", "pts": [Vector2(72, 9), Vector2(86, 4), Vector2(104, 10)], "amp": 0.95, "w": 6.0},
	{"name": "VESKAR HEIGHTS", "pts": [Vector2(126, 10), Vector2(136, 6), Vector2(148, 9), Vector2(160, 15)], "amp": 0.9, "w": 6.5},
	{"name": "SOREN RIDGE", "pts": [Vector2(88, 26), Vector2(93, 32), Vector2(96, 38)], "amp": 0.55, "w": 3.5},
	{"name": "", "pts": [Vector2(18, 34), Vector2(22, 46), Vector2(20, 56)], "amp": 0.45, "w": 5.0},
	{"name": "", "pts": [Vector2(80, 62), Vector2(84, 72)], "amp": 0.35, "w": 3.0},
	{"name": "", "pts": [Vector2(58, 96), Vector2(68, 102), Vector2(76, 100)], "amp": 0.35, "w": 4.0},
	{"name": "", "pts": [Vector2(148, 106), Vector2(158, 112)], "amp": 0.45, "w": 4.0},
]
const PASSES := [
	{"name": "BRENN PASS", "pos": Vector2(60, 10)},
	{"name": "DUBROVA PASS", "pos": Vector2(115, 12)},
]
const CONTOUR_LEVELS := [0.3, 0.5, 0.7, 0.9]
const INDEX_LEVELS := [0.5, 0.9]                 # drawn brighter
const FORESTS := [
	[Vector2(2, 14), Vector2(30, 13), Vector2(44, 18), Vector2(40, 30), Vector2(24, 31), Vector2(6, 28)],
	[Vector2(2, 40), Vector2(12, 37), Vector2(15, 50), Vector2(10, 57), Vector2(2, 56)],
	[Vector2(36, 55), Vector2(50, 57), Vector2(54, 65), Vector2(45, 71), Vector2(34, 66)],
	[Vector2(80, 21), Vector2(94, 19), Vector2(98, 28), Vector2(90, 33), Vector2(82, 30)],
	[Vector2(61, 51), Vector2(70, 53), Vector2(68, 60), Vector2(60, 58)],
	[Vector2(100, 39), Vector2(106, 37), Vector2(108, 43), Vector2(102, 44)],
	[Vector2(110, 96), Vector2(118, 94), Vector2(120, 102), Vector2(112, 104)],
]

# --- Hydrography -------------------------------------------------------------
## cls 0 main river, 1 tributary, 2 stream. Tributaries end exactly on a
## vertex of the river they join.
const RIVERS := [
	{"name": "LESNA", "cls": 0, "pts": [Vector2(131, 12), Vector2(128, 20), Vector2(124, 28), Vector2(116, 36), Vector2(106, 42), Vector2(98, 45),
		Vector2(94, 46.5), Vector2(89, 51), Vector2(84, 56), Vector2(78, 60.5), Vector2(72, 65), Vector2(64, 70),
		Vector2(56, 76), Vector2(48, 82), Vector2(40, 90), Vector2(32, 98), Vector2(24, 108), Vector2(16, 120)]},
	{"name": "VILNA", "cls": 1, "pts": [Vector2(58, 16), Vector2(60, 26), Vector2(64, 36), Vector2(66, 46), Vector2(68, 56), Vector2(72, 65)]},
	{"name": "BROD", "cls": 1, "pts": [Vector2(154, 19), Vector2(150, 30), Vector2(142, 40), Vector2(132, 48), Vector2(120, 52), Vector2(108, 52), Vector2(98, 45)]},
	{"name": "SAVA", "cls": 1, "pts": [Vector2(152, 106), Vector2(140, 96), Vector2(124, 92), Vector2(108, 88), Vector2(92, 84), Vector2(76, 86), Vector2(64, 82), Vector2(56, 76)]},
	{"name": "ORLA", "cls": 2, "pts": [Vector2(24, 44), Vector2(28, 56), Vector2(34, 66), Vector2(42, 76), Vector2(48, 82)]},
]

# --- Transport -------------------------------------------------------------
## Railways: cls 0 main line, 1 branch, 2 spur. Branches start exactly on
## a vertex of the main line (a real junction, not an overlap).
const KARSEN_JN := Vector2(78, 47)
const RAILS := [
	{"name": "MAIN LINE", "cls": 0, "pts": [Vector2(0, 30), Vector2(12, 32), Vector2(24, 36), Vector2(32, 40), Vector2(42, 43),
		Vector2(54, 44), Vector2(66, 45), KARSEN_JN, Vector2(86, 49), Vector2(92, 50), Vector2(100, 52), Vector2(112, 56),
		Vector2(122, 60), Vector2(136, 62), Vector2(160, 66)]},
	{"name": "NORTH LINE", "cls": 1, "pts": [KARSEN_JN, Vector2(74, 36), Vector2(68, 26), Vector2(62, 16), Vector2(60, 8), Vector2(60, 0)]},
	{"name": "SOUTH LINE", "cls": 1, "pts": [KARSEN_JN, Vector2(79, 58), Vector2(81, 66), Vector2(84, 78), Vector2(86, 90), Vector2(86, 96), Vector2(88, 120)]},
	{"name": "", "cls": 1, "pts": [Vector2(122, 60), Vector2(130, 48), Vector2(140, 40)]},
	{"name": "", "cls": 1, "pts": [Vector2(122, 60), Vector2(128, 76), Vector2(140, 90), Vector2(146, 92)]},
	{"name": "", "cls": 2, "pts": [Vector2(32, 40), Vector2(34, 44), Vector2(35, 47)]},
	{"name": "", "cls": 2, "pts": [KARSEN_JN, Vector2(75, 50), Vector2(73, 52)]},
]
## Roads: cls 0 primary, 1 secondary, 2 local track (close zoom only).
const ROADS := [
	{"cls": 0, "pts": [Vector2(0, 42), Vector2(14, 44), Vector2(32, 40), Vector2(44, 48), Vector2(58, 50), Vector2(70, 50), Vector2(79.5, 45.5),
		Vector2(88, 46), Vector2(94, 47), Vector2(100, 48), Vector2(112, 54), Vector2(122, 60)]},
	{"cls": 0, "pts": [Vector2(32, 40), Vector2(40, 30), Vector2(50, 20), Vector2(57, 12), Vector2(62, 0)]},
	{"cls": 0, "pts": [Vector2(79.5, 45.5), Vector2(76, 56), Vector2(74, 66), Vector2(78, 80), Vector2(86, 96), Vector2(90, 120)]},
	{"cls": 0, "pts": [Vector2(122, 60), Vector2(130, 72), Vector2(146, 92), Vector2(160, 98)]},
	{"cls": 1, "pts": [Vector2(18, 62), Vector2(24, 52), Vector2(32, 40)]},
	{"cls": 1, "pts": [Vector2(18, 62), Vector2(28, 84), Vector2(40, 100), Vector2(60, 104), Vector2(74, 99), Vector2(86, 96)]},
	{"cls": 1, "pts": [Vector2(60, 36), Vector2(58, 50)]},
	{"cls": 1, "pts": [Vector2(46, 22), Vector2(50, 20)]},
	{"cls": 1, "pts": [Vector2(88, 30), Vector2(84, 38), Vector2(79.5, 45.5)]},
	{"cls": 1, "pts": [Vector2(88, 30), Vector2(96, 22), Vector2(106, 16), Vector2(114, 10), Vector2(116, 0)]},
	{"cls": 1, "pts": [Vector2(62, 72), Vector2(66, 62), Vector2(70, 50)]},
	{"cls": 1, "pts": [Vector2(70, 86), Vector2(78, 80)]},
	{"cls": 1, "pts": [Vector2(108, 84), Vector2(120, 76), Vector2(130, 72)]},
	{"cls": 1, "pts": [Vector2(122, 60), Vector2(132, 50), Vector2(140, 40)]},
	{"cls": 1, "pts": [Vector2(128, 108), Vector2(146, 92)]},
	{"cls": 2, "pts": [Vector2(90.8, 51.2), Vector2(92.5, 49), Vector2(94, 47)]},
	{"cls": 2, "pts": [Vector2(32, 40), Vector2(35, 47)]},
	{"cls": 2, "pts": [Vector2(79.5, 45.5), Vector2(73, 52)]},
	{"cls": 2, "pts": [Vector2(28, 84), Vector2(20, 92)]},
	{"cls": 2, "pts": [Vector2(86, 96), Vector2(96, 100)]},
	{"cls": 2, "pts": [Vector2(60, 36), Vector2(54, 30)]},
	{"cls": 2, "pts": [Vector2(140, 40), Vector2(146, 31)]},
]
## Map-edge connections (not drawn as places; Varnesk lies off this sheet).
const EXITS := [
	{"label": "TO VARNESK", "pos": Vector2(0, 36), "dir": Vector2.LEFT},
	{"label": "TO DRAVONYA", "pos": Vector2(160, 66), "dir": Vector2.RIGHT},
]

# --- Settlements and infrastructure -----------------------------------------
## cls "town" or "village". All settlements are civilian-sensitive.
const SETTLEMENTS := [
	{"name": "HADRIN", "pos": Vector2(32, 40), "cls": "town", "side": "N"},
	{"name": "ORLEN", "pos": Vector2(18, 62), "cls": "town", "side": "N"},
	{"name": "PELLIN", "pos": Vector2(40, 100), "cls": "town", "side": "N"},
	{"name": "KOSSA", "pos": Vector2(46, 22), "cls": "village", "side": "N"},
	{"name": "BRENN", "pos": Vector2(60, 36), "cls": "village", "side": "N"},
	{"name": "TARVIK", "pos": Vector2(62, 72), "cls": "village", "side": "N"},
	{"name": "LOSNO", "pos": Vector2(28, 84), "cls": "village", "side": "N"},
	{"name": "KARSEN", "pos": Vector2(79.5, 45.5), "cls": "town", "side": "N"},
	{"name": "DUBROVA", "pos": Vector2(88, 30), "cls": "village", "side": "N"},
	{"name": "LIPA", "pos": Vector2(90.8, 51.2), "cls": "village", "side": "N"},
	{"name": "TOVEL", "pos": Vector2(86, 96), "cls": "town", "side": "N"},
	{"name": "MEDNO", "pos": Vector2(70, 86), "cls": "village", "side": "N"},
	{"name": "ZARECH", "pos": Vector2(122, 60), "cls": "town", "side": "D"},
	{"name": "GRODEK", "pos": Vector2(140, 40), "cls": "village", "side": "D"},
	{"name": "SOBIN", "pos": Vector2(108, 84), "cls": "village", "side": "D"},
	{"name": "KURGAL", "pos": Vector2(146, 92), "cls": "town", "side": "D"},
	{"name": "VELO", "pos": Vector2(128, 108), "cls": "village", "side": "D"},
]
const SETTLEMENT_RADIUS := {"town": 1.4, "village": 0.6}
## type: junction, freight, factory, power, logistics. military = drawn in
## the UNITS layer (logistics areas), otherwise in SETTLEMENTS.
const FACILITIES := [
	{"name": "KARSEN JUNCTION", "pos": KARSEN_JN, "type": "junction", "side": "N", "military": false},
	{"name": "KARSEN YARD", "pos": Vector2(73, 52), "type": "freight", "side": "N", "military": false},
	{"name": "HADRIN WORKS", "pos": Vector2(35, 47), "type": "factory", "side": "N", "military": false},
	{"name": "HADRIN POWER STN", "pos": Vector2(28, 37), "type": "power", "side": "N", "military": false},
	{"name": "LOG AREA 2", "pos": Vector2(44, 47), "type": "logistics", "side": "N", "military": true},
	{"name": "ZARECH DEPOT", "pos": Vector2(126, 63), "type": "logistics", "side": "D", "military": true},
]

# --- Military overlay (what Norvak knows) ------------------------------------
const BORDER := [Vector2(160, 26), Vector2(140, 28), Vector2(122, 26), Vector2(110, 30), Vector2(102, 38), Vector2(99, 48),
	Vector2(98, 60), Vector2(95, 72), Vector2(92, 86), Vector2(90, 100), Vector2(88, 120)]
## Line of contact: follows the border except a Dravonyan salient west of it.
const FRONT := [Vector2(160, 26), Vector2(140, 28), Vector2(122, 26), Vector2(110, 30), Vector2(100, 34), Vector2(92, 38),
	Vector2(87, 44), Vector2(85, 50), Vector2(86, 58), Vector2(89, 68), Vector2(95, 72), Vector2(92, 86), Vector2(90, 100), Vector2(88, 120)]
## side F friendly, H hostile (confirmed), U unidentified contact.
## type: armour, motor, artillery, airdef, recon, engineer, unknown.
const UNITS := [
	{"id": "21 MR", "side": "F", "type": "motor", "pos": Vector2(81, 42)},
	{"id": "7 ARM", "side": "F", "type": "armour", "pos": Vector2(76, 54)},
	{"id": "4 ART", "side": "F", "type": "artillery", "pos": Vector2(70, 44)},
	{"id": "112 AD", "side": "F", "type": "airdef", "pos": Vector2(60, 41)},
	{"id": "3 ENG", "side": "F", "type": "engineer", "pos": Vector2(66, 47)},
	{"id": "9 MR", "side": "F", "type": "motor", "pos": Vector2(88, 82)},
	{"id": "33 MR", "side": "H", "type": "motor", "pos": Vector2(102, 64)},
	{"id": "5 ART", "side": "H", "type": "artillery", "pos": Vector2(110, 58)},
	{"id": "61 TK", "side": "H", "type": "armour", "pos": Vector2(118, 70)},
	{"id": "UNK", "side": "U", "type": "unknown", "pos": Vector2(97, 40)},
]
## Friendly observation posts; outcomes beyond their range are unknown.
const OBSERVATION := [
	{"id": "OP K1", "pos": Vector2(85.2, 46.0), "range": 22.0},
	{"id": "OP K2", "pos": Vector2(84, 66), "range": 22.0},
]
## Reported, unconfirmed intelligence (INTELLIGENCE layer).
const INTEL := [
	{"id": "14 TK DIV (RPT)", "pos": Vector2(90, 50), "radius": 3.5, "source": "AIR RECCE, SINGLE SOURCE", "order": "SC-001"},
	{"id": "ARTY BTY (RPT)", "pos": Vector2(104, 44), "radius": 2.5, "source": "SIGNALS, UNCORROBORATED", "order": ""},
]

# --- Scenario truth (hidden; read only by OutcomeModel) ------------------------
const TRUTH := [
	{"kind": "hostile", "name": "ARMOURED BATTALION GROUP (14 TK DIV ELEMENT)", "pos": Vector2(93.8, 48.4), "r": 1.2},
	{"kind": "hostile", "name": "33 MR BATTALION", "pos": Vector2(102, 64), "r": 1.5},
	{"kind": "hostile", "name": "5 ART BATTERIES", "pos": Vector2(110, 58), "r": 1.2},
	{"kind": "hostile", "name": "61 TK BATTALION", "pos": Vector2(118, 70), "r": 1.5},
	{"kind": "hostile", "name": "RECONNAISSANCE PATROL", "pos": Vector2(97, 40), "r": 0.5},
]

static var _built := {}


# --- Derived data ------------------------------------------------------------

## Contours, forest symbols and bridges, computed once per run.
static func derived() -> Dictionary:
	if _built.is_empty():
		_built = {
			"contours": _contours(2.0),
			"forest_marks": _forest_marks(),
			"bridges": _bridges(),
		}
	return _built


static func height(p: Vector2) -> float:
	var h := 0.18 * (1.0 - p.y / MapGrid.EXTENT.y)
	for r in RIDGES:
		var d := _dist_to_polyline(p, r.pts)
		h += r.amp * exp(-d * d / (2.0 * r.w * r.w))
	return h


static func _contours(step: float) -> Array:
	# Marching squares over the heightfield; one list of segments per level.
	var nx := int(MapGrid.EXTENT.x / step) + 1
	var ny := int(MapGrid.EXTENT.y / step) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * ny)
	for j in range(ny):
		for i in range(nx):
			hs[j * nx + i] = height(Vector2(i, j) * step)
	var out := []
	for level in CONTOUR_LEVELS:
		var segs := PackedVector2Array()
		for j in range(ny - 1):
			for i in range(nx - 1):
				var c := [hs[j * nx + i], hs[j * nx + i + 1], hs[(j + 1) * nx + i + 1], hs[(j + 1) * nx + i]]
				var p := [Vector2(i, j) * step, Vector2(i + 1, j) * step, Vector2(i + 1, j + 1) * step, Vector2(i, j + 1) * step]
				var cross := PackedVector2Array()
				for e in range(4):
					var a: float = c[e]
					var b: float = c[(e + 1) % 4]
					if (a < level) != (b < level):
						cross.append(p[e].lerp(p[(e + 1) % 4], (level - a) / (b - a)))
				if cross.size() >= 2:
					segs.append(cross[0])
					segs.append(cross[1])
				if cross.size() == 4:
					segs.append(cross[2])
					segs.append(cross[3])
		out.append({"level": level, "segments": segs})
	return out


static func _forest_marks() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1985
	var marks := []
	for poly in FORESTS:
		var packed := PackedVector2Array(poly)
		var box := Rect2(packed[0], Vector2.ZERO)
		for v in packed:
			box = box.expand(v)
		var target := int(_area(packed) / 5.0)
		var placed := 0
		var tries := 0
		while placed < target and tries < target * 20:
			tries += 1
			var q := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			if Geometry2D.is_point_in_polygon(q, packed):
				marks.append(q)
				placed += 1
	return marks


## Every place a road or railway crosses a river, numbered west to east.
static func _bridges() -> Array:
	var found := []
	for kind in ["rail", "road"]:
		var lines: Array = RAILS if kind == "rail" else ROADS
		for line in lines:
			for river in RIVERS:
				for i in range(line.pts.size() - 1):
					for k in range(river.pts.size() - 1):
						var x = Geometry2D.segment_intersects_segment(line.pts[i], line.pts[i + 1], river.pts[k], river.pts[k + 1])
						if x != null:
							found.append({"pos": x, "kind": kind, "river": river.name, "cls": line.cls,
									"dir": (line.pts[i + 1] - line.pts[i]).normalized()})
	found.sort_custom(func(a, b) -> bool: return a.pos.x < b.pos.x)
	for i in range(found.size()):
		found[i]["id"] = "B-%d" % (i + 1)
	return found


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best
