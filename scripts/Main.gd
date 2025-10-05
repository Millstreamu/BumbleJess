extends Node2D

const HexGrid := preload("res://scripts/grid/HexGrid.gd")

@onready var background: ColorRect = $Background
@onready var hex_grid: HexGrid = $HexGrid

func _ready() -> void:
	if hex_grid and hex_grid.grid_config:
		background.color = hex_grid.grid_config.background_color
	hex_grid.position = get_viewport_rect().size * 0.5
