extends RefCounted
class_name TileSetBuilder

static func make_flat_top_hex_polygon(px: int, margin: float = 1.0, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
		var effective_px: float = max(float(px) - margin * 2.0, 1.0)
		var radius_x: float = effective_px * 0.5
		var radius_y: float = radius_x * (sqrt(3.0) / 2.0)
		var c: Vector2 = center if center != Vector2.ZERO else Vector2.ZERO

		var poly := PackedVector2Array()
		poly.push_back(c + Vector2(+radius_x, 0.0))
		poly.push_back(c + Vector2(+radius_x * 0.5, +radius_y))
		poly.push_back(c + Vector2(-radius_x * 0.5, +radius_y))
		poly.push_back(c + Vector2(-radius_x, 0.0))
		poly.push_back(c + Vector2(-radius_x * 0.5, -radius_y))
		poly.push_back(c + Vector2(+radius_x * 0.5, -radius_y))
		return poly

static func _make_hex_image(px: int, color: Color) -> Image:
		var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

		var center := Vector2(px / 2.0, px / 2.0)
		var polygon := make_flat_top_hex_polygon(px, 2.0, center)

		for y in range(px):
				for x in range(px):
						var point := Vector2(x + 0.5, y + 0.5)
						if Geometry2D.is_point_in_polygon(point, polygon):
								img.set_pixelv(Vector2i(x, y), color)

		return img

static func encode_tile_key(source_id: int, atlas_coords: Vector2i) -> String:
		return "%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y]

static func build_named_hex_tiles(tilemap: TileMap, names_to_colors: Dictionary, tile_px: int) -> Dictionary:
		var ts := TileSet.new()
		ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
		ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
		ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
		ts.tile_offset = TileSet.TileOffset.TILE_OFFSET_EVEN
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
