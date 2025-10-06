extends RefCounted

func _basic_chosen() -> Dictionary:
    var chosen: Dictionary = {}
    var tiles: Dictionary = Config.tiles()
    var variants_variant: Variant = tiles.get("variants", {})
    if typeof(variants_variant) != TYPE_DICTIONARY:
        return chosen
    var variants: Dictionary = variants_variant
    var categories_variant: Variant = tiles.get("categories", [])
    if typeof(categories_variant) != TYPE_ARRAY:
        return chosen
    var categories: Array = categories_variant
    for category_variant in categories:
        if typeof(category_variant) != TYPE_STRING:
            continue
        var cat: String = category_variant
        var maybe_pool: Variant = variants.get(cat, [])
        if typeof(maybe_pool) != TYPE_ARRAY:
            continue
        var pool_array: Array = maybe_pool
        if pool_array.is_empty():
            continue
        var first_variant_variant: Variant = pool_array[0]
        if typeof(first_variant_variant) != TYPE_DICTIONARY:
            continue
        var first_variant: Dictionary = first_variant_variant
        var variant_id_variant: Variant = first_variant.get("id", "")
        if typeof(variant_id_variant) == TYPE_STRING:
            var variant_id: String = variant_id_variant
            chosen[cat] = variant_id
    return chosen

func _distribution_total(dist:Dictionary) -> int:
    var total := 0
    for key in dist.keys():
        var count_variant: Variant = dist.get(key, 0)
        total += int(count_variant)
    return total

func test_build_deck_uses_distribution() -> bool:
    Config.load_all()
    var chosen: Dictionary = _basic_chosen()
    var distribution_variant: Variant = Config.deck().get("distribution", {})
    if typeof(distribution_variant) != TYPE_DICTIONARY:
        return false
    var distribution: Dictionary = distribution_variant
    var deck: Array = Deck.build_deck(chosen, distribution, 123)
    if deck.size() != _distribution_total(distribution):
        return false
    for entry_variant in deck:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            return false
        var entry: Dictionary = entry_variant
        if not entry.has("category") or not entry.has("variant_id"):
            return false
        var category_variant: Variant = entry.get("category", "")
        if typeof(category_variant) != TYPE_STRING:
            return false
        var cat: String = category_variant
        var variant_id: String = str(entry.get("variant_id", ""))
        if chosen.has(cat) and variant_id != str(chosen[cat]):
            return false
    return true

func test_shuffle_is_deterministic() -> bool:
    Config.load_all()
    var chosen: Dictionary = _basic_chosen()
    var distribution_variant: Variant = Config.deck().get("distribution", {})
    if typeof(distribution_variant) != TYPE_DICTIONARY:
        return false
    var distribution: Dictionary = distribution_variant
    var deck1: Array = Deck.build_deck(chosen, distribution, 999)
    var deck2: Array = Deck.build_deck(chosen, distribution, 999)
    var deck3: Array = Deck.build_deck(chosen, distribution, 1000)
    if deck1 != deck2:
        return false
    return deck1 == deck2 and deck1 != deck3

func test_missing_chosen_variant_falls_back() -> bool:
    Config.load_all()
    var chosen: Dictionary = _basic_chosen()
    chosen.erase("Storage")
    var distribution_variant: Variant = Config.deck().get("distribution", {})
    if typeof(distribution_variant) != TYPE_DICTIONARY:
        return false
    var distribution: Dictionary = distribution_variant
    var total := _distribution_total(distribution)
    var deck: Array = Deck.build_deck(chosen, distribution, 42)
    if deck.size() != total:
        return false
    for entry_variant in deck:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_variant
        var category_variant: Variant = entry.get("category", "")
        if typeof(category_variant) != TYPE_STRING:
            continue
        var cat: String = category_variant
        if cat == "Storage":
            return str(entry.get("variant_id", "")) != ""
    return true
