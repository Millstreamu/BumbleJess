extends RefCounted

const PanelManager := preload("res://src/ui/PanelManager.gd")

func test_tab_cycles_panels() -> void:
        var root := Node.new()
        var manager := PanelManager.new()
        root.add_child(manager)
        var panel_nodes: Array[Control] = []
        for i in range(3):
                var panel := Control.new()
                panel.name = "Panel%d" % i
                root.add_child(panel)
                panel_nodes.append(panel)
        manager.panels = [
                NodePath("../Panel0"),
                NodePath("../Panel1"),
                NodePath("../Panel2"),
        ]
        manager.review_banner_path = NodePath("")
        manager._initialize()
        for panel in panel_nodes:
                if panel.visible:
                        push_error("Panels should start hidden")
        var event := InputEventAction.new()
        event.action = "tab"
        event.pressed = true
        manager._unhandled_input(event)
        if not panel_nodes[0].visible:
                push_error("First panel should be visible after first tab press")
        manager._unhandled_input(event)
        if not panel_nodes[1].visible:
                push_error("Second panel should be visible after second tab press")
        manager._unhandled_input(event)
        if not panel_nodes[2].visible:
                push_error("Third panel should be visible after third tab press")
        manager._unhandled_input(event)
        for panel in panel_nodes:
                if panel.visible:
                        push_error("All panels should hide after cycling past the last entry")
