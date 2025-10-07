extends RefCounted
## Handles conversion of Nature and Earth into Water for refine tiles.
class_name ProducerRefine

const Resources := preload("res://src/systems/Resources.gd")
const Hex := preload("res://src/core/Hex.gd")

var cooldown_turns: int = 2
var _cooldowns: Dictionary = {}

func process_turn(tiles: Array, resources: Resources) -> void:
        var active: Dictionary = {}
        for entry in tiles:
                var axial := _to_vector2i(entry)
                active[axial] = true
                var remaining := int(_cooldowns.get(axial, cooldown_turns))
                remaining -= 1
                if remaining <= 0:
                        if _try_convert(resources):
                                remaining = cooldown_turns
                        else:
                                remaining = 1
                _cooldowns[axial] = remaining
        var to_remove: Array = []
        for key in _cooldowns.keys():
                if not active.has(key):
                        to_remove.append(key)
        for key in to_remove:
                _cooldowns.erase(key)

func _try_convert(resources: Resources) -> bool:
        if not resources:
                return false
        if not resources.has_amount("nature", 1):
                return false
        if not resources.has_amount("earth", 1):
                return false
        if not resources.consume("nature", 1):
                return false
        if not resources.consume("earth", 1):
                resources.add("nature", 1)
                return false
        resources.add("water", 1)
        return true

static func _to_vector2i(value: Variant) -> Vector2i:
        if value is Vector2i:
                return value
        if value is Hex.Axial:
                return value.to_vector2i()
        if typeof(value) == TYPE_DICTIONARY and value.has("q") and value.has("r"):
                return Vector2i(int(value.q), int(value.r))
        return Vector2i.ZERO
