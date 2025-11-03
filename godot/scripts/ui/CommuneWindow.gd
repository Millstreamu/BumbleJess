extends CanvasLayer
class_name CommuneWindow

const CARD_SCENE := preload("res://scenes/ui/CommuneCard.tscn")

@onready var row: HBoxContainer = $"Panel/Row"

var _pending_choices: Array = []
var _battle_ui_active := false

func _ready() -> void:
	visible = false

	if typeof(CommuneManager) != TYPE_NIL:
		if not CommuneManager.offer_ready.is_connected(_on_offer):
			CommuneManager.offer_ready.connect(_on_offer)

		if not CommuneManager.chosen.is_connected(_on_chosen):
			CommuneManager.chosen.connect(_on_chosen)

		if not CommuneManager.cleared.is_connected(_on_cleared):
			CommuneManager.cleared.connect(_on_cleared)

	_bind_battle_manager()


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
								var btn := CARD_SCENE.instantiate() as Button
								if btn == null:
												continue
								var name_label := btn.get_node_or_null("Name") as Label
								if name_label != null:
												var display_name := String(tile_def.get("name", tile_def.get("id", "(tile)")))
												name_label.text = display_name
								var category_label := btn.get_node_or_null("CategoryTopRight") as Label
								if category_label != null:
												var cat := CategoryMap.canonical(String(tile_def.get("category", "")))
												var display_cat := CategoryMap.display_name(cat)
												category_label.text = display_cat
								var summary := btn.get_node_or_null("RichTextLabel") as RichTextLabel
								if summary != null:
												summary.text = _summarize(tile_def)
								var tid := String(tile_def.get("id", ""))
								btn.disabled = tid.is_empty()
								if not tid.is_empty():
												btn.pressed.connect(func():
																CommuneManager.choose(tid)
												)
								row.add_child(btn)
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
