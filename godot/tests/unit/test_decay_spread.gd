extends Node

const MAP_ID := "map.demo_001"
const MAP_PATH := "res://scenes/world/World.tscn"

func _ready() -> void:
        var world_scene: PackedScene = preload(MAP_PATH)
        var world := world_scene.instantiate()
        add_child(world)
        await world.ready

        MapSeeder.load_map(MAP_ID, world)
        await get_tree().process_frame

        var decay_before := _collect_decay_cells(world)
        assert(decay_before.size() >= 2, "Map seeding should create initial decay totems")

        var interval := int(DecayManager.cfg.get("totem_spread_interval_turns", 3))
        DecayManager.set("_turn", interval)
        DecayManager.set("_last_spread_turn", 0)
        DecayManager.call("_spread_clusters_if_due")
        await get_tree().process_frame

        var decay_after := _collect_decay_cells(world)
        assert(decay_after.size() > decay_before.size(), "Decay should spread when the interval elapses")

        print("Decay spread: PASS")
        get_tree().quit()

func _collect_decay_cells(world: Node) -> Array[Vector2i]:
        var result: Array[Vector2i] = []
        for y in range(world.height):
                for x in range(world.width):
                        var cell := Vector2i(x, y)
                        if world.get_cell_name(world.LAYER_OBJECTS, cell) == "decay":
                                result.append(cell)
        return result
