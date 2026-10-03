extends SceneTree

var failures := 0
var _mouse_last_point := Vector2.ZERO


func _initialize() -> void:
	print("== 教程战逻辑测试 ==")
	test_cards_load()
	test_wrath_effects()
	test_guard_blocks_enemy_plays()
	test_call_suppresses()
	test_card_costs()
	test_cost_pool()
	test_revive_flow()
	test_staging_zone()
	test_commit_batch()
	test_end_turn_settles_staged()
	test_commit_ends_turn()
	test_hand_limit()
	test_discard_for_cost()
	test_round_gain_economy()
	test_enemy_plays_cards()
	test_round_gain_hand_limit()
	test_full_victory_flow()
	test_custom_deck_battle()
	test_card_pool()
	test_practice_battle()
	# 等一帧让 SceneTree 进入运行态，节点加入 root 时 _ready 才会立即执行
	await process_frame
	await test_battle_scene_tutorial()
	await test_battle_scene_practice()
	await test_scene_turn_timer()
	await test_scene_drag_and_discard()
	await test_engine_drag_input()
	await test_scene_hover_scale()
	await test_scene_fan_hand_geometry()
	await test_scene_pile_counts()
	await test_scene_forced_discard()
	await test_sfx_wiring()
	await test_main_flow_full()
	await test_main_flow_skip_practice()
	if failures == 0:
		print("== 全部通过 ==")
		quit(0)
	else:
		printerr("== %d 项失败 ==" % failures)
		quit(1)


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ok - " + message)
	else:
		failures += 1
		printerr("  FAIL - " + message)


func _make_state(logs: Array = []) -> BattleState:
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start()
	return state


func _find_card(cards: Array[CardData], card_id: String) -> int:
	for i in cards.size():
		if cards[i].id == card_id:
			return i
	return -1


# 把手里所有匹配的牌摆进出牌区（摆不下的跳过）
func _stage_all(state: BattleState, card_id: String) -> void:
	var index := 0
	while index < state.hand.size():
		if state.hand[index].id == card_id and state.can_stage(state.hand[index]):
			state.stage_card(index)
		else:
			index += 1


func _turn_cycle(state: BattleState, card_ids: Array) -> void:
	for card_id in card_ids:
		_stage_all(state, String(card_id))
	if not state.staged.is_empty():
		# 打出即结束回合：commit 内部会跑敌人回合并进入新玩家回合
		state.commit_staged()
	else:
		state.end_turn()


func _fight_until_over(state: BattleState) -> void:
	var turns := 0
	while state.phase == BattleState.Phase.PLAYER and turns < 10:
		turns += 1
		_turn_cycle(state, ["strike", "guard", "call"])


func _log_contains(logs: Array, fragment: String) -> bool:
	for line in logs:
		if String(line).contains(fragment):
			return true
	return false


func _count_log(logs: Array, fragment: String) -> int:
	var count := 0
	for line in logs:
		if String(line).contains(fragment):
			count += 1
	return count


func _first_live_button(container: Node, prefix: String) -> Button:
	for child in container.get_children():
		if child is Button and not child.is_queued_for_deletion() and (child as Button).text.begins_with(prefix):
			return child
	return null


# 走拖拽路径：取牌面的拖拽数据 → 把目标区域中心换算成本场景局部坐标 → 投放
func _drag_card_to(scene: Variant, card_button: CardButton, target: Control) -> bool:
	var drag_data: Variant = card_button._get_drag_data(Vector2.ZERO)
	if drag_data == null:
		return false
	var local_point: Vector2 = scene.get_global_transform().affine_inverse() * target.get_global_rect().get_center()
	if not scene._can_drop_data(local_point, drag_data):
		return false
	scene._drop_data(local_point, drag_data)
	return true


func _count_live_card_buttons(container: Node) -> int:
	var count := 0
	for child in container.get_children():
		if child is CardButton and not child.is_queued_for_deletion():
			count += 1
	return count


func _live_hand_cards(hand_box: Control) -> Array:
	var result: Array = []
	for child in hand_box.get_children():
		if child is CardButton and not child.is_queued_for_deletion():
			result.append(child)
	return result


# headless 下根窗口只有 64×64，全屏锚点布局会失真；放进固定 1280×720 的 SubViewport
func _attach_scene(scene: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	viewport.add_child(scene)
	return viewport


func _push_mouse_button(target: Viewport, at_point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at_point
	event.global_position = at_point
	_mouse_last_point = at_point
	target.push_input(event)


# relative 必须设置：引擎的拖拽判定累计 mm->get_relative()，超过阈值才会进入拖拽
func _push_mouse_motion(target: Viewport, at_point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at_point
	event.global_position = at_point
	event.relative = at_point - _mouse_last_point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_mouse_last_point = at_point
	target.push_input(event)


# 像玩家一样：拖手牌里的打击进出牌区，摆完按「打出」，打不出就结束回合，直到战斗不再是玩家回合
func _press_strikes_until_over(scene: Variant) -> void:
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var commit_button := scene.get_node("%CommitButton") as Button
	var end_turn_button := scene.get_node("%EndTurnButton") as Button
	var safety := 0
	while scene.state.phase == BattleState.Phase.PLAYER and safety < 120:
		safety += 1
		var dragged_strike := false
		for child in hand_box.get_children():
			var card_button := child as CardButton
			if card_button != null and card_button.visible and not card_button.is_queued_for_deletion() and card_button.card != null and card_button.card.id == "strike" and scene.state.can_stage(card_button.card):
				dragged_strike = _drag_card_to(scene, card_button, play_box)
				break
		if dragged_strike:
			continue
		if not scene.state.staged.is_empty():
			if not commit_button.disabled:
				commit_button.pressed.emit()
			continue
		end_turn_button.pressed.emit()


func test_cards_load() -> void:
	print("[卡牌数据]")
	for card_id in ["strike", "guard", "call", "wrath", "enemy_strike"]:
		var card := CardDB.get_card(card_id)
		check(card != null, "载入 " + card_id)
		if card != null:
			check(card.id == card_id, card_id + " id 一致")
			check(not card.effects.is_empty(), card_id + " 有效果")
	var wrath := CardDB.get_card("wrath")
	check(wrath.permanent, "暴怒是永久牌")
	check(wrath.kind == CardData.Kind.SIN, "暴怒是罪牌")


func test_wrath_effects() -> void:
	print("[罪牌：3 伤 + 攻击永久 +1]")
	var state := _make_state()
	state.debug_force_plays = 0
	state.gain_card(CardDB.get_card("wrath"))
	check(state.stage_card(_find_card(state.hand, "wrath")), "暴怒可以摆进出牌区")
	check(state.staged_cost() == 6, "出牌区合计 Cost 6")
	check(state.commit_staged(), "打出整批")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 3, "暴怒直接造成 3 伤")
	check(state.attack_bonus == 1, "攻击加成 +1")
	check(state.collection.has(CardDB.get_card("wrath")), "罪牌留在面前而不是进弃牌堆")
	check(state.phase == BattleState.Phase.PLAYER, "打出后已是新回合")
	check(state.stage_card(_find_card(state.hand, "strike")), "新回合摆一张打击")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 6, "打击吃到加成(3 伤)")


func test_guard_blocks_enemy_plays() -> void:
	print("[护住 vs 对方出牌：同批结算后紧接着的对方回合被挡下]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 2
	# 开局手牌从 8 张牌组随机摸 5，钉死手牌保证有护住
	state.hand.clear()
	state.hand.append(CardDB.get_card("guard"))
	state.stage_card(0)
	state.commit_staged()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "对方两张占位牌共 2 点伤害被同批打出的护住完整挡下")
	check(state.player_block == 0, "格挡正好用掉；新回合格挡清零")
	check(state.revives == 0, "没有倒下")
	check(_log_contains(logs, "挡"), "日志记录了挡下")
	check(state.phase == BattleState.Phase.PLAYER, "回到新回合")


func test_call_suppresses() -> void:
	print("[呼喊：同批结算后紧接着的对方回合不打人]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 2
	# 开局手牌从 8 张牌组随机摸 5，钉死手牌保证有呼喊
	state.hand.clear()
	state.hand.append(CardDB.get_card("call"))
	state.stage_card(0)
	state.commit_staged()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "换来的这一回合没有挨打")
	check(not state.enemy_suppressed, "压制在本次对方回合用掉")
	check(_log_contains(logs, "……对不起"), "她说了题眼那句")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP, "呼喊不伤她")


