extends RefCounted

const Board := preload("res://scripts/world/Board.gd")
const Config := preload("res://autoload/Config.gd")
const Decay := preload("res://scripts/world/Decay.gd")
const RunState := preload("res://autoload/RunState.gd")

func _reset_state() -> Dictionary:
	Config.load_all()
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	var backup := {}
	if typeof(totem_cfg_variant) == TYPE_DICTIONARY:
		var totem_cfg: Dictionary = totem_cfg_variant
		backup = totem_cfg.duplicate(true)
	RunState.connected_set = {}
	RunState.decay_totems = []
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	RunState.seed = 12345
	return backup

func _restore_config(backup: Dictionary) -> void:
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	if typeof(totem_cfg_variant) != TYPE_DICTIONARY:
		return
	var totem_cfg: Dictionary = totem_cfg_variant
	for key in backup.keys():
		totem_cfg[key] = backup[key]
	for key in totem_cfg.keys():
		if not backup.has(key):
			totem_cfg.erase(key)

func _axial_distance(ax: Vector2i) -> int:
	var q := ax.x
	var r := ax.y
	var s := -q - r
	return (abs(q) + abs(r) + abs(s)) / 2

func test_seed_totems_within_ring_and_unique() -> bool:
	var backup := _reset_state()
	var totem_cfg_variant: Variant = Config.decay().get("totems", {})
	if typeof(totem_cfg_variant) != TYPE_DICTIONARY:
		_restore_config(backup)
		return false
	var totem_cfg: Dictionary = totem_cfg_variant
	totem_cfg["count"] = 3
	totem_cfg["spread_every_turns"] = 4
	totem_cfg["min_radius"] = 2
	totem_cfg["max_radius"] = 3
	RunState.connected_set[Board.key(Vector2i.ZERO)] = true
	Decay.seed_totems()
	var ok := true
	ok = ok and RunState.decay_totems.size() == 3
	var seen := {}
	for entry_variant in RunState.decay_totems:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			ok = false
			break
		var entry: Dictionary = entry_variant
		var ax_variant: Variant = entry.get("ax", Vector2i.ZERO)
		if typeof(ax_variant) != TYPE_VECTOR2I:
			ok = false
			break
		var ax: Vector2i = ax_variant
		var dist := _axial_distance(ax)
		if dist < 2 or dist > 3:
			ok = false
			break
		if int(entry.get("timer", 0)) != 4:
			ok = false
			break
		var key := Board.key(ax)
		if seen.has(key):
			ok = false
			break
		seen[key] = true
	_restore_config(backup)
	RunState.decay_totems = []
	RunState.decay_tiles = {}
	RunState.decay_adjacent_age = {}
	return ok
