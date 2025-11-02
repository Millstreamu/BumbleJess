extends Node

signal passive_applied(id: String, context: String)

var _defs: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _effect_handlers: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	_load_all_passives()
	_connect_turn_engine()
	call_deferred("_connect_turn_engine")

func reload() -> void:
	_load_all_passives()

func register_effect_handler(effect_type: String, callable: Callable) -> void:
	var key := String(effect_type)
	if key.is_empty():
		return
	var handlers: Array = _effect_handlers.get(key, [])
	if not (handlers is Array):
		handlers = []
	for existing in handlers:
		if existing == callable:
			return
	handlers.append(callable)
	_effect_handlers[key] = handlers

func unregister_effect_handler(effect_type: String, callable: Callable) -> void:
	var key := String(effect_type)
	if key.is_empty():
		return
	var handlers_variant: Variant = _effect_handlers.get(key, null)
	if handlers_variant is Array:
		var handlers: Array = handlers_variant
		if handlers.has(callable):
			handlers.erase(callable)
		if handlers.is_empty():
			_effect_handlers.erase(key)
		else:
			_effect_handlers[key] = handlers

func has_passive(id: String) -> bool:
	return _defs.has(id)

func get_passive_def(id: String) -> Dictionary:
	if _defs.has(id):
		var def_variant: Variant = _defs[id]
		if def_variant is Dictionary:
			return (def_variant as Dictionary).duplicate(true)
	return {}

func tick_passives(_turn_index: int = 0) -> void:
	_apply_totem_passives()

func _load_all_passives() -> void:
	_defs.clear()
	var arr := DataLite.load_json_array("res://data/passives.json")
	for entry in arr:
		if not (entry is Dictionary):
			continue
		var def: Dictionary = entry
		var pid := String(def.get("id", ""))
		if pid.is_empty():
			continue
		_defs[pid] = def

func _connect_turn_engine() -> void:
	var engine := _resolve_turn_engine()
	if engine == null:
		return
	if engine.has_signal("phase_started") and not engine.is_connected(
		"phase_started", Callable(self, "_on_phase_started")
	):
		engine.connect("phase_started", Callable(self, "_on_phase_started"))

func _resolve_turn_engine() -> Node:
	if Engine.has_singleton("TurnEngine"):
		var singleton := Engine.get_singleton("TurnEngine")
		if singleton is Node:
			return singleton
	return get_tree().root.get_node_or_null("TurnEngine")

func _on_phase_started(name: String) -> void:
	if name != "totem_passives":
		return
	_apply_totem_passives()

func _apply_totem_passives() -> void:
		if not Engine.has_singleton("RunConfig"):
				return
		var tid := String(RunConfig.totem_id)
		if tid.is_empty():
				return
		var totem := _get_totem_def(tid)
		if totem.is_empty():
				return
		var passives_variant: Variant = totem.get("passives", [])
		var pids: Array = []
		if passives_variant is Array:
				pids = passives_variant
		elif passives_variant is PackedStringArray:
				pids = Array(passives_variant)
		if pids.is_empty():
				return
		var tier := int(totem.get("tier", 1))
		var metadata := {
				"source": "totem",
				"totem_id": tid,
				"tier": tier,
		}
		for pid in pids:
				var passive_id := String(pid)
				if passive_id.is_empty():
						continue
				var def_variant: Variant = _defs.get(passive_id, {})
				if not (def_variant is Dictionary):
						continue
				var def: Dictionary = def_variant
				metadata["passive_id"] = passive_id
				metadata["trigger"] = String(def.get("trigger", ""))
				_execute_passive_def(passive_id, def, "totem_passives", metadata)

func _execute_passive(id: String, context: String = "", metadata: Dictionary = {}) -> void:
		if not _defs.has(id):
			return
		var def_variant: Variant = _defs[id]
		if not (def_variant is Dictionary):
			return
			var def: Dictionary = def_variant
			var meta: Dictionary = metadata.duplicate(true)
		if not meta.has("passive_id"):
				meta["passive_id"] = id
		_execute_passive_def(id, def, context, meta)

