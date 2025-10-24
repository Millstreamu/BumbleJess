@tool
extends Resource
class_name TotemDefinition

@export var id: String = ""
@export var display_name: String = ""
@export_group("Tile Generation")
@export_range(1, 99, 1) var tile_generation_interval_turns: int = 3
@export var tile_generation_special_forced_place: bool = true
@export var tile_pack_choices: Array[TotemTilePackChoice] = []
@export_group("Evolution")
@export var tier_max: int = 5
@export var life_essence_costs: PackedInt32Array = PackedInt32Array([0])

func to_dict() -> Dictionary:
    var tile_gen: Dictionary = {
        "interval_turns": tile_generation_interval_turns,
        "special_forced_place": tile_generation_special_forced_place,
        "choices": []
    }
    for choice in tile_pack_choices:
        if choice == null or not choice.is_valid():
            continue
        tile_gen["choices"].append(choice.to_dict())
    var evolution: Dictionary = {
        "tier_max": tier_max,
        "life_essence_costs": _costs_array()
    }
    return {
        "id": id,
        "name": display_name,
        "tile_gen": tile_gen,
        "evolution": evolution
    }

func is_valid() -> bool:
    if id.is_empty():
        return false
    if tile_pack_choices.is_empty():
        return false
    for choice in tile_pack_choices:
        if choice != null and choice.is_valid():
            return true
    return false

func _costs_array() -> Array[int]:
    var arr: Array[int] = []
    for value in life_essence_costs:
        arr.append(int(value))
    if arr.is_empty():
        arr.append(0)
    return arr
