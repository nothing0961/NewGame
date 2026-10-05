class_name BattleState
extends RefCounted

enum Phase { PLAYER, STRIP, DEBRIEF, DEFEAT, ENDED }
enum Mode { TUTORIAL, PRACTICE, STORY }

signal log_event(text: String)
signal stats_changed()
signal phase_changed(phase: int)
signal card_staged(card: CardData)
signal card_recalled(card: CardData)
signal card_played(card: CardData)
signal card_discarded(card: CardData)
signal card_merged(merged: CardData)

var mode: int = Mode.TUTORIAL
var enemy_name := BattleConfig.ENEMY_NAME
var enemy_max_hp := BattleConfig.ENEMY_MAX_HP
var enemy_deck_composition: Dictionary = {}
# 层主战：胜利后走净化/收下（教程战同为层主战）；层内小怪战：胜利直接结束
var is_boss := true
# 本场收下（吸收）的罪卡；教程＝暴怒，层主战由关卡配置给出
var sin_card_id := BattleConfig.SIN_CARD_ID
var strip_lines: Array = BattleConfig.TEXT_STRIP
var purify_lines: Array = BattleConfig.TEXT_PURIFY
var practice_end_text := BattleConfig.TEXT_PRACTICE_END

var player_hp := 0
var player_cost := 0
var player_block := 0
var enemy_hp := 0
var attack_bonus := 0
var turn_attack_bonus := 0  # 「弃掉：本回合伤害 +N」类效果，回合开始时清零
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

# 罪卡规则：任务+回合保底解锁、每场一次；turn_count 从 1 起
var turn_count := 0
var attack_plays_this_battle := 0
var sin_available := false
var sin_used_this_battle := false
# 本场牌组里的罪卡（最多一张，组卡约束保证）；空＝本场无罪卡
var deck_sin_id := ""

var _stage: Dictionary = {}


func start(custom_deck: Array = []) -> void:
	_stage = {}
	_setup(Mode.TUTORIAL, custom_deck)


func start_practice(custom_deck: Array = []) -> void:
	_stage = {}
	_setup(Mode.PRACTICE, custom_deck)


# 层内关卡战：stage 来自当前层路线（LayerConfig.generate_route 的池抽取节点）的所选节点（enemy / enemy_hp / enemy_deck / boss / sin_card / strip_lines / purify_lines）
func start_story(custom_deck: Array, stage: Dictionary) -> void:
	_stage = stage
	_setup(Mode.STORY, custom_deck)


func can_afford(card: CardData) -> bool:
	return card.cost <= player_cost


func can_stage(card: CardData) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if card.kind == CardData.Kind.AMPLIFY:
		return false  # 增幅牌不能打出/摆放，只能弃掉触发
	if card.kind == CardData.Kind.SIN and not _sin_available(card):
		return false
	if staged.size() >= BattleConfig.PLAY_ZONE_SIZE:
		return false
	return card.cost + staged_cost() <= player_cost


func staged_cost() -> int:
	var total := 0
	for card in staged:
		total += card.cost
	return total


func _sin_available(card: CardData) -> bool:
	if sin_used_this_battle:
		return false
	if deck_sin_id == "" or card.id != deck_sin_id:
		return false
	return sin_available


func sin_lock_reason() -> String:
	if deck_sin_id == "":
		return ""
	if sin_used_this_battle:
		return BattleConfig.TEXT_SIN_USED % CardDB.get_card(deck_sin_id).display_name
	var config := _sin_task_config()
	var task := ""
	if String(config.get("task", "")) == BattleConfig.SIN_TASK_ATTACK:
		var count: int = int(config.get("count", 0))
		task = BattleConfig.TEXT_SIN_TASK % count
		task += BattleConfig.TEXT_SIN_PROGRESS % [attack_plays_this_battle, count]
	return BattleConfig.TEXT_SIN_BLOCKED % [CardDB.get_card(deck_sin_id).display_name, task, "", BattleConfig.SIN_ROUND_FALLBACK]


