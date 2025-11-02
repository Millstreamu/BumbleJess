extends CanvasLayer

@onready var turn_l: Label = $"HBox/TurnLabel"
@onready var phase_l: Label = $"HBox/PhaseLabel"
@onready var dq: Label = $"HBox/DecayQueueLabel"
@onready var sprout_hp_label: Label = $"HBox/SproutHpLabel"
@onready var end_btn: Button = $"HBox/EndTurnBtn"
@onready var toast_layer: Control = $"ToastLayer"

var _world: Node = null
var _current_phase: String = ""

func _ready() -> void:
		_world = get_parent()
		_setup_turn_engine_hooks()
		_setup_decay_hooks()
		_setup_world_hooks()
		_setup_sprout_hooks()
		_set_end_ready(false)
		_refresh_turn_display()
		_refresh_phase_label()
		_refresh_sprout_hp()

func _setup_turn_engine_hooks() -> void:
		if not Engine.has_singleton("TurnEngine"):
				return
		var engine := TurnEngine
		if engine.has_signal("turn_changed"):
				engine.turn_changed.connect(_on_turn_changed)
		if engine.has_signal("phase_started"):
				engine.phase_started.connect(_on_phase_started)
		_on_turn_changed(int(engine.turn_index))

func _setup_decay_hooks() -> void:
		if Engine.has_singleton("DecayManager") and DecayManager.has_signal("battle_queue_updated"):
				DecayManager.battle_queue_updated.connect(_on_decay_queue_updated)

func _setup_world_hooks() -> void:
		if end_btn != null:
				end_btn.pressed.connect(_on_end_turn_pressed)
		if _world != null and _world.has_signal("tile_placed"):
				_world.connect("tile_placed", Callable(self, "_on_tile_placed"))

func _setup_sprout_hooks() -> void:
		if not Engine.has_singleton("SproutRegistry"):
				return
		SproutRegistry.roster_changed.connect(_refresh_sprout_hp)
		if SproutRegistry.has_signal("roster_regenerated"):
				SproutRegistry.roster_regenerated.connect(_on_roster_regenerated)

func _on_turn_changed(turn_index: int) -> void:
		var safe_turn := max(turn_index, 1)
		if turn_l != null:
				turn_l.text = "Turn %d" % safe_turn

func _on_phase_started(name: String) -> void:
		_current_phase = name
		_refresh_phase_label()
		if name == "player" or name == "growth":
				_set_end_ready(false)

func _refresh_phase_label() -> void:
		if phase_l == null:
				return
		if _current_phase.is_empty():
				phase_l.text = "Phase: —"
		else:
				phase_l.text = "Phase: %s" % _current_phase.capitalize()

func _on_decay_queue_updated(pending: int, processed: int, max_per_turn: int) -> void:
		if dq == null:
				return
		dq.text = "Decay Battles %d/%d (pending %d)" % [processed, max_per_turn, pending]

func _on_end_turn_pressed() -> void:
		if _world != null and _world.has_method("on_end_turn_pressed"):
				_world.call("on_end_turn_pressed")
		_set_end_ready(false)

func _on_tile_placed(_id: String, _cell: Vector2i) -> void:
		_set_end_ready(true)

func _set_end_ready(ready: bool) -> void:
		if end_btn == null:
				return
		end_btn.modulate = Color(1, 1, 1, 1) if ready else Color(0.8, 0.8, 0.8, 1)
		end_btn.add_theme_constant_override("outline_size", 2 if ready else 0)

func _refresh_turn_display() -> void:
		var turn_index := 1
		if Engine.has_singleton("TurnEngine"):
				turn_index = max(int(TurnEngine.turn_index), 1)
		_on_turn_changed(turn_index)

func _refresh_sprout_hp() -> void:
		if sprout_hp_label == null:
				return
		if not Engine.has_singleton("SproutRegistry"):
				sprout_hp_label.text = "Sprout HP: —"
				sprout_hp_label.hint_tooltip = ""
				return
		var roster := SproutRegistry.get_roster()
		if roster.is_empty():
				sprout_hp_label.text = "Sprout HP: 0"
				sprout_hp_label.hint_tooltip = ""
				return
		var total_hp := 0
		var tooltip_parts: Array[String] = []
		for entry_variant in roster:
				if not (entry_variant is Dictionary):
						continue
				var entry: Dictionary = entry_variant
				var sid := String(entry.get("id", ""))
				if sid.is_empty():
						continue
				var level := int(entry.get("level", 1))
				var stats := SproutRegistry.compute_stats(sid, level)
				var hp := int(stats.get("hp", 0))
				total_hp += hp
				var display := sid
				var def := SproutRegistry.get_by_id(sid)
				if def.has("name"):
						display = String(def.get("name"))
				tooltip_parts.append("%s: %d HP" % [display, hp])
		sprout_hp_label.text = "Sprout HP: %d" % total_hp
		sprout_hp_label.hint_tooltip = "\n".join(tooltip_parts)

func _on_roster_regenerated(percent: float) -> void:
		_show_toast("+%d%% Regen" % int(round(percent)))
		_refresh_sprout_hp()

func _show_toast(message: String) -> void:
		if toast_layer == null:
				return
		var label := Label.new()
		label.text = message
		label.modulate.a = 0.0
		toast_layer.add_child(label)
		label.position = Vector2(24, 120 + randi() % 48)
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(1.0)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.finished.connect(label.queue_free)
