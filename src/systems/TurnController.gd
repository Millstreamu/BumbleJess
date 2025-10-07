extends Node
## Coordinates turn phase flow and exposes a lightweight phase bus.
class_name TurnController

signal phase_new_tile
signal phase_growth
signal phase_mutation
signal phase_resources
signal phase_decay
signal phase_battle
signal phase_review

const RunState := preload("res://src/core/RunState.gd")
const Hex := preload("res://src/core/Hex.gd")
const ResourcesSystem := preload("res://src/systems/Resources.gd")
const Clusters := preload("res://src/systems/Clusters.gd")
const ProducerRefine := preload("res://src/systems/ProducerRefine.gd")

const PRODUCER_RESOURCE := {
"Harvest": "nature",
"Build": "earth",
"Refine": "water",
}

var resources: ResourcesSystem
var _grid: Dictionary = {}
var _producer_refine: ProducerRefine

var _subscribers := {
        "phase_new_tile": [],
        "phase_growth": [],
        "phase_mutation": [],
        "phase_resources": [],
        "phase_decay": [],
        "phase_battle": [],
        "phase_review": [],
}

var is_advancing := false
var is_in_review := false

func _init() -> void:
        resources = ResourcesSystem.new()
        _producer_refine = ProducerRefine.new()
        # Preserve legacy resource processing for tests and tooling.
        subscribe("phase_resources", Callable(self, "_legacy_process_resources_phase"))

func subscribe(phase: String, callable: Callable) -> void:
        if not _subscribers.has(phase):
                push_warning("Unknown phase: %s" % phase)
                return
        _subscribers[phase].append(callable)

func unsubscribe(phase: String, callable: Callable) -> void:
        if not _subscribers.has(phase):
                return
        _subscribers[phase].erase(callable)

func _emit_phase(phase: String) -> void:
        emit_signal(phase)
        var listeners: Array = _subscribers.get(phase, [])
        for listener in listeners:
                if listener is Callable and listener.is_valid():
                        listener.call()

func end_turn() -> void:
        if is_advancing or is_in_review:
                return
        is_advancing = true
        RunState.turn += 1
        var tree := get_tree()
        var phases := [
                "phase_new_tile",
                "phase_growth",
                "phase_mutation",
                "phase_resources",
                "phase_decay",
                "phase_battle",
        ]
        for phase in phases:
                _emit_phase(phase)
                if tree:
                        await tree.process_frame
        is_in_review = true
        _emit_phase("phase_review")
        if tree:
                await tree.process_frame
        is_advancing = false

func ack_review_and_resume() -> void:
        if not is_in_review:
                return
        is_in_review = false

func set_tile(axial: Vector2i, category: String) -> void:
        if category == "" or category == null:
                _grid.erase(axial)
                return
        _grid[axial] = {"category": category}

func remove_tile(axial: Vector2i) -> void:
        _grid.erase(axial)

func _legacy_process_resources_phase() -> void:
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
