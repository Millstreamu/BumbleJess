extends Node

func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventKey and event.is_pressed():
                if event.echo:
                        return
                if event.is_action_pressed("debug_unlock_all") and Engine.has_singleton("MetaManager"):
                        if MetaManager.has_method("debug_unlock_all"):
                                MetaManager.debug_unlock_all()
                if event.is_action_pressed("debug_wipe_library") and Engine.has_singleton("MetaManager"):
                        if MetaManager.has_method("wipe_library"):
                                MetaManager.wipe_library()
                if event.is_action_pressed("debug_print_unlocked") and Engine.has_singleton("MetaManager"):
                        if MetaManager.has_method("list_unlocked"):
                                print("Unlocked:", MetaManager.list_unlocked())
