extends RefCounted
class_name TileSetBuilder

static func _make_hex_image(px: int, color: Color) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(px / 2.0, px / 2.0)
	var radius := px * 0.48
	for y in range(px):
		for x in range(px):
			var v := Vector2(x + 0.5, y + 0.5)
			if v.distance_to(center) <= radius * 0.98:
				img.set_pixelv(Vector2i(x, y), color)
	return img

static func encode_tile_key(source_id: int, atlas_coords: Vector2i) -> String:
	return "%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y]

static func build_named_hex_tiles(tilemap: TileMap, names_to_colors: Dictionary, tile_px: int) -> Dictionary:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_size = Vector2i(tile_px, tile_px)
	tilemap.tile_set = ts

	var name_to_id: Dictionary = {}
	var id_to_name: Dictionary = {}

	var next_source_id := 0

	for tile_name in names_to_colors.keys():
		var img := _make_hex_image(tile_px, names_to_colors[tile_name])
		var tex := ImageTexture.create_from_image(img)

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(tile_px, tile_px)

		var atlas_coords := Vector2i.ZERO
		src.create_tile(atlas_coords)

		var src_id: int = next_source_id
		next_source_id += 1
		ts.add_source(src, src_id)

		var key := encode_tile_key(src_id, atlas_coords)
		var tile_ref := {
			"source_id": src_id,
			"atlas_coords": atlas_coords,
			"key": key,
		}
		name_to_id[tile_name] = tile_ref
		id_to_name[key] = tile_name

	tilemap.set_meta("tiles_name_to_id", name_to_id)
	tilemap.set_meta("tiles_id_to_name", id_to_name)
	return name_to_id
