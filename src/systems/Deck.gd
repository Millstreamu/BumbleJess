extends Node
class_name Deck

static func build_deck(chosen:Dictionary, distribution:Dictionary, seed:int) -> Array:
    var entries : Array = []
    var tile_data: Dictionary = Config.tiles()
    var tile_variants: Variant = tile_data.get("variants", {})
    for cat in distribution.keys():
        var count : int = int(distribution[cat])
        var vid := str(chosen.get(cat, ""))
        if vid.is_empty():
            if typeof(tile_variants) == TYPE_DICTIONARY:
                var maybe_pool: Variant = tile_variants.get(cat, [])
                if typeof(maybe_pool) == TYPE_ARRAY:
                    var pool_array := maybe_pool as Array
                    if pool_array.size() > 0:
                        var first_variant := pool_array[0] as Dictionary
                        vid = str(first_variant.get("id", ""))
            if vid.is_empty():
                push_warning("Missing chosen variant for %s" % cat)
                continue
            push_warning("Missing chosen variant for %s, fallback=%s" % [cat, vid])
        for i in range(max(count, 0)):
            entries.append({ "category": cat, "variant_id": vid })
    shuffle_in_place(entries, seed)
    return entries

static func shuffle_in_place(arr:Array, seed:int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    for i in range(arr.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp: Variant = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