func test_card_costs() -> void:
	print("[卡牌 Cost]")
	check(CardDB.get_card("strike").cost == 1, "打击 Cost 1")
	check(CardDB.get_card("guard").cost == 1, "护住 Cost 1")
	check(CardDB.get_card("call").cost == 1, "呼喊 Cost 1")
	check(CardDB.get_card("wrath").cost == 6, "暴怒（罪牌）Cost 6")


func test_cost_pool() -> void:
	print("[Cost 池：摆放不扣、打出结算、每回合重置]")
	var state := _make_state()
	state.debug_force_plays = 0
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "开局满 Cost（12/12）")
	check(state.stage_card(_find_card(state.hand, "strike")), "打击可以摆进出牌区")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "摆放不扣 Cost（12/12）")
	check(state.staged_cost() == 1, "出牌区合计 Cost 1")
	check(state.recall_card(0), "可以收回")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "收回不补也不扣")
	state.player_cost = 5
	state.hand.append(CardDB.get_card("wrath"))
	var wrath_index := _find_card(state.hand, "wrath")
	check(not state.can_stage(state.hand[wrath_index]), "Cost 不够摆不进暴怒（需 6 剩 5）")
	check(not state.stage_card(wrath_index), "摆放被拒")
	check(state.player_cost == 5, "被拒时不扣 Cost")
	check(state.can_afford(CardDB.get_card("strike")), "打击还打得动")
	check(not state.can_afford(CardDB.get_card("wrath")), "暴怒打不动")
	state.player_cost = 10
	check(state.stage_card(_find_card(state.hand, "strike")), "重新摆一张打击")
	check(state.staged_cost() == 1, "合计 Cost 1")
	check(state.player_cost == 10, "结算前不扣")
	check(state.commit_staged(), "打出结算这批")
	check(state.staged.is_empty(), "打出后出牌区清空")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "打出即结束回合，新回合 Cost 重置满")


func test_revive_flow() -> void:
	print("[倒下：法阵拉回]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 5
	var guard := 0
	while state.revives == 0 and guard < 10:
		guard += 1
		state.end_turn()
	check(state.revives == 1, "吃满 10 伤后倒下一次")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "回满血")
	check(_log_contains(logs, "法阵亮了一下"), "法阵读白出现")


func test_staging_zone() -> void:
	print("[出牌区：最多五张，越限或越额都摆不进]")
	var state := _make_state()
	var guard := 0
	while not state.hand.is_empty() and guard < 10:
		guard += 1
		state.stage_card(0)
	check(state.staged.size() == 5, "开局五张全部摆进")
	check(state.hand.is_empty(), "手牌清空")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "摆放全程不扣 Cost")
	state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == 1, "获得一张新牌")
	check(not state.can_stage(state.hand[0]), "出牌区满后不能继续摆")
	check(not state.stage_card(0), "摆放被拒")
	check(state.recall_card(2), "收回出牌区第 3 张")
	check(state.staged.size() == 4, "收回后剩 4 张")
	check(state.hand.size() == 2, "收回的牌回到手牌")
	check(state.can_stage(state.hand[0]), "空出卡槽后可以再摆")
	check(state.stage_card(0), "重新摆进一张")
	check(state.staged.size() == 5, "重回 5 张")
	check(not state.recall_card(9), "越界收回被拒")
	var state2 := BattleState.new()
	state2.start(["strike", "strike", "strike", "strike", "strike"])
	state2.player_cost = 3
	check(state2.stage_card(0) and state2.stage_card(0) and state2.stage_card(0), "三张打击摆进（合计 Cost 3）")
	check(state2.staged_cost() == 3, "合计 Cost 3")
	check(not state2.can_stage(state2.hand[0]), "合计到上限后第 4 张摆不进")
	check(not state2.stage_card(0), "摆放被拒")


func test_commit_batch() -> void:
	print("[打出即结束回合：结算整批后自动轮到敌人，再进新回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 1
	check(not state.commit_staged(), "空出牌区打不出")
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "strike"))
	check(state.commit_staged(), "两张打击一起打出")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "两张打击各 2 伤（整批一次结算）")
	check(_count_log(logs, "你打出「打击」。") == 2, "日志逐张记录")
	# 新回合补牌会把弃牌堆洗回抽牌堆，所以在整局范围内核对五张打击的去向
	var strike_stock := 0
	for card in state.hand:
		if card.id == "strike":
			strike_stock += 1
	for card in state.draw_pile:
		if card.id == "strike":
			strike_stock += 1
	for card in state.discard_pile:
		if card.id == "strike":
			strike_stock += 1
	check(strike_stock == 5, "五张打击都在牌堆里循环")
	check(state.collection.is_empty(), "非永久牌不进收藏")
	check(_count_log(logs, "—— 小默的回合 ——") == 1, "打出后自动进入对方回合")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 1, "对方出了 1 张占位牌，打了 1 点")
	check(state.phase == BattleState.Phase.PLAYER, "回到新的玩家回合")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "新回合 Cost 重置满")
	check(state.can_stage(state.hand[0]), "新回合可以再摆")
	check(not state.commit_staged(), "新回合还没摆放，打不出")


func test_end_turn_settles_staged() -> void:
	print("[结束回合自动结算摆放的牌（手动与超时同一条路径）]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.stage_card(_find_card(state.hand, "strike"))
	check(_count_log(logs, "—— 小默的回合 ——") == 0, "还没过回合")
	state.end_turn()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 2, "结束时先结算摆好的打击")
	check(state.staged.is_empty(), "出牌区清空")
	check(_count_log(logs, "—— 小默的回合 ——") == 1, "对方回合来过一次")
	check(state.phase == BattleState.Phase.PLAYER, "进入新回合")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "新回合 Cost 重置")
	check(state.can_stage(state.hand[0]), "新回合可以再摆")


func test_commit_ends_turn() -> void:
	print("[手牌打空：这批打出后照样直接过回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	var guard := 0
	while not state.hand.is_empty() and guard < 10:
		guard += 1
		state.stage_card(0)
	check(state.commit_staged(), "五张一起打出")
	check(_count_log(logs, "—— 小默的回合 ——") == 1, "打出后自动过了一次对方回合")
	check(state.phase == BattleState.Phase.PLAYER, "回到玩家回合")
	check(state.hand.size() == BattleConfig.ROUND_GAIN, "打空后过一轮，手里只剩新摸的三张")


func test_hand_limit() -> void:
	print("[手牌上限 8：计数与弃牌]")
	var state := _make_state()
	for _i in 3:
		state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == BattleConfig.HAND_LIMIT, "手牌到上限 8")
	check(not state.needs_discard(), "到上限还不需弃牌")
	state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == 9, "第 9 张超出上限")
	check(state.needs_discard(), "超过上限需要弃牌")
	check(not state.discard_from_hand(99), "越界弃牌被拒")
	check(state.discard_from_hand(0), "弃掉一张")
	check(state.hand.size() == BattleConfig.HAND_LIMIT, "回到 8 张")
	check(not state.needs_discard(), "不再需要弃牌")
	check(state.discard_pile.size() == 1, "弃掉的牌进弃牌堆")


func test_discard_for_cost() -> void:
	print("[主动弃牌换 Cost：n-1、可超上限、只限本回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	check(state.discard_for_cost(0) == 0, "弃一张 1 费牌 +0")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "1 费牌不涨 Cost（12/12）")
	state.gain_card(CardDB.get_card("wrath"))
	var wrath_index := _find_card(state.hand, "wrath")
	check(wrath_index >= 0, "暴怒在手")
	check(state.discard_for_cost(wrath_index) == 5, "弃 6 费暴怒 +5")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST + 5, "Cost 可超上限（17/12）")
	check(_log_contains(logs, "Cost +5"), "日志记录了获得点数")
	check(_find_card(state.discard_pile, "wrath") >= 0, "弃掉的暴怒进弃牌堆")
	check(state.discard_for_cost(99) == -1, "越界弃牌被拒")
	check(state.discard_for_cost(-1) == -1, "负数下标被拒")
	check(state.stage_card(_find_card(state.hand, "strike")), "摆一张打击")
	check(state.commit_staged(), "打出结算")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "打出即过回合，新回合重置回 12/12，超出作废")
	check(state.discard_for_cost(0) >= 0, "新回合仍可主动弃牌换 Cost")
	var state2 := BattleState.new()
	state2.start()
	state2.phase = BattleState.Phase.STRIP
	check(state2.discard_for_cost(0) == -1, "非玩家回合不能弃牌换 Cost")


