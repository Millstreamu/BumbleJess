extends RefCounted

func test_config_load_all() -> bool:
    Config.load_all()
    var tiles: Dictionary = Config.tiles()
    if tiles.is_empty():
        return false
    if not tiles.has("categories") or not tiles.has("variants"):
        return false
    var deck_variant: Variant = Config.deck()
    if typeof(deck_variant) != TYPE_DICTIONARY:
        return false
    var deck_data: Dictionary = deck_variant
    if not deck_data.has("distribution"):
        return false
    var variant: Dictionary = Config.get_variant("Harvest", "harvest_default")
    if variant.is_empty():
        return false
    var effects_variant: Variant = variant.get("effects", {})
    if typeof(effects_variant) != TYPE_DICTIONARY:
        return false
    var effects: Dictionary = effects_variant
    return effects.has("nature_per_adjacent_grove")
