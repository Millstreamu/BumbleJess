extends Node
class_name Decay

const Config := preload("res://src/data/Config.gd")
const RunState := preload("res://src/core/RunState.gd")
const Board := preload("res://src/systems/Board.gd")
const PathHex := preload("res://src/core/PathHex.gd")

const DIRECTIONS := [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

static func seed_totems() -> void:
    var cfg_variant: Variant = Config.decay().get("totems", {})
    if typeof(cfg_variant) != TYPE_DICTIONARY:
        RunState.decay_totems = []
        RunState.decay_tiles = {}
        RunState.decay_adjacent_age = {}
        return
    var cfg: Dictionary = cfg_variant
    var count: int = int(cfg.get("count", 0))
    RunState.decay_totems = []
    RunState.decay_tiles = {}
    RunState.decay_adjacent_age = {}
    if count <= 0:
        return
    var spread_every: int = int(cfg.get("spread_every_turns", 3))
    var min_radius: int = int(cfg.get("min_radius", 1))
    var max_radius: int = int(cfg.get("max_radius", min_radius))
    if max_radius < min_radius:
        var tmp: int = min_radius
        min_radius = max_radius
        max_radius = tmp
    var candidates: Array[Vector2i] = []
    for radius in range(max(min_radius, 1), max_radius + 1):
        candidates.append_array(_ring_coords(radius))
    var filtered: Array[Vector2i] = []
    for ax_variant in candidates:
        if typeof(ax_variant) != TYPE_VECTOR2I:
            continue
        var ax: Vector2i = ax_variant
        var key := Board.key(ax)
        if RunState.connected_set.has(key):
            continue
        if filtered.has(ax):
            continue
        filtered.append(ax)
    if filtered.is_empty():
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = int(RunState.seed)
    while RunState.decay_totems.size() < count and filtered.size() > 0:
        var index := rng.randi_range(0, filtered.size() - 1)
        var chosen: Vector2i = filtered[index]
        filtered.remove_at(index)
        RunState.decay_totems.append({"ax": chosen, "timer": spread_every})

static func do_spread(board: Node) -> void:
    if board == null:
        return
    PathHex.set_board(board)
    var cfg_variant: Variant = Config.decay().get("totems", {})
    var cfg: Dictionary = {}
    if typeof(cfg_variant) == TYPE_DICTIONARY:
        cfg = cfg_variant
    var spread_every: int = int(cfg.get("spread_every_turns", 3))
    var global_cap: int = int(cfg.get("attacks_per_turn", 3))
    var placed_this_turn := 0
    for i in range(RunState.decay_totems.size()):
        var totem_variant: Variant = RunState.decay_totems[i]
        if typeof(totem_variant) != TYPE_DICTIONARY:
            continue
        var totem: Dictionary = totem_variant
        var timer_value: int = int(totem.get("timer", spread_every)) - 1
        totem["timer"] = timer_value
        var should_attempt := timer_value <= 0
        if should_attempt:
            if placed_this_turn < global_cap:
                var step_variant := _next_decay_step_from(totem.get("ax", Vector2i.ZERO))
                if typeof(step_variant) == TYPE_VECTOR2I:
                    var step_ax: Vector2i = step_variant
                    if not board.is_decay(step_ax):
                        board.add_decay(step_ax)
                        var k := Board.key(step_ax)
                        RunState.decay_tiles[k] = {"age_adj_life": 0}
                        if RunState.overgrowth.has(k):
                            RunState.overgrowth.erase(k)
                        placed_this_turn += 1
                    else:
                        var existing_key := Board.key(step_ax)
                        if not RunState.decay_tiles.has(existing_key):
                            RunState.decay_tiles[existing_key] = {"age_adj_life": 0}
            totem["timer"] = spread_every
        RunState.decay_totems[i] = totem

static func apply_adjacency_corruption(board: Node) -> void:
    if board == null:
        return
    var decay_axes: Array[Vector2i] = _gather_decay_axes(board)
    var adjacent_life: Dictionary[String, Vector2i] = {}
    for ax in decay_axes:
        for neighbor in neighbors(ax):
            if not board.has_tile(neighbor):
                continue
            if board.is_decay(neighbor):
                continue
            adjacent_life[Board.key(neighbor)] = neighbor
    var tracked_keys: Array[String] = RunState.decay_adjacent_age.keys()
    for key in tracked_keys:
        if not adjacent_life.has(key):
            RunState.decay_adjacent_age.erase(key)
    for key in adjacent_life.keys():
        var age: int = int(RunState.decay_adjacent_age.get(key, 0)) + 1
        RunState.decay_adjacent_age[key] = age
        if age >= 3:
            var ax: Vector2i = adjacent_life[key]
            board.replace_tile(ax, "Decay", "decay_base")
            RunState.decay_tiles[key] = {"age_adj_life": 0}
            RunState.decay_adjacent_age.erase(key)
            if RunState.overgrowth.has(key):
                RunState.overgrowth.erase(key)
            if RunState.connected_set.has(key):
                RunState.connected_set.erase(key)

static func neighbors(ax: Vector2i) -> Array:
    var out: Array = []
    for dir in DIRECTIONS:
        out.append(ax + dir)
    return out

static func _next_decay_step_from(ax_variant: Variant) -> Variant:
    if typeof(ax_variant) != TYPE_VECTOR2I:
        return null
    return PathHex.nearest_connected_step(ax_variant)

static func _ring_coords(radius: int) -> Array[Vector2i]:
    var coords: Array[Vector2i] = []
    if radius <= 0:
        return coords
    var ax: Vector2i = Vector2i(-radius, radius)
    for dir in DIRECTIONS:
        for _i in range(radius):
            coords.append(ax)
            ax += dir
    return coords

static func _gather_decay_axes(board: Node) -> Array[Vector2i]:
    var axes: Array[Vector2i] = []
    if board == null:
        return axes
    if board is Board:
        var b: Board = board
        for k in b.placed_tiles.keys():
            var tile: Dictionary = b.placed_tiles[k]
            if tile.get("category", "") == "Decay":
                var ax := Board.unkey(k)
                axes.append(ax)
                if not RunState.decay_tiles.has(k):
                    RunState.decay_tiles[k] = {"age_adj_life": 0}
    if axes.is_empty():
        for key in RunState.decay_tiles.keys():
            axes.append(Board.unkey(key))
    return axes
