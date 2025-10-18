extends Node
class_name TileSetBuilder

static func _make_hex_image(px: int, color: Color) -> Image:
    var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var center := Vector2(px / 2.0, px / 2.0)
    var radius := px * 0.48
    img.lock()
    for y in range(px):
        for x in range(px):
            var v := Vector2(x + 0.5, y + 0.5)
            if v.distance_to(center) <= radius * 0.98:
                img.set_pixelv(Vector2i(x, y), color)
    img.unlock()
    return img

static func encode_tile_key(source_id: int, atlas_coords: Vector2i) -> String:
    return "%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y]

static func build_named_hex_tiles(tilemap: TileMap, names_to_colors: Dictionary, tile_px: int) -> Dictionary:
    var ts := tilemap.tile_set
    if ts == null:
        ts = TileSet.new()
        tilemap.tile_set = ts
    else:
        ts.clear()

    var name_to_id: Dictionary = {}
    var id_to_name: Dictionary = {}

    for name in names_to_colors.keys():
        var img := _make_hex_image(tile_px, names_to_colors[name])
        var tex := ImageTexture.create_from_image(img)

        var src := TileSetAtlasSource.new()
        src.texture = tex
        src.texture_region_size = Vector2i(tile_px, tile_px)

        var src_id: int = ts.get_last_source_id() + 1
        ts.add_source(src, src_id)

        var atlas_coords: Vector2i = ts.get_last_unused_tile_id(src_id)
        ts.create_tile(src_id, atlas_coords)
        ts.set_tile_texture_region(src_id, atlas_coords, Rect2i(Vector2i.ZERO, Vector2i(tile_px, tile_px)))
        ts.set_tile_texture_origin(src_id, atlas_coords, Vector2(tile_px / 2, tile_px / 2))

        var key := encode_tile_key(src_id, atlas_coords)
        var tile_ref := {
            "source_id": src_id,
            "atlas_coords": atlas_coords,
            "key": key,
        }
        name_to_id[name] = tile_ref
        id_to_name[key] = name

    tilemap.set_meta("tiles_name_to_id", name_to_id)
    tilemap.set_meta("tiles_id_to_name", id_to_name)
    return name_to_id
