extends Node
class_name AudioController

enum SFX {
        TILE_PLACE,
        GROWTH,
        DECAY,
        BATTLE_WIN,
        RESOURCE_GAIN,
        UI_TOGGLE,
}

static var _singleton: AudioController

func _ready() -> void:
        _singleton = self

static func play(cue: SFX) -> void:
        if not is_instance_valid(_singleton):
                        return
        _singleton._play(cue)

func _play(_cue: SFX) -> void:
        # Stub for future audio implementation. Keeping method for integration hooks.
        pass
