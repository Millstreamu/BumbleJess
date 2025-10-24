@tool
extends Resource
class_name TilePackDefinition

@export var id: String = ""
@export var tiles: Array[String] = []
@export var special: Array[String] = []

func to_dict() -> Dictionary:
    var data: Dictionary = {
        "id": id
    }
    if tiles.size() > 0:
        data["tiles"] = tiles.duplicate()
    if special.size() > 0:
        data["special"] = special.duplicate()
    return data

func is_valid() -> bool:
    return not id.is_empty()
