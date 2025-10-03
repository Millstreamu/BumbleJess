extends RefCounted

const Coord := preload("res://scripts/core/Coord.gd")

func test_axial_conversion_round_trip() -> void:
    var size := 32.0
    for q in range(-2, 3):
        for r in range(-2, 3):
            if abs(q + r) > 2:
                continue
            var position := Coord.axial_to_world(Vector2i(q, r), size)
            var round_trip := Coord.world_to_axial(position, size)
            assert(round_trip == Vector2i(q, r))
