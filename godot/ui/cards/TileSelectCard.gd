extends "res://ui/cards/BaseCard.gd"
class_name TileSelectCard

func set_tile(tile_name: String, effects_text: String, desc_text: String, tex: Texture2D, id: String) -> void:
	set_data({
		"id": id,
		"title": tile_name,
		"body": "[b]Effects[/b]\n" + effects_text + "\n\n" + desc_text,
		"art": tex
	})
