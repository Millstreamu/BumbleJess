extends Node
## Tracks resource balances and build costs for specialized cells.
class_name ResourceManager

const CellType := preload("res://scripts/core/CellType.gd")

const DATA_DIR := "res://data"
const RESOURCES_PATH := DATA_DIR + "/resources_state.json"
const COSTS_PATH := DATA_DIR + "/build_costs.json"

const RESOURCE_NAMES := ["honey", "comb", "pollen", "nectar", "royal_jelly"]

var _balances: Dictionary = {}
var _build_costs: Dictionary = {}

func _ready() -> void:
    _ensure_data_directory()
    _load_resource_state()
    _load_build_costs()

func get_balance(name: String) -> int:
    return int(_balances.get(name, 0))

func get_balances() -> Dictionary:
    return _balances.duplicate(true)

func can_pay(cost: Dictionary) -> bool:
    for resource_name in RESOURCE_NAMES:
        var required: int = int(cost.get(resource_name, 0))
        if required <= 0:
            continue
        if get_balance(resource_name) < required:
            return false
    return true

func spend(cost: Dictionary) -> void:
    if cost.is_empty():
        return
    if not can_pay(cost):
        push_warning("Attempted to spend resources without sufficient balance")
        return
    for resource_name in RESOURCE_NAMES:
        var required: int = int(cost.get(resource_name, 0))
        if required == 0:
            continue
        _balances[resource_name] = get_balance(resource_name) - required
    save_state()

func grant(delta: Dictionary) -> void:
    if delta.is_empty():
        return
    for resource_name in RESOURCE_NAMES:
        var amount: int = int(delta.get(resource_name, 0))
        if amount == 0:
            continue
        _balances[resource_name] = get_balance(resource_name) + amount
    save_state()

func save_state() -> void:
    _write_json(RESOURCES_PATH, _balances)

func get_build_cost(cell_type: int) -> Dictionary:
    var key := _get_type_key(cell_type)
    var base_cost: Dictionary = _build_costs.get(key, {})
    if base_cost.is_empty():
        base_cost = _default_cost_for_type(key, CellType.buildable_types().has(cell_type))
    return base_cost.duplicate(true)

func _ensure_data_directory() -> void:
    var dir := DirAccess.open("res://")
    if dir:
        dir.make_dir_recursive(DATA_DIR.replace("res://", ""))

func _load_resource_state() -> void:
    var defaults := {}
    for name in RESOURCE_NAMES:
        defaults[name] = 0

    _balances = _read_json(RESOURCES_PATH, defaults)
    for name in RESOURCE_NAMES:
        _balances[name] = int(_balances.get(name, 0))

    if not FileAccess.file_exists(RESOURCES_PATH):
        save_state()

func _load_build_costs() -> void:
    var defaults := {}
    for type_key in _buildable_type_keys():
        defaults[type_key] = _default_cost_for_type(type_key, true)

    _build_costs = _read_json(COSTS_PATH, defaults)

    # Normalize entries to ensure all resource keys are present.
    for type_key in defaults.keys():
        var cost: Dictionary = _build_costs.get(type_key, {}).duplicate(true)
        if cost.is_empty():
            cost = defaults[type_key].duplicate(true)
        for resource_name in RESOURCE_NAMES:
            if not cost.has(resource_name):
                cost[resource_name] = 0
            else:
                cost[resource_name] = int(cost[resource_name])
        _build_costs[type_key] = cost

    if not FileAccess.file_exists(COSTS_PATH):
        _write_json(COSTS_PATH, _build_costs)

func _read_json(path: String, fallback: Dictionary) -> Dictionary:
    if not FileAccess.file_exists(path):
        return fallback.duplicate(true)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Failed to open %s" % path)
        return fallback.duplicate(true)
    var text := file.get_as_text()
    var json := JSON.new()
    var error := json.parse(text)
    if error != OK:
        push_warning("Failed to parse %s; using defaults" % path)
        return fallback.duplicate(true)
    var data := json.data
    if typeof(data) != TYPE_DICTIONARY:
        return fallback.duplicate(true)
    return data

func _write_json(path: String, data: Dictionary) -> void:
    _ensure_data_directory()
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Failed to write %s" % path)
        return
    file.store_string(JSON.stringify(data, "  "))

func _buildable_type_keys() -> Array:
    var keys: Array = []
    for cell_type in CellType.buildable_types():
        keys.append(_get_type_key(cell_type))
    return keys

func _default_cost_for_type(type_key: String, is_buildable: bool = false) -> Dictionary:
    var defaults := {}
    for resource_name in RESOURCE_NAMES:
        defaults[resource_name] = 0
    if is_buildable:
        defaults["pollen"] = 1
    return defaults

func _get_type_key(cell_type: int) -> String:
    var keys := CellType.Type.keys()
    if cell_type >= 0 and cell_type < keys.size():
        return String(keys[cell_type])
    return str(cell_type)
