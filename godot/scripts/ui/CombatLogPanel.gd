extends Control
class_name CombatLog

@onready var vbox: VBoxContainer = $Scroll/VBox

var lines: Array[String] = []

static var _singleton: CombatLog

func _ready() -> void:
        _singleton = self
        _refresh()

static func log(msg: String) -> void:
        if msg == null:
                        return
        if not is_instance_valid(CombatLog._singleton):
                        print(msg)
                        return
        CombatLog._singleton._append(str(msg))

static func last_line() -> String:
        if not is_instance_valid(CombatLog._singleton):
                        return ""
        if CombatLog._singleton.lines.is_empty():
                        return ""
        return CombatLog._singleton.lines.back()

static func has_line(msg: String) -> bool:
        if not is_instance_valid(CombatLog._singleton):
                        return false
        return CombatLog._singleton.lines.has(msg)

func _append(msg: String) -> void:
        lines.append(msg)
        while lines.size() > 50:
                        lines.pop_front()
                        if vbox.get_child_count() > 0:
                                        vbox.get_child(0).queue_free()
        var lbl := Label.new()
        lbl.text = msg
        vbox.add_child(lbl)
        if vbox.get_child_count() > 50:
                        var child := vbox.get_child(0)
                        child.queue_free()

func _refresh() -> void:
        if vbox == null:
                        return
        for child in vbox.get_children():
                        child.queue_free()
        for msg in lines:
                        var lbl := Label.new()
                        lbl.text = msg
                        vbox.add_child(lbl)
