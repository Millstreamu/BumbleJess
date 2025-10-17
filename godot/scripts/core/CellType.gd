extends RefCounted
## Enumerates the tile roles used throughout the forest regrowth prototype.
class_name CellType

enum Type {
	TOTEM,
	HARVEST,
	BUILD,
	REFINE,
	STORAGE,
	GUARD,
	UPGRADE,
	CHANTING,
	GROVE,
	OVERGROWTH,
	DECAY,
	EMPTY,
}

static func buildable_types() -> Array[int]:
	return [
		Type.HARVEST,
		Type.BUILD,
		Type.REFINE,
		Type.STORAGE,
		Type.GUARD,
		Type.UPGRADE,
		Type.CHANTING,
	]

static func to_display_name(cell_type: int) -> String:
	match cell_type:
		Type.TOTEM:
			return "Totem"
		Type.HARVEST:
			return "Harvest"
		Type.BUILD:
			return "Build"
		Type.REFINE:
			return "Refine"
		Type.STORAGE:
			return "Storage"
		Type.GUARD:
			return "Guard"
		Type.UPGRADE:
			return "Upgrade"
		Type.CHANTING:
			return "Chanting"
		Type.GROVE:
			return "Grove"
		Type.OVERGROWTH:
			return "Overgrowth"
		Type.DECAY:
			return "Decay"
		Type.EMPTY:
			return "Empty"
		_:
			return "Unknown"

static func is_placeable(cell_type: int) -> bool:
	return buildable_types().has(cell_type)

static func is_network_member(cell_type: int) -> bool:
	return cell_type != Type.EMPTY and cell_type != Type.DECAY

static func to_key(cell_type: int) -> String:
	var keys := Type.keys()
	if cell_type >= 0 and cell_type < keys.size():
		return String(keys[cell_type])
	return str(cell_type)

static func from_key(key: String) -> int:
	var normalized := key.strip_edges()
	if normalized.is_empty():
		return Type.EMPTY

	var keys := Type.keys()
	for i in range(keys.size()):
		var enum_key := String(keys[i])
		if enum_key == normalized:
			return i

	var normalized_upper := normalized.to_upper()
	for i in range(keys.size()):
		var enum_key := String(keys[i])
		if enum_key == normalized_upper:
			return i

	return Type.EMPTY
