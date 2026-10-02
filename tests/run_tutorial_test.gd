extends SceneTree

var failures := 0


func _initialize() -> void:
	print("== 教程战逻辑测试 ==")
	test_cards_load()
	test_wrath_effects()
	test_guard_blocks_heads()
	test_call_suppresses()
	test_revive_flow()
	test_empty_hand_auto_ends_turn()
	test_full_victory_flow()
	# 等一帧让 SceneTree 进入运行态，节点加入 root 时 _ready 才会立即执行
	await process_frame
	test_battle_scene_builds()
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


func _play_all(state: BattleState, card_id: String) -> void:
	var index := 0
	while index < state.hand.size() and state.phase == BattleState.Phase.PLAYER:
		if state.hand[index].id == card_id:
			state.play_card(index)
		else:
			index += 1


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


func test_cards_load() -> void:
	print("[卡牌数据]")
	for card_id in ["strike", "guard", "call", "wrath"]:
		var card := CardDB.get_card(card_id)
		check(card != null, "载入 " + card_id)
		if card != null:
			check(card.id == card_id, card_id + " id 一致")
			check(not card.effects.is_empty(), card_id + " 有效果")
	var wrath := CardDB.get_card("wrath")
	check(wrath.permanent, "暴怒是永久牌")
	check(wrath.kind == CardData.Kind.SIN, "暴怒是罪牌")


func test_wrath_effects() -> void:
	print("[暴怒：3 伤 + 攻击永久 +1]")
	var state := _make_state()
	state.hand.append(CardDB.get_card("wrath"))
	state.play_card(_find_card(state.hand, "wrath"))
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 3, "暴怒直接造成 3 伤")
	check(state.attack_bonus == 1, "攻击加成 +1")
	check(state.collection.has(CardDB.get_card("wrath")), "暴怒留在面前而不是进弃牌堆")
	state.play_card(_find_card(state.hand, "strike"))
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 6, "打击吃到加成(3 伤)")


