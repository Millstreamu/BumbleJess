extends Node
class_name HexUtil

static func clamp_cell(c: Vector2i, w: int, h: int) -> Vector2i:
    return Vector2i(clamp(c.x, 0, w - 1), clamp(c.y, 0, h - 1))

static func neighbors_even_q(c: Vector2i, w: int, h: int) -> Array[Vector2i]:
    var even := (c.x % 2) == 0
    var deltas_even := [
        Vector2i(+1, 0), Vector2i(-1, 0),
        Vector2i(0, -1), Vector2i(0, +1),
        Vector2i(+1, -1), Vector2i(-1, -1),
    ]
    var deltas_odd := [
        Vector2i(+1, 0), Vector2i(-1, 0),
        Vector2i(0, -1), Vector2i(0, +1),
        Vector2i(+1, +1), Vector2i(-1, +1),
    ]
    var out: Array[Vector2i] = []
    for d in (even ? deltas_even : deltas_odd):
        var n := Vector2i(c.x + d.x, c.y + d.y)
        if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
            out.append(n)
    return out
