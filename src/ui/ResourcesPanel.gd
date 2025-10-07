extends Control
## Displays core resource totals and capacity information.
class_name ResourcesPanel

const Resources := preload("res://src/systems/Resources.gd")
const PanelSwitcher := preload("res://src/ui/PanelSwitcher.gd")

@export var panel_switcher_path: NodePath

var _resources: Resources
var _labels: Dictionary = {}

func _ready() -> void:
        _labels = {
                "nature": get_node_or_null("%NatureValue"),
                "earth": get_node_or_null("%EarthValue"),
                "water": get_node_or_null("%WaterValue"),
                "life": get_node_or_null("%LifeValue"),
        }
        _register_with_switcher()
        _refresh_all()

func set_resources(resources: Resources) -> void:
        if _resources == resources:
                return
        var callback := Callable(self, "_on_resource_changed")
        if _resources and _resources.resource_changed.is_connected(callback):
                _resources.resource_changed.disconnect(callback)
        _resources = resources
        if _resources and not _resources.resource_changed.is_connected(callback):
                _resources.resource_changed.connect(callback)
        _refresh_all()

func _register_with_switcher() -> void:
        var switcher := _resolve_panel_switcher()
        if switcher:
                switcher.register_panel("Resources", self)

func _resolve_panel_switcher() -> PanelSwitcher:
        if panel_switcher_path != NodePath():
                var node := get_node_or_null(panel_switcher_path)
                if node is PanelSwitcher:
                        return node
        var current := get_parent()
        while current:
                if current is PanelSwitcher:
                        return current
                current = current.get_parent()
        return null

func _refresh_all() -> void:
        if not _resources:
                _update_label("nature", 0, 0)
                _update_label("earth", 0, 0)
                _update_label("water", 0, 0)
                _update_label("life", 0, 0)
                return
        for key in _labels.keys():
                var entry := _resources.get_entry(key)
                _update_label(key, int(entry.get("amount", 0)), int(entry.get("cap", 0)))

func _on_resource_changed(resource_type: String, amount: int, cap: int) -> void:
        _update_label(resource_type, amount, cap)

func _update_label(resource_type: String, amount: int, cap: int) -> void:
        var label: Label = _labels.get(resource_type, null)
        if not label:
                return
        if resource_type == "life" or cap <= 0:
                label.text = str(amount)
        else:
                label.text = "%d/%d" % [amount, cap]
