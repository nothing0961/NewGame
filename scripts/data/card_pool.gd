class_name CardPool
extends RefCounted

var owned: Dictionary = {}
var deck: Array[String] = []


func _init() -> void:
	for card_id in BattleConfig.WAREHOUSE_INITIAL:
		owned[card_id] = int(BattleConfig.WAREHOUSE_INITIAL[card_id])


func owned_count(card_id: String) -> int:
	return int(owned.get(card_id, 0))


func deck_count(card_id: String) -> int:
	var count := 0
	for id in deck:
		if id == card_id:
			count += 1
	return count


func can_add(card_id: String) -> bool:
	return deck.size() < BattleConfig.DECK_SIZE and deck_count(card_id) < owned_count(card_id)


func add_to_deck(card_id: String) -> bool:
	if not can_add(card_id):
		return false
	deck.append(card_id)
	return true


func remove_from_deck(card_id: String) -> bool:
	var index := deck.find(card_id)
	if index < 0:
		return false
	deck.remove_at(index)
	return true


func is_deck_valid() -> bool:
	if deck.size() != BattleConfig.DECK_SIZE:
		return false
	for card_id in deck:
		var card := CardDB.get_card(card_id)
		for effect in card.effects:
			if String(effect.get("op", "")) == "deal_damage":
				return true
	return false
