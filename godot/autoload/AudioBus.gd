extends Node

var _player := AudioStreamPlayer.new()

func _ready() -> void:
        add_child(_player)
        _player.bus = "Master"

func play(path: String) -> void:
        if path.is_empty():
                return
        if not ResourceLoader.exists(path):
                return
        var stream := ResourceLoader.load(path)
        if stream is AudioStream:
                _player.stream = stream
                _player.play()
