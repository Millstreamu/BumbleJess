extends RefCounted

func _basic_chosen() -> Dictionary:
    var chosen : Dictionary = {}
    var variants := Config.tiles().get("variants", {})
    if typeof(variants) != TYPE_DICTIONARY:
        return chosen
    for cat in Config.tiles().get("categories", []):
        var maybe_pool = variants.get(cat, [])
        if typeof(maybe_pool) == TYPE_ARRAY:
            var pool_array := maybe_pool as Array
            if pool_array.size() > 0:
                var first_variant := pool_array[0] as Dictionary
                chosen[cat] = first_variant.get("id", "")
    return chosen

func _distribution_total(dist:Dictionary) -> int:
    var total := 0
    for key in dist.keys():
        total += int(dist[key])
    return total

func test_build_deck_uses_distribution() -> bool:
    Config.load_all()
    var chosen := _basic_chosen()
    var distribution := Config.deck().get("distribution", {})
    var deck := Deck.build_deck(chosen, distribution, 123)
    if deck.size() != _distribution_total(distribution):
        return false
    for entry in deck:
        if not entry.has("category") or not entry.has("variant_id"):
            return false
        var cat := entry["category"]
        if chosen.has(cat) and entry["variant_id"] != chosen[cat]:
            return false
    return true

func test_shuffle_is_deterministic() -> bool:
    Config.load_all()
    var chosen := _basic_chosen()
    var distribution := Config.deck().get("distribution", {})
    var deck1 := Deck.build_deck(chosen, distribution, 999)
    var deck2 := Deck.build_deck(chosen, distribution, 999)
    var deck3 := Deck.build_deck(chosen, distribution, 1000)
    if deck1 != deck2:
        return false
    return deck1 == deck2 and deck1 != deck3

func test_missing_chosen_variant_falls_back() -> bool:
    Config.load_all()
    var chosen := _basic_chosen()
    chosen.erase("Storage")
    var distribution := Config.deck().get("distribution", {})
    var total := _distribution_total(distribution)
    var deck := Deck.build_deck(chosen, distribution, 42)
    if deck.size() != total:
        return false
    for entry in deck:
        if entry["category"] == "Storage":
            return entry["variant_id"] != ""
    return true
