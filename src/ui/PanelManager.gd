extends Node
class_name PanelManager

const ReviewBanner := preload("res://src/ui/ReviewBanner.gd")
const AudioController := preload("res://src/audio/AudioController.gd")

@export var panels: Array[NodePath] = []
@export var review_banner_path: NodePath

var _index := -1
var _resolved: Array[Control] = []
var _review_banner: ReviewBanner

func _ready() -> void:
        set_process_unhandled_input(true)
        call_deferred("_initialize")

func _initialize() -> void:
        _resolved.clear()
        for path in panels:
                var node := get_node_or_null(path)
                if node is Control:
                        _resolved.append(node)
        if not review_banner_path.is_empty():
                        _review_banner = get_node_or_null(review_banner_path)
        _update_visibility()
        _update_review_banner()
        AudioController.play(AudioController.SFX.UI_TOGGLE)

func _unhandled_input(event: InputEvent) -> void:
        if not event.is_action_pressed("tab"):
                        return
        if _resolved.is_empty():
                        _index = -1
                        _update_visibility()
                        _update_review_banner()
                        AudioController.play(AudioController.SFX.UI_TOGGLE)
                        return
        _index += 1
        if _index >= _resolved.size():
                        _index = -1
        _update_visibility()
        _update_review_banner()
        AudioController.play(AudioController.SFX.UI_TOGGLE)

func _update_visibility() -> void:
        for i in range(_resolved.size()):
                        var panel := _resolved[i]
                        if not is_instance_valid(panel):
                                        continue
                        panel.visible = i == _index
        if _index < 0:
                        for panel in _resolved:
                                        if is_instance_valid(panel):
                                                        panel.visible = false

func _update_review_banner() -> void:
        if _review_banner == null:
                        return
        if not is_instance_valid(_review_banner):
                        _review_banner = null
                        return
        var name := ""
        if _index >= 0 and _index < _resolved.size():
                        name = _resolved[_index].name
        _review_banner.set_active_panel(name)

func current_panel_name() -> String:
        if _index < 0 or _index >= _resolved.size():
                        return ""
        return _resolved[_index].name

func reset_cycle() -> void:
        _index = -1
        _update_visibility()
        _update_review_banner()