# 任务达成或回合保底 → 解锁；每场战斗只需解锁一次
func _check_sin_unlock() -> void:
	if sin_available or deck_sin_id == "":
		return
	if turn_count < BattleConfig.SIN_ROUND_FALLBACK and not _sin_task_done():
		return
	sin_available = true
	log_event.emit(BattleConfig.TEXT_SIN_UNLOCKED % CardDB.get_card(deck_sin_id).display_name)


func _sin_task_config() -> Dictionary:
	return BattleConfig.SIN_TASK_CONFIG.get(deck_sin_id, {})


func _sin_task_done() -> bool:
	var config := _sin_task_config()
	if String(config.get("task", "")) == BattleConfig.SIN_TASK_ATTACK:
		return attack_plays_this_battle >= int(config.get("count", 0))
	return false


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


# 堆叠：手牌里同大类的牌可叠到出牌区已摆牌上（罪/敌方/增幅除外），合成牌占同一卡槽
func can_merge_with(card: CardData, staged_index: int) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if staged_index < 0 or staged_index >= staged.size():
		return false
	if card.kind == CardData.Kind.SIN or card.kind == CardData.Kind.ENEMY or card.kind == CardData.Kind.AMPLIFY:
		return false
	var target: CardData = staged[staged_index]
	if card.kind != target.kind:
		return false
	# 合并后出牌区总费用 = 现有 + 这张牌的费用 + 一次叠牌费
	return staged_cost() + card.cost + BattleConfig.STACK_FEE <= player_cost


