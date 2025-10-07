extends Node

const Deck := preload("res://src/systems/Deck.gd")

var seed:int = 0
var chosen_variants:Dictionary = {}
var deck:Array = []
var draw_index:int = 0

func start_new_run() -> void:
        seed = int(Time.get_unix_time_from_system())
        Config.load_all()
        chosen_variants = {}
        deck = []
        draw_index = 0
        finalize_after_draft()

func finalize_after_draft() -> void:
	var distribution : Dictionary = {}
	if Config.deck().has("distribution"):
		distribution = Config.deck()["distribution"]
	deck = Deck.build_deck(chosen_variants, distribution, seed)
	draw_index = 0