func test_round_gain_economy() -> void:
	print("[一轮结束：双方各获得三张，没打完的保留]")
	# 用户示例（设定文档）：手 5 张，打 3 张 → 剩 2＋3＝第二轮 5 张；敌人打 2 → 剩 3＋3＝6 张
	var state := _make_state()
	state.debug_force_plays = 2
	check(state.hand.size() == BattleConfig.HAND_SIZE, "开局玩家 5 张")
	check(state.enemy_hand.size() == BattleConfig.HAND_SIZE, "开局敌人 5 张")
	state.hand.clear()
	state.draw_pile.clear()
	state.discard_pile.clear()
	for _i in 5:
		state.hand.append(CardDB.get_card("strike"))
	for _i in 3:
		state.draw_pile.append(CardDB.get_card("guard"))
	for _i in 3:
		state.stage_card(_find_card(state.hand, "strike"))
	check(state.staged.size() == 3, "玩家第一轮打出 3 张打击")
	state.commit_staged()
	check(state.hand.size() == 5, "玩家：剩 2 张＋摸 3 张＝第二轮 5 张")
	check(state.enemy_hand.size() == 6, "敌人：出 2 张剩 3 张＋摸 3 张＝第二轮 6 张")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 2, "敌人出的两张各打 1 点")
	# 用户实测复现：牌组共 8 张，打 1 张 → 剩 4＋备用 3＝第二轮 7 张（牌组只有 5 张时供给不足会卡在 5 张）
	var state2 := _make_state()
	state2.debug_force_plays = 2
	state2.hand.clear()
	state2.draw_pile.clear()
	state2.discard_pile.clear()
	state2.hand.append(CardDB.get_card("strike"))
	for _i in 3:
		state2.hand.append(CardDB.get_card("guard"))
	state2.hand.append(CardDB.get_card("call"))
	for _i in 3:
		state2.draw_pile.append(CardDB.get_card("strike"))
	check(state2.stage_card(_find_card(state2.hand, "strike")), "玩家第一轮打出 1 张打击")
	state2.commit_staged()
	check(state2.hand.size() == 7, "玩家：剩 4 张＋摸 3 张＝第二轮 7 张")


func test_enemy_plays_cards() -> void:
	print("[敌人真出牌：张数随机；每张 1 伤；打出的牌进敌方弃牌堆]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.end_turn()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "强制 0 张：这回合没挨打")
	check(_log_contains(logs, "没有出牌"), "日志写着没出牌")
	state.debug_force_plays = 3
	state.end_turn()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 3, "出 3 张，每张 1 伤")
	check(_log_contains(logs, BattleConfig.TEXT_ENEMY_DOMINANT), "多张时「它」占上风的它-她对读")
	var deck_size: int = int(BattleConfig.ENEMY_DECK_COMPOSITION["enemy_strike"])
	var stock: int = state.enemy_hand.size() + state.enemy_draw_pile.size() + state.enemy_discard_pile.size()
	check(stock == deck_size, "敌方八张占位牌一直在手牌/牌堆/弃牌堆间循环")
	# 敌方牌堆全部见底：这轮只摸得回刚打出的那一张
	state.enemy_hand.clear()
	state.enemy_draw_pile.clear()
	state.enemy_discard_pile.clear()
	state.enemy_hand.append(CardDB.get_card("enemy_strike"))
	state.debug_force_plays = 1
	state.end_turn()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 4, "再出 1 张（累计 4 点）")
	check(_log_contains(logs, BattleConfig.TEXT_ENEMY_RESISTING), "单张时「她」还在挣的它-她对读")
	check(state.enemy_hand.size() == 1, "供给见底时能摸几张是几张（只摸回 1 张）")
	check(state.enemy_discard_pile.is_empty(), "打出的牌被洗回并摸走")
	check(_log_contains(logs, BattleConfig.TEXT_ROUND_GAIN_ENEMY % ["小默", 1]), "摸牌日志写着只获得 1 张")


func test_round_gain_hand_limit() -> void:
	print("[每轮 +3 顶破手牌上限：超限触发强制弃牌]")
	var state := BattleState.new()
	var big_deck: Array = []
	for _i in 14:
		big_deck.append("strike")
	state.start(big_deck)
	state.debug_force_plays = 0
	check(state.hand.size() == BattleConfig.HAND_SIZE, "14 张牌堆开局手牌 5 张")
	var guard := 0
	while not state.needs_discard() and guard < 10:
		guard += 1
		state.end_turn()
	check(state.hand.size() > BattleConfig.HAND_LIMIT, "连过几轮后手牌超过 8")
	check(state.needs_discard(), "超限需要强制弃牌")


func test_full_victory_flow() -> void:
	print("[完整流程：打赢 → 剥离 → 收下 → 三问 → 结束]")
	var state := _make_state()
	state.debug_force_plays = 0
	_fight_until_over(state)
	check(state.phase == BattleState.Phase.STRIP, "打倒后进入剥离时刻")
	check(state.enemy_hp == 0, "她归零了")
	check(state.collection.is_empty(), "剥离前收藏为空")
	check(state.absorb_wrath(), "拿起暴怒")
	check(state.collection.size() == 1 and state.collection[0].id == "wrath", "暴怒进收藏")
	check(_find_card(state.discard_pile, "wrath") == -1, "暴怒不在弃牌堆")
	check(_find_card(state.draw_pile, "wrath") == -1, "暴怒不在抽牌堆")
	check(state.phase == BattleState.Phase.DEBRIEF, "进入三问")
	check(state.finish_debrief(), "结束三问")
	check(state.phase == BattleState.Phase.ENDED, "流程结束")
	check(not state.stage_card(0), "结束后不能再摆牌")
	check(not state.commit_staged(), "结束后不能结算")


func test_custom_deck_battle() -> void:
	print("[自组卡组开局]")
	var state := BattleState.new()
	state.start(["strike", "strike", "strike", "guard", "guard", "guard", "call", "call"])
	check(state.hand.size() + state.draw_pile.size() == BattleConfig.DECK_SIZE, "牌堆里正好 8 张")
	var ids: Array = []
	for card in state.hand:
		ids.append(card.id)
	for card in state.draw_pile:
		ids.append(card.id)
	ids.sort()
	check(ids == ["call", "call", "guard", "guard", "guard", "strike", "strike", "strike"], "卡组构成正确")
	check(state.enemy_name == "小默" and state.enemy_max_hp == BattleConfig.ENEMY_MAX_HP, "教程模式对手是小默")


func test_card_pool() -> void:
	print("[仓库与卡组模型]")
	var pool := CardPool.new()
	check(pool.owned_count("strike") == int(BattleConfig.WAREHOUSE_INITIAL["strike"]), "仓库初始打击数量")
	check(pool.owned_count("wrath") == 0, "仓库初始没有罪卡")
	check(not pool.is_deck_valid(), "空卡组不合法")
	for _i in 5:
		pool.add_to_deck("strike")
	for _i in 3:
		pool.add_to_deck("guard")
	check(pool.deck.size() == BattleConfig.DECK_SIZE, "卡组满 8 张")
	check(not pool.add_to_deck("guard"), "卡组已满不能再加")
	check(pool.is_deck_valid(), "5 打击＋3 护住的卡组合法")
	check(pool.remove_from_deck("strike"), "可以移出一张")
	check(pool.deck.size() == BattleConfig.DECK_SIZE - 1, "移出后剩 7 张")
	var pool2 := CardPool.new()
	check(pool2.owned_count("strike") == 5 and pool2.owned_count("guard") == 3 and pool2.owned_count("call") == 2, "仓库共 10 张：打击 5、护住 3、呼喊 2")
	for _i in 3:
		pool2.add_to_deck("guard")
	for _i in 2:
		pool2.add_to_deck("call")
	check(pool2.deck.size() == 5, "全用防御牌只能凑 5 张")
	check(not pool2.is_deck_valid(), "凑不满 8 张不合法")
	pool2.add_to_deck("strike")
	check(not pool2.is_deck_valid(), "有伤害牌但还没满 8 张仍不合法")
	var pool3 := CardPool.new()
	for _i in 8:
		pool3.deck.append("guard")
	check(not pool3.is_deck_valid(), "满 8 张但全无伤害牌不合法")
	check(not pool2.add_to_deck("guard"), "超过仓库数量不能加（护住只有 3 张）")


