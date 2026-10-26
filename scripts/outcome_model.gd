class_name OutcomeModel
extends RefCounted
## Abstract, deterministic outcome of a fictional launch. The only reader
## of MapData.TRUTH: hidden facts appear in reports after the event, never
## before. No casualty figures or graphic detail are produced.

const CATEGORIES := {
	"FRIENDLY": "FRIENDLY FORCES AT RISK",
	"CIVILIAN": "CIVILIAN-SENSITIVE AREA AFFECTED",
	"HOSTILE": "CONFIRMED HOSTILE TARGET AFFECTED",
	"NOT_CONFIRMED": "REPORTED HOSTILE TARGET NOT CONFIRMED",
	"INFRASTRUCTURE": "INFRASTRUCTURE AFFECTED",
	"EMPTY": "TARGET LOCATION EMPTY",
	"UNKNOWN": "OUTCOME UNKNOWN",
}
## Most significant first: the report's headline category.
const SEVERITY := ["FRIENDLY", "CIVILIAN", "HOSTILE", "NOT_CONFIRMED", "INFRASTRUCTURE", "EMPTY"]


static func evaluate(cell: Vector2i, ammo: String) -> Dictionary:
	var c := MapGrid.cell_center(cell)
	var r: float = Ammunition.get_type(ammo).radius_km
	var found := {"FRIENDLY": [], "CIVILIAN": [], "HOSTILE": [], "NOT_CONFIRMED": [], "INFRASTRUCTURE": []}

	if not _observed(c):
		return {"category": CATEGORIES.UNKNOWN, "key": "UNKNOWN", "lines": [
			"NO OBSERVATION COVERAGE AT %s." % MapGrid.ref_of_cell(cell),
			"EFFECT CANNOT BE ASSESSED FROM THIS POST.",
		]}

	for u in MapData.UNITS:
		if u.side == "F" and u.pos.distance_to(c) <= r + 0.5:
			found.FRIENDLY.append(u.id)
	for o in MapData.OBSERVATION:
		if o.pos.distance_to(c) <= r + 0.4:
			found.FRIENDLY.append(o.id)
	for s in MapData.SETTLEMENTS:
		if s.pos.distance_to(c) <= r + MapData.SETTLEMENT_RADIUS[s.cls]:
			found.CIVILIAN.append(s.name)
	for t in MapData.TRUTH:
		if t.kind == "hostile" and t.pos.distance_to(c) <= r + t.r:
			found.HOSTILE.append(t.name)
	for f in MapData.FACILITIES:
		if f.pos.distance_to(c) <= r + 0.5:
			found.INFRASTRUCTURE.append(f.name)
	for b in MapData.derived().bridges:
		if b.pos.distance_to(c) <= r:
			found.INFRASTRUCTURE.append("%s %s BRIDGE" % [b.id, b.kind.to_upper()])
	# A reported formation whose uncertainty area overlaps the effect area,
	# with nothing actually there (same overlap rule as MapQuery).
	for i in MapData.INTEL:
		if i.pos.distance_to(c) <= r + i.radius:
			var real := false
			for t in MapData.TRUTH:
				if t.kind == "hostile" and t.pos.distance_to(c) <= r + t.r:
					real = true
			if not real:
				found.NOT_CONFIRMED.append(i.id)

	var key := "EMPTY"
	for k in SEVERITY:
		if k != "EMPTY" and not found[k].is_empty():
			key = k
			break
	var lines: Array[String] = []
	if not found.FRIENDLY.is_empty():
		lines.append("FRIENDLY UNITS WITHIN EFFECT AREA: " + ", ".join(found.FRIENDLY) + ".")
	if not found.CIVILIAN.is_empty():
		lines.append("SETTLEMENT AFFECTED: " + ", ".join(found.CIVILIAN) + ". ASSESSMENT PENDING.")
	if not found.HOSTILE.is_empty():
		lines.append("HOSTILE AFFECTED: " + ", ".join(found.HOSTILE) + ".")
	if not found.NOT_CONFIRMED.is_empty():
		lines.append("NO FORMATION OBSERVED WHERE REPORTED (" + ", ".join(found.NOT_CONFIRMED) + ").")
	if not found.INFRASTRUCTURE.is_empty():
		lines.append("INFRASTRUCTURE: " + ", ".join(found.INFRASTRUCTURE) + ".")
	if lines.is_empty():
		lines.append("NO OBJECTS OBSERVED IN EFFECT AREA.")
	return {"category": CATEGORIES[key], "key": key, "lines": lines, "found": found}


## Whether anyone could report on the area: observation posts, friendly
## units nearby, or civil defence in Norvak's own settlements.
static func _observed(c: Vector2) -> bool:
	for o in MapData.OBSERVATION:
		if o.pos.distance_to(c) <= o.range:
			return true
	for u in MapData.UNITS:
		if u.side == "F" and u.pos.distance_to(c) <= 12.0:
			return true
	for s in MapData.SETTLEMENTS:
		if s.side == "N" and s.pos.distance_to(c) <= 15.0:
			return true
	return false
