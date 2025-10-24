@tool
extends Resource
class_name TotemTilePackChoice

@export var pack: TilePackDefinition
@export var pack_id_override: String = ""
@export_range(1, 999, 1) var weight: int = 1
@export_range(1, 99, 1) var min_tier: int = 1

func get_pack_id() -> String:
    if not pack_id_override.is_empty():
        return pack_id_override
    if pack != null and pack.id != "":
        return pack.id
    return ""

func to_dict() -> Dictionary:
    return {
        "pack_id": get_pack_id(),
        "weight": weight,
        "min_tier": min_tier
    }

func is_valid() -> bool:
    return not get_pack_id().is_empty()
