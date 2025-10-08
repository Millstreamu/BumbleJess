extends Node2D

const HexGrid := preload("res://scripts/grid/HexGrid.gd")
const Enclosure := preload("res://src/systems/Enclosure.gd")
const Growth := preload("res://src/systems/Growth.gd")
const Mutation := preload("res://src/systems/Mutation.gd")
const ResourcesSystem := preload("res://src/systems/Resources.gd")
const Decay := preload("res://src/systems/Decay.gd")
const Battle := preload("res://src/systems/Battle.gd")
const RunState := preload("res://src/core/RunState.gd")
const TurnController := preload("res://src/systems/TurnController.gd")
const ReviewBanner := preload("res://src/ui/ReviewBanner.gd")

@onready var background: ColorRect = $Background
@onready var hex_grid: HexGrid = $HexGrid
@onready var board: Node = $Board
@onready var turn_controller: TurnController = $TurnController
@onready var review_banner: ReviewBanner = $UI/ReviewBanner

func _ready() -> void:
    if hex_grid and hex_grid.grid_config:
        background.color = hex_grid.grid_config.background_color
    hex_grid.position = get_viewport_rect().size * 0.5
    _wire_turn_systems()

func _wire_turn_systems() -> void:
    if not turn_controller:
        return
    if board:
        turn_controller.subscribe("phase_new_tile", func(): Enclosure.detect_and_mark_overgrowth(board))
        turn_controller.subscribe("phase_growth", func(): Growth.do_growth(board))
        turn_controller.subscribe("phase_mutation", func(): Mutation.do_mutations(board))
        turn_controller.subscribe("phase_resources", func(): ResourcesSystem.do_production(board))
        turn_controller.subscribe("phase_decay", func(): Decay.do_spread(board))
        turn_controller.subscribe("phase_battle", func(): Battle.resolve_all(board))
    if review_banner:
        review_banner.turn_controller = turn_controller
        turn_controller.subscribe("phase_review", func(): review_banner.show_for_turn(RunState.turn))
