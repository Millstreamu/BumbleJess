extends Node

func _ready() -> void:
	DataDB.refresh()
	_reset_world()
	_run_targeting_tests()
	_run_condition_tests()
	_run_operation_tests()
	_run_interval_tests()
	_run_adjacency_tests()
	print("EffectsEngine tests: PASS")

func _reset_world() -> void:
	TileManager.clear()
	TileManager.clear_decay()
	EffectsEngine.reset_state()
	Game.set_turn_index(1)

func _assign_effects(tile: TileManager.TileRef, effects: Array) -> void:
	if tile == null:
		return
	tile.definition["effects"] = effects

func _run_targeting_tests() -> void:
	_reset_world()
	var tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(tile, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"op": "add",
		"stat": "output.nature",
		"amount": 2,
		"stacking": "sum"
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(tile.stats["output"]["nature"], 2.0))
	_reset_world()
	var center := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	var forest := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(1, 0))
	forest.tags = ["forest"]
	var plains := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 1))
	_assign_effects(center, [{
		"when": "start_of_turn",
		"target": {"scope": "adjacent", "has_tags_any": ["forest"]},
		"op": "add",
		"stat": "output.nature",
		"amount": 3
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(forest.stats["output"]["nature"], 3.0))
	assert(is_equal_approx(plains.stats["output"]["nature"], 0.0))
	_reset_world()
	var radius_source := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	var radius_target := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(1, -1))
	_assign_effects(radius_source, [{
		"when": "start_of_turn",
		"target": {"scope": "radius", "radius": 1},
		"op": "set",
		"stat": "purity",
		"amount": 5
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(radius_source.stats["purity"], 5.0))
	assert(is_equal_approx(radius_target.stats["purity"], 5.0))
	_reset_world()
	var global_source := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	var other := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(2, -2))
	_assign_effects(global_source, [{
		"when": "start_of_turn",
		"target": {"scope": "global"},
		"op": "add",
		"stat": "cap.local",
		"amount": 1
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(global_source.stats["cap"]["local"], 1.0))
	assert(is_equal_approx(other.stats["cap"]["local"], 1.0))

func _run_condition_tests() -> void:
	_reset_world()
	var conditional := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(conditional, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"condition": {"adjacent_count": {"tag": "river", "op": ">=", "value": 1}},
		"op": "add",
		"stat": "output.water",
		"amount": 2
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(conditional.stats["output"]["water"], 0.0))
	var river := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(1, 0))
	river.tags = ["river"]
	EffectsEngine.apply_when("on_adjacency_change")
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(conditional.stats["output"]["water"], 2.0))
	_reset_world()
	var decay_tester := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(decay_tester, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"condition": {"touching_decay": true},
		"op": "add",
		"stat": "purity",
		"amount": 4
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(decay_tester.stats["purity"], 0.0))
	TileManager.set_decay_cell(Vector2i(1, 0), 1.0)
	EffectsEngine.apply_when("on_adjacency_change")
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(decay_tester.stats["purity"], 4.0))
	_reset_world()
	var mod_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(mod_tile, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"condition": {"turn_mod": {"mod": 2, "eq": 0}},
		"op": "add",
		"stat": "output.nature",
		"amount": 5
	}])
	Game.set_turn_index(1)
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(mod_tile.stats["output"]["nature"], 0.0))
	Game.set_turn_index(2)
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(mod_tile.stats["output"]["nature"], 5.0))

