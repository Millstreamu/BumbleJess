extends RefCounted

func test_config_load_all() -> bool:
    Config.load_all()
    var tiles := Config.tiles()
    if tiles.is_empty():
        return false
    if not tiles.has("categories") or not tiles.has("variants"):
        return false
    var deck_data := Config.deck()
    if not deck_data.has("distribution"):
        return false
    var variant := Config.get_variant("Harvest", "harvest_default")
    if variant.is_empty():
        return false
    var effects := variant.get("effects", {})
    return effects.has("nature_per_adjacent_grove")
