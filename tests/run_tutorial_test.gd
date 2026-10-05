extends SceneTree

var failures := 0
var _mouse_last_point := Vector2.ZERO


func _initialize() -> void:
	print("== 教程战逻辑测试 ==")
	test_cards_load()
	test_wrath_effects()
	test_sin_unlock_rules()
	test_new_card_effects()
	test_guard_blocks_enemy_plays()
	test_call_suppresses()
	test_card_costs()
	test_cost_pool()
	test_defeat_flow()
	test_practice_defeat()
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
	test_amplify_cards()
	test_card_stacking()
	test_practice_battle()
	test_layer_data()
	test_card_pool_sin()
	test_story_battle_small()
	test_story_battle_boss()
	# 等一帧让 SceneTree 进入运行态，节点加入 root 时 _ready 才会立即执行
	await process_frame
	await test_battle_scene_tutorial()
	await test_battle_scene_practice()
	await test_battle_scene_defeat()
	await test_map_page()
	await test_event_page()
	await test_transition_page()
	await test_scene_turn_timer()
	await test_scene_drag_and_discard()
	await test_scene_stacking()
	await test_engine_drag_input()
	await test_scene_hover_scale()
	await test_scene_fan_hand_geometry()
	await test_scene_pile_counts()
	await test_scene_forced_discard()
	await test_sfx_wiring()
	await test_main_flow_full()
	await test_main_flow_skip_practice()
	await test_main_flow_layer2()
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


