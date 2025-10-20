extends Node

func on_grove_spawned(cell: Vector2i) -> void:
        # Placeholder implementation; future work can replace this with actual sprout creation.
        print("Grove spawned at ", cell)

func pick_for_battle(count: int) -> Array:
        var result: Array = []
        var limit := min(count, 3)
        for i in range(limit):
                result.append({"id": "sprout.woodling", "level": 1})
        return result
