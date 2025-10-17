extends Node

const Deck := preload("res://scripts/tiles/Deck.gd")

static var seed: int = 0
static var turn: int = 0
static var chosen_variants: Dictionary = {}
static var deck: Array = []
static var draw_index: int = 0
static var overgrowth: Dictionary = {}
static var connected_set: Dictionary = {}
static var refine_cooldown: Dictionary = {}
static var decay_totems: Array = []
static var decay_tiles: Dictionary = {}
static var decay_adjacent_age: Dictionary = {}
static var tile_tokens: int = 0
static var turn_notes: Array = []

static func start_new_run() -> void:

	seed = int(Time.get_unix_time_from_system())
	Config.load_all()
	chosen_variants = {}
	deck = []
	draw_index = 0
	overgrowth = {}
	connected_set = {}
	refine_cooldown = {}
	decay_totems = []
	decay_tiles = {}
	decay_adjacent_age = {}
	tile_tokens = 0
	turn_notes.clear()
	turn = 0
	RunState.finalize_after_draft()

static func add_turn_note(note: String) -> void:
	var trimmed := String(note).strip_edges()
	if trimmed.is_empty():
		return
	turn_notes.append(trimmed)


static func finalize_after_draft() -> void:
	var distribution: Dictionary = {}
	if Config.deck().has("distribution"):
		distribution = Config.deck()["distribution"]
	deck = Deck.build_deck(chosen_variants, distribution, seed)
	draw_index = 0