# 罪卡检定只对「牌组里的罪卡」生效（deck_sin_id 由开局扫描得出）；构造带罪卡的牌组
func _make_sin_state(logs: Array = [], sin_id := "wrath") -> BattleState:
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start([sin_id, "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
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
	while state.phase == BattleState.Phase.PLAYER and turns < 120:
		turns += 1
		_turn_cycle(state, ["strike", "heavy_strike", "guard", "call"])


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


func _pool_battle(enemy_name: String) -> Dictionary:
	for battle in LayerConfig.LAYER2_BATTLES:
		if String(battle.get("enemy", "")) == enemy_name:
			return battle
	return {}


func _pool_event(title: String) -> Dictionary:
	for event_item in LayerConfig.LAYER2_EVENTS:
		if String(event_item.get("title", "")) == title:
			return event_item
	return {}


func _route_signature(route: Array) -> String:
	var column_parts := PackedStringArray()
	for column in route:
		var node_parts := PackedStringArray()
		for stage in column:
			node_parts.append(String(stage.get("enemy", stage.get("title", "?"))))
		column_parts.append(",".join(node_parts))
	return "|".join(column_parts)


# 层内流程测试夹具：固定三列（3 选 1 → 2 选 1 → 层主战），排除随机性干扰；
# 随机性由 test_layer_data 的生成器测试单独覆盖
func _fixture_route() -> Array:
	return [
		[_pool_event("粉雾"), _pool_battle("污染体"), _pool_event("镜阶")],
		[_pool_battle("残响回廊"), _pool_event("烛台走廊")],
		[LayerConfig.LAYER2_BOSS],
	]


func _check_cost_label(scene: Variant, cost_text: String, message: String) -> void:
	var label := scene.get_node("%CostLabel") as Label
	check(label.text.ends_with(cost_text), message + "（实际：" + label.text + "）")


func _first_live_button(container: Node, prefix: String) -> Button:
	for child in container.get_children():
		if not child is Button or child.is_queued_for_deletion():
			continue
		var button := child as Button
		# 卡牌按钮的文字画在自绘子节点里（Button.text 为空），按卡名匹配
		if button is CardButton:
			if (button as CardButton).card != null and (button as CardButton).card.display_name.contains(prefix):
				return button
		elif button.text.contains(prefix):
			return button
	return null


# 深层查找：程序化页面（地图/事件/过渡）按钮嵌在多层容器里，且 rebuild 后需跳过待释放节点
func _deep_find_button(node: Node, prefix: String) -> Button:
	if node is Button and not node.is_queued_for_deletion():
		var button := node as Button
		if button.text.contains(prefix):
			return button
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var found := _deep_find_button(child, prefix)
		if found != null:
			return found
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
	for card_id in ["strike", "heavy_strike", "guard", "strong_guard", "call", "shift", "wrath", "enemy_strike", "quench", "surge", "bulwark"]:
		var card := CardDB.get_card(card_id)
		check(card != null, "载入 " + card_id)
		if card != null:
			check(card.id == card_id, card_id + " id 一致")
			if card.kind == CardData.Kind.AMPLIFY:
				check(not card.discard_effects.is_empty(), card_id + " 有弃牌触发效果")
			else:
				check(not card.effects.is_empty(), card_id + " 有效果")
	var wrath := CardDB.get_card("wrath")
	check(wrath.permanent, "暴怒是永久牌")
	check(wrath.kind == CardData.Kind.SIN, "暴怒是罪牌")
	check(CardDB.get_card("strike").kind == CardData.Kind.ATTACK, "打击是攻击牌")
	check(CardDB.get_card("heavy_strike").kind == CardData.Kind.ATTACK, "重击是攻击牌")
	check(CardDB.get_card("guard").kind == CardData.Kind.DEFENSE, "护住是防御牌")
	check(CardDB.get_card("strong_guard").kind == CardData.Kind.DEFENSE, "坚守是防御牌")
	check(CardDB.get_card("call").kind == CardData.Kind.UTILITY, "呼喊是功能牌")
	check(CardDB.get_card("shift").kind == CardData.Kind.UTILITY, "转换是功能牌")
	check(CardDB.get_card("quench").kind == CardData.Kind.AMPLIFY, "淬火是增幅牌")
	check(CardDB.get_card("surge").kind == CardData.Kind.AMPLIFY, "蓄能是增幅牌")
	check(CardDB.get_card("bulwark").kind == CardData.Kind.AMPLIFY, "筑壁是增幅牌")
	check(CardDB.get_card("quench").kind_label() == "功能", "卡型标签：增幅呈现并入功能")
	check(CardDB.get_card("quench").cost == 1, "增幅牌 Cost 1")
	check(CardDB.get_card("heavy_strike").kind_label() == "攻击", "卡型标签：攻击")
	check(CardDB.get_card("shift").kind_label() == "功能", "卡型标签：功能")
	check(CardDB.get_card("wrath").kind_label() == "罪", "卡型标签：罪")


func test_wrath_effects() -> void:
	print("[罪牌：3 伤 + 攻击永久 +1]")
	var state := _make_sin_state()
	state.debug_force_plays = 0
	state.sin_available = true
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


func test_sin_unlock_rules() -> void:
	print("[罪卡规则：任务+8回合保底解锁、每场仅一次]")
	var logs: Array = []
	var state := _make_sin_state(logs)
	state.debug_force_plays = 0
	state.gain_card(CardDB.get_card("wrath"))
	check(state.deck_sin_id == "wrath", "牌组里的罪卡被识别为本场检定对象")
	check(not state.sin_available, "开局罪卡封锁")
	check(not state.can_stage(CardDB.get_card("wrath")), "封锁时不能摆出")
	check(state.sin_lock_reason().contains("封印"), "封锁提示在")
	check(state.sin_lock_reason().contains("0/%d" % int(BattleConfig.SIN_TASK_CONFIG["wrath"]["count"])), "任务进度 0/3")
	var index := _find_card(state.hand, "wrath")
	check(not state.stage_card(index), "封锁时摆放被拒")
	check(state.hand.has(CardDB.get_card("wrath")), "罪卡还在手里")
	# 任务路径：累计打出 3 张攻击牌 → 解锁
	state.hand.clear()
	state.draw_pile.clear()
	state.discard_pile.clear()
	for _i in 3:
		state.hand.append(CardDB.get_card("strike"))
	state.stage_card(0)
	state.stage_card(0)
	state.commit_staged()
	check(state.attack_plays_this_battle == 2, "本场已打出 2 张攻击牌")
	check(not state.sin_available, "还差 1 张，罪卡仍封锁")
	state.stage_card(0)
	state.commit_staged()
	check(state.attack_plays_this_battle == 3, "本场已打出 3 张攻击牌")
	check(state.sin_available, "任务达成，罪卡解锁")
	check(_log_contains(logs, "封印解开了"), "解锁日志出现")
	# 解锁后打过一张，再摸一张也不能再用
	state.hand.clear()
	state.hand.append(CardDB.get_card("wrath"))
	check(state.can_stage(CardDB.get_card("wrath")), "解锁后可以摆出")
	state.stage_card(0)
	check(state.commit_staged(), "罪卡打出")
	check(state.sin_used_this_battle, "本场标记已用")
	check(state.collection.has(CardDB.get_card("wrath")), "打出后进收藏不再离开")
	state.hand.append(CardDB.get_card("wrath"))
	check(not state.can_stage(CardDB.get_card("wrath")), "同一场第二张同 id 罪卡也被禁止")
	check(state.sin_lock_reason().contains("已经用过了"), "已用提示在")
	# 保底路径：新的一场只过回合不出攻击牌，第 8 回合解锁
	var state2 := _make_sin_state()
	state2.debug_force_plays = 0
	for _i in 7:
		state2.end_turn()
	check(state2.turn_count == 8, "已到第 8 回合")
	check(state2.sin_available, "8 回合保底解锁")
	check(state2.attack_plays_this_battle == 0, "全程没出攻击牌，纯保底")
	# 新的一场重新检定
	var state3 := _make_sin_state()
	state3.debug_force_plays = 0
	check(not state3.sin_available, "新一场战斗罪卡重新封锁")
	# 不带罪卡的牌组：罪卡检定整场不生效（手里拿到也不解锁不出）
	var state4 := _make_state()
	state4.debug_force_plays = 0
	check(state4.deck_sin_id == "", "牌组无罪卡时无检定对象")
	check(state4.sin_lock_reason() == "", "无罪卡时无封锁提示")
	check(not state4.can_stage(CardDB.get_card("wrath")), "罪卡不在牌组里时也摆不出")
	for _i in 8:
		state4.end_turn()
	check(not state4.sin_available, "无罪卡时过 8 回合也不解锁")


func test_new_card_effects() -> void:
	print("[新卡：重击 4 伤 / 坚守 3 格挡 / 转换抽 2]")
	var state := _make_state()
	state.debug_force_plays = 0
	state.hand.clear()
	state.hand.append(CardDB.get_card("heavy_strike"))
	state.stage_card(0)
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "重击 4 伤")
	# 坚守的格挡在「打出→敌人回合」之间生效；回合结束后清零，用击穿线反推本回合格挡量
	var state_g := _make_state()
	state_g.debug_force_plays = 2
	state_g.hand.clear()
	state_g.hand.append(CardDB.get_card("strong_guard"))
	state_g.stage_card(0)
	state_g.commit_staged()
	check(state_g.player_hp == BattleConfig.PLAYER_MAX_HP, "坚守 3 格挡挡下对方 2 点（同批结算生效）")
	# 转换：抽 2 张进手；结算后过一轮，弃牌堆洗回再摸 1 张（供给见底能摸几张是几张）
	var state2 := _make_state()
	state2.debug_force_plays = 0
	state2.hand.clear()
	state2.hand.append(CardDB.get_card("shift"))
	state2.draw_pile.clear()
	state2.discard_pile.clear()
	state2.draw_pile.append(CardDB.get_card("strike"))
	state2.draw_pile.append(CardDB.get_card("guard"))
	state2.stage_card(0)
	state2.commit_staged()
	check(state2.hand.size() == 3, "转换抽 2 张＋弃牌堆洗回再摸 1 张＝3 张")
	check(_find_card(state2.hand, "strike") >= 0 and _find_card(state2.hand, "guard") >= 0, "抽到的打击与护住都在手")
	var logs: Array = []
	var state3 := _make_state(logs)
	state3.debug_force_plays = 0
	state3.hand.clear()
	state3.hand.append(CardDB.get_card("shift"))
	state3.draw_pile.clear()
	state3.discard_pile.clear()
	state3.draw_pile.append(CardDB.get_card("strike"))
	state3.stage_card(0)
	state3.commit_staged()
	check(_log_contains(logs, "你抽了 1 张牌"), "抽牌日志记录实际张数")


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
	check(state.phase != BattleState.Phase.DEFEAT, "没有倒下")
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
	state.deck_sin_id = "wrath"
	state.sin_available = true  # 本测试只考 Cost 门槛，先放行罪卡检定
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


func test_defeat_flow() -> void:
	print("[判负：倒下不复活，回合不再推进]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 5
	var safety := 0
	while state.phase == BattleState.Phase.PLAYER and safety < 20:
		safety += 1
		state.end_turn()
	check(state.phase == BattleState.Phase.DEFEAT, "吃满伤害后倒下")
	check(state.player_hp == 0, "生命归零")
	check(_log_contains(logs, "得从头再来"), "判负读白出现")
	check(not state.end_turn(), "判负后结束回合被拒")
	check(not state.commit_staged(), "判负后不能结算")
	check(not state.stage_card(0), "判负后不能摆牌")


func test_practice_defeat() -> void:
	print("[练习战：倒下不判负，练习结束]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start_practice(["strike", "strike", "strike", "strike", "strike"])
	state._damage_player(BattleConfig.PLAYER_MAX_HP + 5)
	check(state.phase == BattleState.Phase.ENDED, "练习中倒下＝练习结束")
	check(state.player_hp == 0, "生命归零")
	check(_log_contains(logs, BattleConfig.TEXT_PRACTICE_DEFEAT), "练习判负读白")
	check(state.practice_end_text == BattleConfig.TEXT_PRACTICE_DEFEAT, "结束文案按败北切换")


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
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "打出后自动进入对方回合")
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
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 0, "还没过回合")
	state.end_turn()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 2, "结束时先结算摆好的打击")
	check(state.staged.is_empty(), "出牌区清空")
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "对方回合来过一次")
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
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "打出后自动过了一次对方回合")
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
	check(_log_contains(logs, BattleConfig.TEXT_ROUND_GAIN_ENEMY % ["贝尔芬格", 1]), "摸牌日志写着只获得 1 张")


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
	print("[完整流程：打赢 → 净化 → 收下 → 三问 → 结束]")
	var state := _make_state()
	state.debug_force_plays = 0
	_fight_until_over(state)
	check(state.phase == BattleState.Phase.STRIP, "打倒后进入净化时刻")
	check(state.enemy_hp == 0, "她归零了")
	check(state.collection.is_empty(), "净化前收藏为空")
	check(state.absorb_sin(), "拿起暴怒")
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
	check(state.enemy_name == "贝尔芬格" and state.enemy_max_hp == BattleConfig.ENEMY_MAX_HP, "教程模式对手是贝尔芬格")


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
	var pool_total := 0
	for card_id in BattleConfig.WAREHOUSE_INITIAL:
		pool_total += int(BattleConfig.WAREHOUSE_INITIAL[card_id])
	check(pool_total == 20, "仓库初始卡池共 20 张（攻击 7＋防御 5＋功能 8［含增幅 4］）")
	check(pool2.owned_count("strike") == 5 and pool2.owned_count("guard") == 3 and pool2.owned_count("call") == 2, "仓库打击 5、护住 3、呼喊 2")
	check(pool2.owned_count("quench") == 2 and pool2.owned_count("surge") == 1 and pool2.owned_count("bulwark") == 1, "仓库增幅牌：淬火 2、蓄能 1、筑壁 1")
	check(pool2.can_add("quench"), "增幅牌可以加进卡组")
	for _i in 3:
		pool2.add_to_deck("guard")
	for _i in 2:
		pool2.add_to_deck("call")
	check(pool2.deck.size() == 5, "全用防御/功能牌只能凑 5 张")
	check(not pool2.is_deck_valid(), "凑不满 8 张不合法")
	pool2.add_to_deck("strike")
	check(not pool2.is_deck_valid(), "有伤害牌但还没满 8 张仍不合法")
	var pool3 := CardPool.new()
	for _i in 8:
		pool3.deck.append("guard")
	check(not pool3.is_deck_valid(), "满 8 张但全无伤害牌不合法")
	check(not pool2.add_to_deck("guard"), "超过仓库数量不能加（护住只有 3 张）")