func _execute_passive_def(id: String, def_variant: Variant, context: String, metadata: Dictionary) -> void:
	if not (def_variant is Dictionary):
		return
	var def: Dictionary = def_variant
	var tier := int(metadata.get("tier", 1))
	var handled := false
	var attempted := false
	var effects_variant: Variant = def.get("effects", null)
	if effects_variant is Array:
		for raw_effect in effects_variant:
			var effect := _coerce_effect(raw_effect)
			if effect.is_empty():
				continue
			attempted = true
			var scaled := _scale_effect(effect, tier)
			handled = _dispatch_effect(id, def, scaled, context, metadata) or handled
	else:
		var single_effect := _coerce_effect(def.get("effect", {}))
		if not single_effect.is_empty():
			attempted = true
			var scaled_effect := _scale_effect(single_effect, tier)
			handled = _dispatch_effect(id, def, scaled_effect, context, metadata) or handled
	if handled:
		var signal_context := context
		if signal_context.is_empty():
			signal_context = "totem_phase"
		emit_signal("passive_applied", id, signal_context)
		var root := get_tree().root
		var hud := root.get_node_or_null("HUD") if root != null else null
		if hud == null and root != null:
			hud = root.get_node_or_null("Main/World/HUD")
		if hud != null and hud.has_method("_show_toast"):
			hud.call_deferred("_show_toast", "Passive: %s" % id)
	elif attempted:
		push_warning("Passive type not implemented: %s" % [String(def.get("id", id))])

func _coerce_effect(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _scale_effect(effect: Dictionary, tier: int) -> Dictionary:
	var scaled := effect.duplicate(true)
	if tier > 1:
		if scaled.has("percent"):
			scaled["percent"] = float(scaled["percent"]) * tier
		if scaled.has("multiplier"):
			var mult_value := float(scaled["multiplier"])
			scaled["multiplier"] = pow(mult_value, tier)
	return scaled

func _dispatch_effect(
	id: String, def: Dictionary, effect: Dictionary, context: String, metadata: Dictionary
) -> bool:
	var typ := String(effect.get("type", ""))
	if typ.is_empty():
		return false
	var handled := false
	match typ:
		"regen_all":
			_apply_regen_all(effect)
			handled = true
		"growth_speed_mult":
			_apply_growth_mult(effect)
			handled = true
		"resource_bonus":
			_apply_resource_bonus(effect)
			handled = true
		_:
			pass
	if _effect_handlers.has(typ):
		var handlers_variant: Variant = _effect_handlers.get(typ, [])
		if handlers_variant is Array:
			var handlers: Array = handlers_variant
			var still_valid: Array = []
			for callable in handlers:
				if not (callable is Callable):
					continue
				var cb: Callable = callable
				if not cb.is_valid():
					continue
				cb.call(effect.duplicate(true), context, metadata.duplicate(true), def.duplicate(true))
				still_valid.append(cb)
				handled = true
			if still_valid.is_empty():
				_effect_handlers.erase(typ)
			else:
				_effect_handlers[typ] = still_valid
	return handled

func _apply_regen_all(effect: Dictionary) -> void:
	var pct := float(effect.get("percent", 1.0))
	if Engine.has_singleton("SproutRegistry") and SproutRegistry.has_method("regen_percent_all"):
		SproutRegistry.regen_percent_all(pct)
	if Engine.has_singleton("DecayManager") and DecayManager.has_method("regen_percent_hostiles"):
		DecayManager.regen_percent_hostiles(pct)

func _apply_growth_mult(effect: Dictionary) -> void:
	var mult := float(effect.get("multiplier", 1.0))
	if Engine.has_singleton("GrowthManager") and GrowthManager.has_method("apply_growth_multiplier"):
		GrowthManager.apply_growth_multiplier(mult)

func _apply_resource_bonus(effect: Dictionary) -> void:
	var mult := float(effect.get("multiplier", 1.0))
	var kind := String(effect.get("resource", "nature"))
	if Engine.has_singleton("ResourceManager") and ResourceManager.has_method("apply_resource_bonus"):
		ResourceManager.apply_resource_bonus(kind, mult)

func _get_totem_def(id: String) -> Dictionary:
	var arr := DataLite.load_json_array("res://data/totems.json")
	for entry in arr:
		if not (entry is Dictionary):
			continue
		var totem: Dictionary = entry
		if String(totem.get("id", "")) == id:
			return totem
	return {}
