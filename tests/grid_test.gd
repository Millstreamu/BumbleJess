extends RefCounted

const Hex := preload("res://src/core/Hex.gd")

func test_axial_neighbors() -> bool:
        var origin := Hex.Axial.new(0, 0)
        var neighbors := Hex.neighbors(origin)
        var expected := [
                Hex.Axial.new(1, 0),
                Hex.Axial.new(0, 1),
                Hex.Axial.new(-1, 1),
                Hex.Axial.new(-1, 0),
                Hex.Axial.new(0, -1),
                Hex.Axial.new(1, -1),
        ]
        var remaining := expected.duplicate()
        for neighbor in neighbors:
                var idx := _index_of_axial(remaining, neighbor)
                if idx == -1:
                        push_error("Unexpected neighbor: %s" % [neighbor.to_vector2i()])
                        return false
                remaining.remove_at(idx)
        if not remaining.is_empty():
                var missing: Array[Vector2i] = []
                for axial in remaining:
                        missing.append(axial.to_vector2i())
                push_error("Missing neighbors: %s" % [missing])
                return false
        return true

func test_axial_conversion_round_trip() -> bool:
        var size := 32.0
        for q in range(-2, 3):
                for r in range(-2, 3):
                        if abs(q + r) > 2:
                                continue
                        var axial := Hex.Axial.new(q, r)
                        var position := Hex.axial_to_world(axial, size)
                        var round_trip: Hex.Axial = Hex.world_to_axial(position, size)
                        if round_trip.q != axial.q or round_trip.r != axial.r:
                                push_error("Round trip mismatch for %s -> %s" % [axial.to_vector2i(), round_trip.to_vector2i()])
                                return false
        return true

func test_ring_count_matches_radius() -> bool:
        var center := Hex.Axial.new(0, 0)
        for radius in range(0, 4):
                var ring := Hex.ring(center, radius)
                var expected_count := 1 if radius == 0 else radius * 6
                if ring.size() != expected_count:
                        push_error("Ring radius %d expected %d but got %d" % [radius, expected_count, ring.size()])
                        return false
        return true

static func _index_of_axial(haystack: Array, needle: Hex.Axial) -> int:
        for index in range(haystack.size()):
                var value: Hex.Axial = haystack[index]
                if value.q == needle.q and value.r == needle.r:
                        return index
        return -1
