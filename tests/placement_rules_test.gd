extends RefCounted

const Hex := preload("res://src/core/Hex.gd")
const PlacementRules := preload("res://src/systems/PlacementRules.gd")

func test_cannot_place_on_occupied_cell() -> bool:
        var rules := PlacementRules.new([Hex.Axial.new(0, 0)])
        var occupied := {Vector2i(1, 0): true}
        if rules.can_place(Vector2i(1, 0), occupied):
                push_error("Should not place on occupied cell")
                return false
        return true

func test_requires_neighbor_in_connected_set() -> bool:
        var rules := PlacementRules.new([Hex.Axial.new(0, 0)])
        var empty := {}
        if not rules.can_place(Vector2i(1, 0), empty):
                push_error("Expected placement adjacent to connected set to succeed")
                return false
        if rules.can_place(Vector2i(2, 0), empty):
                push_error("Placement without adjacency should fail")
                return false
        return true

func test_mark_connected_expands_network() -> bool:
        var rules := PlacementRules.new([Hex.Axial.new(0, 0)])
        var empty := {}
        if not rules.can_place(Vector2i(1, 0), empty):
                push_error("First neighbor should be buildable")
                return false
        rules.mark_connected(Vector2i(1, 0))
        if not rules.can_place(Vector2i(2, 0), empty):
                push_error("Newly connected tile should allow further placements")
                return false
        return true
