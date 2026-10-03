class_name BattleState
extends RefCounted

enum Phase { PLAYER, STRIP, DEBRIEF, ENDED }
enum Mode { TUTORIAL, PRACTICE }

signal log_event(text: String)
signal stats_changed()
signal phase_changed(phase: int)
signal card_staged(card: CardData)
signal card_recalled(card: CardData)
signal card_played(card: CardData)
signal card_discarded(card: CardData)

var mode: int = Mode.TUTORIAL
var enemy_name := BattleConfig.ENEMY_NAME
var enemy_max_hp := BattleConfig.ENEMY_MAX_HP

var player_hp := 0
var player_cost := 0
var player_block := 0
var enemy_hp := 0
var attack_bonus := 0
var revives := 0
var enemy_suppressed := false
var debug_force_plays := -1  # -1=随机出牌数, 0..n=强制出牌数（仅测试用）

var phase: int = Phase.PLAYER
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var staged: Array[CardData] = []
var discard_pile: Array[CardData] = []
var collection: Array[CardData] = []
var enemy_draw_pile: Array[CardData] = []
var enemy_hand: Array[CardData] = []
var enemy_discard_pile: Array[CardData] = []
var batch_committed := false


func start(custom_deck: Array = []) -> void:
	_setup(Mode.TUTORIAL, custom_deck)


func start_practice(custom_deck: Array = []) -> void:
	_setup(Mode.PRACTICE, custom_deck)


func can_afford(card: CardData) -> bool:
	return card.cost <= player_cost


func can_stage(card: CardData) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if staged.size() >= BattleConfig.PLAY_ZONE_SIZE:
		return false
	return card.cost + staged_cost() <= player_cost


func staged_cost() -> int:
	var total := 0
	for card in staged:
		total += card.cost
	return total


func stage_card(hand_index: int) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: CardData = hand[hand_index]
	if not can_stage(card):
		return false
	hand.remove_at(hand_index)
	staged.append(card)
	stats_changed.emit()
	card_staged.emit(card)
	return true


func recall_card(staged_index: int) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if staged_index < 0 or staged_index >= staged.size():
		return false
	var card: CardData = staged[staged_index]
	hand.append(card)
	staged.remove_at(staged_index)
	stats_changed.emit()
	card_recalled.emit(card)
	return true


# 打出即结束回合：整批结算后（战斗未结束）自动轮到敌人、再进入新的玩家回合
func commit_staged() -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if staged.is_empty():
		return false
	var total := staged_cost()
	player_cost -= total
	batch_committed = true
	var cards := staged.duplicate()
	staged.clear()
	for card in cards:
		log_event.emit("你打出「%s」。" % card.display_name)
		card_played.emit(card)
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
		if mode == Mode.PRACTICE:
			_end_practice()
		else:
			_enter_strip()
	else:
		_finish_round()
	stats_changed.emit()
	return true


func gain_card(card: CardData) -> void:
	hand.append(card)
	log_event.emit("「%s」进了你的手牌。" % card.display_name)
	stats_changed.emit()


func needs_discard() -> bool:
	return hand.size() > BattleConfig.HAND_LIMIT


func discard_from_hand(index: int) -> bool:
	if phase != Phase.PLAYER:
		return false
	if index < 0 or index >= hand.size():
		return false
	var card: CardData = hand[index]
	hand.remove_at(index)
	discard_pile.append(card)
	log_event.emit("你弃掉了「%s」。" % card.display_name)
	stats_changed.emit()
	card_discarded.emit(card)
	return true


# 主动弃牌换 Cost：获得「牌 Cost - 1」点，可超过上限；只限本回合（回合重置时回满）
func discard_for_cost(index: int) -> int:
	if phase != Phase.PLAYER:
		return -1
	if index < 0 or index >= hand.size():
		return -1
	var card: CardData = hand[index]
	var gain: int = card.cost - 1
	hand.remove_at(index)
	discard_pile.append(card)
	player_cost += gain
	log_event.emit("你弃掉了「%s」，Cost +%d。（现在 Cost %d）" % [card.display_name, gain, player_cost])
	stats_changed.emit()
	card_discarded.emit(card)
	return gain


func end_turn() -> bool:
	if phase != Phase.PLAYER:
		return false
	if not staged.is_empty():
		# 有摆放：走「打出」同一条结算路径（结算后自动进入敌人回合）
		return commit_staged()
	_finish_round()
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


func _setup(new_mode: int, custom_deck: Array) -> void:
	mode = new_mode
	if mode == Mode.PRACTICE:
		enemy_name = BattleConfig.PRACTICE_ENEMY_NAME
		enemy_max_hp = BattleConfig.PRACTICE_ENEMY_HP
	else:
		enemy_name = BattleConfig.ENEMY_NAME
		enemy_max_hp = BattleConfig.ENEMY_MAX_HP
	player_hp = BattleConfig.PLAYER_MAX_HP
	player_cost = BattleConfig.PLAYER_MAX_COST
	player_block = 0
	enemy_hp = enemy_max_hp
	attack_bonus = 0
	revives = 0
	enemy_suppressed = false
	phase = Phase.PLAYER
	batch_committed = false
	staged.clear()
	collection.clear()
	_build_deck(custom_deck)
	_build_enemy_deck()
	if mode == Mode.PRACTICE:
		log_event.emit(BattleConfig.TEXT_PRACTICE_START)
	# 开局：双方各摸五张
	_draw_from(draw_pile, discard_pile, hand, BattleConfig.HAND_SIZE)
	if mode == Mode.TUTORIAL:
		_draw_from(enemy_draw_pile, enemy_discard_pile, enemy_hand, BattleConfig.HAND_SIZE)
	_start_player_turn()