func test_amplify_cards() -> void:
	print("[增幅牌：弃掉触发的本回合加成]")
	# 淬火：弃掉后本回合伤害 +2；下回合回归
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.hand.clear()
	state.hand.append(CardDB.get_card("quench"))
	state.hand.append(CardDB.get_card("strike"))
	state.hand.append(CardDB.get_card("strike"))
	check(state.discard_for_cost(0) == 0, "弃淬火（1 费）+0 Cost")
	check(state.turn_attack_bonus == 2, "本回合伤害加成 +2")
	check(_log_contains(logs, "本回合你的伤害 +2"), "弃牌触发日志出现")
	check(state.stage_card(0), "摆一张打击")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "打击吃到加成（2+2=4 伤）")
	check(state.turn_attack_bonus == 0, "新回合加成归零")
	check(state.stage_card(0), "下回合再摆一张打击")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 6, "下回合回归 2 伤（累计 6）")
	# 蓄能：弃掉 → 获得 3 点 Cost（可超上限）
	var state2 := _make_state()
	state2.debug_force_plays = 0
	state2.hand.clear()
	state2.hand.append(CardDB.get_card("surge"))
	check(state2.discard_for_cost(0) == 0, "弃蓄能 +0 Cost")
	check(state2.player_cost == BattleConfig.PLAYER_MAX_COST + 3, "获得 Cost +3（15/12）")
	# 筑壁：弃掉 → 获得 3 点格挡，挡下本回合敌人 2 点
	var state3 := _make_state()
	state3.debug_force_plays = 2
	state3.hand.clear()
	state3.hand.append(CardDB.get_card("bulwark"))
	check(state3.discard_for_cost(0) == 0, "弃筑壁 +0 Cost")
	check(state3.player_block == 3, "格挡 +3")
	state3.end_turn()
	check(state3.player_hp == BattleConfig.PLAYER_MAX_HP, "挡下敌人 2 点")
	# 增幅牌不能摆放（打出），只能弃
	var state4 := _make_state()
	state4.hand.clear()
	state4.hand.append(CardDB.get_card("quench"))
	check(not state4.can_stage(CardDB.get_card("quench")), "增幅牌不可摆放")
	check(not state4.stage_card(0), "摆放被拒")
	check(state4.staged.is_empty(), "出牌区没进牌")
	# 强制弃牌（超限）不触发弃牌效果
	var state5 := _make_state()
	state5.debug_force_plays = 0
	for _i in 8:
		state5.hand.append(CardDB.get_card("strike"))
	state5.hand.append(CardDB.get_card("quench"))
	var quench_index := _find_card(state5.hand, "quench")
	check(quench_index >= 0, "超限手牌里有淬火")
	check(state5.discard_from_hand(quench_index), "强制弃牌成功")
	check(state5.turn_attack_bonus == 0, "强制弃牌不触发加成")


func test_card_stacking() -> void:
	print("[堆叠：同类合成一张、费用并入叠费、拆开还原]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.hand.clear()
	state.hand.append(CardDB.get_card("strike"))
	state.hand.append(CardDB.get_card("strike"))
	state.hand.append(CardDB.get_card("guard"))
	check(state.stage_card(0), "摆第一张打击")
	check(state.can_merge_with(state.hand[0], 0), "手牌打击可叠到出牌区打击上")
	check(state.merge_into_staged(0, 0), "拖叠成功")
	check(state.staged.size() == 1, "合成牌占同一卡槽（仍 1 张）")
	var merged: CardData = state.staged[0]
	check(merged.is_merged(), "标记为合成牌")
	check(merged.cost == 3, "费用 = 1+1+叠牌费 1 = 3")
	check(merged.display_name == "打击＋打击", "牌名以＋连接")
	check(merged.parts.size() == 2, "记录两张原牌")
	check(merged.text == "造成 4 点伤害。", "牌面文本合成为 4 伤")
	check(state.staged_cost() == 3, "出牌区合计费用 3")
	check(not state.can_merge_with(CardDB.get_card("guard"), 0), "异类不能叠（护住叠不进打击）")
	check(not state.can_merge_with(CardDB.get_card("quench"), 0), "增幅牌不能叠")
	state.hand.append(CardDB.get_card("wrath"))
	state.sin_available = true
	check(not state.can_merge_with(CardDB.get_card("wrath"), 0), "罪卡不能叠")
	check(state.commit_staged(), "打出合成牌")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "合成牌一次打出 4 伤")
	check(state.attack_plays_this_battle == 2, "攻击任务按原牌张数计（2 张）")
	check(state.discard_pile.size() == 2, "弃牌堆拆回两张原牌")
	check(state.discard_pile[0].id == "strike" and state.discard_pile[1].id == "strike", "弃牌堆里是原牌不是合成体")
	check(_log_contains(logs, "合成「打击＋打击」"), "合成日志出现")
	# 三张合成：费用 1+1+1+2×1=5；2+2+4=8 伤；累计 3 张攻击触发罪卡任务解锁
	var state2 := _make_sin_state()
	state2.debug_force_plays = 0
	state2.hand.clear()
	state2.hand.append(CardDB.get_card("strike"))
	state2.hand.append(CardDB.get_card("strike"))
	state2.hand.append(CardDB.get_card("heavy_strike"))
	state2.stage_card(0)
	state2.merge_into_staged(0, 0)
	check(state2.can_merge_with(state2.hand[0], 0), "重击可叠进打击＋打击（同大类）")
	check(state2.merge_into_staged(0, 0), "三张合成")
	check(state2.staged[0].cost == 5, "三张合成费用 = 3 张原费 + 2 次叠牌费 = 5")
	check(state2.staged[0].display_name == "打击＋打击＋重击", "三张牌名")
	state2.commit_staged()
	check(state2.enemy_hp == BattleConfig.ENEMY_MAX_HP - 8, "2+2+4=8 伤一次打出")
	check(state2.attack_plays_this_battle == 3, "三张攻击牌计 3")
	check(state2.sin_available, "任务达成，罪卡解锁")
	# 拆开：叠加后收回＝原牌逐张回手，叠牌费不花
	var state3 := _make_state()
	state3.hand.clear()
	state3.hand.append(CardDB.get_card("strike"))
	state3.hand.append(CardDB.get_card("strike"))
	state3.stage_card(0)
	state3.merge_into_staged(0, 0)
	state3.hand.append(CardDB.get_card("guard"))
	check(state3.recall_card(0), "收回合成牌")
	check(state3.staged.is_empty(), "出牌区清空")
	var strike_count := 0
	for card in state3.hand:
		if card.id == "strike":
			strike_count += 1
	check(strike_count == 2 and state3.hand.size() == 3, "拆成两张打击＋护住回手")
	# 5 槽满仍可叠（不新增卡槽，绕过槽上限）
	var state4 := BattleState.new()
	var deck: Array = []
	for _i in 8:
		deck.append("strike")
	state4.start(deck)
	for _i in 5:
		state4.stage_card(0)
	check(state4.staged.size() == BattleConfig.PLAY_ZONE_SIZE, "五张全部摆进（槽满）")
	state4.gain_card(CardDB.get_card("strike"))
	check(not state4.can_stage(state4.hand[0]), "槽满后不能再摆")
	check(state4.can_merge_with(state4.hand[0], 0), "槽满仍可叠（不新增卡槽）")
	check(state4.merge_into_staged(0, 0), "叠进第一张")
	check(state4.staged.size() == BattleConfig.PLAY_ZONE_SIZE, "卡槽数不变")
	check(state4.staged[0].cost == 3, "合成牌费用 3")
	# 费不够不能叠：回退为普通摆放
	var state5 := BattleState.new()
	var deck2: Array = []
	for _i in 8:
		deck2.append("strike")
	state5.start(deck2)
	state5.player_cost = 2
	state5.stage_card(0)
	check(not state5.can_merge_with(state5.hand[0], 0), "费不够不能叠（1+1+1=3 > 2）")
	check(state5.stage_card(0), "费刚好时仍可直接再摆一张")
	check(state5.staged.size() == 2, "费不够时回退为普通摆放")


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
	check(state.phase == BattleState.Phase.ENDED, "打空血量后直接结束（不过净化）")
	check(_log_contains(logs, BattleConfig.TEXT_PRACTICE_END), "结束读白出现")
	check(state.collection.is_empty(), "练习没有罪卡")
	check(not state.absorb_sin(), "练习结束后也没有拿起环节")


