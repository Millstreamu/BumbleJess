extends Node

const MAP_ID := "map.demo_001"
const MAP_PATH := "res://scenes/world/World.tscn"

func _ready() -> void:
	_reset_deck()
	var initial_next := DeckManager.peek()
	assert(not initial_next.is_empty(), "Deck should provide an initial tile after reset")
	var initial_category := DeckManager.get_tile_category(initial_next)
	assert(not initial_category.is_empty(), "Initial tile should have a category for placement")
	var initial_remaining := DeckManager.remaining()
	assert(initial_remaining > 0, "Deck should have remaining cards after the first draw")

	var world_scene: PackedScene = preload(MAP_PATH)
	var world := world_scene.instantiate()
	add_child(world)
	await world.ready

	MapSeeder.load_map(MAP_ID, world)
	await get_tree().process_frame

	var origin := MapSeeder.get_origin_cell()
	assert(origin == Vector2i(8, 6), "Origin cell should match map seed data")
	assert(world.width == 16 and world.height == 12, "World dimensions should match map data")
	assert(world.tile_px == 64, "Tile pixel size should match map data")

	var totem_name: String = world.get_cell_name(world.LAYER_OBJECTS, origin)
	assert(totem_name == "totem", "Totem must be placed at the origin cell")

	var decay_one := Vector2i(3, 2)
	var decay_two := Vector2i(13, 9)
	assert(world.get_cell_name(world.LAYER_OBJECTS, decay_one) == "decay", "First decay totem should be placed correctly")
	assert(world.get_cell_name(world.LAYER_OBJECTS, decay_two) == "decay", "Second decay totem should be placed correctly")

	var far_cell := Vector2i(origin.x + 4, origin.y + 4)
	far_cell = world.clamp_cell(far_cell)
	assert(not world.can_place_at(far_cell), "Tiles cannot be placed away from the connected network")

	var neighbor := Vector2i(origin.x + 1, origin.y)
	neighbor = world.clamp_cell(neighbor)
	assert(world.can_place_at(neighbor), "Adjacent cells to the totem should be valid placement targets")
	assert(world.turn == 0, "Turn counter should start at zero")

	world.attempt_place_at(neighbor)
	await get_tree().process_frame

	assert(world.turn == 1, "Placing a tile should advance the turn counter")
	var placed_name: String = world.get_cell_name(world.LAYER_LIFE, neighbor)
	assert(placed_name == initial_category, "Placed tile should match the drawn tile category")

	var after_remaining := DeckManager.remaining()
	assert(after_remaining == initial_remaining - 1, "Drawing a tile should shrink the deck by one")
	var next_tile := DeckManager.peek()
	assert(not next_tile.is_empty(), "Deck should provide the next tile after placement")

	print("World integration: PASS")
	get_tree().quit()

func _reset_deck() -> void:
	DeckManager.build_starting_deck()
	DeckManager.shuffle()
	DeckManager.draw_one()
