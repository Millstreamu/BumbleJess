extends Node

func _ready():
    var w := 16
    var h := 12
    var ns: Array[Vector2i] = HexUtil.neighbors_even_q(Vector2i(0, 0), w, h)
    for c in ns:
        assert(c.x >= 0 and c.y >= 0 and c.x < w and c.y < h)
    print("HexUtil neighbors_even_q: PASS")
