extends Node

func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventKey and event.is_pressed():
                if event.echo:
                        return
                var meta := get_node_or_null("/root/MetaManager")
                if event.is_action_pressed("debug_unlock_all") and meta != null:
                        if meta.has_method("debug_unlock_all"):
                                meta.debug_unlock_all()
                if event.is_action_pressed("debug_wipe_library") and meta != null:
                        if meta.has_method("wipe_library"):
                                meta.wipe_library()
                if event.is_action_pressed("debug_print_unlocked") and meta != null:
                        if meta.has_method("list_unlocked"):
                                print("Unlocked:", meta.list_unlocked())
