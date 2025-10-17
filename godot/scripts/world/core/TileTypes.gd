extends RefCounted
class_name TileTypes

enum TileCategory { Harvest, Build, Refine, Storage, Guard, Upgrade, Chanting, Grove }

static var _map := {
	"Harvest": TileCategory.Harvest,
	"Build": TileCategory.Build,
	"Refine": TileCategory.Refine,
	"Storage": TileCategory.Storage,
	"Guard": TileCategory.Guard,
	"Upgrade": TileCategory.Upgrade,
	"Chanting": TileCategory.Chanting,
	"Grove": TileCategory.Grove
}

static func category_from_string(s:String) -> int:
	return _map.get(s, -1)

static func string_from_category(cat:int) -> String:
	for k in _map.keys():
		if _map[k] == cat:
			return k
	return ""

static func variant_exists(category:int, id:String) -> bool:
	var s := string_from_category(category)
	if s == "":
		return false
	var variant := Config.get_variant(s, id)
	return variant is Dictionary and not variant.is_empty()