func _build_deck(custom_deck: Array) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	if custom_deck.is_empty():
		for card_id in BattleConfig.DECK_COMPOSITION:
			for _i in BattleConfig.DECK_COMPOSITION[card_id]:
				draw_pile.append(CardDB.get_card(card_id))
	else:
		for card_id in custom_deck:
			draw_pile.append(CardDB.get_card(String(card_id)))
	draw_pile.shuffle()


func _build_enemy_deck() -> void:
	enemy_draw_pile.clear()
	enemy_hand.clear()
	enemy_discard_pile.clear()
	if mode != Mode.TUTORIAL:
		return
	for card_id in BattleConfig.ENEMY_DECK_COMPOSITION:
		for _i in BattleConfig.ENEMY_DECK_COMPOSITION[card_id]:
			enemy_draw_pile.append(CardDB.get_card(card_id))
	enemy_draw_pile.shuffle()


# 从牌组摸 count 张：牌组空时把弃牌堆洗回；供给见底就停，返回实际摸到的张数
func _draw_from(source: Array[CardData], discard: Array[CardData], target: Array[CardData], count: int) -> int:
	var drawn := 0
	while drawn < count:
		if source.is_empty():
			if discard.is_empty():
				break
			for card in discard:
				source.append(card)
			discard.clear()
			source.shuffle()
		target.append(source.pop_back())
		drawn += 1
	return drawn


# 一轮结束：敌人回合 → 双方各摸三张 → 新的玩家回合
func _finish_round() -> void:
	log_event.emit("—— %s的回合 ——" % enemy_name)
	_enemy_turn()
	_gain_round_cards()
	_start_player_turn()


func _gain_round_cards() -> void:
	var player_drawn := _draw_from(draw_pile, discard_pile, hand, BattleConfig.ROUND_GAIN)
	log_event.emit(BattleConfig.TEXT_ROUND_GAIN_PLAYER % player_drawn)
	if mode == Mode.TUTORIAL:
		var enemy_drawn := _draw_from(enemy_draw_pile, enemy_discard_pile, enemy_hand, BattleConfig.ROUND_GAIN)
		log_event.emit(BattleConfig.TEXT_ROUND_GAIN_ENEMY % [enemy_name, enemy_drawn])


func _start_player_turn() -> void:
	player_block = 0
	player_cost = BattleConfig.PLAYER_MAX_COST
	batch_committed = false
	phase = Phase.PLAYER
	log_event.emit("—— 你的回合 ——")
	phase_changed.emit(phase)
	stats_changed.emit()


# 敌人从自己的手牌随机打出若干张；打出的牌就是它的攻击
func _enemy_turn() -> void:
	if mode == Mode.PRACTICE:
		log_event.emit(BattleConfig.TEXT_PRACTICE_IDLE)
		return
	if enemy_suppressed:
		enemy_suppressed = false
		log_event.emit(BattleConfig.TEXT_SUPPRESSED)
		return
	var plays := _decide_enemy_plays()
	if plays <= 0:
		log_event.emit(BattleConfig.TEXT_ENEMY_IDLE % enemy_name)
		return
	if plays >= 2:
		log_event.emit(BattleConfig.TEXT_ENEMY_DOMINANT)
	else:
		log_event.emit(BattleConfig.TEXT_ENEMY_RESISTING)
	# 整批一次结算：倒下时法阵拉回是整回合的结果，不在牌堆中间被再次打穿
	var total_damage := 0
	for _i in plays:
		var card: CardData = enemy_hand.pop_back()
		log_event.emit("%s打出「%s」。" % [enemy_name, card.display_name])
		total_damage += _enemy_card_damage(card)
		enemy_discard_pile.append(card)
	if total_damage > 0:
		_damage_player(total_damage)


func _decide_enemy_plays() -> int:
	if debug_force_plays >= 0:
		return min(debug_force_plays, enemy_hand.size())
	return randi_range(0, enemy_hand.size())


# 敌方牌的效果按「对玩家」解释，返回这张牌造成的伤害（现只有占位 1 伤）
func _enemy_card_damage(card: CardData) -> int:
	var total := 0
	for effect in card.effects:
		if String(effect.get("op", "")) == "deal_damage":
			total += int(effect.get("amount", 0))
	return total


func _apply_effect(effect: Dictionary, card_name: String) -> void:
	match String(effect.get("op", "")):
		"deal_damage":
			var damage: int = int(effect.get("amount", 0)) + attack_bonus
			enemy_hp = max(0, enemy_hp - damage)
			log_event.emit("%s受到 %d 点伤害。" % [enemy_name, damage])
		"gain_block":
			var amount: int = int(effect.get("amount", 0))
			player_block += amount
			log_event.emit("你摆出「%s」——能挡下 %d 点。" % [card_name, amount])
		"suppress_enemy_attack":
			enemy_suppressed = true
			if mode == Mode.PRACTICE:
				log_event.emit("你喊：「回来！」木桩纹丝不动——它本来就不动。")
			else:
				log_event.emit("你喊：「回来！」她愣住，抬起头。")
		"buff_attack_permanent":
			var bonus: int = int(effect.get("amount", 0))
			attack_bonus += bonus
			log_event.emit("此后你每次攻击 +%d。（当前加成 +%d）" % [bonus, attack_bonus])


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


func _end_practice() -> void:
	phase = Phase.ENDED
	log_event.emit(BattleConfig.TEXT_PRACTICE_END)
	phase_changed.emit(phase)