func test_layer_data() -> void:
	print("[层数据：八层表 / 占位池 / 路线随机生成 / 局内进度]")
	check(LayerConfig.MAX_LAYER == 8, "共八层")
	check(LayerConfig.layer_name(1) == "懒惰" and LayerConfig.demon_name(1) == "贝尔芬格", "第 1 层懒惰·贝尔芬格")
	check(LayerConfig.layer_name(2) == "色欲" and LayerConfig.demon_name(2) == "阿斯莫德", "第 2 层色欲·阿斯莫德")
	check(LayerConfig.layer_name(8) == "同位体" and LayerConfig.demon_name(8) == "贝嘉", "第 8 层同位体·贝嘉")
	# 占位池（作战 4＋事件 5；层主独立）
	check(LayerConfig.LAYER2_BATTLES.size() == 4, "作战池 4 项")
	check(LayerConfig.LAYER2_EVENTS.size() == 5, "事件池 5 项")
	check(LayerConfig.LAYER2_BOSS.get("boss", false) and String(LayerConfig.LAYER2_BOSS.get("enemy", "")) == "阿斯莫德", "层主独立不入池")
	for battle in LayerConfig.LAYER2_BATTLES:
		check(String(battle.get("type", "")) == LayerConfig.TYPE_BATTLE and String(battle.get("enemy", "")) != "" and int(battle.get("enemy_hp", 0)) > 0 and not (battle.get("enemy_deck", {}) as Dictionary).is_empty(), "作战池字段完整：" + String(battle.get("enemy", "")))
	for event_item in LayerConfig.LAYER2_EVENTS:
		check(String(event_item.get("title", "")) != "" and String(event_item.get("scene", "")) != "" and (event_item.get("choices", []) as Array).size() == 3 and (event_item.get("feedback", []) as Array).size() == 3, "事件池字段完整：" + String(event_item.get("title", "")))
	# 生成器不变量（种子化批量掷路线）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	var min_cols := 99
	var max_cols := 0
	var min_nodes := 99
	var max_nodes := 0
	for roll in 40:
		var route := LayerConfig.generate_route(2, rng)
		var cols := route.size()
		min_cols = mini(min_cols, cols)
		max_cols = maxi(max_cols, cols)
		check(cols >= LayerConfig.ROUTE_MIN_COLUMNS and cols <= LayerConfig.ROUTE_MAX_COLUMNS, "列数 2–4（第 %d 掷：%d 列）" % [roll, cols])
		var boss_column: Array = route[cols - 1]
		check(boss_column.size() == 1 and boss_column[0].get("boss", false), "末列＝层主战唯一节点")
		var seen := {}
		for c in cols - 1:
			var column: Array = route[c]
			min_nodes = mini(min_nodes, column.size())
			max_nodes = maxi(max_nodes, column.size())
			check(column.size() >= LayerConfig.ROUTE_MIN_NODES and column.size() <= LayerConfig.ROUTE_MAX_NODES, "普通列 1–3 节点")
			for stage in column:
				var key := String(stage.get("enemy", stage.get("title", "")))
				check(not seen.has(key), "全图不重复：" + key)
				seen[key] = true
	check(min_cols == LayerConfig.ROUTE_MIN_COLUMNS and max_cols == LayerConfig.ROUTE_MAX_COLUMNS, "40 掷里 2 列与 4 列都出现过")
	check(min_nodes == LayerConfig.ROUTE_MIN_NODES and max_nodes == LayerConfig.ROUTE_MAX_NODES, "40 掷里 1 节点与 3 节点列都出现过")
	check(LayerConfig.generate_route(1, rng).is_empty(), "教程层不走路线表")
	check(LayerConfig.generate_route(3, rng).is_empty(), "第 3 层起内容待设计轮")
	# 同种子可复现
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	check(_route_signature(LayerConfig.generate_route(2, rng_a)) == _route_signature(LayerConfig.generate_route(2, rng_b)), "同种子同路线")
	check(LayerConfig.transition_lines(2).size() == 3, "第 2 层有上行过渡读白")
	check(LayerConfig.transition_lines(1).is_empty(), "第 1 层过渡走教程结尾读白")
	# RunState：进层懒生成一次、层内稳定；四态；死亡重掷（重生成）＋夹具行进
	var run := RunState.new()
	check(run.current_layer == 2, "教程完成后的目标是第 2 层")
	check(not run.is_layer_unlocked(2), "未过教程时第 2 层锁定")
	check(run.is_layer_unlocked(1), "教程层始终可进")
	run.tutorial_done = true
	check(run.is_layer_cleared(1), "教程完成后第 1 层已净化")
	check(run.is_layer_unlocked(2), "第 2 层解锁")
	check(not run.is_layer_unlocked(3), "第 3 层无内容仍锁定")
	run.rng.seed = 424242
	var generated := run.current_columns()
	check(generated.size() >= LayerConfig.ROUTE_MIN_COLUMNS and (generated[generated.size() - 1][0] as Dictionary).get("boss", false), "首次读取生成合法路线")
	check(_route_signature(run.current_columns()) == _route_signature(generated), "层内重复读取同一路线（缓存）")
	var sig_before := _route_signature(generated)
	check(run.column_index == 0 and not run.is_route_finished(), "开局在第一列")
	run.reset_layer()
	check(run.route_layer == -1, "死亡后路线缓存失效")
	check(_route_signature(run.current_columns()) != sig_before, "死亡重掷＝重新生成新路线")
	# 夹具注入：四态推进与完成（随机性已单独覆盖）
	run.route = _fixture_route()
	run.route_layer = run.current_layer
	check(run.node_state(0, 0) == RunState.NodeState.CURRENT, "第一列节点当前可选")
	check(run.node_state(1, 0) == RunState.NodeState.FUTURE, "第二列未到")
	var picked := run.choose(2)
	check(String(picked.get("title", "")) == "镜阶", "选下节点返回该关卡")
	check(run.column_index == 1, "选路推进到第二列")
	check(run.node_state(0, 2) == RunState.NodeState.DONE, "已走节点＝已走")
	check(run.node_state(0, 0) == RunState.NodeState.MISSED, "同列未选＝错失")
	check(run.node_state(1, 1) == RunState.NodeState.CURRENT, "第二列当前可选")
	check(String(run.choose(0).get("enemy", "")) == "残响回廊", "第二列选作战节点")
	check(not run.is_route_finished(), "还剩层主战")
	check(run.choose(0).get("boss", false), "第三列选层主战")
	check(run.is_route_finished(), "路线走完")
	check(run.choose(0).is_empty(), "越界选择返回空")
	run.reset_layer()
	check(run.route_layer == -1, "死亡（含夹具）同样失效路线缓存待重掷")
	check(run.column_index == 0 and not run.is_route_finished(), "死亡重置回第一列")
	run.collect_sin("lust")
	run.collect_sin("lust")
	check(run.sin_cards.size() == 1, "罪卡收集不重复")
	run.add_companion("阿斯莫德")
	check(run.companions.has("阿斯莫德"), "层主同行入列")
	run.complete_layer()
	check(run.current_layer == 3, "层完成上行到第 3 层")
	check(run.column_index == 0 and run.chosen.is_empty(), "上行后选路记录清空")
	check(not run.is_layer_unlocked(3), "第 3 层仍锁定（待续）")
	check(run.is_demo_end(), "到达 demo 边界")


func test_card_pool_sin() -> void:
	print("[罪卡入仓与卡组约束：最多一张]")
	var pool := CardPool.new()
	check(pool.owned_count("wrath") == 0, "初始没有罪卡")
	check(not pool.is_sin_card("strike") and pool.is_sin_card("wrath"), "罪卡识别")
	check(not pool.add_to_deck("wrath"), "仓库没有时加不进卡组")
	pool.collect_sin("wrath")
	check(pool.owned_count("wrath") == 1, "收下后仓库有这张罪卡")
	pool.collect_sin("wrath")
	check(pool.owned_count("wrath") == 1, "重复收下不叠加")
	pool.collect_sin("lust")
	check(pool.owned_count("lust") == 1, "不同罪卡各自入仓")
	check(pool.add_to_deck("wrath"), "罪卡可以放进卡组")
	check(pool.sin_in_deck(), "卡组里有罪卡")
	check(not pool.add_to_deck("lust"), "卡组已有罪卡时不能再放第二张")
	check(pool.remove_from_deck("wrath"), "罪卡可以移出")
	check(not pool.sin_in_deck(), "移出后卡组无罪卡")
	check(pool.add_to_deck("lust"), "换一张罪卡进卡组")