func test_practice_battle() -> void:
	print("[练习战：木桩不还手，打赢直接结束]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start_practice(["strike", "strike", "strike", "strike", "strike"])
	check(state.enemy_name == "木桩", "对手是木桩")
	check(state.enemy_max_hp == BattleConfig.PRACTICE_ENEMY_HP, "木桩血量按配置")
	check(state.enemy_hp == BattleConfig.PRACTICE_ENEMY_HP, "木桩满血开局")
	var hp_before: int = state.player_hp
	state.end_turn()
	check(state.player_hp == hp_before, "木桩一回合都没还手")
	check(_log_contains(logs, BattleConfig.TEXT_PRACTICE_IDLE), "日志写着木桩不动")
	var safety := 0
	while state.phase == BattleState.Phase.PLAYER and safety < 40:
		safety += 1
		_stage_all(state, "strike")
		if not state.staged.is_empty():
			state.commit_staged()
		if state.phase == BattleState.Phase.PLAYER:
			state.end_turn()
	check(state.phase == BattleState.Phase.ENDED, "打空血量后直接结束（不过剥离）")
	check(_log_contains(logs, BattleConfig.TEXT_PRACTICE_END), "结束读白出现")
	check(state.collection.is_empty(), "练习没有罪卡")
	check(not state.absorb_wrath(), "练习结束后也没有拿起环节")


func test_battle_scene_tutorial() -> void:
	print("[战斗场景·教程模式：拖拽摆放 → 收回 → 打出 → 完整一局]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	check(packed != null, "battle.tscn 可加载")
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var commit_button := scene.get_node("%CommitButton") as Button
	var end_turn_button := scene.get_node("%EndTurnButton") as Button
	var timer_label := scene.get_node("%TurnTimerLabel") as Label
	var overlay := scene.get_node("%Overlay") as Control
	var story := scene.get_node("%StoryText") as Label
	check((scene.get_node("%EnemyNameLabel") as Label).text == "小默", "敌人名显示小默")
	var enemy_hand_label := scene.get_node("%EnemyHandLabel") as Label
	check(enemy_hand_label.visible and enemy_hand_label.text == "手牌 5 张", "敌人手牌张数显示 5 张")
	check(not overlay.visible, "开局不弹覆盖层（召唤告知已上移到主流程）")
	check(not (scene.get_node("%QuitPracticeButton") as Button).visible, "教程模式不显示结束练习")
	check(hand_box.get_child_count() == 5, "开局手牌 5 张")
	check(play_box.get_child_count() == BattleConfig.PLAY_ZONE_SIZE, "出牌区有 5 个卡槽")
	check(commit_button.disabled and commit_button.text == "打出", "空出牌区时「打出」置灰")
	check(timer_label.text == "剩余 45 秒", "开局计时 45 秒")
	var cost_label := scene.get_node("%CostLabel") as Label
	check(cost_label.text == "Cost 12 / 12", "开局 Cost 显示 12/12")
	var first_strike := _first_live_button(hand_box, "打击")
	check(first_strike != null, "手里有打击")
	check(first_strike.drag_zone == "hand", "手牌处于可拖状态")
	check(_drag_card_to(scene, first_strike, play_box), "拖手牌到出牌区")
	check(scene.state.staged.size() == 1, "拖拽摆进出牌区")
	check(cost_label.text == "Cost 12 / 12", "摆放不扣 Cost")
	check(commit_button.text == "打出（Cost -1）", "打出按钮预告合计 Cost")
	var staged_button := _first_live_button(play_box, "打击")
	check(staged_button != null, "出牌区出现已摆的牌")
	staged_button.pressed.emit()
	check(scene.state.staged.is_empty(), "点击已摆的牌收回")
	check(cost_label.text == "Cost 12 / 12", "收回不扣 Cost")
	var strike_again := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, strike_again, play_box), "重新拖进")
	check(scene.state.staged.size() == 1, "重新摆进出牌区")
	scene.state.player_cost = 0
	scene.state.stats_changed.emit()
	var all_grayed := true
	for child in hand_box.get_children():
		var card_button := child as CardButton
		if card_button != null and not card_button.is_queued_for_deletion() and card_button.visible and card_button.modulate.r >= 1.0:
			all_grayed = false
	check(all_grayed, "Cost 不够时手牌全部置灰（仍可拖去弃牌）")
	scene.state.player_cost = BattleConfig.PLAYER_MAX_COST
	scene.state.stats_changed.emit()
	check(not commit_button.disabled, "Cost 恢复后可以打出")
	scene.state.debug_force_plays = 1
	commit_button.pressed.emit()
	check(scene.state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 2, "打击照常生效")
	check(scene.state.staged.is_empty(), "打出后出牌区清空")
	check(cost_label.text == "Cost 12 / 12", "打出即结束回合，新回合 Cost 重置满")
	check(timer_label.text == "剩余 45 秒", "新回合计时重置")
	check(scene.state.player_hp == BattleConfig.PLAYER_MAX_HP - 1, "打出后对方出了 1 张，打了 1 点")
	check(enemy_hand_label.text == "手牌 7 张", "敌人出 1 张再摸 3 张，手牌显示 7 张")
	check(commit_button.disabled and commit_button.text == "打出", "新回合打出按钮回到初始态")
	check(not end_turn_button.disabled, "新回合结束回合按钮可用")
	var strike_next := _first_live_button(hand_box, "打击")
	check(strike_next != null and strike_next.modulate.r >= 1.0, "新回合手牌恢复可用")
	var ended_calls: Array = []
	scene.battle_ended.connect(func(practice: bool) -> void: ended_calls.append(practice))
	scene.state.debug_force_plays = 0
	_press_strikes_until_over(scene)
	check(scene.state.phase == BattleState.Phase.STRIP, "拖拽流程进入剥离时刻")
	check(overlay.visible, "剥离覆盖层出现")
	var strip_hand_locked := true
	for child in hand_box.get_children():
		var card_button := child as CardButton
		if card_button != null and not card_button.is_queued_for_deletion() and not card_button.disabled:
			strip_hand_locked = false
	check(strip_hand_locked, "剥离时刻手牌全部禁用（不可拖拽）")
	check(story.text.contains("滚烫的白火"), "剥离读白在屏上")
	var absorb_button := scene.get_node("%AbsorbButton") as Button
	check(absorb_button.visible, "拿起按钮出现")
	absorb_button.pressed.emit()
	check(scene.state.phase == BattleState.Phase.DEBRIEF, "收下罪卡进入净化")
	check(story.text.contains("剥下来的罪"), "净化读白在屏上")
	var continue_button := scene.get_node("%ContinueButton") as Button
	continue_button.pressed.emit()
	check(story.text.contains("归零"), "第一问出现")
	continue_button.pressed.emit()
	continue_button.pressed.emit()
	continue_button.pressed.emit()
	check(scene.state.phase == BattleState.Phase.ENDED, "三问走完，流程结束")
	check(not overlay.visible, "覆盖层收起")
	check(ended_calls == [false], "教程结束发回 battle_ended(false)")
	viewport.queue_free()
	await process_frame


