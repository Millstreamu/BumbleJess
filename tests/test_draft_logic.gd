extends RefCounted

const DraftScene := preload("res://scenes/Draft.tscn")

func _instantiate_draft() -> Control:
    var tree := Engine.get_main_loop()
    if not (tree is SceneTree):
        return null
    var draft := DraftScene.instantiate()
    tree.root.add_child(draft)
    return draft

func _cleanup_draft(draft:Control) -> void:
    if draft == null:
        return
    if draft.get_parent():
        draft.get_parent().remove_child(draft)
    draft.queue_free()

func test_draft_selects_all_categories() -> bool:
    Config.load_all()
    RunState.start_new_run()
    var draft := _instantiate_draft()
    if draft == null:
        return false
    var completed := false
    draft.draft_completed.connect(func(): completed = true)
    for i in range(7):
        draft._confirm_pick()
    var expected := ["Harvest","Build","Refine","Storage","Guard","Upgrade","Chanting"]
    var chosen := RunState.chosen_variants
    var success := completed and chosen.size() == expected.size()
    for cat in expected:
        success = success and chosen.has(cat)
    _cleanup_draft(draft)
    return success

func test_go_back_resets_previous_choice() -> bool:
    Config.load_all()
    RunState.start_new_run()
    var draft := _instantiate_draft()
    if draft == null:
        return false
    draft._confirm_pick()
    var progressed := draft._index == 1
    draft._go_back()
    var reset := draft._index == 0 and not draft._picked.has("Harvest")
    _cleanup_draft(draft)
    return progressed and reset