func _run_operation_tests() -> void:
	_reset_world()
	var stat_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(stat_tile, [
		{
			"when": "start_of_turn",
			"target": {"scope": "self"},
			"op": "set",
			"stat": "purity",
			"amount": 3
		},
		{
			"when": "start_of_turn",
			"target": {"scope": "self"},
			"op": "mul",
			"stat": "cap.global",
			"amount": 2
		}
	])
	stat_tile.stats["cap"]["global"] = 1.5
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(stat_tile.stats["purity"], 3.0))
	assert(is_equal_approx(stat_tile.stats["cap"]["global"], 3.0))
	_reset_world()
	var convert_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(convert_tile, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"op": "convert",
		"amount": {
			"from": {"nature": 1},
			"to": {"water": 1},
			"period": 2
		}
	}])
	convert_tile.stats["output"]["nature"] = 5
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(convert_tile.stats["output"]["nature"], 5.0))
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(convert_tile.stats["output"]["nature"], 4.0))
	assert(is_equal_approx(convert_tile.stats["output"]["water"], 1.0))
	_reset_world()
	var spawn_source := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(spawn_source, [{
		"when": "start_of_turn",
		"target": {"scope": "adjacent"},
		"op": "spawn",
		"amount": {"tile_id": "tile.wind_swept_meadow", "count": 1, "empty_only": true}
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(TileManager.has_tile(Vector2i(1, 0)))
	_reset_world()
	var transform_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(transform_tile, [{
		"when": "start_of_turn",
		"interval_turns": 2,
		"target": {"scope": "self"},
		"op": "transform",
		"amount": {"to": "tile.overgrowth.default"}
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(transform_tile.id == "tile.wind_swept_meadow")
	EffectsEngine.apply_when("start_of_turn")
	assert(transform_tile.id == "tile.overgrowth.default")
	_reset_world()
	var cleanse_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	TileManager.set_decay_cell(Vector2i(1, 0), 1.0)
	_assign_effects(cleanse_tile, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"op": "cleanse_decay",
		"amount": {"radius": 1, "max_tiles": 1}
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(not TileManager.is_touching_decay(Vector2i(0, 0)))
	_reset_world()
	var damage_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	TileManager.set_decay_cell(Vector2i(1, 0), 2.0)
	_assign_effects(damage_tile, [{
		"when": "start_of_turn",
		"target": {"scope": "self"},
		"op": "damage_decay",
		"amount": {"radius": 1, "amount": 1.5}
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(TileManager.is_touching_decay(Vector2i(0, 0)))
	EffectsEngine.apply_when("start_of_turn")
	assert(not TileManager.is_touching_decay(Vector2i(0, 0)))
	_reset_world()
	var aura_source := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	var aura_target := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(1, 0))
	_assign_effects(aura_source, [{
		"when": "start_of_turn",
		"target": {"scope": "adjacent"},
		"op": "aura_sprout",
		"amount": {"stat": "hp_pct", "op": "add", "amount": 0.1},
		"stacking": "sum"
	}])
	EffectsEngine.apply_when("start_of_turn")
	var aura_cache := EffectsEngine.get_aura_cache()
	assert(aura_cache.has(String(aura_target.uid)))
	var aura_entry: Dictionary = aura_cache[String(aura_target.uid)]
	var aura_values: Dictionary = aura_entry["|add|hp_pct"]
	assert(is_equal_approx(float(aura_values.get("amount", 0.0)), 0.1))

func _run_interval_tests() -> void:
	_reset_world()
	var tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(tile, [{
		"when": "start_of_turn",
		"interval_turns": 2,
		"target": {"scope": "self"},
		"op": "add",
		"stat": "output.nature",
		"amount": 1
	}])
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(tile.stats["output"]["nature"], 0.0))
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(tile.stats["output"]["nature"], 1.0))
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(tile.stats["output"]["nature"], 1.0))
	_reset_world()
	var duration_tile := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(duration_tile, [{
		"when": "start_of_turn",
		"duration_turns": 2,
		"target": {"scope": "self"},
		"op": "add",
		"stat": "purity",
		"amount": 2
	}])
	Game.set_turn_index(1)
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(duration_tile.stats["purity"], 2.0))
	Game.set_turn_index(2)
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(duration_tile.stats["purity"], 4.0))
	Game.set_turn_index(3)
	EffectsEngine.apply_when("start_of_turn")
	assert(is_equal_approx(duration_tile.stats["purity"], 4.0))

func _run_adjacency_tests() -> void:
	_reset_world()
	var watcher := TileManager.place_tile("tile.wind_swept_meadow", Vector2i(0, 0))
	_assign_effects(watcher, [{
		"when": "on_adjacency_change",
		"target": {"scope": "self"},
		"op": "add",
		"stat": "purity",
		"amount": 1
	}])
	TileManager.place_tile("tile.wind_swept_meadow", Vector2i(1, 0))
	assert(is_equal_approx(watcher.stats["purity"], 1.0))
	EffectsEngine.apply_when("on_adjacency_change")
	assert(is_equal_approx(watcher.stats["purity"], 2.0))
