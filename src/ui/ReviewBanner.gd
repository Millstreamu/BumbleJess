extends Control
class_name ReviewBanner

@onready var label: Label = $PanelContainer/MarginContainer/Label

var turn_controller: TurnController

func _ready() -> void:
        visible = false
        set_process_unhandled_input(true)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_for_turn(turn: int) -> void:
        label.text = "Turn %d — Review (Space to continue)" % turn
        visible = true

func hide_banner() -> void:
        visible = false

func _unhandled_input(event: InputEvent) -> void:
        if not visible:
                return
        if event.is_action_pressed("ui_accept"):
                hide_banner()
                if turn_controller:
                        turn_controller.ack_review_and_resume()
                get_viewport().set_input_as_handled()
