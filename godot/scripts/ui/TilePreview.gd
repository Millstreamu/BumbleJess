extends Control
class_name TilePreview

@export var board_path: NodePath

@onready var label: Label = $Label

var _board: Board

func _ready() -> void:
        if not board_path.is_empty():
                var node := get_node_or_null(board_path)
                if node is Board:
                        _board = node
        if _board == null:
                var board_node := get_tree().get_root().find_child("Board", true, false)
                if board_node is Board:
                        _board = board_node

func update_for(ax: Vector2i) -> void:
        if _board == null:
                        label.text = ""
                        return
        var tiles := _board.placed_tiles
        var k := Board.key(ax)
        if not tiles.has(k):
                        label.text = ""
                        return
        var tile: Dictionary = tiles[k]
        var cat := String(tile.get("category", "?"))
        var vid := String(tile.get("variant_id", ""))
        var flags_variant: Variant = tile.get("flags", {})
        var flags := []
        if typeof(flags_variant) == TYPE_DICTIONARY:
                        for key in (flags_variant as Dictionary).keys():
                                        flags.append(str(key))
        var info := "%s" % cat
        if vid != "":
                        info += " (%s)" % vid
        if flags.is_empty():
                        label.text = info
        else:
                        label.text = "%s\nFlags: %s" % [info, ", ".join(flags)]