func test_battle_scene_practice() -> void:
	print("[战斗场景·练习模式：木桩]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	scene.configure(BattleState.Mode.PRACTICE, ["strike", "strike", "strike", "strike", "strike"])
	var viewport := _attach_scene(scene)
	await process_frame
	check(not (scene.get_node("%EnemyHandLabel") as Label).visible, "练习模式不显示敌人手牌")
	var overlay := scene.get_node("%Overlay") as Control
	var story := scene.get_node("%StoryText") as Label
	var quit_button := scene.get_node("%QuitPracticeButton") as Button
	var ended_calls: Array = []
	scene.battle_ended.connect(func(practice: bool) -> void: ended_calls.append(practice))
	check(quit_button.visible, "练习模式显示结束练习按钮")
	check((scene.get_node("%EnemyNameLabel") as Label).text == "木桩", "对手显示木桩")
	check((scene.get_node("%EnemyHpLabel") as Label).text == "生命 %d / %d" % [BattleConfig.PRACTICE_ENEMY_HP, BattleConfig.PRACTICE_ENEMY_HP], "血量按木桩显示")
	check((scene.get_node("%CostLabel") as Label).text == "Cost 12 / 12", "练习模式也是同一套 Cost")
	var hp_before: int = scene.state.player_hp
	scene.state.end_turn()
	check(scene.state.player_hp == hp_before, "木桩不还手")
	_press_strikes_until_over(scene)
	check(scene.state.phase == BattleState.Phase.ENDED, "打空木桩血量后结束")
	check(overlay.visible, "练习结束覆盖层出现")
	check(story.text.contains("木桩倒下"), "结束读白在屏上")
	check(not (scene.get_node("%AbsorbButton") as Button).visible, "练习没有拿起按钮")
	var continue_button := scene.get_node("%ContinueButton") as Button
	check(continue_button.text == "返回练习站", "结束按钮文案")
	continue_button.pressed.emit()
	check(ended_calls == [true], "练习结束发回 battle_ended(true)")
	viewport.queue_free()
	await process_frame
	var scene2: Variant = packed.instantiate()
	scene2.configure(BattleState.Mode.PRACTICE, ["guard", "guard", "guard", "guard", "guard"])
	var viewport2 := _attach_scene(scene2)
	var ended2: Array = []
	scene2.battle_ended.connect(func(practice: bool) -> void: ended2.append(practice))
	(scene2.get_node("%QuitPracticeButton") as Button).pressed.emit()
	check(ended2 == [true], "中途「结束练习」也能直接回去")
	viewport2.queue_free()
	await process_frame


func test_scene_turn_timer() -> void:
	print("[回合计时：到点自动结算并过回合]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	scene.configure(BattleState.Mode.PRACTICE, ["strike", "strike", "strike", "strike", "strike"])
	var viewport := _attach_scene(scene)
	await process_frame
	var timer_label := scene.get_node("%TurnTimerLabel") as Label
	check(timer_label.text == "剩余 45 秒", "开局 45 秒")
	var strike_button := _first_live_button(scene.get_node("%HandBox") as Control, "打击")
	check(_drag_card_to(scene, strike_button, scene.get_node("%PlayBox") as HBoxContainer), "拖一张打击进出牌区")
	check(scene.state.staged.size() == 1, "摆了一张打击")
	scene.turn_time_left = 0.0
	await process_frame
	await process_frame
	check(scene.state.staged.is_empty(), "到点自动结算出牌区")
	check(scene.state.enemy_hp == BattleConfig.PRACTICE_ENEMY_HP - 2, "摆放的打击已结算")
	check(scene.state.player_cost == BattleConfig.PLAYER_MAX_COST, "进入新回合，Cost 重置")
	check(timer_label.text == "剩余 45 秒", "计时重置")
	check(not timer_label.has_theme_color_override("font_color"), "平时计时器不标红")
	scene.turn_time_left = 12.0
	scene._update_timer_label()
	check(not timer_label.has_theme_color_override("font_color"), "剩 12 秒还未到警戒线")
	scene.turn_time_left = 8.0
	scene._update_timer_label()
	check(timer_label.get_theme_color("font_color") == Color(1.0, 0.35, 0.3), "最后 10 秒计时器变红")
	scene.turn_time_left = 0.0
	await process_frame
	await process_frame
	check(not timer_label.has_theme_color_override("font_color"), "新回合计时器颜色复位")
	viewport.queue_free()
	await process_frame


func test_scene_drag_and_discard() -> void:
	print("[战斗场景·拖拽：手牌 → 出牌区 / 弃牌区换 Cost]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var discard_zone := scene.get_node("%DiscardZone") as PanelContainer
	var discard_zone_label := scene.get_node("%DiscardZoneLabel") as Label
	var cost_label := scene.get_node("%CostLabel") as Label
	check(play_box.size.x > scene.size.x * 0.6, "出牌区有实际宽度（可承接拖放）")
	check((scene.get_node("HandScroll") as ScrollContainer).size.x > scene.size.x * 0.6, "手牌区横跨屏幕底部")
	var strike_button := _first_live_button(hand_box, "打击")
	check(strike_button != null and strike_button.drag_zone == "hand", "手牌处于可拖状态")
	var drag_data: Variant = strike_button._get_drag_data(Vector2.ZERO)
	check(typeof(drag_data) == TYPE_DICTIONARY and String(drag_data.get("zone", "")) == "hand", "拖拽数据带着来源与序号")
	var outside_point: Vector2 = scene.get_global_transform().affine_inverse() * Vector2(640.0, 250.0)
	check(scene._can_drop_data(outside_point, drag_data), "手牌拖出后放手在任何非弃牌区都接受")
	check(scene._drag_target_now == "play", "非弃牌区悬停一律记为出牌区")
	scene._drop_data(outside_point, drag_data)
	check(scene.state.staged.size() == 1, "在日志区放手，牌自动摆进出牌区")
	check(_count_live_card_buttons(hand_box) == 4, "手牌少了一张")
	var play_strike := _first_live_button(play_box, "打击")
	check(play_strike != null and play_strike.drag_zone == "play", "出牌区的牌可拖")
	check(_drag_card_to(scene, play_strike, hand_box), "拖回手牌区可以收回")
	check(scene.state.staged.is_empty(), "拖回后出牌区清空")
	check(_count_live_card_buttons(hand_box) == 5, "手牌回到五张")
	scene.state.gain_card(CardDB.get_card("wrath"))
	check(cost_label.text == "Cost 12 / 12", "弃牌前 Cost 12 / 12")
	var wrath_button := _first_live_button(hand_box, "暴怒")
	check(wrath_button != null, "手里出现暴怒")
	# 悬停反馈：模拟拖拽开始状态（与引擎通知同路径），检查高亮与弃牌收益预告
	var play_panel := scene.get_node("%PlayZonePanel") as PanelContainer
	var play_base_border: Color = (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var discard_base_border: Color = (discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	scene._drag_zone_source = "hand"
	var wrath_data: Variant = wrath_button._get_drag_data(Vector2.ZERO)
	var discard_point: Vector2 = scene.get_global_transform().affine_inverse() * discard_zone.get_global_rect().get_center()
	check(scene._can_drop_data(discard_point, wrath_data), "暴怒能投放到弃牌区")
	check(scene._drag_target_now == "discard", "悬停目标记录为弃牌区")
	check(discard_zone_label.text.contains("弃掉「暴怒」") and discard_zone_label.text.contains("Cost +5"), "弃牌区预告弃牌收益（暴怒 → Cost +5）")
	check((discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color != discard_base_border, "悬停的弃牌区边框亮起")
	check((play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color != play_base_border, "可投放的出牌区边框提示")
	check(scene._can_drop_data(outside_point, wrath_data), "拖到空白处也接受（自动摆进出牌区）")
	check(scene._drag_target_now == "play", "离开弃牌区后悬停目标记为出牌区")
	check(not discard_zone_label.text.contains("弃掉「暴怒」"), "离开弃牌区后预告收起")
	scene._notification(Control.NOTIFICATION_DRAG_END)
	check((discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color == discard_base_border and (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == play_base_border, "拖拽结束高亮复位")
	check(_drag_card_to(scene, wrath_button, discard_zone), "拖暴怒到弃牌区")
	check(cost_label.text == "Cost 17 / 12", "弃 6 费牌 +5，Cost 超上限（17/12）")
	check(discard_zone_label.text.contains("+5"), "弃牌区显示本回合已获得 +5")
	check(_find_card(scene.state.discard_pile, "wrath") >= 0, "弃掉的暴怒进弃牌堆")
	var strike_to_discard := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, strike_to_discard, discard_zone), "1 费牌也能拖去弃掉")
	check(cost_label.text == "Cost 17 / 12", "1 费牌弃掉 +0，Cost 不变")
	var play_strike2 := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, play_strike2, play_box), "摆一张打击准备打出")
	scene.state.debug_force_plays = 0
	(scene.get_node("%CommitButton") as Button).pressed.emit()
	check(scene.state.staged.is_empty(), "打出后出牌区清空")
	check(scene.state.phase == BattleState.Phase.PLAYER, "打出即结束回合，回到新回合")
	check(cost_label.text == "Cost 12 / 12", "新回合 Cost 重置回 12 / 12")
	check(discard_zone_label.text.contains("+0"), "弃牌区回合计数归零")
	var strike_after_commit := _first_live_button(hand_box, "打击")
	check(strike_after_commit != null, "新回合手里仍有打击")
	if strike_after_commit != null:
		_drag_card_to(scene, strike_after_commit, play_box)
	check(scene.state.staged.size() == 1, "新回合可以继续摆放")
	viewport.queue_free()
	await process_frame


func test_engine_drag_input() -> void:
	print("[引擎级拖拽：真实鼠标事件 按下 → 拖到出牌区 → 松手]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var play_panel := scene.get_node("%PlayZonePanel") as PanelContainer
	var play_base_border: Color = (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var strike_button := _first_live_button(hand_box, "打击")
	check(strike_button != null, "手里有打击")
	if strike_button == null:
		viewport.queue_free()
		await process_frame
		return
	var from_point: Vector2 = strike_button.get_global_rect().get_center()
	var to_point: Vector2 = play_box.get_global_rect().get_center()
	_push_mouse_button(viewport, from_point, true)
	_push_mouse_motion(viewport, from_point + Vector2(12.0, -12.0))
	check(viewport.gui_is_dragging(), "引擎进入了拖拽状态")
	# 引擎把拖拽预览 Label 挂在场景根下（不在 viewport 直接子级）
	var preview_found := false
	for child in scene.get_children():
		if child is Label and (child as Label).text == strike_button.card.display_name:
			preview_found = true
	check(preview_found, "拖拽预览跟随出现")
	_push_mouse_motion(viewport, to_point)
	check(scene._drag_zone_source == "hand", "引擎拖拽中记住了拖拽来源")
	check(scene._drag_target_now == "play", "悬停出牌区时记录悬停目标")
	check((play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color != play_base_border, "悬停的出牌区边框亮起")
	_push_mouse_button(viewport, to_point, false)
	check(not viewport.gui_is_dragging(), "松手后拖拽结束")
	check(scene._drag_zone_source == "" and scene._drag_target_now == "", "松手后拖拽状态清空")
	check((play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == play_base_border, "松手后高亮复位")
	check(scene.state.staged.size() == 1, "真实拖拽把牌放进了出牌区")
	if scene.state.staged.size() == 1:
		check(scene.state.staged[0].id == "strike", "放进去的正是被拖的打击")
	check(_count_live_card_buttons(hand_box) == 4, "手牌跟着少一张")
	# 出牌区拖回手牌（撤回），同样走引擎级真实拖拽
	var staged_button := _first_live_button(play_box, "打击")
	check(staged_button != null and staged_button.drag_zone == "play", "出牌区的牌可拖回")
	if staged_button != null:
		var back_from: Vector2 = staged_button.get_global_rect().get_center()
		var back_to: Vector2 = hand_box.get_global_rect().get_center()
		_push_mouse_button(viewport, back_from, true)
		_push_mouse_motion(viewport, back_from + Vector2(12.0, 12.0))
		_push_mouse_motion(viewport, back_to)
		check(scene._drag_target_now == "hand", "引擎拖拽悬停手牌区（可撤回）")
		_push_mouse_button(viewport, back_to, false)
		check(scene.state.staged.is_empty(), "拖回后出牌区清空")
		check(_count_live_card_buttons(hand_box) == 5, "手牌恢复五张")
	# 弃牌区同样走引擎级真实拖拽（PanelContainer 默认 STOP 会静默拦截投放，2026-10-03 修复）
	scene.state.gain_card(CardDB.get_card("wrath"))
	await process_frame
	var wrath_button := _first_live_button(hand_box, "暴怒")
	check(wrath_button != null, "手里出现暴怒")
	if wrath_button != null:
		var discard_to: Vector2 = (scene.get_node("%DiscardZone") as PanelContainer).get_global_rect().get_center()
		var wrath_from: Vector2 = wrath_button.get_global_rect().get_center()
		_push_mouse_button(viewport, wrath_from, true)
		_push_mouse_motion(viewport, wrath_from + Vector2(10.0, -10.0))
		_push_mouse_motion(viewport, discard_to)
		check(scene._drag_target_now == "discard", "引擎拖拽悬停弃牌区")
		_push_mouse_button(viewport, discard_to, false)
		check((scene.get_node("%CostLabel") as Label).text == "Cost 17 / 12", "引擎级拖拽弃牌 +5（17/12）")
		check(_find_card(scene.state.discard_pile, "wrath") >= 0, "暴怒经引擎拖拽进了弃牌堆")
	# 手牌拖出后在非弃牌区松手（例：日志区）＝自动摆进出牌区（日志区控件必须 IGNORE，否则引擎拖放被静默拦截）
	var strike_free := _first_live_button(hand_box, "打击")
	check(strike_free != null, "手里还有打击可拖")
	if strike_free != null:
		var free_from: Vector2 = strike_free.get_global_rect().get_center()
		var free_to := Vector2(640.0, 255.0)
		_push_mouse_button(viewport, free_from, true)
		_push_mouse_motion(viewport, free_from + Vector2(10.0, -10.0))
		_push_mouse_motion(viewport, free_to)
		check(scene._drag_target_now == "play", "拖到日志区：悬停目标仍是出牌区")
		_push_mouse_button(viewport, free_to, false)
		check(scene.state.staged.size() == 1, "在日志区松手，牌自动摆进出牌区")
	viewport.queue_free()
	await process_frame


func test_scene_hover_scale() -> void:
	print("[卡牌悬停：动态放大，移开缩回]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var card_button := _first_live_button(hand_box, "打击")
	check(card_button != null, "手牌在场")
	if card_button == null:
		viewport.queue_free()
		await process_frame
		return
	check(card_button.pivot_offset == card_button.size / 2.0, "缩放轴心在卡牌中心")
	check(card_button.scale == Vector2.ONE, "初始不放大")
	check(card_button.fan_arranged, "手牌交给扇形排布接管")
	var base_position: Vector2 = card_button.position
	var neighbor: Control = null
	for child in hand_box.get_children():
		if child is Control and child != card_button:
			neighbor = child
			break
	check(neighbor != null, "有邻居卡用于对比")
	var neighbor_pos: Vector2 = neighbor.position
	# headless 帧间隔极小，用 time_scale 加速 tween，循环等待到目标值
	Engine.time_scale = 120.0
	card_button.mouse_entered.emit()
	check(card_button.position.y == base_position.y - CardButton.HOVER_LIFT, "悬停的牌整体向上抬起")
	check(card_button.position.x == base_position.x, "抬起不改变水平位置")
	var waited := 0
	while card_button.scale.x <= 1.0 and waited < 300:
		waited += 1
		await process_frame
	check(card_button.scale.x > 1.0, "悬停后动态放大")
	check(card_button.z_index == 1, "放大时提到上层显示")
	check(neighbor.position == neighbor_pos, "放大与抬升不影响邻居布局")
	card_button.mouse_exited.emit()
	check(card_button.position == base_position, "移开后落回原位")
	waited = 0
	while card_button.scale.x > 1.0001 and waited < 600:
		waited += 1
		await process_frame
	Engine.time_scale = 1.0
	check(is_equal_approx(card_button.scale.x, 1.0), "移开后缩回原大小")
	check(card_button.z_index == 0, "复位后回到普通层")
	viewport.queue_free()
	await process_frame


func test_scene_fan_hand_geometry() -> void:
	print("[扇形手牌：8 张上限内完整排开；超限窗口仍全可见；拖拽不破坏]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var hand_scroll := scene.get_node("HandScroll") as ScrollContainer
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var opening := _live_hand_cards(hand_box)
	check(opening.size() == 5, "开局手牌 5 张")
	var no_overlap := true
	for i in range(1, opening.size()):
		if not is_equal_approx(opening[i].position.x - opening[i - 1].position.x, 118.0):
			no_overlap = false
	check(no_overlap, "≤8 张不叠压：相邻步进 118")
	for _i in 3:
		scene.state.gain_card(CardDB.get_card("strike"))
	await process_frame
	await process_frame
	var scroll_rect: Rect2 = hand_scroll.get_global_rect()
	var full := _live_hand_cards(hand_box)
	check(full.size() == 8, "8 张到上限，牌面全部生成")
	var full_step := true
	var full_inside := true
	for i in full.size():
		if i > 0 and not is_equal_approx(full[i].position.x - full[i - 1].position.x, 118.0):
			full_step = false
		var full_rect: Rect2 = full[i].get_global_rect()
		if full_rect.position.x < scroll_rect.position.x - 0.5 or full_rect.end.x > scroll_rect.end.x + 0.5 \
				or full_rect.position.y < scroll_rect.position.y - 0.5 or full_rect.end.y > scroll_rect.end.y + 0.5:
			full_inside = false
	check(full_step, "上限内 8 张仍不叠压（步进 118）")
	check(full_inside, "8 张全部含于手牌区内")
	# 上限内无强制弃牌页遮挡：走引擎级真实拖拽（最右卡）
	var rightmost: CardButton = full[7]
	var from_point: Vector2 = rightmost.get_global_rect().get_center()
	var to_point: Vector2 = play_box.get_global_rect().get_center()
	_push_mouse_button(viewport, from_point, true)
	_push_mouse_motion(viewport, from_point + Vector2(12.0, -12.0))
	check(viewport.gui_is_dragging(), "上限内引擎拖拽可启动（最右卡）")
	_push_mouse_motion(viewport, to_point)
	_push_mouse_button(viewport, to_point, false)
	check(scene.state.staged.size() == 1, "最右卡拖进了出牌区")
	await process_frame
	await process_frame
	var after := _live_hand_cards(hand_box)
	check(after.size() == 7, "拖走一张后剩 7 张")
	# 第二张走数据链直接投放（与应用级路径同源）
	var leftmost: CardButton = after[0]
	check(_drag_card_to(scene, leftmost, play_box), "第二张拖拽数据链完好")
	check(scene.state.staged.size() == 2, "第二张也摆进了出牌区")
	await process_frame
	await process_frame
	var rest := _live_hand_cards(hand_box)
	check(rest.size() == 6, "收走两张后剩 6 张")
	var rest_step_ok := true
	var rest_inside := true
	for i in rest.size():
		if i > 0 and not is_equal_approx(rest[i].position.x - rest[i - 1].position.x, 118.0):
			rest_step_ok = false
		var rest_rect: Rect2 = rest[i].get_global_rect()
		if rest_rect.position.x < scroll_rect.position.x - 0.5 or rest_rect.end.x > scroll_rect.end.x + 0.5:
			rest_inside = false
	check(rest_step_ok, "6 张重排后步进仍 118")
	check(rest_inside, "重排后仍全部在手牌区内")
	# 超限窗口（9–11 张）：临时叠压、全部可见（此时强制弃牌页在场，弃牌走弃牌页）
	for _i in 5:
		scene.state.gain_card(CardDB.get_card("strike"))
	await process_frame
	await process_frame
	var over := _live_hand_cards(hand_box)
	check(over.size() == 11, "超限窗口 11 张牌面全部生成")
	var expected_step: float = (hand_box.size.x - 20.0 - 118.0) / 10.0
	var monotonic := true
	var even := true
	var inside := true
	for i in over.size():
		if i > 0:
			var gap: float = over[i].position.x - over[i - 1].position.x
			if gap <= 0.0:
				monotonic = false
			if not is_equal_approx(gap, expected_step):
				even = false
		var over_rect: Rect2 = over[i].get_global_rect()
		if over_rect.position.x < scroll_rect.position.x - 0.5 or over_rect.end.x > scroll_rect.end.x + 0.5 \
				or over_rect.position.y < scroll_rect.position.y - 0.5 or over_rect.end.y > scroll_rect.end.y + 0.5:
			inside = false
	check(monotonic, "11 张从左到右递增")
	check(even, "11 张均等步进叠压（约 %.1f px）" % expected_step)
	check(inside, "11 张全部含于手牌区内")
	viewport.queue_free()
	await process_frame


func test_scene_pile_counts() -> void:
	print("[牌堆/弃牌堆计数：随弃牌、打出、摸牌洗回实时同步]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	await process_frame
	var hand_count := scene.get_node("%HandCountLabel") as Label
	var pile_count := scene.get_node("%PileCountLabel") as Label
	var hand_box := scene.get_node("%HandBox") as Control
	var discard_zone := scene.get_node("%DiscardZone") as PanelContainer
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	check(hand_count.text == "手牌 5/8", "开局：手牌 5/8")
	check(pile_count.text == "牌堆 3　弃牌堆 0", "开局：牌堆 3、弃牌堆 0")
	scene.state.debug_force_plays = 0
	var to_discard: CardButton = _live_hand_cards(hand_box)[0]
	check(_drag_card_to(scene, to_discard, discard_zone), "拖一张进弃牌区换 Cost")
	await process_frame
	check(hand_count.text == "手牌 4/8", "弃牌后手牌 4/8")
	check(pile_count.text == "牌堆 3　弃牌堆 1", "弃牌后：牌堆 3、弃牌堆 1")
	var strike_button := _first_live_button(hand_box, "打击")
	check(strike_button != null, "手里还有打击")
	if strike_button != null:
		check(_drag_card_to(scene, strike_button, play_box), "摆一张打击")
		(scene.get_node("%CommitButton") as Button).pressed.emit()
		await process_frame
		check(pile_count.text == "牌堆 0　弃牌堆 2", "打出并摸 3 张后：牌堆 0、弃牌堆 2（打出的牌入弃牌堆）")
	var victim: CardButton = _live_hand_cards(hand_box)[0]
	check(_drag_card_to(scene, victim, discard_zone), "再弃一张")
	await process_frame
	check(pile_count.text == "牌堆 0　弃牌堆 3", "弃牌后：牌堆 0、弃牌堆 3")
	var hand_before: int = scene.state.hand.size()
	(scene.get_node("%EndTurnButton") as Button).pressed.emit()
	await process_frame
	check(scene.state.hand.size() == hand_before + 3, "空过一轮照常摸 3 张（弃牌堆洗回）")
	check(pile_count.text == "牌堆 0　弃牌堆 0", "洗回后摸完：牌堆 0、弃牌堆 0")
	check(pile_count.text == "牌堆 %d　弃牌堆 %d" % [scene.state.draw_pile.size(), scene.state.discard_pile.size()], "显示与 state 完全一致")
	viewport.queue_free()
	await process_frame


func test_scene_forced_discard() -> void:
	print("[手牌上限 8：超限强制弹出弃牌页]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	var overlay := scene.get_node("%Overlay") as Control
	var discard_scroll := scene.get_node("%DiscardScroll") as ScrollContainer
	var discard_box := scene.get_node("%DiscardBox") as VBoxContainer
	var story := scene.get_node("%StoryText") as Label
	var hand_count := scene.get_node("%HandCountLabel") as Label
	var pile_count := scene.get_node("%PileCountLabel") as Label
	check(not overlay.visible, "未超限时不弹弃牌页")
	check(hand_count.text == "手牌 5/8", "开局计数 5/8")
	check(not hand_count.has_theme_color_override("font_color"), "未满上限不标警示色")
	check(pile_count.text == "牌堆 3　弃牌堆 0", "开局牌堆/弃牌堆 3 / 0")
	for _i in 3:
		scene.state.gain_card(CardDB.get_card("strike"))
	check(scene.state.hand.size() == BattleConfig.HAND_LIMIT, "手牌到 8 张")
	check(hand_count.text == "手牌 8/8", "到上限计数 8/8")
	check(hand_count.has_theme_color_override("font_color"), "到上限计数变警示色")
	check(not overlay.visible, "到上限还不够，不弹")
	scene.state.gain_card(CardDB.get_card("strike"))
	check(scene.state.hand.size() == 9, "第 9 张超出上限")
	check(hand_count.text == "手牌 9/8", "超限计数 9/8")
	check(overlay.visible and discard_scroll.visible, "强制弹出弃牌页")
	check(story.text.contains("还差 1 张"), "提示还差 1 张")
	check(discard_box.get_child_count() == 9, "列出全部 9 张手牌")
	var first_discard := discard_box.get_child(0) as Button
	first_discard.pressed.emit()
	check(scene.state.hand.size() == BattleConfig.HAND_LIMIT, "弃掉 1 张后回到上限")
	check(hand_count.text == "手牌 8/8", "弃回后计数 8/8")
	check(not overlay.visible, "弃牌页自动关闭")
	check(scene.state.discard_pile.size() == 1, "弃掉的牌进了弃牌堆")
	check(pile_count.text == "牌堆 3　弃牌堆 1", "弃牌堆计数 3 / 1")
	viewport.queue_free()
	await process_frame


func _sfx_file_exists(sfx_name: String) -> bool:
	for ext in [".ogg", ".wav", ".mp3"]:
		if FileAccess.file_exists("res://assets/audio/sfx/" + sfx_name + ext):
			return true
	return false


func test_sfx_wiring() -> void:
	print("[音效接线：信号连接＋缺失静默降级＋文件存在时播放]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	var viewport := _attach_scene(scene)
	await process_frame
	check(scene._sfx_players.is_empty(), "开局不预载，懒加载无播放器")
	check(scene.state.card_staged.is_connected(scene._on_card_staged), "摆放信号已接线")
	check(scene.state.card_recalled.is_connected(scene._on_card_recalled), "收回信号已接线")
	check(scene.state.card_played.is_connected(scene._on_card_played), "打出信号已接线")
	check(scene.state.card_discarded.is_connected(scene._on_card_discarded), "弃牌信号已接线")
	scene._play_sfx("sfx_never_exists")
	check(not scene._sfx_players.has("sfx_never_exists"), "缺失音效静默降级，不建播放器")
	var index := _find_card(scene.state.hand, "strike")
	if index < 0:
		index = 0
	scene.state.stage_card(index)
	check(scene._sfx_players.has("sfx_stage") == _sfx_file_exists("sfx_stage"), "真实摆放路径接线（有文件则有声）")
	scene.state.recall_card(0)
	check(scene._sfx_players.has("sfx_recall") == _sfx_file_exists("sfx_recall"), "真实收回路径接线（有文件则有声）")
	var wired := ["sfx_hit", "sfx_guard", "sfx_call", "sfx_stage", "sfx_recall", "sfx_discard", "sfx_strip", "sfx_absorb"]
	var found := 0
	for sfx_name in wired:
		if _sfx_file_exists(sfx_name):
			found += 1
			check(scene._load_sfx(sfx_name) != null, sfx_name + " 可加载")
	check(found > 0, "音效文件已生成（%d/8）" % found)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 8000
	wav.data = PackedByteArray()
	wav.data.resize(8000)  # 1 秒静音
	wav.data.fill(128)
	DirAccess.make_dir_recursive_absolute("res://assets/audio/sfx")
	wav.save_to_wav("res://assets/audio/sfx/sfx_test_wire.wav")
	var players_before: int = scene._sfx_players.size()
	scene._play_sfx("sfx_test_wire")
	var player: AudioStreamPlayer = scene._sfx_players.get("sfx_test_wire")
	check(player != null, "音频文件存在时懒加载建播放器")
	# headless 哑音频驱动无节拍、微秒级吞完整个流，is_playing 单断言天然竞态：
	# 播放生效＝「还在播」或「已被播完且 finished 已到」，两条通道取或
	var playback_finished := {"done": false}
	if player != null:
		player.finished.connect(func() -> void: playback_finished["done"] = true)
		scene._play_sfx("sfx_test_wire")
	var playback_proven := false
	for _i in 20:
		if player != null and (player.is_playing() or playback_finished["done"]):
			playback_proven = true
			break
		await process_frame
	check(playback_proven, "播放路径生效（播放中或已被哑驱动播完）")
	check(scene._sfx_players.size() == players_before + 1, "重复播放复用同一播放器")
	DirAccess.remove_absolute("res://assets/audio/sfx/sfx_test_wire.wav")
	viewport.queue_free()
	await process_frame


func test_main_flow_full() -> void:
	print("[主流程：告知 → 练习站组卡 → 木桩 → 转化 → 教程战 → 三问 → 同行]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var story_page := main.get_node("%StoryPage") as Control
	var practice_page := main.get_node("%PracticePage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	check(story_page.visible, "开场在读白页")
	check(story.text.contains("八层"), "召唤告知：世界是八层")
	check(story.text.contains("清空"), "召唤告知：目标只说清空血量")
	check(not story.text.contains("剥离") and not story.text.contains("收下"), "告知边界：不提前提剥离/收下")
	check(not secondary.visible, "开场单按钮")
	primary.pressed.emit()
	check(story.text.contains("打击") and story.text.contains("护住"), "教学读白在屏上")
	check(not story.text.contains("剥离"), "教学段也不提剥离")
	check(secondary.visible, "教学页出现「直接去台阶」")
	primary.pressed.emit()
	check(practice_page.visible, "进入练习站")
	var warehouse := main.get_node("%WarehouseList") as VBoxContainer
	check(_first_live_button(warehouse, "「打击」") != null, "仓库里有打击")
	for i in 5:
		var strike_button := _first_live_button(warehouse, "「打击」")
		check(strike_button != null, "第 %d 张打击按钮在场" % (i + 1))
		if strike_button != null:
			strike_button.pressed.emit()
	for i in 3:
		var guard_button := _first_live_button(warehouse, "「护住」")
		check(guard_button != null, "第 %d 张护住按钮在场" % (i + 1))
		if guard_button != null:
			guard_button.pressed.emit()
	var start_button := main.get_node("%StartPracticeButton") as Button
	check((main.get_node("%DeckCountLabel") as Label).text == "卡组 8 / 8", "卡组计数更新")
	check(not start_button.disabled, "8 张组好后可开打")
	start_button.pressed.emit()
	check(battle_host.get_child_count() == 1, "练习战进入战斗位")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.mode == BattleState.Mode.PRACTICE, "是练习模式")
	check(battle.state.enemy_name == "木桩", "对手是木桩")
	await process_frame
	_press_strikes_until_over(battle)
	check(battle.state.phase == BattleState.Phase.ENDED, "木桩被打倒")
	var practice_continue := battle.get_node("%ContinueButton") as Button
	check(practice_continue.text == "返回练习站", "练习结束按钮")
	practice_continue.pressed.emit()
	check(practice_page.visible, "回到练习站")
	await process_frame
	check(battle_host.get_child_count() == 0, "练习战斗已释放")
	(main.get_node("%LeavePracticeButton") as Button).pressed.emit()
	check(story_page.visible, "离开练习站后回到读白页")
	check(story.text.contains("清空"), "转化读白：目标仍是清空血量")
	check(not story.text.contains("剥离"), "告知边界：转化页也不提剥离")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "教程战进入战斗位")
	var battle2: Variant = battle_host.get_child(0)
	check(battle2.state.mode == BattleState.Mode.TUTORIAL, "是教程模式")
	check(battle2.state.enemy_name == "小默", "对手是小默")
	check((battle2.get_node("%CostLabel") as Label).text == "Cost 12 / 12", "教程战 Cost 显示 12/12")
	check(battle2.state.draw_pile.size() + battle2.state.hand.size() == BattleConfig.DECK_SIZE, "教程战用练习站自组的 8 张卡组")
	battle2.state.debug_force_plays = 0
	await process_frame
	_press_strikes_until_over(battle2)
	check(battle2.state.phase == BattleState.Phase.STRIP, "打倒小默进入剥离时刻")
	check((battle2.get_node("%Overlay") as Control).visible, "剥离覆盖层出现")
	(battle2.get_node("%AbsorbButton") as Button).pressed.emit()
	check(battle2.state.collection.size() == 1, "罪卡收下")
	var cont2 := battle2.get_node("%ContinueButton") as Button
	cont2.pressed.emit()
	cont2.pressed.emit()
	cont2.pressed.emit()
	cont2.pressed.emit()
	check(battle2.state.phase == BattleState.Phase.ENDED, "三问走完")
	await process_frame
	check(story_page.visible, "回到读白页（结尾）")
	check(story.text.contains("小默"), "同行结尾读白在屏上")
	viewport.queue_free()
	await process_frame


func test_main_flow_skip_practice() -> void:
	print("[主流程·跳过练习：默认卡组打教程战]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	var battle_host := main.get_node("%BattleHost") as Control
	primary.pressed.emit()
	secondary.pressed.emit()
	check(story.text.contains("清空"), "转化读白在屏上")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "直接进入教程战")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.mode == BattleState.Mode.TUTORIAL, "教程模式")
	check(battle.state.hand.size() == BattleConfig.HAND_SIZE, "没组卡时用默认卡组，开局手牌 5 张")
	viewport.queue_free()
	await process_frame
