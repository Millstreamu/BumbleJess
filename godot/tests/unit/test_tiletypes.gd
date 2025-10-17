extends RefCounted

func test_roundtrip_categories() -> bool:
	Config.load_all()
	var names := ["Harvest","Build","Refine","Storage","Guard","Upgrade","Chanting","Grove"]
	for name in names:
		var cat := TileTypes.category_from_string(name)
		if cat == -1:
			return false
		if TileTypes.string_from_category(cat) != name:
			return false
	return true

func test_invalid_category_returns_minus_one() -> bool:
	return TileTypes.category_from_string("Unknown") == -1

func test_variant_exists_helper() -> bool:
	Config.load_all()
	var cat := TileTypes.category_from_string("Harvest")
	return TileTypes.variant_exists(cat, "harvest_default")