func merge_into_staged(hand_index: int, staged_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: CardData = hand[hand_index]
	if not can_merge_with(card, staged_index):
		return false
	var target: CardData = staged[staged_index]
	var parts := _parts_of(target)
	parts.append(card)
	var merged := _make_merged(parts)
	hand.remove_at(hand_index)
	staged[staged_index] = merged
	log_event.emit("你把「%s」叠进「%s」（叠牌费 %d）——合成「%s」，费用 %d。" % [card.display_name, target.display_name, BattleConfig.STACK_FEE, merged.display_name, merged.cost])
	stats_changed.emit()
	card_merged.emit(merged)
	return true


func _parts_of(card: CardData) -> Array[CardData]:
	var result: Array[CardData] = []
	if card.is_merged():
		result.assign(card.parts)
	else:
		result.append(card)
	return result


# 合成牌：费用＝各原牌费用之和＋每多一张收一次叠牌费；效果与牌面文本按 op 聚合
func _make_merged(parts: Array[CardData]) -> CardData:
	var merged := CardData.new()
	merged.kind = parts[0].kind
	var total_cost := 0
	var name_parts := PackedStringArray()
	var id_parts := PackedStringArray()
	var order: Array[String] = []
	var sums := {}
	for part in parts:
		total_cost += part.cost
		name_parts.append(part.display_name)
		id_parts.append(part.id)
		for effect in part.effects:
			var op := String(effect.get("op", ""))
			if not sums.has(op):
				order.append(op)
				sums[op] = 0
			sums[op] += int(effect.get("amount", 0))
		for effect in part.discard_effects:
			merged.discard_effects.append(effect)
	total_cost += (parts.size() - 1) * BattleConfig.STACK_FEE
	merged.cost = total_cost
	merged.display_name = "＋".join(name_parts)
	merged.id = "+".join(id_parts)
	for part in parts:
		for effect in part.effects:
			merged.effects.append(effect)
	merged.text = _merged_text(order, sums)
	merged.parts = parts
	return merged


func _merged_text(order: Array[String], sums: Dictionary) -> String:
	var lines := PackedStringArray()
	for op in order:
		var amount: int = sums[op]
		match op:
			"deal_damage":
				lines.append("造成 %d 点伤害。" % amount)
			"gain_block":
				lines.append("挡下 %d 点伤害。" % amount)
			"suppress_enemy_attack":
				lines.append("她这一回合不出手。")
			"draw_cards":
				lines.append("抽 %d 张牌。" % amount)
			"buff_attack_permanent":
				lines.append("此后攻击 +%d。" % amount)
	return "\n".join(lines)


func recall_card(staged_index: int) -> bool:
	if phase != Phase.PLAYER or batch_committed:
		return false
	if staged_index < 0 or staged_index >= staged.size():
		return false
	var card: CardData = staged[staged_index]
	staged.remove_at(staged_index)
	if card.is_merged():
		# 收回合成牌＝拆回原样：原牌逐张回手，叠牌费不再收取
		for part in card.parts:
			hand.append(part)
		log_event.emit("你把「%s」拆开，收回了 %d 张牌。" % [card.display_name, card.parts.size()])
	else:
		hand.append(card)
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
		if card.is_merged():
			# 合成牌按原牌算任务进度；进弃牌堆时拆回原牌，避免合成体粘进牌堆
			for part in card.parts:
				if part.kind == CardData.Kind.ATTACK:
					attack_plays_this_battle += 1
		elif card.kind == CardData.Kind.ATTACK:
			attack_plays_this_battle += 1
		if card.flavor != "":
			log_event.emit(card.flavor)
		for effect in card.effects:
			_apply_effect(effect, card.display_name)
		if card.kind == CardData.Kind.SIN:
			sin_used_this_battle = true
			collection.append(card)
			log_event.emit("「%s」留在了你面前，这一场不会再回来。" % card.display_name)
		elif card.permanent:
			collection.append(card)
			log_event.emit("「%s」留在了你面前。" % card.display_name)
		elif card.is_merged():
			for part in card.parts:
				discard_pile.append(part)
		else:
			discard_pile.append(card)
	_check_sin_unlock()
	if enemy_hp <= 0:
		if mode == Mode.PRACTICE:
			_end_practice(true)
		elif mode == Mode.STORY and not is_boss:
			_end_story_stage()
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
# 弃牌区主动弃掉会触发 discard_effects（强制弃牌 discard_from_hand 不触发）
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
	if gain > 0:
		log_event.emit("你弃掉了「%s」，Cost +%d。（现在 Cost %d）" % [card.display_name, gain, player_cost])
	else:
		log_event.emit("你弃掉了「%s」。（现在 Cost %d）" % [card.display_name, player_cost])
	for effect in card.discard_effects:
		_apply_effect(effect, card.display_name, true)
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


# 收下：吸收本场罪卡（design/design-round3.md §6——收下入局内收藏，战斗结束即入仓库）
func absorb_sin() -> bool:
	if phase != Phase.STRIP or sin_card_id == "":
		return false
	var sin_card := CardDB.get_card(sin_card_id)
	collection.append(sin_card)
	sin_available = true
	log_event.emit("你拿起了「%s」。" % sin_card.display_name)
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
		enemy_deck_composition = {}
		is_boss = false
		sin_card_id = ""
		strip_lines = []
		purify_lines = []
	elif mode == Mode.STORY:
		enemy_name = String(_stage.get("enemy", ""))
		enemy_max_hp = int(_stage.get("enemy_hp", BattleConfig.ENEMY_MAX_HP))
		enemy_deck_composition = _stage.get("enemy_deck", {})
		is_boss = bool(_stage.get("boss", false))
		sin_card_id = String(_stage.get("sin_card", ""))
		strip_lines = _stage.get("strip_lines", [])
		purify_lines = _stage.get("purify_lines", [])
	else:
		enemy_name = BattleConfig.ENEMY_NAME
		enemy_max_hp = BattleConfig.ENEMY_MAX_HP
		enemy_deck_composition = BattleConfig.ENEMY_DECK_COMPOSITION
		is_boss = true  # 教程战＝懒惰层主战：打倒后走净化
		sin_card_id = BattleConfig.SIN_CARD_ID
		strip_lines = BattleConfig.TEXT_STRIP
		purify_lines = BattleConfig.TEXT_PURIFY
	player_hp = BattleConfig.PLAYER_MAX_HP
	player_cost = BattleConfig.PLAYER_MAX_COST
	player_block = 0
	enemy_hp = enemy_max_hp
	attack_bonus = 0
	enemy_suppressed = false
	phase = Phase.PLAYER
	batch_committed = false
	turn_count = 0
	attack_plays_this_battle = 0
	sin_available = false  # 解锁状态每场战斗重新检定
	sin_used_this_battle = false
	staged.clear()
	collection.clear()
	_build_deck(custom_deck)
	_build_enemy_deck()
	if mode == Mode.PRACTICE:
		log_event.emit(BattleConfig.TEXT_PRACTICE_START)
	# 开局：双方各摸五张
	_draw_from(draw_pile, discard_pile, hand, BattleConfig.HAND_SIZE)
	if mode != Mode.PRACTICE:
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
	deck_sin_id = ""
	for card in draw_pile:
		if card.kind == CardData.Kind.SIN:
			deck_sin_id = card.id
			break


func _build_enemy_deck() -> void:
	enemy_draw_pile.clear()
	enemy_hand.clear()
	enemy_discard_pile.clear()
	if enemy_deck_composition.is_empty():
		return
	for card_id in enemy_deck_composition:
		for _i in enemy_deck_composition[card_id]:
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
	if phase == Phase.DEFEAT or phase == Phase.ENDED:
		return  # 玩家倒下 / 练习结束：回合不再推进
	_gain_round_cards()
	_start_player_turn()


func _gain_round_cards() -> void:
	var player_drawn := _draw_from(draw_pile, discard_pile, hand, BattleConfig.ROUND_GAIN)
	log_event.emit(BattleConfig.TEXT_ROUND_GAIN_PLAYER % player_drawn)
	if mode != Mode.PRACTICE:
		var enemy_drawn := _draw_from(enemy_draw_pile, enemy_discard_pile, enemy_hand, BattleConfig.ROUND_GAIN)
		log_event.emit(BattleConfig.TEXT_ROUND_GAIN_ENEMY % [enemy_name, enemy_drawn])


func _start_player_turn() -> void:
	turn_count += 1
	player_block = 0
	player_cost = BattleConfig.PLAYER_MAX_COST
	turn_attack_bonus = 0
	batch_committed = false
	phase = Phase.PLAYER
	_check_sin_unlock()
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


func _apply_effect(effect: Dictionary, card_name: String, via_discard := false) -> void:
	match String(effect.get("op", "")):
		"deal_damage":
			var damage: int = int(effect.get("amount", 0)) + attack_bonus + turn_attack_bonus
			enemy_hp = max(0, enemy_hp - damage)
			log_event.emit("%s受到 %d 点伤害。" % [enemy_name, damage])
		"gain_block":
			var amount: int = int(effect.get("amount", 0))
			player_block += amount
			if via_discard:
				log_event.emit("「%s」被弃掉——格挡 +%d。（当前 %d）" % [card_name, amount, player_block])
			else:
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
		"buff_attack_turn":
			var turn_bonus: int = int(effect.get("amount", 0))
			turn_attack_bonus += turn_bonus
			log_event.emit("「%s」被弃掉——本回合你的伤害 +%d。（本回合加成 +%d）" % [card_name, turn_bonus, turn_attack_bonus])
		"gain_cost":
			var cost_gain: int = int(effect.get("amount", 0))
			player_cost += cost_gain
			log_event.emit("「%s」被弃掉——你获得 %d 点 Cost。（现在 Cost %d）" % [card_name, cost_gain, player_cost])
		"draw_cards":
			var draw_count: int = int(effect.get("amount", 0))
			var drawn: int = _draw_from(draw_pile, discard_pile, hand, draw_count)
			log_event.emit("你抽了 %d 张牌。" % drawn)


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
		_handle_defeat()


# 死亡规则（design/design-round3.md §5）：教程战与层战判负（法阵拽回退役）；
# 练习战不判负——失败即练习结束
func _handle_defeat() -> void:
	if mode == Mode.PRACTICE:
		_end_practice(false)
		return
	phase = Phase.DEFEAT
	log_event.emit(BattleConfig.TEXT_DEFEAT)
	phase_changed.emit(phase)


func _enter_strip() -> void:
	phase = Phase.STRIP
	phase_changed.emit(phase)


func _end_practice(won: bool) -> void:
	phase = Phase.ENDED
	practice_end_text = BattleConfig.TEXT_PRACTICE_END if won else BattleConfig.TEXT_PRACTICE_DEFEAT
	log_event.emit(practice_end_text)
	phase_changed.emit(phase)


func _end_story_stage() -> void:
	phase = Phase.ENDED
	log_event.emit(BattleConfig.TEXT_STAGE_WIN)
	phase_changed.emit(phase)
