extends Node
class_name PathHex

const RunState := preload("res://src/core/RunState.gd")

const DIRECTIONS := [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

static var _board: Node = null

static func set_board(board: Node) -> void:
    _board = board

static func bfs_first_step(from_ax: Vector2i, is_goal: Callable, is_walkable: Callable) -> Variant:
    var visited: Dictionary[String, bool] = {}
    var parents: Dictionary[String, Vector2i] = {}
    var queue: Array[Vector2i] = []
    queue.append(from_ax)
    visited[_key(from_ax)] = true
    while queue.size() > 0:
        var current: Vector2i = queue.pop_front()
        if is_goal.call([current]):
            var step := _retrace_first_step(from_ax, current, parents)
            if step != null:
                return step
        for dir in DIRECTIONS:
            var nxt: Vector2i = current + dir
            var nxt_key := _key(nxt)
            if visited.has(nxt_key):
                continue
            if not is_walkable.call([nxt]):
                continue
            visited[nxt_key] = true
            parents[nxt_key] = current
            queue.append(nxt)
    return null

static func nearest_connected_step(from_ax: Vector2i) -> Variant:
    if _board == null:
        return null
    if not _board.has_method("is_empty") or not _board.has_method("is_decay"):
        return null
    var goal := func (ax: Vector2i) -> bool:
        for dir in DIRECTIONS:
            var neighbor: Vector2i = ax + dir
            if RunState.connected_set.has(_key(neighbor)):
                return true
        return false
    var walkable := func (ax: Vector2i) -> bool:
        var k := _key(ax)
        if RunState.connected_set.has(k):
            return false
        if _board.is_decay(ax):
            return true
        return _board.is_empty(ax)
    return bfs_first_step(from_ax, goal, walkable)

static func _key(ax: Vector2i) -> String:
    return "%d,%d" % [ax.x, ax.y]

static func _retrace_first_step(start_ax: Vector2i, goal_ax: Vector2i, parents: Dictionary[String, Vector2i]) -> Variant:
    var path: Array[Vector2i] = []
    var current: Vector2i = goal_ax
    var current_key := _key(current)
    path.push_front(current)
    while parents.has(current_key):
        var prev: Vector2i = parents[current_key]
        path.push_front(prev)
        current = prev
        current_key = _key(current)
    if path.is_empty():
        return null
    if path[0] != start_ax:
        path.push_front(start_ax)
    return _first_non_decay_step(path)

static func _first_non_decay_step(path: Array[Vector2i]) -> Variant:
    if path.size() <= 1:
        return null
    for i in range(1, path.size()):
        var step: Variant = path[i]
        if typeof(step) != TYPE_VECTOR2I:
            continue
        var step_ax: Vector2i = step
        if _board == null:
            return step_ax
        if not _board.has_method("is_decay"):
            return step_ax
        if not _board.is_decay(step_ax):
            return step_ax
    return null