func test_story_battle_small() -> void:
	print("[层战·小怪：胜利直接结束，不过净化]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start_story(["strike", "strike", "strike", "strike", "strike"], _pool_battle("污染体"))
	check(state.mode == BattleState.Mode.STORY, "层战模式")
	check(state.enemy_name == "污染体" and state.enemy_max_hp == 20, "对手与血量按关卡配置")
	check(not state.is_boss, "小怪战非层主")
	check(state.sin_card_id == "", "小怪战无收下环节")
	state.debug_force_plays = 0
	var safety := 0
	while state.phase == BattleState.Phase.PLAYER and safety < 120:
		safety += 1
		_turn_cycle(state, ["strike"])
	check(state.phase == BattleState.Phase.ENDED, "打空后直接结束")
	check(_log_contains(logs, BattleConfig.TEXT_STAGE_WIN), "小怪战胜利读白")
	check(not state.absorb_sin(), "小怪战没有收下环节")


func test_story_battle_boss() -> void:
	print("[层战·层主：胜利走净化与收下，罪卡按关卡]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	var stage: Dictionary = LayerConfig.LAYER2_BOSS
	state.start_story(["strike", "strike", "strike", "strike", "strike"], stage)
	check(state.enemy_name == "阿斯莫德" and state.enemy_max_hp == 24, "层主名与血量按关卡")
	check(state.is_boss, "层主战")
	check(state.sin_card_id == "lust", "本场收下的罪卡＝色欲")
	check(String(state.strip_lines[0]).contains("粉色的裙摆"), "净化时刻读白按关卡")
	state.debug_force_plays = 0
	var safety := 0
	while state.phase == BattleState.Phase.PLAYER and safety < 120:
		safety += 1
		_turn_cycle(state, ["strike"])
	check(state.phase == BattleState.Phase.STRIP, "打倒层主进入净化时刻")
	check(state.absorb_sin(), "拿起色欲")
	check(state.collection.size() == 1 and state.collection[0].id == "lust", "色欲进收藏")
	check(state.phase == BattleState.Phase.DEBRIEF, "进入净化读白")
	check(state.finish_debrief(), "读完即结束（层战无三问）")
	check(state.phase == BattleState.Phase.ENDED, "层战结束")
	# 牌组里带罪卡：本场检定对象＝色欲，任务参数按 Lust 配置
	var state2 := BattleState.new()
	state2.start_story(["lust", "strike", "strike", "strike", "strike"], stage)
	check(state2.deck_sin_id == "lust", "牌组里的色欲被识别为检定对象")
	check(state2.sin_lock_reason().contains("（0/2）"), "色欲任务进度 0/2")
	check(not state2.sin_available, "开局封锁")


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
	check((scene.get_node("%EnemyNameLabel") as Label).text == "贝尔芬格", "敌人名显示贝尔芬格")
	var enemy_hand_label := scene.get_node("%EnemyHandLabel") as Label
	check(enemy_hand_label.visible and enemy_hand_label.text == "手牌 5 张", "敌人手牌张数显示 5 张")
	check(not overlay.visible, "开局不弹覆盖层（召唤告知已上移到主流程）")
	check(not (scene.get_node("%QuitPracticeButton") as Button).visible, "教程模式不显示结束练习")
	check(hand_box.get_child_count() == 5, "开局手牌 5 张")
	check(play_box.get_child_count() == BattleConfig.PLAY_ZONE_SIZE, "出牌区有 5 个卡槽")
	check(commit_button.disabled and commit_button.text == "打出", "空出牌区时「打出」置灰")
	check(timer_label.text == "剩余 45 秒", "开局计时 45 秒")
	var cost_label := scene.get_node("%CostLabel") as Label
	_check_cost_label(scene, "Cost 12 / 12", "开局 Cost 显示 12/12")
	var first_strike := _first_live_button(hand_box, "打击")
	check(first_strike != null, "手里有打击")
	check(first_strike.drag_zone == "hand", "手牌处于可拖状态")
	check(_drag_card_to(scene, first_strike, play_box), "拖手牌到出牌区")
	check(scene.state.staged.size() == 1, "拖拽摆进出牌区")
	_check_cost_label(scene, "Cost 11 / 12", "摆放后可用 Cost 实时下调（11/12，摆放不扣实扣）")
	check(commit_button.text == "打出（Cost -1）", "打出按钮预告合计 Cost")
	var staged_button := _first_live_button(play_box, "打击")
	check(staged_button != null, "出牌区出现已摆的牌")
	staged_button.pressed.emit()
	check(scene.state.staged.is_empty(), "点击已摆的牌收回")
	_check_cost_label(scene, "Cost 12 / 12", "收回后可用 Cost 实时恢复（12/12）")
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
	_check_cost_label(scene, "Cost 12 / 12", "打出即结束回合，新回合 Cost 重置满")
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
	check(scene.state.phase == BattleState.Phase.STRIP, "拖拽流程进入净化时刻")
	check(overlay.visible, "净化覆盖层出现")
	var strip_hand_locked := true
	for child in hand_box.get_children():
		var card_button := child as CardButton
		if card_button != null and not card_button.is_queued_for_deletion() and not card_button.disabled:
			strip_hand_locked = false
	check(strip_hand_locked, "净化时刻手牌全部禁用（不可拖拽）")
	check(story.text.contains("滚烫的白火"), "净化时刻读白在屏上")
	var absorb_button := scene.get_node("%AbsorbButton") as Button
	check(absorb_button.visible, "拿起按钮出现")
	absorb_button.pressed.emit()
	check(scene.state.phase == BattleState.Phase.DEBRIEF, "收下罪卡进入净化")
	check(story.text.contains("净化不会让罪消失"), "净化读白在屏上")
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
	_check_cost_label(scene, "Cost 12 / 12", "练习模式也是同一套 Cost")
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


func test_battle_scene_defeat() -> void:
	print("[战斗场景·判负：覆盖层＋battle_lost，不发 battle_ended]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	scene.configure(BattleState.Mode.STORY, ["strike", "strike", "strike", "strike", "strike"], _pool_battle("污染体"))
	var viewport := _attach_scene(scene)
	await process_frame
	var lost_calls: Array = []
	var ended_calls: Array = []
	scene.battle_lost.connect(func() -> void: lost_calls.append(true))
	scene.battle_ended.connect(func(practice: bool) -> void: ended_calls.append(practice))
	scene.state.debug_force_plays = 5
	var safety := 0
	while scene.state.phase == BattleState.Phase.PLAYER and safety < 20:
		safety += 1
		scene.state.end_turn()
	check(scene.state.phase == BattleState.Phase.DEFEAT, "层战判负")
	var overlay := scene.get_node("%Overlay") as Control
	check(overlay.visible, "判负覆盖层出现")
	check((scene.get_node("%StoryText") as Label).text.contains("得从头再来"), "判负读白在屏上")
	var continue_button := scene.get_node("%ContinueButton") as Button
	check(continue_button.text == BattleConfig.TEXT_DEFEAT_BUTTON, "按钮＝重新开始本层")
	continue_button.pressed.emit()
	check(lost_calls == [true], "发出 battle_lost")
	check(ended_calls.is_empty(), "判负不自行发 battle_ended（等主流程处理）")
	viewport.queue_free()
	await process_frame


func test_map_page() -> void:
	print("[层地图页：三态＋当前层展开路线图（节点四态）]")
	var page := MapPage.new()
	var viewport := _attach_scene(page)
	await process_frame
	var run := RunState.new()
	run.tutorial_done = true
	# 注入夹具路线（固定 3/2/1 列），覆盖 ✓/✕/当前/未到四态；随机性由 test_layer_data 覆盖
	run.route = _fixture_route()
	run.route_layer = run.current_layer
	var picks: Array = []
	page.node_requested.connect(func(index: int) -> void: picks.append(index))
	page.build(run)
	check(page.visible, "地图页在屏")
	var layer1 := _deep_find_button(page, "第 1 层·懒惰")
	check(layer1 != null and layer1.text.contains("已净化"), "第 1 层已净化")
	check(layer1.disabled, "已净化层不可点（只有未解锁层可点）")
	var layer2 := _deep_find_button(page, "第 2 层·色欲")
	check(layer2 != null and layer2.text.contains("当前"), "第 2 层当前")
	var layer3 := _deep_find_button(page, "第 3 层·暴食")
	check(layer3 != null and layer3.text.contains("待续") and not layer3.disabled, "第 3 层待续可点")
	layer3.pressed.emit()
	check(page._toast.visible and page._toast.text.contains("待续"), "点未解锁层提示待续")
	var fog := _deep_find_button(page, "事件·粉雾")
	var pol1 := _deep_find_button(page, "作战·污染体")
	var mirror := _deep_find_button(page, "事件·镜阶")
	check(fog != null and not fog.disabled, "第一列事件节点可选")
	check(pol1 != null and not pol1.disabled, "同列作战节点也可选")
	check(mirror != null and not mirror.disabled, "同列第三个节点可选")
	var echo := _deep_find_button(page, "作战·残响回廊")
	check(echo != null and echo.disabled, "下一列节点未到不可点")
	var boss_node := _deep_find_button(page, "层主战·阿斯莫德")
	check(boss_node != null and boss_node.disabled, "层主战节点未到不可点")
	fog.pressed.emit()
	check(picks == [0], "点击节点发出 node_requested(0)")
	run.choose(0)
	page.build(run)
	await process_frame
	var fog_after := _deep_find_button(page, "事件·粉雾")
	check(fog_after.text.contains("✓") and fog_after.disabled, "已走节点标 ✓ 不可再点")
	var pol_after := _deep_find_button(page, "作战·污染体")
	check(pol_after.text.contains("✕") and pol_after.disabled, "同列未选标 ✕ 错失")
	var echo_after := _deep_find_button(page, "作战·残响回廊")
	check(echo_after != null and not echo_after.disabled, "推进后第二列可选")
	var candle_after := _deep_find_button(page, "事件·烛台走廊")
	check(candle_after != null and not candle_after.disabled, "第二列事件节点可选")
	check(_deep_find_button(page, "返回菜单") != null and _deep_find_button(page, "进入练习站") != null, "地图底部有练习站与菜单入口")
	viewport.queue_free()
	await process_frame


func test_event_page() -> void:
	print("[事件页：三选一 → 就地反馈 → 完成]")
	var page := EventPage.new()
	var viewport := _attach_scene(page)
	await process_frame
	var done: Array = []
	page.completed.connect(func() -> void: done.append(true))
	var stage: Dictionary = _pool_event("粉雾")
	page.show_event(stage)
	check(page._title.text == "粉雾", "标题按关卡")
	check(page._scene.text.contains("淡粉色的雾"), "场景说明在屏上")
	check(page._choices_box.get_child_count() == 3, "三个选项按钮")
	var complete_button := page._complete_button as Button
	check(complete_button.disabled, "未选择不能完成")
	var choice0 := page._choices_box.get_child(0) as Button
	choice0.pressed.emit()
	check(page._feedback.text == String(stage["feedback"][0]), "选择后展出对应反馈")
	check(not complete_button.disabled, "选择后可以完成")
	check(choice0.disabled, "选择后选项锁定（只能选一次）")
	complete_button.pressed.emit()
	check(done == [true], "发出 completed")
	# 第二个占位事件（烛台走廊）同样能上屏（等一帧清掉旧选项按钮）
	var candle: Dictionary = _pool_event("烛台走廊")
	page.show_event(candle)
	await process_frame
	check(page._title.text == "烛台走廊", "第二列事件节点数据完整")
	check(page._choices_box.get_child_count() == 3, "烛台走廊三个选项")
	check(page._feedback.text == "" and complete_button.disabled, "重开后反馈清空、完成按钮复位")
	viewport.queue_free()
	await process_frame


func test_transition_page() -> void:
	print("[过渡页：读白分段＋插画缺失时纯色回退]")
	var page := TransitionPage.new()
	var viewport := _attach_scene(page)
	await process_frame
	var done: Array = []
	page.continued.connect(func() -> void: done.append(true))
	page.show_transition(["第一行", "第二行"])
	check(page._read_text.text == "第一行\n\n第二行", "读白按双换行分段")
	var has_png := FileAccess.file_exists("res://assets/sprites/ui/transition_climb.png")
	check(page._illustration.visible == has_png, "插画存在则显示，缺失则纯色回退")
	var continue_button := _first_live_button(page, "继续")
	check(continue_button != null, "继续按钮在")
	continue_button.pressed.emit()
	check(done == [true], "发出 continued")
	viewport.queue_free()
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
	if strike_button == null:
		viewport.queue_free()
		await process_frame
		return
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
	# 本测试只验拖拽/悬停 UI：钉死罪卡为本场检定对象并解锁，不混入封印逻辑
	scene.state.deck_sin_id = "wrath"
	scene.state.sin_available = true
	_check_cost_label(scene, "Cost 12 / 12", "弃牌前 Cost 12 / 12")
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
	_check_cost_label(scene, "Cost 17 / 12", "弃 6 费牌 +5，Cost 超上限（17/12）")
	check(discard_zone_label.text.contains("+5"), "弃牌区显示本回合已获得 +5")
	check(_find_card(scene.state.discard_pile, "wrath") >= 0, "弃掉的暴怒进弃牌堆")
	var strike_to_discard := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, strike_to_discard, discard_zone), "1 费牌也能拖去弃掉")
	_check_cost_label(scene, "Cost 17 / 12", "1 费牌弃掉 +0，Cost 不变")
	var play_strike2 := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, play_strike2, play_box), "摆一张打击准备打出")
	scene.state.debug_force_plays = 0
	(scene.get_node("%CommitButton") as Button).pressed.emit()
	check(scene.state.staged.is_empty(), "打出后出牌区清空")
	check(scene.state.phase == BattleState.Phase.PLAYER, "打出即结束回合，回到新回合")
	_check_cost_label(scene, "Cost 12 / 12", "新回合 Cost 重置回 12 / 12")
	check(discard_zone_label.text.contains("+0"), "弃牌区回合计数归零")
	var strike_after_commit := _first_live_button(hand_box, "打击")
	check(strike_after_commit != null, "新回合手里仍有打击")
	if strike_after_commit != null:
		_drag_card_to(scene, strike_after_commit, play_box)
	check(scene.state.staged.size() == 1, "新回合可以继续摆放")
	viewport.queue_free()
	await process_frame


