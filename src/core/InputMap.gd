extends Node
## Configures the project's input actions at runtime so both keyboard and gamepad
## bindings are centralized in one place.
class_name InputMapConfig

const ACTION_DEFINITIONS := {
        "ui_left": [
                _key_event(KEY_LEFT),
                _joypad_button_event(JOY_BUTTON_DPAD_LEFT),
        ],
        "ui_right": [
                _key_event(KEY_RIGHT),
                _joypad_button_event(JOY_BUTTON_DPAD_RIGHT),
        ],
        "ui_up": [
                _key_event(KEY_UP),
                _joypad_button_event(JOY_BUTTON_DPAD_UP),
        ],
        "ui_down": [
                _key_event(KEY_DOWN),
                _joypad_button_event(JOY_BUTTON_DPAD_DOWN),
        ],
        "confirm": [
                _key_event(KEY_SPACE),
                _joypad_button_event(JOY_BUTTON_A),
        ],
        "cancel": [
                _key_event(KEY_Z),
                _joypad_button_event(JOY_BUTTON_B),
        ],
        "panel_next": [
                _key_event(KEY_TAB),
                _joypad_button_event(JOY_BUTTON_START),
        ],
}

static func apply() -> void:
        ## Ensures the engine's InputMap matches the default bindings declared above.
        for action_name in ACTION_DEFINITIONS.keys():
                _register_action(action_name, ACTION_DEFINITIONS[action_name])

static func _register_action(action_name: String, events: Array) -> void:
        if not InputMap.has_action(action_name):
                InputMap.add_action(action_name)
        else:
                InputMap.action_erase_events(action_name)
        for event in events:
                if event:
                        InputMap.action_add_event(action_name, event)

static func _key_event(keycode: Key) -> InputEventKey:
        var event := InputEventKey.new()
        event.keycode = keycode
        event.physical_keycode = keycode
        return event

static func _joypad_button_event(button: int) -> InputEventJoypadButton:
        var event := InputEventJoypadButton.new()
        event.button_index = button
        return event

