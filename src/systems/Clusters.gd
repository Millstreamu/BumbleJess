extends RefCounted
## Identifies contiguous clusters of tiles by category on a hex grid.
class_name Clusters

const Hex := preload("res://src/core/Hex.gd")

static func collect(grid: Dictionary, category: String) -> Array:
        var clusters: Array = []
        var target := category
        var visited: Dictionary = {}
        for key in grid.keys():
                var axial := _to_vector2i(key)
                if visited.has(axial):
                        continue
                var tile_category := str(_get_category(grid.get(key)))
                if tile_category != target:
                        continue
                clusters.append(_flood_fill(grid, axial, target, visited))
        return clusters

static func _flood_fill(grid: Dictionary, start: Vector2i, category: String, visited: Dictionary) -> Array:
        var cluster: Array = []
        var frontier: Array = [start]
        visited[start] = true
        while frontier.size() > 0:
                var current: Vector2i = frontier[0]
                frontier.remove_at(0)
                cluster.append(current)
                for neighbor in Hex.neighbors(Hex.Axial.from_vector2i(current)):
                        var vec := neighbor.to_vector2i()
                        if visited.has(vec):
                                continue
                        if not grid.has(vec):
                                continue
                        if str(_get_category(grid.get(vec))) != category:
                                continue
                        visited[vec] = true
                        frontier.append(vec)
        return cluster

static func _get_category(tile_data: Variant) -> String:
        if typeof(tile_data) == TYPE_DICTIONARY:
                return String(tile_data.get("category", ""))
        if typeof(tile_data) == TYPE_STRING:
                return String(tile_data)
        return ""

static func _to_vector2i(value: Variant) -> Vector2i:
        if value is Vector2i:
                return value
        if value is Hex.Axial:
                return value.to_vector2i()
        if typeof(value) == TYPE_DICTIONARY and value.has("q") and value.has("r"):
                return Vector2i(int(value.q), int(value.r))
        return Vector2i.ZERO
