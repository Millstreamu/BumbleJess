extends BaseCard
class_name TileSelectCard

func set_tile(name: String, effects_text: String, desc_text: String, tex: Texture2D, id: String) -> void:
	set_data({
		"id": id,
		"title": name,
		"body": "[b]Effects[/b]\n" + effects_text + "\n\n" + desc_text,
		"art": tex
	})
