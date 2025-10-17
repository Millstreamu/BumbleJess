extends RefCounted

const CombatLogScene := preload("res://scenes/ui/CombatLogPanel.tscn")
const CombatLog := preload("res://scripts/ui/CombatLogPanel.gd")

func test_combat_log_prunes_after_50_entries() -> void:
        var root := Node.new()
        var panel := CombatLogScene.instantiate()
        root.add_child(panel)
        panel._ready()
        for i in range(60):
                CombatLog.log("Entry %d" % i)
        if panel.lines.size() != 50:
                push_error("Combat log should keep only the most recent 50 entries")
        if panel.vbox.get_child_count() != 50:
                push_error("UI should mirror the 50-entry cap")
        if panel.lines[0] != "Entry 10":
                push_error("Oldest entry should be Entry 10 after pruning")
        if (panel.vbox.get_child(0) as Label).text != "Entry 10":
                push_error("UI should discard pruned labels as well")
