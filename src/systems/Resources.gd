extends RefCounted
## Tracks core essence resources with capacity limits and change notifications.
class_name Resources

signal resource_changed(resource_type: String, amount: int, cap: int)
signal resources_reset

const RESOURCE_TYPES := ["nature", "earth", "water", "life"]

static func do_production(_board: Node) -> void:
        # TODO (Phase 4): clusters, storage capacity, refine cooldown conversions, etc.
        print_debug("Resources.do_production() — stub")

var _data: Dictionary = {}

func _init() -> void:
        for key in RESOURCE_TYPES:
                _data[key] = {"amount": 0, "cap": 0}

func reset() -> void:
        for key in RESOURCE_TYPES:
                var entry: Dictionary = _data[key]
                entry["amount"] = 0
                entry["cap"] = 0
                _emit_change(key, entry)
        emit_signal("resources_reset")

func add(resource_type: String, delta: int) -> int:
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        var amount: int = int(entry.get("amount", 0))
        var cap: int = int(entry.get("cap", 0))
        var new_amount := amount + delta
        if new_amount < 0:
                new_amount = 0
        if key != "life":
                if cap <= 0:
                        new_amount = 0
                else:
                        new_amount = clamp(new_amount, 0, cap)
        entry["amount"] = new_amount
        _emit_change(key, entry)
        return new_amount

func consume(resource_type: String, amount: int) -> bool:
        if amount <= 0:
                return true
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        var current: int = int(entry.get("amount", 0))
        if current < amount:
                return false
        entry["amount"] = current - amount
        _emit_change(key, entry)
        return true

func has_amount(resource_type: String, amount: int) -> bool:
        if amount <= 0:
                return true
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        return int(entry.get("amount", 0)) >= amount

func set_cap_delta(resource_type: String, delta: int) -> int:
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        var cap: int = int(entry.get("cap", 0))
        var new_cap := max(0, cap + delta)
        if new_cap == cap:
                return cap
        entry["cap"] = new_cap
        if key != "life":
                if new_cap <= 0:
                        entry["amount"] = 0
                else:
                        entry["amount"] = min(int(entry.get("amount", 0)), new_cap)
        _emit_change(key, entry)
        return new_cap

func set_cap(resource_type: String, value: int) -> int:
        var key := _normalize(resource_type)
        _ensure_entry(key)
        var cap: int = int(_data[key].get("cap", 0))
        return set_cap_delta(key, value - cap)

func get_amount(resource_type: String) -> int:
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        return int(entry.get("amount", 0))

func get_cap(resource_type: String) -> int:
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        return int(entry.get("cap", 0))

func get_entry(resource_type: String) -> Dictionary:
        var key := _normalize(resource_type)
        var entry := _ensure_entry(key)
        return {"amount": int(entry.get("amount", 0)), "cap": int(entry.get("cap", 0))}

func get_all() -> Dictionary:
        var copy := {}
        for key in RESOURCE_TYPES:
                copy[key] = get_entry(key)
        return copy

func _ensure_entry(resource_type: String) -> Dictionary:
        if not _data.has(resource_type):
                _data[resource_type] = {"amount": 0, "cap": 0}
        return _data[resource_type]

func _normalize(resource_type: String) -> String:
        return resource_type.to_lower()

func _emit_change(resource_type: String, entry: Dictionary) -> void:
        emit_signal("resource_changed", resource_type, int(entry.get("amount", 0)), int(entry.get("cap", 0)))