func test_guard_blocks_heads() -> void:
	print("[护住 vs 正面 2 伤]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_roll = 1
	state.play_card(_find_card(state.hand, "guard"))
	check(state.player_block == 2, "护住后格挡 2")
	var hp_before: int = state.player_hp
	state.end_turn()
	check(state.player_hp == hp_before, "正面 2 伤被完整挡下")
	check(state.player_block == 0, "新回合格挡清零")
	check(state.revives == 0, "没有倒下")
	check(_log_contains(logs, "挡"), "日志记录了挡下")


func test_call_suppresses() -> void:
	print("[呼喊：这一回合不打人]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_roll = 1
	state.play_card(_find_card(state.hand, "call"))
	check(state.enemy_suppressed, "压制标记已设")
	var hp_before: int = state.player_hp
	state.end_turn()
	check(state.player_hp == hp_before, "没有挨打")
	check(_log_contains(logs, "……对不起"), "他说了题眼那句")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP, "呼喊不伤他")


func test_revive_flow() -> void:
	print("[倒下：法阵拉回]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_roll = 1
	for _i in 5:
		state.end_turn()
	check(state.revives == 1, "吃满 10 伤后倒下一次")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "回满血")
	check(_log_contains(logs, "法阵亮了一下"), "法阵读白出现")


func test_empty_hand_auto_ends_turn() -> void:
	print("[手牌打完自动过回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_roll = 2
	var marks_before := _count_log(logs, "—— 他的回合 ——")
	var played := 0
	while _count_log(logs, "—— 他的回合 ——") == marks_before and played < 10:
		played += 1
		state.play_card(0)
	check(played == 5, "恰好出完 5 张后自动过回合")
	check(_count_log(logs, "—— 他的回合 ——") == marks_before + 1, "他的回合只来了一次")
	check(state.hand.size() == BattleConfig.HAND_SIZE, "新回合手牌自动补满")
	check(state.phase == BattleState.Phase.PLAYER, "回到可出牌状态")


func test_full_victory_flow() -> void:
	print("[完整流程：打赢 → 剥离 → 收下 → 三问 → 结束]")
	var state := _make_state()
	state.debug_force_roll = 2
	var turns := 0
	while state.phase == BattleState.Phase.PLAYER and turns < 10:
		turns += 1
		_play_all(state, "strike")
		if state.phase == BattleState.Phase.PLAYER:
			_play_all(state, "guard")
		if state.phase == BattleState.Phase.PLAYER:
			_play_all(state, "call")
		if state.phase == BattleState.Phase.PLAYER:
			state.end_turn()
	check(state.phase == BattleState.Phase.STRIP, "打倒后进入剥离时刻")
	check(state.enemy_hp == 0, "他归零了")
	check(state.collection.is_empty(), "剥离前收藏为空")
	check(state.absorb_wrath(), "拿起暴怒")
	check(state.collection.size() == 1 and state.collection[0].id == "wrath", "暴怒进收藏")
	check(_find_card(state.discard_pile, "wrath") == -1, "暴怒不在弃牌堆")
	check(_find_card(state.draw_pile, "wrath") == -1, "暴怒不在抽牌堆")
	check(state.phase == BattleState.Phase.DEBRIEF, "进入三问")
	check(state.finish_debrief(), "结束三问")
	check(state.phase == BattleState.Phase.ENDED, "流程结束")
	check(not state.play_card(0), "结束后不能再出牌")


func test_battle_scene_builds() -> void:
	print("[战斗场景：按钮走完整局]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	check(packed != null, "battle.tscn 可加载")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var screen := scene as Control
	var hand_box := scene.get_node("%HandBox") as HBoxContainer
	var overlay := scene.get_node("%Overlay") as Control
	var story := scene.get_node("%StoryText") as Label
	check(hand_box.get_child_count() == 5, "开局手牌 5 张")
	check(overlay.visible, "开场读白覆盖层出现")
	check(story.text != "", "开场读白有内容")
	# 点"继续"收掉开场
	(scene.get_node("%ContinueButton") as Button).pressed.emit()
	check(not overlay.visible, "开场读白收掉")
	# 像玩家一样点牌：一直点打击，没打击就结束回合，打倒为止
	screen.state.debug_force_roll = 2
	var safety := 0
	while screen.state.phase == BattleState.Phase.PLAYER and safety < 40:
		safety += 1
		var pressed_strike := false
		for child in hand_box.get_children():
			var card_button := child as CardButton
			if card_button != null and card_button.visible and card_button.card.id == "strike":
				card_button.pressed.emit()
				pressed_strike = true
				break
		if not pressed_strike and screen.state.phase == BattleState.Phase.PLAYER:
			(scene.get_node("%EndTurnButton") as Button).pressed.emit()
	check(screen.state.phase == BattleState.Phase.STRIP, "点击流程进入剥离时刻")
	check(overlay.visible, "剥离覆盖层出现")
	check(story.text.contains("滚烫的白火"), "剥离读白在屏上")
	var absorb_button := scene.get_node("%AbsorbButton") as Button
	check(absorb_button.visible, "「拿起 暴怒」按钮出现")
	absorb_button.pressed.emit()
	check(screen.state.phase == BattleState.Phase.DEBRIEF, "收下罪卡进入净化")
	check(story.text.contains("剥下来的罪"), "净化读白在屏上")
	var continue_button := scene.get_node("%ContinueButton") as Button
	check(continue_button.visible, "继续按钮在场")
	continue_button.pressed.emit()
	check(story.text.contains("归零"), "第一问出现")
	continue_button.pressed.emit()
	continue_button.pressed.emit()
	continue_button.pressed.emit()
	check(screen.state.phase == BattleState.Phase.ENDED, "三问走完，流程结束")
	check(not overlay.visible, "覆盖层收起")
	scene.queue_free()
