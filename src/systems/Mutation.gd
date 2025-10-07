extends Node
class_name Mutation

static func axial_neighbors(ax: Vector2i) -> Array:
        var dirs := [Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1)]
        var out: Array = []
        for d in dirs:
                out.append(ax + d)
        return out

static func key(ax: Vector2i) -> String:
        return "%d,%d" % [ax.x, ax.y]

static func unkey(k: String) -> Vector2i:
        var p := k.split(",")
        return Vector2i(int(p[0]), int(p[1]))

static func do_mutations(board: Node) -> void:
        for k in board.placed_tiles.keys():
                var t: Dictionary = board.placed_tiles[k]
                if t.get("category", "") != "Grove":
                        continue
                var ax := unkey(k)
                var has_harvest := false
                for n in axial_neighbors(ax):
                        var nk := key(n)
                        if board.placed_tiles.has(nk) and board.placed_tiles[nk].get("category", "") == "Harvest":
                                has_harvest = true
                                break
                if not t.has("flags"):
                        t["flags"] = {}
                t["flags"]["thicket"] = has_harvest
                board.placed_tiles[k] = t