func test_scene_stacking() -> void:
	print("[战斗场景·堆叠与增幅：拖叠合成 → 拆开 → 弃增幅加成 → 打出]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	scene.configure(BattleState.Mode.PRACTICE, ["strike", "strike", "guard", "quench", "surge"])
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var discard_zone := scene.get_node("%DiscardZone") as PanelContainer
	var discard_zone_label := scene.get_node("%DiscardZoneLabel") as Label
	var block_label := scene.get_node("%PlayerBlockLabel") as Label
	# 拖叠：两张打击合成一张（费用 3）
	var strike_a := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, strike_a, play_box), "摆第一张打击")
	_check_cost_label(scene, "Cost 11 / 12", "摆放后可用 Cost 11/12")
	await process_frame  # 等容器重排完成，新卡牌 rect 才可命中
	var strike_b := _first_live_button(hand_box, "打击")
	check(strike_b != null, "手里还有第二张打击")
	var staged_button := _first_live_button(play_box, "打击")
	var drag_data: Variant = strike_b._get_drag_data(Vector2.ZERO)
	var staged_point: Vector2 = scene.get_global_transform().affine_inverse() * staged_button.get_global_rect().get_center()
	check(scene._can_drop_data(staged_point, drag_data), "悬停同类已摆牌被接受")
	check((staged_button as CardButton).is_merge_highlighted(), "可叠目标描金高亮")
	scene._drop_data(staged_point, drag_data)
	check(scene.state.staged.size() == 1, "合成为一张，占同一卡槽")
	check(scene.state.staged[0].display_name == "打击＋打击" and scene.state.staged[0].cost == 3, "合成牌 打击＋打击，费用 3")
	check(_count_live_card_buttons(hand_box) == 3, "手牌消耗一张（5→4→3）")
	_check_cost_label(scene, "Cost 9 / 12", "合成后出牌区合计 3，可用 Cost 9/12")
	var merged_button := _first_live_button(play_box, "打击＋打击")
	check(merged_button != null, "出牌区显示合成牌")
	# 拖回拆开：两张原牌回手，费用不花
	check(_drag_card_to(scene, merged_button, hand_box), "拖回手牌区")
	check(scene.state.staged.is_empty(), "出牌区清空")
	check(_count_live_card_buttons(hand_box) == 5, "拆开回手两张，手牌回到 5")
	_check_cost_label(scene, "Cost 12 / 12", "拆开后 Cost 复原 12/12")
	# 增幅牌：灰显、不可摆、拖拽悬停出现触发预告
	var quench_button := _first_live_button(hand_box, "淬火")
	check(quench_button != null and quench_button.modulate.r < 1.0, "增幅牌灰显（不可摆放）")
	check(quench_button.tooltip_text.contains("不能打出"), "增幅牌提示说明玩法")
	var quench_data: Variant = quench_button._get_drag_data(Vector2.ZERO)
	var discard_point: Vector2 = scene.get_global_transform().affine_inverse() * discard_zone.get_global_rect().get_center()
	check(scene._can_drop_data(discard_point, quench_data), "增幅牌只能投弃牌区")
	check(scene._drag_target_now == "discard", "悬停目标为弃牌区")
	check(discard_zone_label.text.contains("弃掉「淬火」") and discard_zone_label.text.contains("本回合伤害 +2"), "弃牌预告显示触发效果")
	scene._drop_data(discard_point, quench_data)
	check(scene.state.turn_attack_bonus == 2, "弃掉淬火，本回合伤害 +2")
	check(block_label.text.contains("本回合攻击 +2"), "状态行显示本回合加成")
	check(_find_card(scene.state.discard_pile, "quench") >= 0, "淬火进弃牌堆")
	# 加成在打出时生效（2+2=4），下一回合回归
	var strike_c := _first_live_button(hand_box, "打击")
	check(_drag_card_to(scene, strike_c, play_box), "摆一张打击吃加成")
	(scene.get_node("%CommitButton") as Button).pressed.emit()
	check(scene.state.enemy_hp == BattleConfig.PRACTICE_ENEMY_HP - 4, "打击 2+2=4 伤（木桩 48→44）")
	check(scene.state.turn_attack_bonus == 0, "新回合加成归零")
	check(not block_label.text.contains("本回合攻击"), "状态行加成收起")
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
	_check_cost_label(scene, "Cost 11 / 12", "引擎级拖拽摆放后左上角可用 Cost 实时下调（11/12）")
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
		_check_cost_label(scene, "Cost 12 / 12", "引擎级拖回后左上角可用 Cost 实时恢复（12/12）")
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
		_check_cost_label(scene, "Cost 17 / 12", "引擎级拖拽弃牌 +5（17/12）")
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
	await process_frame  # 等容器重排完成，出牌区新按钮 rect 才可命中
	# 引擎级拖叠：手里剩下的打击拖到出牌区已摆的打击上 → 合成一张（描金高亮 → 松手合成）
	var merge_from_button := _first_live_button(hand_box, "打击")
	check(merge_from_button != null, "手里还有打击可拖（用于叠）")
	if merge_from_button != null and scene.state.staged.size() == 1:
		var staged_target := _first_live_button(play_box, "打击")
		check(staged_target != null, "出牌区有打击作为叠合目标")
		if staged_target != null:
			var merge_from: Vector2 = merge_from_button.get_global_rect().get_center()
			var merge_to: Vector2 = staged_target.get_global_rect().get_center()
			_push_mouse_button(viewport, merge_from, true)
			_push_mouse_motion(viewport, merge_from + Vector2(10.0, -10.0))
			_push_mouse_motion(viewport, merge_to)
			check(scene._drag_target_now == "play", "悬停合成目标时仍记为出牌区")
			check((staged_target as CardButton).is_merge_highlighted(), "叠合目标描金高亮")
			_push_mouse_button(viewport, merge_to, false)
			check(scene.state.staged.size() == 1, "合成后仍占一个卡槽")
			check(scene.state.staged[0].is_merged() and scene.state.staged[0].cost == 3, "引擎拖叠合成，费用 3（1+1+叠费）")
			check(_count_live_card_buttons(hand_box) == 3, "合成消耗一张手牌")
			_check_cost_label(scene, "Cost 14 / 12", "合成后出牌区 3，可用 Cost 14（17-3）")
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
	check(scene.state.card_merged.is_connected(scene._on_card_merged), "合成信号已接线")
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
	print("[主流程：告知 → 菜单 → 教学 → 练习站组卡 → 木桩 → 转化 → 教程战 → 三问 → 菜单]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var story_page := main.get_node("%StoryPage") as Control
	var menu_page := main.get_node("%MenuPage") as Control
	var practice_page := main.get_node("%PracticePage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	check(story_page.visible, "开场在读白页")
	check(not menu_page.visible, "开场菜单页隐藏")
	check(story.text.contains("八层"), "召唤告知：世界是八层")
	check(story.text.contains("清空"), "召唤告知：目标只说清空血量")
	check(not story.text.contains("净化") and not story.text.contains("收下"), "告知边界：不提前提净化/收下")
	check(not secondary.visible, "开场单按钮")
	primary.pressed.emit()
	check(menu_page.visible, "读白后进入入口菜单")
	check(not story_page.visible, "读白页收起")
	var menu_continue := main.get_node("%MenuContinueButton") as Button
	var menu_practice := main.get_node("%MenuPracticeButton") as Button
	check(menu_continue.text == "继续剧情", "未看过教学时按钮为继续剧情")
	check(menu_practice.visible, "菜单提供练习站入口")
	menu_continue.pressed.emit()
	check(story_page.visible and not menu_page.visible, "继续剧情回到读白页")
	check(story.text.contains("打击") and story.text.contains("护住"), "教学读白在屏上")
	check(not story.text.contains("净化"), "教学段也不提净化")
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
	check(not story.text.contains("净化"), "告知边界：转化页也不提净化")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "教程战进入战斗位")
	var battle2: Variant = battle_host.get_child(0)
	check(battle2.state.mode == BattleState.Mode.TUTORIAL, "是教程模式")
	check(battle2.state.enemy_name == "贝尔芬格", "对手是贝尔芬格")
	_check_cost_label(battle2, "Cost 12 / 12", "教程战 Cost 显示 12/12")
	check(battle2.state.draw_pile.size() + battle2.state.hand.size() == BattleConfig.DECK_SIZE, "教程战用练习站自组的 8 张卡组")
	battle2.state.debug_force_plays = 0
	await process_frame
	_press_strikes_until_over(battle2)
	check(battle2.state.phase == BattleState.Phase.STRIP, "打倒贝尔芬格进入净化时刻")
	check((battle2.get_node("%Overlay") as Control).visible, "净化覆盖层出现")
	(battle2.get_node("%AbsorbButton") as Button).pressed.emit()
	check(battle2.state.collection.size() == 1, "罪卡收下")
	var cont2 := battle2.get_node("%ContinueButton") as Button
	cont2.pressed.emit()
	cont2.pressed.emit()
	cont2.pressed.emit()
	cont2.pressed.emit()
	check(battle2.state.phase == BattleState.Phase.ENDED, "三问走完")
	await process_frame
	var transition_page := main.get_node("%TransitionPage") as Control
	var map_page := main.get_node("%MapPage") as Control
	check(transition_page.visible, "教程战结束进入上行过渡页")
	check((transition_page._read_text as Label).text.contains("贝尔芬格"), "同行过渡读白在屏上")
	check(main.run.tutorial_done, "教程标记完成")
	check(main.run.companions.has("贝尔芬格"), "贝尔芬格入同行列")
	var trans_continue := _first_live_button(transition_page, "继续")
	check(trans_continue != null, "过渡页有继续按钮")
	trans_continue.pressed.emit()
	check(map_page.visible, "过渡后进入层地图")
	var layer1_row := _deep_find_button(map_page, "第 1 层·懒惰")
	check(layer1_row != null and layer1_row.text.contains("已净化"), "第 1 层已净化")
	var layer2_row := _deep_find_button(map_page, "第 2 层·色欲")
	check(layer2_row != null and layer2_row.text.contains("当前"), "第 2 层当前")
	var layer3_row := _deep_find_button(map_page, "第 3 层·暴食")
	check(layer3_row != null and layer3_row.text.contains("待续"), "第 3 层待续")
	var map_menu_button := _deep_find_button(map_page, "返回菜单")
	check(map_menu_button != null, "地图有返回菜单入口")
	map_menu_button.pressed.emit()
	check(menu_page.visible, "地图可回入口菜单")
	check(menu_continue.text == "继续剧情", "教程完成后菜单按钮为继续剧情")
	menu_continue.pressed.emit()
	check(map_page.visible, "继续剧情直达层地图")
	viewport.queue_free()
	await process_frame


func test_main_flow_skip_practice() -> void:
	print("[主流程·跳过练习：默认卡组打教程战]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var story_page := main.get_node("%StoryPage") as Control
	var menu_page := main.get_node("%MenuPage") as Control
	var practice_page := main.get_node("%PracticePage") as Control
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	var battle_host := main.get_node("%BattleHost") as Control
	primary.pressed.emit()
	check(menu_page.visible, "读白后进入入口菜单")
	# 菜单里的练习站入口随时可用：进站又原样退出（未看教学 → 回菜单）
	(main.get_node("%MenuPracticeButton") as Button).pressed.emit()
	check(practice_page.visible, "菜单可直达练习站")
	(main.get_node("%LeavePracticeButton") as Button).pressed.emit()
	check(menu_page.visible, "未看教学时退出练习站回菜单")
	(main.get_node("%MenuContinueButton") as Button).pressed.emit()
	check(story_page.visible, "继续剧情进入教学读白")
	secondary.pressed.emit()
	check(story.text.contains("清空"), "转化读白在屏上")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "直接进入教程战")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.mode == BattleState.Mode.TUTORIAL, "教程模式")
	check(battle.state.hand.size() == BattleConfig.HAND_SIZE, "没组卡时用默认卡组，开局手牌 5 张")
	viewport.queue_free()
	await process_frame


