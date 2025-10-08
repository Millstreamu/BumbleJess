extends RefCounted

const Resources := preload("res://src/systems/Resources.gd")
const RunState := preload("res://src/core/RunState.gd")

func _reset() -> void:
        Resources.reset()
        RunState.refine_cooldown = {}

func test_add_clamps_to_cap() -> bool:
        _reset()
        Resources.set_cap("Nature", 10)
        Resources.add("Nature", 15)
        if Resources.amount["Nature"] != 10:
                push_error("Nature should clamp to cap of 10")
                return false
        Resources.add("Nature", -20)
        if Resources.amount["Nature"] != 0:
                push_error("Nature should not drop below zero")
                return false
        return true

func test_lower_cap_clamps_amount() -> bool:
        _reset()
        Resources.set_cap("Earth", 10)
        Resources.add("Earth", 7)
        Resources.set_cap("Earth", 4)
        if Resources.amount["Earth"] != 4:
                push_error("Earth amount should clamp when cap is reduced")
                return false
        return true
