class_name CardPool
extends RefCounted

var owned: Dictionary = {}
var deck: Array[String] = []


func _init() -> void:
	for card_id in BattleConfig.WAREHOUSE_INITIAL:
		owned[card_id] = int(BattleConfig.WAREHOUSE_INITIAL[card_id])


# 收下的罪卡入仓库（design/design-round3.md §6）；罪卡唯一，重复收集不叠加
func collect_sin(card_id: String) -> void:
	if owned_count(card_id) > 0:
		return
	owned[card_id] = 1


func owned_count(card_id: String) -> int:
	return int(owned.get(card_id, 0))


func deck_count(card_id: String) -> int:
	var count := 0
	for id in deck:
		if id == card_id:
			count += 1
	return count


func is_sin_card(card_id: String) -> bool:
	return CardDB.get_card(card_id).kind == CardData.Kind.SIN


func sin_in_deck() -> bool:
	for id in deck:
		if is_sin_card(id):
			return true
	return false


# 组卡约束：罪卡最多放一张（七选一的最小实现，design/design-round3.md §6）
func can_add(card_id: String) -> bool:
	if deck.size() >= BattleConfig.DECK_SIZE:
		return false
	if deck_count(card_id) >= owned_count(card_id):
		return false
	if is_sin_card(card_id) and sin_in_deck():
		return false
	return true


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
