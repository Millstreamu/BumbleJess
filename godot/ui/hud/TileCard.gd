extends Panel
class_name TileCard

@onready var _art: TextureRect = $"HBoxContainer/Art"
@onready var _title: Label = $"HBoxContainer/VBoxContainer/Title"
@onready var _effects: RichTextLabel = $"HBoxContainer/VBoxContainer/Effects"
@onready var _desc: RichTextLabel = $"HBoxContainer/VBoxContainer/Desc"

func update_card(data: Dictionary) -> void:
	if _title:
		_title.text = str(data.get("name", ""))
	if _effects:
		_effects.text = str(data.get("effects", ""))
	if _desc:
		_desc.text = str(data.get("desc", ""))
	var tex := data.get("texture")
	if _art:
		if tex != null and tex is Texture2D:
			_art.texture = tex
		else:
			_art.texture = null
