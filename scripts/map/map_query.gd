class_name MapQuery
extends RefCounted
## Answers "what does Norvak know about this place?" from the visible map
## data only. Hidden scenario truth is never read here, so moving the
## cursor or selecting a cell cannot reveal it.


## Known contents of one grid cell.
static func known_in_cell(cell: Vector2i) -> Dictionary:
	var rect := MapGrid.cell_rect(cell)
	var k := {
		"ref": MapGrid.ref_of_cell(cell), "settlements": [], "infrastructure": [],
		"friendly": [], "hostile": [], "reported": [], "unknown": [],
	}
	for s in MapData.SETTLEMENTS:
		if rect.grow(MapData.SETTLEMENT_RADIUS[s.cls]).has_point(s.pos):
			k.settlements.append(s.name)
	for f in MapData.FACILITIES:
		if rect.has_point(f.pos):
			k.infrastructure.append(f.name)
	for b in MapData.derived().bridges:
		if rect.has_point(b.pos):
			k.infrastructure.append("%s %s BRIDGE (%s)" % [b.id, b.kind.to_upper(), b.river])
	for r in MapData.RAILS:
		if _line_in_rect(r.pts, rect):
			k.infrastructure.append("RAILWAY")
			break
	for r in MapData.ROADS:
		if r.cls < 2 and _line_in_rect(r.pts, rect):
			k.infrastructure.append("ROAD")
			break
	for u in MapData.UNITS:
		if rect.has_point(u.pos):
			k[{"F": "friendly", "H": "hostile", "U": "unknown"}[u.side]].append(u.id)
	for o in MapData.OBSERVATION:
		if rect.has_point(o.pos):
			k.friendly.append(o.id)
	for i in MapData.INTEL:
		if rect.has_point(i.pos) or rect.get_center().distance_to(i.pos) <= i.radius:
			k.reported.append(i.id)
	return k


## Classification and confidence from known contents (most significant first).
static func classify(k: Dictionary) -> Dictionary:
	if not k.friendly.is_empty():
		return {"class": "FRIENDLY FORCES", "confidence": "CONFIRMED"}
	if not k.hostile.is_empty():
		return {"class": "HOSTILE FORMATION", "confidence": "CONFIRMED"}
	if not k.reported.is_empty():
		return {"class": "REPORTED HOSTILE", "confidence": "UNCONFIRMED"}
	if not k.unknown.is_empty():
		return {"class": "UNIDENTIFIED CONTACT", "confidence": "UNCONFIRMED"}
	if not k.settlements.is_empty():
		return {"class": "SETTLEMENT", "confidence": "MAP DATA"}
	if not k.infrastructure.is_empty():
		return {"class": "INFRASTRUCTURE", "confidence": "MAP DATA"}
	return {"class": "NO KNOWN OBJECT", "confidence": "NO INTELLIGENCE"}


## Known friendly forces and settlements within `radius` km of `center`
## (used to warn before a launch; uses map knowledge only).
static func known_near(center: Vector2, radius: float) -> Dictionary:
	var near := {"friendly": [], "settlements": []}
	for u in MapData.UNITS:
		if u.side == "F" and u.pos.distance_to(center) <= radius:
			near.friendly.append(u.id)
	for o in MapData.OBSERVATION:
		if o.pos.distance_to(center) <= radius:
			near.friendly.append(o.id)
	for s in MapData.SETTLEMENTS:
		if s.pos.distance_to(center) <= radius + MapData.SETTLEMENT_RADIUS[s.cls]:
			near.settlements.append(s.name)
	return near


static func _line_in_rect(pts: Array, rect: Rect2) -> bool:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 0.25))
		for s in range(n + 1):
			if rect.has_point(a.lerp(b, float(s) / n)):
				return true
	return false
