extends RefCounted
## Coordinates end-of-turn updates for resources and tile-based systems.
class_name TurnController

const Hex := preload("res://src/core/Hex.gd")
const Resources := preload("res://src/systems/Resources.gd")
const Clusters := preload("res://src/systems/Clusters.gd")
const ProducerRefine := preload("res://src/systems/ProducerRefine.gd")

const PRODUCER_RESOURCE := {
        "Harvest": "nature",
        "Build": "earth",
        "Refine": "water",
}

var resources: Resources
var _grid: Dictionary = {}
var _producer_refine: ProducerRefine

func _init() -> void:
        resources = Resources.new()
        _producer_refine = ProducerRefine.new()

func set_tile(axial: Vector2i, category: String) -> void:
        if category == "" or category == null:
                _grid.erase(axial)
                return
        _grid[axial] = {"category": category}

func remove_tile(axial: Vector2i) -> void:
        _grid.erase(axial)

func end_turn() -> void:
        _recompute_capacity()
        _process_refine()

func _recompute_capacity() -> void:
        var caps := {
                "nature": 0,
                "earth": 0,
                "water": 0,
                "life": resources.get_cap("life"),
        }
        for key in _grid.keys():
                var category := str(_grid[key].get("category", ""))
                if PRODUCER_RESOURCE.has(category):
                        var res_type: String = PRODUCER_RESOURCE[category]
                        caps[res_type] = caps.get(res_type, 0) + 5
        var harvest_clusters := Clusters.collect(_grid, "Harvest")
        for cluster in harvest_clusters:
                caps["nature"] = caps.get("nature", 0) + cluster.size() * 10
        var storage_positions := _positions_for_category("Storage")
        for storage_pos in storage_positions:
                for neighbor in Hex.neighbors(Hex.Axial.from_vector2i(storage_pos)):
                        var neighbor_vec := neighbor.to_vector2i()
                        if not _grid.has(neighbor_vec):
                                continue
                        var neighbor_category := str(_grid[neighbor_vec].get("category", ""))
                        if PRODUCER_RESOURCE.has(neighbor_category):
                                var res_key: String = PRODUCER_RESOURCE[neighbor_category]
                                caps[res_key] = caps.get(res_key, 0) + 5
        for key in caps.keys():
                resources.set_cap(key, int(caps[key]))

func _process_refine() -> void:
        var refine_positions := _positions_for_category("Refine")
        _producer_refine.process_turn(refine_positions, resources)

func _positions_for_category(category: String) -> Array:
        var results: Array = []
        for key in _grid.keys():
                var tile_category := str(_grid[key].get("category", ""))
                if tile_category == category:
                        results.append(key)
        return results