func test_main_flow_layer2() -> void:
	print("[第二层路线全流程：夹具选路（含死亡重掷）→ 层主战 → 上行 → 地图（demo 边界）]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var menu_page := main.get_node("%MenuPage") as Control
	var map_page := main.get_node("%MapPage") as Control
	var event_page := main.get_node("%EventPage") as Control
	var transition_page := main.get_node("%TransitionPage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	await process_frame
	# 跳过教程（教程战已由主流程测试覆盖）：直接置教程完成，从入口菜单进地图
	(main.get_node("%PrimaryButton") as Button).pressed.emit()
	main.run.tutorial_done = true
	# 注入夹具路线（层内流程走指定节点）＋固定随机源（死亡重掷断言可复现）
	main.run.route = _fixture_route()
	main.run.route_layer = main.run.current_layer
	main.run.rng.seed = 20261005
	(main.get_node("%MenuContinueButton") as Button).pressed.emit()
	check(map_page.visible, "继续剧情进入层地图")
	# 第一列·事件（粉雾）
	var fog := _deep_find_button(map_page, "事件·粉雾")
	check(fog != null and not fog.disabled, "第一列事件节点当前可点")
	fog.pressed.emit()
	check(event_page.visible, "进入事件页")
	check(event_page._title.text == "粉雾", "事件标题按节点")
	(event_page._choices_box.get_child(0) as Button).pressed.emit()
	check(not (event_page._complete_button as Button).disabled, "选择后可以完成")
	(event_page._complete_button as Button).pressed.emit()
	check(map_page.visible, "事件完成回地图")
	check(main.run.column_index == 1, "选路推进到第二列")
	# 第二列·作战（残响回廊）→ 故意判负，验证死亡回层首重选
	var echo := _deep_find_button(map_page, "作战·残响回廊")
	check(echo != null and not echo.disabled, "第二列作战节点当前可点")
	echo.pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 1, "第二列作战进入战斗位")
	var lost_battle: Variant = battle_host.get_child(0)
	check(lost_battle.state.mode == BattleState.Mode.STORY, "层战模式")
	check(lost_battle.state.enemy_name == "残响回廊" and lost_battle.state.enemy_max_hp == 16, "第二列作战按节点配置")
	lost_battle.state.debug_force_plays = 5
	var safety := 0
	while lost_battle.state.phase == BattleState.Phase.PLAYER and safety < 20:
		safety += 1
		lost_battle.state.end_turn()
	check(lost_battle.state.phase == BattleState.Phase.DEFEAT, "判负")
	(lost_battle.get_node("%ContinueButton") as Button).pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 0, "判负后战斗已释放")
	check(map_page.visible, "判负回地图")
	check(main.run.column_index == 0 and main.run.chosen.is_empty(), "死亡回层首＝选路重置")
	check(_route_signature(main.run.current_columns()) != _route_signature(_fixture_route()), "死亡重掷＝重新生成新路线（rng 播种，可复现）")
	# 重掷已断言；重新注入夹具，继续走固定节点（第一列·作战：污染体）
	main.run.route = _fixture_route()
	main.run.route_layer = main.run.current_layer
	main._open_map()
	var pol := _deep_find_button(map_page, "作战·污染体")
	check(pol != null and not pol.disabled, "第一列作战节点当前可点")
	pol.pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 1, "小怪战进入战斗位")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.enemy_name == "污染体" and battle.state.enemy_max_hp == 20, "小怪按节点配置")
	battle.state.debug_force_plays = 0
	_press_strikes_until_over(battle)
	check(battle.state.phase == BattleState.Phase.ENDED, "小怪战打完直接结束（不过净化）")
	await process_frame
	check(battle_host.get_child_count() == 0, "小怪战已释放")
	check(map_page.visible and main.run.column_index == 1, "小怪战胜利回地图、进入第二列")
	# 第二列改选·事件（烛台走廊）
	var candle := _deep_find_button(map_page, "事件·烛台走廊")
	check(candle != null and not candle.disabled, "第二列事件节点当前可点")
	candle.pressed.emit()
	check(event_page._title.text == "烛台走廊", "第二列事件标题")
	(event_page._choices_box.get_child(1) as Button).pressed.emit()
	(event_page._complete_button as Button).pressed.emit()
	check(map_page.visible and main.run.column_index == 2, "事件关走完进入第三列（层主战）")
	# 第三列·层主战（阿斯莫德）
	var boss_node := _deep_find_button(map_page, "层主战·阿斯莫德")
	check(boss_node != null and not boss_node.disabled, "层主战节点当前可点")
	boss_node.pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 1, "层主战进入战斗位")
	var boss_battle: Variant = battle_host.get_child(0)
	check(boss_battle.state.enemy_name == "阿斯莫德" and boss_battle.state.enemy_max_hp == 24, "层主按节点配置")
	check(boss_battle.state.sin_card_id == "lust", "本场收下的罪卡＝色欲")
	check((boss_battle.get_node("%AbsorbButton") as Button).text == "拿起 色欲", "拿起按钮按本场罪卡")
	boss_battle.state.debug_force_plays = 0
	_press_strikes_until_over(boss_battle)
	check(boss_battle.state.phase == BattleState.Phase.STRIP, "打倒层主进入净化时刻")
	var boss_overlay := boss_battle.get_node("%Overlay") as Control
	check(boss_overlay.visible, "净化覆盖层出现")
	check((boss_battle.get_node("%StoryText") as Label).text.contains("粉色的裙摆"), "净化时刻读白按关卡")
	(boss_battle.get_node("%AbsorbButton") as Button).pressed.emit()
	check(boss_battle.state.phase == BattleState.Phase.DEBRIEF, "收下后进入净化读白")
	check((boss_battle.get_node("%StoryText") as Label).text.contains("接住"), "净化读白按关卡")
	(boss_battle.get_node("%ContinueButton") as Button).pressed.emit()
	check(boss_battle.state.phase == BattleState.Phase.ENDED, "层战净化读完直接结束（无三问）")
	await process_frame
	check(transition_page.visible, "路线走完进入上行过渡页")
	check((transition_page._read_text as Label).text.contains("阿斯莫德"), "上行读白在屏")
	_first_live_button(transition_page, "继续").pressed.emit()
	check(map_page.visible, "上行后回地图")
	check(main.run.current_layer == 3, "上行到第 3 层")
	check(main.run.is_demo_end(), "停在 demo 边界")
	check(main.run.chosen.is_empty() and main.run.column_index == 0, "上行后选路记录清空")
	check(_deep_find_button(map_page, "第 2 层·色欲").text.contains("已净化"), "第 2 层已净化")
	check(_deep_find_button(map_page, "第 3 层·暴食").text.contains("待续"), "第 3 层待续")
	check(main.run.sin_cards == ["lust"], "色欲入局内收集")
	check(main.run.companions.has("阿斯莫德"), "阿斯莫德入同行列")
	check(main.pool.owned_count("lust") == 1, "罪卡入仓库")
	viewport.queue_free()
	await process_frame
