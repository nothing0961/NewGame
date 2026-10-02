class_name BattleState
extends RefCounted

enum Phase { PLAYER, STRIP, DEBRIEF, ENDED }

signal log_event(text: String)
signal stats_changed()
signal phase_changed(phase: int)

var player_hp := 0
var player_block := 0
var enemy_hp := 0
var attack_bonus := 0
var revives := 0
var enemy_suppressed := false
var debug_force_roll := 0  # 0=正常掷硬币, 1=强制正面, 2=强制反面（仅测试用）

var phase: int = Phase.PLAYER
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var collection: Array[CardData] = []


func start() -> void:
	player_hp = BattleConfig.PLAYER_MAX_HP
	player_block = 0
	enemy_hp = BattleConfig.ENEMY_MAX_HP
	attack_bonus = 0
	revives = 0
	enemy_suppressed = false
	phase = Phase.PLAYER
	collection.clear()
	_build_deck()
	_start_player_turn()


func play_card(index: int) -> bool:
	if phase != Phase.PLAYER:
		return false
	if index < 0 or index >= hand.size():
		return false
	var card: CardData = hand[index]
	hand.remove_at(index)
	log_event.emit("你打出「%s」。" % card.display_name)
	if card.flavor != "":
		log_event.emit(card.flavor)
	for effect in card.effects:
		_apply_effect(effect, card.display_name)
	if card.permanent:
		collection.append(card)
		log_event.emit("「%s」留在了你面前。" % card.display_name)
	else:
		discard_pile.append(card)
	if enemy_hp <= 0:
		_enter_strip()
	elif hand.is_empty():
		end_turn()
	stats_changed.emit()
	return true


func end_turn() -> bool:
	if phase != Phase.PLAYER:
		return false
	log_event.emit("—— 他的回合 ——")
	_enemy_turn()
	_start_player_turn()
	return true


func absorb_wrath() -> bool:
	if phase != Phase.STRIP:
		return false
	var wrath := CardDB.get_card("wrath")
	collection.append(wrath)
	log_event.emit("你拿起了「%s」。" % wrath.display_name)
	phase = Phase.DEBRIEF
	phase_changed.emit(phase)
	stats_changed.emit()
	return true


func finish_debrief() -> bool:
	if phase != Phase.DEBRIEF:
		return false
	phase = Phase.ENDED
	log_event.emit(BattleConfig.TEXT_END)
	phase_changed.emit(phase)
	return true


func _build_deck() -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	for card_id in BattleConfig.DECK_COMPOSITION:
		for _i in BattleConfig.DECK_COMPOSITION[card_id]:
			draw_pile.append(CardDB.get_card(card_id))
	draw_pile.shuffle()


func _refill_hand() -> void:
	while hand.size() < BattleConfig.HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			for card in discard_pile:
				draw_pile.append(card)
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())


func _start_player_turn() -> void:
	player_block = 0
	_refill_hand()
	phase = Phase.PLAYER
	log_event.emit("—— 你的回合 ——")
	phase_changed.emit(phase)
	stats_changed.emit()


func _enemy_turn() -> void:
	if enemy_suppressed:
		enemy_suppressed = false
		log_event.emit(BattleConfig.TEXT_SUPPRESSED)
		return
	if _coin_is_heads():
		log_event.emit("硬币正面——「它」占上风。%s打了你 %d 点。" % [BattleConfig.ENEMY_NAME, BattleConfig.COIN_HEADS_DAMAGE])
		_damage_player(BattleConfig.COIN_HEADS_DAMAGE)
	else:
		log_event.emit("硬币反面——「他」还在挣。%s打了你 %d 点，用很轻的声音说：「……对不起。」" % [BattleConfig.ENEMY_NAME, BattleConfig.COIN_TAILS_DAMAGE])
		_damage_player(BattleConfig.COIN_TAILS_DAMAGE)


func _apply_effect(effect: Dictionary, card_name: String) -> void:
	match String(effect.get("op", "")):
		"deal_damage":
			var damage: int = int(effect.get("amount", 0)) + attack_bonus
			enemy_hp = max(0, enemy_hp - damage)
			log_event.emit("%s受到 %d 点伤害。" % [BattleConfig.ENEMY_NAME, damage])
		"gain_block":
			var amount: int = int(effect.get("amount", 0))
			player_block += amount
			log_event.emit("你摆出「%s」——能挡下 %d 点。" % [card_name, amount])
		"suppress_enemy_attack":
			enemy_suppressed = true
			log_event.emit("你喊：「回来！」他愣住，抬起头。")
		"buff_attack_permanent":
			var bonus: int = int(effect.get("amount", 0))
			attack_bonus += bonus
			log_event.emit("此后你每次攻击 +%d。（当前加成 +%d）" % [bonus, attack_bonus])


func _coin_is_heads() -> bool:
	match debug_force_roll:
		1:
			return true
		2:
			return false
	return randi() % 2 == 0


func _damage_player(amount: int) -> void:
	var blocked: int = min(player_block, amount)
	player_block -= blocked
	var to_hp: int = amount - blocked
	if blocked > 0:
		if to_hp == 0:
			log_event.emit("它整个被「护住」挡住了。")
		else:
			log_event.emit("「护住」挡下 %d 点。" % blocked)
	if to_hp > 0:
		player_hp = max(0, player_hp - to_hp)
		log_event.emit("你受到 %d 点伤害。（生命 %d）" % [to_hp, player_hp])
	if player_hp <= 0:
		_revive_player()


func _revive_player() -> void:
	revives += 1
	player_hp = BattleConfig.PLAYER_MAX_HP
	log_event.emit("%s（生命回到 %d）" % [BattleConfig.TEXT_REVIVE, player_hp])


func _enter_strip() -> void:
	phase = Phase.STRIP
	phase_changed.emit(phase)
