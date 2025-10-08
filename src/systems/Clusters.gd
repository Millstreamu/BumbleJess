extends Node
## Utilities for working with contiguous tile clusters on the hex grid.
class_name Clusters

static func neighbors(ax: Vector2i) -> Array:
        var dirs: Array[Vector2i] = [
                Vector2i(+1, 0),
                Vector2i(+1, -1),
                Vector2i(0, -1),
                Vector2i(-1, 0),
                Vector2i(-1, +1),
                Vector2i(0, +1),
        ]
        var out: Array = []
        for d in dirs:
                out.append(ax + d)
        return out

static func key(ax: Vector2i) -> String:
        return "%d,%d" % [ax.x, ax.y]

static func unkey(k: String) -> Vector2i:
        var parts := k.split(",")
        if parts.size() != 2:
                return Vector2i.ZERO
        return Vector2i(int(parts[0]), int(parts[1]))

static func count_harvest_cluster_tiles(board: Node) -> int:
        if board == null:
                return 0
        var tiles_variant := board.get("placed_tiles")
        if typeof(tiles_variant) != TYPE_DICTIONARY:
                return 0
        var tiles: Dictionary = tiles_variant
        var visited := {}
        var total := 0
        for key in tiles.keys():
                if visited.has(key):
                        continue
                var tile: Dictionary = tiles[key]
                if String(tile.get("category", "")) != "Harvest":
                        continue
                total += _flood_count(board, key, tiles, visited)
        return total

static func _flood_count(board: Node, start_key: String, tiles: Dictionary, visited: Dictionary) -> int:
        var stack: Array = [start_key]
        visited[start_key] = true
        var count := 0
        while stack.size() > 0:
                var current_key: String = stack.pop_back()
                count += 1
                var axial := unkey(current_key)
                for nb in neighbors(axial):
                        var nk := key(nb)
                        if visited.has(nk):
                                continue
                        if not tiles.has(nk):
                                continue
                        if String(tiles[nk].get("category", "")) != "Harvest":
                                continue
                        visited[nk] = true
                        stack.append(nk)
        return count
