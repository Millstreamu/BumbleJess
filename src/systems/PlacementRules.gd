extends RefCounted
## Enforces connected placement rules for tiles on the hex grid.
class_name PlacementRules

const Hex := preload("res://src/core/Hex.gd")

var connected_set: Dictionary[Vector2i, bool] = {}

func _init(initial_connected: Array = []) -> void:
        set_connected(initial_connected)

func set_connected(axials: Array) -> void:
        connected_set.clear()
        for axial in axials:
                _add_to_connected(axial)

func mark_connected(axial) -> void:
        _add_to_connected(axial)

func can_place(at, occupied) -> bool:
        var target := _to_vector(at)
        if _contains(occupied, target):
                return false
        for neighbor in Hex.neighbors(Hex.Axial.from_vector2i(target)):
                var neighbor_vec := neighbor.to_vector2i()
                if connected_set.has(neighbor_vec):
                        return true
        return false

func _add_to_connected(value) -> void:
        var vec := _to_vector(value)
        connected_set[vec] = true

static func _to_vector(value) -> Vector2i:
        if value is Hex.Axial:
                return value.to_vector2i()
        if value is Vector2i:
                return value
        if value is Vector2:
                return Vector2i(int(value.x), int(value.y))
        push_warning("Unsupported axial value: %s" % [value])
        return Vector2i.ZERO

static func _contains(collection, value: Vector2i) -> bool:
        if collection == null:
                return false
        match typeof(collection):
                TYPE_DICTIONARY:
                        return collection.has(value)
                TYPE_ARRAY:
                        return collection.has(value)
                TYPE_OBJECT:
                        if collection.has_method("has"):
                                return collection.has(value)
                        return false
                TYPE_PACKED_VECTOR2_ARRAY:
                        return PackedVector2Array(collection).has(value)
                _:
                        return false
