extends CanvasLayer
class_name CommuneWindow

const CARD_SCENE := preload("res://ui/cards/TileSelectCard.tscn")

@onready var row: GridContainer = $"Panel/Row"

var _pending_choices: Array = []
var _battle_ui_active := false

func _ready() -> void:
	set_process_unhandled_input(true)
	visible = false

	if typeof(CommuneManager) != TYPE_NIL:
		if not CommuneManager.offer_ready.is_connected(_on_offer):
			CommuneManager.offer_ready.connect(_on_offer)

		if not CommuneManager.chosen.is_connected(_on_chosen):
			CommuneManager.chosen.connect(_on_chosen)

		if not CommuneManager.cleared.is_connected(_on_cleared):
			CommuneManager.cleared.connect(_on_cleared)

	_bind_battle_manager()

func _unhandled_input(event: InputEvent) -> void:
		if not visible:
				return
		if event.is_action_pressed("ui_cancel"):
				var viewport := get_viewport()
				if viewport != null:
						viewport.set_input_as_handled()

func _bind_battle_manager() -> void:
				if typeof(BattleManager) == TYPE_NIL:
								return
				if BattleManager.has_signal("battle_started") and not BattleManager.battle_started.is_connected(_on_battle_started):
								BattleManager.battle_started.connect(_on_battle_started)
				if BattleManager.has_signal("battle_ui_closed") and not BattleManager.battle_ui_closed.is_connected(_on_battle_ui_closed):
								BattleManager.battle_ui_closed.connect(_on_battle_ui_closed)
				if BattleManager.has_method("is_battle_ui_open"):
								_battle_ui_active = bool(BattleManager.is_battle_ui_open())

func _on_offer(choices: Array) -> void:
				if _battle_ui_active:
								_pending_choices = _duplicate_choices(choices)
								return
				_display_offer(choices)

func _on_chosen(_tile_id: String) -> void:
				visible = false

func _on_cleared() -> void:
				if row.get_child_count() == 0:
								visible = false

func _on_battle_started(_target: Vector2i) -> void:
				_battle_ui_active = true
				visible = false

func _on_battle_ui_closed() -> void:
				_battle_ui_active = false
				if _pending_choices.is_empty():
								return
				var choices := _pending_choices
				_pending_choices = []
				_display_offer(choices)

func _clear_cards() -> void:
	for child in row.get_children():
		var node := child as Node
		if node != null:
			node.queue_free()

func _display_offer(choices: Array) -> void:
	_clear_cards()
	var added_any := false
	for choice_variant in choices:
		if not (choice_variant is Dictionary):
			continue
		var tile_def: Dictionary = choice_variant
		var node := CARD_SCENE.instantiate()
		if node == null:
			continue
		var card := node as TileSelectCard
		if card == null:
			node.queue_free()
			continue
		var tid := String(tile_def.get("id", ""))
		var display_name := String(tile_def.get("name", tid if not tid.is_empty() else "(tile)"))
		var category := CategoryMap.canonical(String(tile_def.get("category", "")))
		var cat_display := CategoryMap.display_name(category)
		var effects_text := _summarize(tile_def)
		if not cat_display.is_empty():
			effects_text = "[i]%s[/i]\n%s" % [cat_display, effects_text]
		var desc_text := String(tile_def.get("description", "")).strip_edges()
		if desc_text.is_empty():
			desc_text = "—"
		var icon_tex := _load_texture(String(tile_def.get("icon", "")))
		card.set_tile(display_name, effects_text, desc_text, icon_tex, tid)
		if not tid.is_empty():
			card.pressed.connect(func(card_id: String):
				CommuneManager.choose(card_id)
			)
		row.add_child(card)
		added_any = true
	visible = added_any

func _duplicate_choices(choices: Array) -> Array:
				var result: Array = []
				for choice_variant in choices:
								if choice_variant is Dictionary:
												result.append(Dictionary(choice_variant).duplicate(true))
								else:
												result.append(choice_variant)
				return result

func _summarize(def: Dictionary) -> String:
		var lines: Array[String] = []
		var outputs_variant: Variant = def.get("outputs", {})
		if outputs_variant is Dictionary:
				var outputs: Dictionary = outputs_variant
				if not outputs.is_empty():
						var kv: Array[String] = []
						for key in outputs.keys():
								var cat := CategoryMap.display_name(String(key))
								var amount := int(outputs[key])
								kv.append("%s +%d" % [cat, amount])
						if not kv.is_empty():
								lines.append("[b]Outputs[/b] " + ", ".join(kv))
		var syn_variant: Variant = def.get("synergies", [])
		if syn_variant is Array:
				for entry in syn_variant:
						if not (entry is Dictionary):
								continue
						var syn: Dictionary = entry
						var tag := String(syn.get("tag", ""))
						var bonus_variant: Variant = syn.get("bonus", {})
						var bonus_text := JSON.stringify(bonus_variant) if bonus_variant is Dictionary else String(bonus_variant)
						lines.append("Adj [%s] +%s" % [tag, bonus_text])
		if lines.is_empty() and def.has("rules"):
				lines.append("(legacy rules)")
		return "\n".join(lines)

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		return res
	return null
