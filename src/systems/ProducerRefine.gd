extends Node
## Handles Water production from Refine tiles using a cooldown system.
class_name ProducerRefine

const Config := preload("res://src/data/Config.gd")
const RunState := preload("res://src/core/RunState.gd")
const Resources := preload("res://src/systems/Resources.gd")

static var last_water_gain: int = 0

static func tick_and_convert(board: Node) -> void:
        last_water_gain = 0
        var cooldown_turns := _cooldown_turns()
        var tiles: Dictionary = _placed_tiles(board)
        var active := {}
        for key in tiles.keys():
                var tile: Dictionary = tiles[key]
                if String(tile.get("category", "")) != "Refine":
                        continue
                active[key] = true
                var remaining := int(RunState.refine_cooldown.get(key, cooldown_turns))
                remaining -= 1
                if remaining <= 0:
                        _try_convert(key)
                        RunState.refine_cooldown[key] = cooldown_turns
                else:
                        RunState.refine_cooldown[key] = remaining
        var to_remove: Array = []
        for key in RunState.refine_cooldown.keys():
                if not active.has(key):
                        to_remove.append(key)
        for key in to_remove:
                RunState.refine_cooldown.erase(key)

static func _try_convert(_key: String) -> void:
        if Resources.amount["Nature"] < 1:
                return
        if Resources.amount["Earth"] < 1:
                return
        if Resources.cap["Water"] > 0 and Resources.amount["Water"] >= Resources.cap["Water"]:
                return
        var consumed_nature := Resources.add("Nature", -1)
        if consumed_nature != -1:
                # Unable to consume Nature; nothing was spent.
                if consumed_nature != 0:
                        Resources.add("Nature", -consumed_nature)
                return
        var consumed_earth := Resources.add("Earth", -1)
        if consumed_earth != -1:
                # Refund Nature and any partial Earth removal.
                Resources.add("Nature", 1)
                if consumed_earth != 0:
                        Resources.add("Earth", -consumed_earth)
                return
        var gained := Resources.add("Water", 1)
        if gained < 1:
                Resources.add("Nature", 1)
                Resources.add("Earth", 1)
                return
        last_water_gain += gained

static func _cooldown_turns() -> int:
        var variant: Dictionary = Config.get_variant("Refine", "refine_default")
        var effects: Dictionary = variant.get("effects", {})
        return int(effects.get("cooldown_turns", 2))

static func _placed_tiles(board: Node) -> Dictionary:
        if board == null:
                return {}
        var tiles_variant := board.get("placed_tiles")
        if typeof(tiles_variant) == TYPE_DICTIONARY:
                return tiles_variant
        return {}
