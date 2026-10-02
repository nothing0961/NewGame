class_name CardDB
extends RefCounted

const CARD_DIR := "res://data/cards/"


static func get_card(card_id: String) -> CardData:
	return load(CARD_DIR + card_id + ".tres") as CardData
