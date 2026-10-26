class_name Ammunition
extends RefCounted
## Fictional ammunition categories. Values are abstract game-balance
## numbers (resource cost, effect radius in map km), not weapon data.

const ORDER := ["SMALL", "MEDIUM", "LARGE"]
const TYPES := {
	"SMALL": {"name": "SMALL", "designation": "NV-S1", "cost": 1, "radius_km": 1.0, "color": "GREEN"},
	"MEDIUM": {"name": "MEDIUM", "designation": "NV-M4", "cost": 2, "radius_km": 2.5, "color": "AMBER"},
	"LARGE": {"name": "LARGE", "designation": "NV-L9", "cost": 4, "radius_km": 6.0, "color": "RED"},
}
const STARTING_RESOURCES := 10


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})
