extends SceneTree

const MAIN_FLOW_SCRIPT := preload("res://scripts/ui/main_flow.gd")

var failures := 0
var _mouse_last_point := Vector2.ZERO


func _initialize() -> void:
	print("== 教程战逻辑测试 ==")
	# 测试全程不触碰真实存档（user://save.json）；需要真读写的用例自行开 disabled／改 save_path 并在用例内清理
	SaveGame.disabled = true
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
	test_layer_pools_complete()
	test_event_games_logic()
	test_event_games_data()
	test_layer_bosses_complete()
	test_sin_cards_data()
	test_last_playable_boundary()
	test_entry_hp_modifier()
	test_card_pool_sin()
	test_story_battle_small()
	test_story_battle_boss()
	test_boss_strip_flow_layer3()
	test_multi_enemy_helpers()
	test_teaching_battle_logic()
	test_teaching_sleep_timeout()
	# 等一帧让 SceneTree 进入运行态，节点加入 root 时 _ready 才会立即执行
	await process_frame
	await test_battle_scene_tutorial()
	await test_battle_scene_practice()
	await test_teaching_battle_scene()
	await test_prologue_page()
	await test_story_beats()
	await test_battle_scene_defeat()
	await test_map_page()
	await test_map_route_scroll()
	await test_event_page()
	await test_event_effect_flow()
	await test_event_panels()
	await test_event_buff_lifecycle()
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
	await test_act2_gating()
	await test_main_menu_practice_entry()
	await test_main_flow_layer2()
	await test_confirm_deck_flow()
	await test_teaching_defeat_restart()
	test_save_roundtrip()
	await test_main_flow_save_resume()
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


# 钉死随机开局手：从抽牌堆换入 card_id 直到手里至少 count 张（对换不增减，牌组张数守恒）
func _pin_hand_cards(state: BattleState, card_id: String, count: int) -> void:
	var have := 0
	for card in state.hand:
		if card.id == card_id:
			have += 1
	while have < count:
		var pile_index := _find_card(state.draw_pile, card_id)
		var hand_index := -1
		for i in state.hand.size():
			if state.hand[i].id != card_id:
				hand_index = i
				break
		if pile_index < 0 or hand_index < 0:
			return
		var swapped: CardData = state.hand[hand_index]
		state.hand[hand_index] = state.draw_pile[pile_index]
		state.draw_pile[pile_index] = swapped
		have += 1


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


# 全层事件查找（第 3–7 层专属事件如 果子树/天平房）
func _find_event(title: String) -> Dictionary:
	for layer in range(2, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		for event_item in LayerConfig.LAYER_EVENTS[layer]:
			if String(event_item.get("title", "")) == title:
				return event_item
	return {}


# 择一小玩法直接走完（选中 → 执行 → 完成）；真实鼠标拖拽路径由 test_event_panels 覆盖
func _complete_pick_event(page: Control, index := 0) -> void:
	var panel := page._panel as PickPanel
	panel.select(index)
	panel._on_exec_pressed()
	(page._complete_button as Button).pressed.emit()


# 真实鼠标拖拽（引擎走链）：按下 → 越过拖拽阈值 → 移到落点 → 松手
func _mouse_drag(viewport: Viewport, from_point: Vector2, to_point: Vector2) -> void:
	_push_mouse_button(viewport, from_point, true)
	_push_mouse_motion(viewport, from_point + Vector2(12.0, -12.0))
	_push_mouse_motion(viewport, to_point)
	_push_mouse_button(viewport, to_point, false)


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
		[_pool_event("试衣镜"), _pool_battle("粉雾歌者"), _pool_event("糖果摊")],
		[_pool_battle("糖丝傀儡"), _pool_event("合唱席")],
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


func _deep_find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer and not node.is_queued_for_deletion():
		return node as ScrollContainer
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var found := _deep_find_scroll(child)
		if found != null:
			return found
	return null


func _deep_find_route(node: Node) -> MapPage.RouteView:
	if node is MapPage.RouteView and not node.is_queued_for_deletion():
		return node as MapPage.RouteView
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var found := _deep_find_route(child)
		if found != null:
			return found
	return null


# 深层查找任意文本节点（Label/Button）是否含片段（用于断言「某文案不在屏上」）
func _deep_has_text(node: Node, fragment: String) -> bool:
	if not node.is_queued_for_deletion():
		if node is Label and (node as Label).text.contains(fragment):
			return true
		if node is Button and (node as Button).text.contains(fragment):
			return true
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if _deep_has_text(child, fragment):
			return true
	return false


# 长线夹具：6 普通列×1 节点＋层主战＝7 列 1608px（＞地图页 1120 视口宽，必溢出可滚）
func _long_route() -> Array:
	var battles: Array = LayerConfig.LAYER2_BATTLES
	var route: Array = []
	for i in 6:
		route.append([battles[i % battles.size()]])
	route.append([LayerConfig.LAYER2_BOSS])
	return route


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


func _push_wheel(target: Viewport, at_point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.factor = 1.0
	event.position = at_point
	event.global_position = at_point
	_mouse_last_point = at_point
	target.push_input(event)


# 像玩家一样：拖手牌里的普通魔弹进出牌区，摆完按「打出」，打不出就结束回合，直到战斗不再是玩家回合
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


# 教学战推进到波 2 登场：R1 整批（防住＋两发魔弹＋治疗）→ R2 补刀 → 三只群怪沉睡（第 3 回合）
func _teaching_reach_wave2(state: BattleState) -> void:
	state.stage_card(_find_card(state.hand, "guard"))
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "heal"))
	state.commit_staged()
	state.stage_card(_find_card(state.hand, "strike"))
	state.commit_staged()


# 教学战钉死节拍全通：R1 整批 → R2 补刀（波 2 沉睡登场）→ R3 净化免疫＋强欲魔弹（对沉睡 3＋2）清场
func _drive_teaching_victory(scene: Variant) -> void:
	var state: BattleState = scene.state
	_teaching_reach_wave2(state)
	state.stage_card(_find_card(state.hand, "cleanse"))
	state.stage_card(_find_card(state.hand, "greed_shot"))
	state.commit_staged()


func test_cards_load() -> void:
	print("[卡牌数据]")
	for card_id in ["strike", "heavy_strike", "guard", "strong_guard", "call", "shift", "wrath", "enemy_strike", "quench", "surge", "bulwark", "heal", "cleanse", "greed_shot", "snail_bite", "gnaw", "gold_smash", "mirror_cut", "piercing_light", "falling_debris", "ember_lash", "flame_burst", "gluttony", "greed", "envy", "pride", "anger"]:
		var card := CardDB.get_card(card_id)
		check(card != null, "载入 " + card_id)
		if card != null:
			check(card.id == card_id, card_id + " id 一致")
			if card.kind == CardData.Kind.AMPLIFY:
				check(not card.discard_effects.is_empty(), card_id + " 有弃牌触发效果")
			else:
				check(not card.effects.is_empty(), card_id + " 有效果")
	var wrath := CardDB.get_card("wrath")
	check(wrath.permanent, "懒惰是永久牌")
	check(wrath.kind == CardData.Kind.SIN, "懒惰是罪牌")
	check(CardDB.get_card("strike").kind == CardData.Kind.ATTACK, "普通魔弹是攻击牌")
	check(CardDB.get_card("heavy_strike").kind == CardData.Kind.ATTACK, "强力魔弹是攻击牌")
	check(CardDB.get_card("guard").kind == CardData.Kind.DEFENSE, "普通防御是防御牌")
	check(CardDB.get_card("strong_guard").kind == CardData.Kind.DEFENSE, "坚固防御是防御牌")
	check(CardDB.get_card("call").kind == CardData.Kind.UTILITY, "震慑是功能牌")
	check(CardDB.get_card("shift").kind == CardData.Kind.UTILITY, "灵感是功能牌")
	check(CardDB.get_card("quench").kind == CardData.Kind.AMPLIFY, "灼印是增幅牌")
	check(CardDB.get_card("surge").kind == CardData.Kind.AMPLIFY, "蓄流是增幅牌")
	check(CardDB.get_card("bulwark").kind == CardData.Kind.AMPLIFY, "坚壁是增幅牌")
	check(CardDB.get_card("quench").kind_label() == "功能", "卡型标签：增幅呈现并入功能")
	check(CardDB.get_card("quench").cost == 1, "增幅牌 Cost 1")
	check(CardDB.get_card("heavy_strike").kind_label() == "攻击", "卡型标签：攻击")
	check(CardDB.get_card("shift").kind_label() == "功能", "卡型标签：功能")
	check(CardDB.get_card("wrath").kind_label() == "罪", "卡型标签：罪")
	check(CardDB.get_card("heal").kind == CardData.Kind.UTILITY, "治疗术是功能牌")
	check(CardDB.get_card("cleanse").kind == CardData.Kind.UTILITY, "净化是功能牌")
	check(CardDB.get_card("greed_shot").kind == CardData.Kind.CORE, "强欲魔弹是核心牌")
	check(CardDB.get_card("greed_shot").kind_label() == "核心", "卡型标签：核心")
	check(CardDB.get_card("wrath").display_name == "懒惰", "暴怒旧名已改为懒惰")
	check(CardDB.get_card("lust").display_name == "色欲", "色欲显示名")
	check(CardDB.get_card("lust").kind == CardData.Kind.SIN, "色欲是罪牌")
	check(CardDB.get_card("snail_bite").display_name == "蜗牛撞击", "蜗牛撞击显示名")
	check(CardDB.get_card("snail_bite").kind == CardData.Kind.ENEMY, "蜗牛撞击是敌牌")


func test_wrath_effects() -> void:
	print("[罪牌：3 伤 + 攻击永久 +1]")
	var state := _make_sin_state()
	state.debug_force_plays = 0
	state.sin_available = true
	state.gain_card(CardDB.get_card("wrath"))
	check(state.stage_card(_find_card(state.hand, "wrath")), "懒惰可以摆进出牌区")
	check(state.staged_cost() == 6, "出牌区合计 Cost 6")
	check(state.commit_staged(), "打出整批")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 3, "懒惰直接造成 3 伤")
	check(state.attack_bonus == 1, "攻击加成 +1")
	check(state.collection.has(CardDB.get_card("wrath")), "罪牌留在面前而不是进弃牌堆")
	check(state.phase == BattleState.Phase.PLAYER, "打出后已是新回合")
	check(state.stage_card(_find_card(state.hand, "strike")), "新回合摆一张普通魔弹")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 6, "普通魔弹吃到加成(3 伤)")


func test_sin_unlock_rules() -> void:
	print("[罪卡规则：任务+5回合保底解锁、每场仅一次]")
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
	# 保底路径：新的一场只过回合不出攻击牌，第 5 回合解锁
	var state2 := _make_sin_state()
	state2.debug_force_plays = 0
	for _i in 4:
		state2.end_turn()
	check(state2.turn_count == 5, "已到第 5 回合")
	check(state2.sin_available, "5 回合保底解锁")
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
	for _i in 5:
		state4.end_turn()
	check(not state4.sin_available, "无罪卡时过 5 回合也不解锁")


func test_new_card_effects() -> void:
	print("[新卡：强力魔弹 4 伤 / 坚固防御 5 格挡 / 灵感抽 2]")
	var state := _make_state()
	state.debug_force_plays = 0
	state.hand.clear()
	state.hand.append(CardDB.get_card("heavy_strike"))
	state.stage_card(0)
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "强力魔弹 4 伤")
	# 坚固防御的格挡在「打出→敌人回合」之间生效；回合结束后清零，用击穿线反推本回合格挡量
	var state_g := _make_state()
	state_g.debug_force_plays = 2
	state_g.hand.clear()
	state_g.hand.append(CardDB.get_card("strong_guard"))
	state_g.stage_card(0)
	state_g.commit_staged()
	check(state_g.player_hp == BattleConfig.PLAYER_MAX_HP, "坚固防御 5 格挡挡下对方 2 张共 4 点（同批结算生效）")
	# 灵感：抽 2 张进手；结算后过一轮，弃牌堆洗回再摸 1 张（供给见底能摸几张是几张）
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
	check(state2.hand.size() == 3, "灵感抽 2 张＋弃牌堆洗回再摸 1 张＝3 张")
	check(_find_card(state2.hand, "strike") >= 0 and _find_card(state2.hand, "guard") >= 0, "抽到的普通魔弹与普通防御都在手")
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
	print("[普通防御 vs 对方出牌：同批结算后紧接着的对方回合被挡下]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 2
	# 开局手牌从牌组随机摸 5，钉死手牌保证有两张普通防御（单张 2 格挡挡不满 2 张敌牌共 4 点）
	state.hand.clear()
	state.hand.append(CardDB.get_card("guard"))
	state.hand.append(CardDB.get_card("guard"))
	state.stage_card(0)
	state.stage_card(0)
	state.commit_staged()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "对方两张占位牌共 4 点伤害被同批打出的两张普通防御完整挡下")
	check(state.player_block == 0, "格挡正好用掉；新回合格挡清零")
	check(state.phase != BattleState.Phase.DEFEAT, "没有倒下")
	check(_log_contains(logs, "挡"), "日志记录了挡下")
	check(state.phase == BattleState.Phase.PLAYER, "回到新回合")


func test_call_suppresses() -> void:
	print("[震慑：同批结算后紧接着的对方回合不打人]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 2
	# 开局手牌从 8 张牌组随机摸 5，钉死手牌保证有震慑
	state.hand.clear()
	state.hand.append(CardDB.get_card("call"))
	state.stage_card(0)
	state.commit_staged()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "换来的这一回合没有挨打")
	check(not state.enemy_suppressed, "压制在本次对方回合用掉")
	check(_log_contains(logs, "……对不起"), "她说了题眼那句")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP, "震慑不伤她")


func test_card_costs() -> void:
	print("[卡牌 Cost]")
	check(CardDB.get_card("strike").cost == 1, "普通魔弹 Cost 1")
	check(CardDB.get_card("guard").cost == 1, "普通防御 Cost 1")
	check(CardDB.get_card("call").cost == 2, "震慑 Cost 2")
	check(CardDB.get_card("heavy_strike").cost == 2, "强力魔弹 Cost 2")
	check(CardDB.get_card("strong_guard").cost == 2, "坚固防御 Cost 2")
	check(CardDB.get_card("wrath").cost == 6, "懒惰（罪牌）Cost 6")


func test_cost_pool() -> void:
	print("[Cost 池：摆放不扣、打出结算、每回合重置]")
	var state := _make_state()
	state.debug_force_plays = 0
	_pin_hand_cards(state, "strike", 1)
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "开局满 Cost（6/6）")
	check(state.stage_card(_find_card(state.hand, "strike")), "普通魔弹可以摆进出牌区")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "摆放不扣 Cost（6/6）")
	check(state.staged_cost() == 1, "出牌区合计 Cost 1")
	check(state.recall_card(0), "可以收回")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "收回不补也不扣")
	state.player_cost = 5
	state.deck_sin_id = "wrath"
	state.sin_available = true  # 本测试只考 Cost 门槛，先放行罪卡检定
	state.hand.append(CardDB.get_card("wrath"))
	var wrath_index := _find_card(state.hand, "wrath")
	check(not state.can_stage(state.hand[wrath_index]), "Cost 不够摆不进懒惰（需 6 剩 5）")
	check(not state.stage_card(wrath_index), "摆放被拒")
	check(state.player_cost == 5, "被拒时不扣 Cost")
	check(state.can_afford(CardDB.get_card("strike")), "普通魔弹还打得动")
	check(not state.can_afford(CardDB.get_card("wrath")), "懒惰打不动")
	state.player_cost = 10
	check(state.stage_card(_find_card(state.hand, "strike")), "重新摆一张普通魔弹")
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
	check(_log_contains(logs, BattleConfig.TEXT_DEFEAT_TEACHING), "判负读白出现（教程层＝教学文案）")
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
	print("[出牌区：最多四张，越限或越额都摆不进]")
	var state := _make_state()
	var guard := 0
	while not state.hand.is_empty() and guard < 10:
		guard += 1
		state.stage_card(0)
	check(state.staged.size() == 4, "开局四槽摆满（第 5 张没槽位）")
	check(state.hand.size() == 1, "手里还剩一张")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "摆放全程不扣 Cost")
	state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == 2, "获得一张新牌")
	check(not state.can_stage(state.hand[0]), "出牌区满后不能继续摆")
	check(not state.stage_card(0), "摆放被拒")
	check(state.recall_card(2), "收回出牌区第 3 张")
	check(state.staged.size() == 3, "收回后剩 3 张")
	check(state.hand.size() == 3, "收回的牌回到手牌")
	check(state.can_stage(state.hand[0]), "空出卡槽后可以再摆")
	check(state.stage_card(0), "重新摆进一张")
	check(state.staged.size() == 4, "重回 4 张")
	check(not state.recall_card(9), "越界收回被拒")
	var state2 := BattleState.new()
	state2.start(["strike", "strike", "strike", "strike", "strike"])
	state2.player_cost = 3
	check(state2.stage_card(0) and state2.stage_card(0) and state2.stage_card(0), "三张普通魔弹摆进（合计 Cost 3）")
	check(state2.staged_cost() == 3, "合计 Cost 3")
	check(not state2.can_stage(state2.hand[0]), "合计到上限后第 4 张摆不进")
	check(not state2.stage_card(0), "摆放被拒")


func test_commit_batch() -> void:
	print("[打出即结束回合：结算整批后自动轮到敌人，再进新回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 1
	_pin_hand_cards(state, "strike", 2)
	check(not state.commit_staged(), "空出牌区打不出")
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "strike"))
	check(state.commit_staged(), "两张普通魔弹一起打出")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "两张普通魔弹各 2 伤（整批一次结算）")
	check(_count_log(logs, "你打出「普通魔弹」。") == 2, "日志逐张记录")
	# 新回合补牌会把弃牌堆洗回抽牌堆，所以在整局范围内核对四张普通魔弹的去向
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
	check(strike_stock == 4, "四张普通魔弹都在牌堆里循环")
	check(state.collection.is_empty(), "非永久牌不进收藏")
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "打出后自动进入对方回合")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 2, "对方出了 1 张占位牌，打了 2 点")
	check(state.phase == BattleState.Phase.PLAYER, "回到新的玩家回合")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "新回合 Cost 重置满")
	check(state.can_stage(state.hand[0]), "新回合可以再摆")
	check(not state.commit_staged(), "新回合还没摆放，打不出")


func test_end_turn_settles_staged() -> void:
	print("[结束回合自动结算摆放的牌（手动与超时同一条路径）]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	_pin_hand_cards(state, "strike", 1)
	state.stage_card(_find_card(state.hand, "strike"))
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 0, "还没过回合")
	state.end_turn()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 2, "结束时先结算摆好的普通魔弹")
	check(state.staged.is_empty(), "出牌区清空")
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "对方回合来过一次")
	check(state.phase == BattleState.Phase.PLAYER, "进入新回合")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "新回合 Cost 重置")
	check(state.can_stage(state.hand[0]), "新回合可以再摆")


func test_commit_ends_turn() -> void:
	print("[打满出牌区：这批打出后照样直接过回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	var guard := 0
	while not state.hand.is_empty() and guard < 10:
		guard += 1
		state.stage_card(0)
	check(state.commit_staged(), "四张一起打出")
	check(_count_log(logs, "—— 贝尔芬格的回合 ——") == 1, "打出后自动过了一次对方回合")
	check(state.phase == BattleState.Phase.PLAYER, "回到玩家回合")
	check(state.hand.size() == 1 + BattleConfig.ROUND_GAIN, "剩 1 张＋摸 4 张＝5 张")


func test_hand_limit() -> void:
	print("[手牌上限 7：计数与弃牌]")
	var state := _make_state()
	for _i in 2:
		state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == BattleConfig.HAND_LIMIT, "手牌到上限 7")
	check(not state.needs_discard(), "到上限还不需弃牌")
	state.gain_card(CardDB.get_card("strike"))
	check(state.hand.size() == 8, "第 8 张超出上限")
	check(state.needs_discard(), "超过上限需要弃牌")
	check(not state.discard_from_hand(99), "越界弃牌被拒")
	check(state.discard_from_hand(0), "弃掉一张")
	check(state.hand.size() == BattleConfig.HAND_LIMIT, "回到 7 张")
	check(not state.needs_discard(), "不再需要弃牌")
	check(state.discard_pile.size() == 1, "弃掉的牌进弃牌堆")


func test_discard_for_cost() -> void:
	print("[主动弃牌换 Cost：n-1、可超上限、只限本回合]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	# 钉死手牌：默认牌组随机首张可能是 2 费牌，弃牌收益断言会随洗牌浮动
	state.hand.clear()
	state.hand.append(CardDB.get_card("strike"))
	state.hand.append(CardDB.get_card("strike"))
	check(state.discard_for_cost(0) == 0, "弃一张 1 费牌 +0")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "1 费牌不涨 Cost（6/6）")
	state.gain_card(CardDB.get_card("wrath"))
	var wrath_index := _find_card(state.hand, "wrath")
	check(wrath_index >= 0, "懒惰在手")
	check(state.discard_for_cost(wrath_index) == 5, "弃 6 费懒惰 +5")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST + 5, "Cost 可超上限（11/6）")
	check(_log_contains(logs, "Cost +5"), "日志记录了获得点数")
	check(_find_card(state.discard_pile, "wrath") >= 0, "弃掉的懒惰进弃牌堆")
	check(state.discard_for_cost(99) == -1, "越界弃牌被拒")
	check(state.discard_for_cost(-1) == -1, "负数下标被拒")
	check(state.stage_card(_find_card(state.hand, "strike")), "摆一张普通魔弹")
	check(state.commit_staged(), "打出结算")
	check(state.player_cost == BattleConfig.PLAYER_MAX_COST, "打出即过回合，新回合重置回 6/6，超出作废")
	check(state.discard_for_cost(0) >= 0, "新回合仍可主动弃牌换 Cost")
	var state2 := BattleState.new()
	state2.start()
	state2.phase = BattleState.Phase.STRIP
	check(state2.discard_for_cost(0) == -1, "非玩家回合不能弃牌换 Cost")


func test_round_gain_economy() -> void:
	print("[一轮结束：双方各获得四张，没打完的保留]")
	# 用户示例（设定文档）：手 5 张，打 3 张 → 剩 2＋4＝第二轮 6 张；敌人打 2 → 剩 3＋4＝7 张
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
	check(state.staged.size() == 3, "玩家第一轮打出 3 张普通魔弹")
	state.commit_staged()
	check(state.hand.size() == 6, "玩家：剩 2 张＋摸 4 张＝第二轮 6 张")
	check(state.enemy_hand.size() == 7, "敌人：出 2 张剩 3 张＋摸 4 张＝第二轮 7 张")
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 4, "敌人出的两张各打 2 点（共 4 点）")
	# 用户实测复现：牌组共 8 张，打 1 张 → 剩 4＋摸 4＝第二轮 8 张（摸牌会把刚打出的洗回弃牌堆补足）
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
	check(state2.stage_card(_find_card(state2.hand, "strike")), "玩家第一轮打出 1 张普通魔弹")
	state2.commit_staged()
	check(state2.hand.size() == 8, "玩家：剩 4 张＋摸 4 张＝第二轮 8 张")
	check(state2.needs_discard(), "8 张超过上限 7，需要弃牌")


func test_enemy_plays_cards() -> void:
	print("[敌人真出牌：张数随机；每张 2 伤；打出的牌进敌方弃牌堆]")
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.end_turn()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP, "强制 0 张：这回合没挨打")
	check(_log_contains(logs, "没有出牌"), "日志写着没出牌")
	state.debug_force_plays = 3
	state.end_turn()
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 6, "出 3 张，每张 2 伤（共 6 点）")
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
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 8, "再出 1 张（累计 8 点）")
	check(_log_contains(logs, BattleConfig.TEXT_ENEMY_RESISTING), "单张时「她」还在挣的它-她对读")
	check(state.enemy_hand.size() == 1, "供给见底时能摸几张是几张（只摸回 1 张）")
	check(state.enemy_discard_pile.is_empty(), "打出的牌被洗回并摸走")
	check(_log_contains(logs, BattleConfig.TEXT_ROUND_GAIN_ENEMY % ["贝尔芬格", 1]), "摸牌日志写着只获得 1 张")
	# 随机路径（非 debug 强制）单回合承伤封顶：最多 2 张 × 2 伤
	state.enemy_hand.clear()
	state.enemy_draw_pile.clear()
	state.enemy_discard_pile.clear()
	for _i in 5:
		state.enemy_hand.append(CardDB.get_card("enemy_strike"))
	state.debug_force_plays = -1
	var hp_before: int = state.player_hp
	state.end_turn()
	check(hp_before - state.player_hp <= BattleConfig.ENEMY_MAX_PLAYS_PER_TURN * 2, "随机出牌封顶：单回合最多 2 张共 4 点")


func test_round_gain_hand_limit() -> void:
	print("[每轮 +4 顶破手牌上限：超限触发强制弃牌]")
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
	check(state.hand.size() > BattleConfig.HAND_LIMIT, "连过几轮后手牌超过 7")
	check(state.needs_discard(), "超限需要强制弃牌")


func test_full_victory_flow() -> void:
	print("[完整流程：打赢 → 净化 → 收下 → 三问 → 结束]")
	var state := _make_state()
	state.debug_force_plays = 0
	_fight_until_over(state)
	check(state.phase == BattleState.Phase.STRIP, "打倒后进入净化时刻")
	check(state.enemy_hp == 0, "她归零了")
	check(state.collection.is_empty(), "净化前收藏为空")
	check(state.absorb_sin(), "拿起懒惰")
	check(state.collection.size() == 1 and state.collection[0].id == "wrath", "懒惰进收藏")
	check(_find_card(state.discard_pile, "wrath") == -1, "懒惰不在弃牌堆")
	check(_find_card(state.draw_pile, "wrath") == -1, "懒惰不在抽牌堆")
	check(state.phase == BattleState.Phase.DEBRIEF, "进入三问")
	check(state.finish_debrief(), "结束三问")
	check(state.phase == BattleState.Phase.ENDED, "流程结束")
	check(not state.stage_card(0), "结束后不能再摆牌")
	check(not state.commit_staged(), "结束后不能结算")


func test_custom_deck_battle() -> void:
	print("[自组卡组开局]")
	var state := BattleState.new()
	state.start(["strike", "strike", "strike", "strike", "guard", "guard", "guard", "heal", "heavy_strike", "heavy_strike"])
	check(state.hand.size() + state.draw_pile.size() == BattleConfig.DECK_SIZE, "牌堆里正好 10 张")
	var ids: Array = []
	for card in state.hand:
		ids.append(card.id)
	for card in state.draw_pile:
		ids.append(card.id)
	ids.sort()
	check(ids == ["guard", "guard", "guard", "heal", "heavy_strike", "heavy_strike", "strike", "strike", "strike", "strike"], "卡组构成正确")
	check(state.enemy_name == "贝尔芬格" and state.enemy_max_hp == BattleConfig.ENEMY_MAX_HP, "教程模式对手是贝尔芬格")


func test_card_pool() -> void:
	print("[仓库与卡组模型]")
	var pool := CardPool.new()
	check(pool.owned_count("strike") == int(BattleConfig.WAREHOUSE_INITIAL["strike"]), "仓库初始普通魔弹数量")
	check(pool.owned_count("wrath") == 0, "仓库初始没有罪卡")
	check(not pool.is_deck_valid(), "空卡组不合法")
	for _i in 4:
		pool.add_to_deck("strike")
	for _i in 2:
		pool.add_to_deck("heavy_strike")
	for _i in 3:
		pool.add_to_deck("guard")
	pool.add_to_deck("heal")
	check(pool.deck.size() == BattleConfig.DECK_SIZE, "卡组满 10 张")
	check(not pool.add_to_deck("guard"), "卡组已满不能再加")
	check(pool.is_deck_valid(), "4 普通魔弹＋2 强力魔弹＋3 普通防御＋1 治疗的卡组合法")
	check(pool.remove_from_deck("strike"), "可以移出一张")
	check(pool.deck.size() == BattleConfig.DECK_SIZE - 1, "移出后剩 9 张")
	var pool2 := CardPool.new()
	var pool_total := 0
	for card_id in BattleConfig.WAREHOUSE_INITIAL:
		pool_total += int(BattleConfig.WAREHOUSE_INITIAL[card_id])
	check(pool_total == 24, "仓库初始卡池共 24 张（攻击 8＋防御 6＋功能 6＋核心 1＋增幅 3）")
	check(pool2.owned_count("strike") == 5 and pool2.owned_count("guard") == 4 and pool2.owned_count("call") == 2, "仓库普通魔弹 5、普通防御 4、震慑 2")
	check(pool2.owned_count("quench") == 1 and pool2.owned_count("surge") == 1 and pool2.owned_count("bulwark") == 1, "仓库增幅牌：灼印 1、蓄流 1、坚壁 1")
	check(pool2.can_add("quench"), "增幅牌可以加进卡组")
	for _i in 3:
		pool2.add_to_deck("guard")
	for _i in 2:
		pool2.add_to_deck("call")
	check(pool2.deck.size() == 5, "全用防御/功能牌只能凑 5 张")
	check(not pool2.is_deck_valid(), "凑不满 10 张不合法")
	pool2.add_to_deck("strike")
	check(not pool2.is_deck_valid(), "有伤害牌但还没满 10 张仍不合法")
	var pool3 := CardPool.new()
	for _i in 10:
		pool3.deck.append("guard")
	check(not pool3.is_deck_valid(), "满 10 张但全无伤害牌不合法")
	check(pool2.add_to_deck("guard"), "第 4 张普通防御可以加进卡组")
	check(not pool2.add_to_deck("guard"), "超过仓库数量不能加（普通防御只有 4 张）")


func test_amplify_cards() -> void:
	print("[增幅牌：弃掉触发的本回合加成]")
	# 灼印：弃掉后本回合伤害 +3；下回合回归
	var logs: Array = []
	var state := _make_state(logs)
	state.debug_force_plays = 0
	state.hand.clear()
	state.hand.append(CardDB.get_card("quench"))
	state.hand.append(CardDB.get_card("strike"))
	state.hand.append(CardDB.get_card("strike"))
	check(state.discard_for_cost(0) == 0, "弃灼印（1 费）+0 Cost")
	check(state.turn_attack_bonus == 3, "本回合伤害加成 +3")
	check(_log_contains(logs, "本回合你的伤害 +3"), "弃牌触发日志出现")
	check(state.stage_card(0), "摆一张普通魔弹")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 5, "普通魔弹吃到加成（2+3=5 伤）")
	check(state.turn_attack_bonus == 0, "新回合加成归零")
	check(state.stage_card(0), "下回合再摆一张普通魔弹")
	state.commit_staged()
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 7, "下回合回归 2 伤（累计 7）")
	# 蓄流：弃掉 → 获得 3 点 Cost（可超上限）
	var state2 := _make_state()
	state2.debug_force_plays = 0
	state2.hand.clear()
	state2.hand.append(CardDB.get_card("surge"))
	check(state2.discard_for_cost(0) == 0, "弃蓄流 +0 Cost")
	check(state2.player_cost == BattleConfig.PLAYER_MAX_COST + 3, "获得 Cost +3（9/6）")
	# 坚壁：弃掉 → 获得 3 点格挡，挡下本回合敌人 2 点（钉死 1 张敌牌，3 格挡正好够）
	var state3 := _make_state()
	state3.debug_force_plays = 1
	state3.hand.clear()
	state3.hand.append(CardDB.get_card("bulwark"))
	check(state3.discard_for_cost(0) == 0, "弃坚壁 +0 Cost")
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
	check(quench_index >= 0, "超限手牌里有灼印")
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
	check(state.stage_card(0), "摆第一张普通魔弹")
	check(state.can_merge_with(state.hand[0], 0), "手牌普通魔弹可叠到出牌区普通魔弹上")
	check(state.merge_into_staged(0, 0), "拖叠成功")
	check(state.staged.size() == 1, "合成牌占同一卡槽（仍 1 张）")
	var merged: CardData = state.staged[0]
	check(merged.is_merged(), "标记为合成牌")
	check(merged.cost == 3, "费用 = 1+1+叠牌费 1 = 3")
	check(merged.display_name == "普通魔弹＋普通魔弹", "牌名以＋连接")
	check(merged.parts.size() == 2, "记录两张原牌")
	check(merged.text == "造成 4 点伤害。", "牌面文本合成为 4 伤")
	check(state.staged_cost() == 3, "出牌区合计费用 3")
	check(not state.can_merge_with(CardDB.get_card("guard"), 0), "异类不能叠（普通防御叠不进普通魔弹）")
	check(not state.can_merge_with(CardDB.get_card("quench"), 0), "增幅牌不能叠")
	state.hand.append(CardDB.get_card("wrath"))
	state.sin_available = true
	check(not state.can_merge_with(CardDB.get_card("wrath"), 0), "罪卡不能叠")
	check(state.commit_staged(), "打出合成牌")
	check(state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 4, "合成牌一次打出 4 伤")
	check(state.attack_plays_this_battle == 2, "攻击任务按原牌张数计（2 张）")
	check(state.discard_pile.size() == 2, "弃牌堆拆回两张原牌")
	check(state.discard_pile[0].id == "strike" and state.discard_pile[1].id == "strike", "弃牌堆里是原牌不是合成体")
	check(_log_contains(logs, "合成「普通魔弹＋普通魔弹」"), "合成日志出现")
	# 三张合成：费用 1+1+2+2×1=6；2+2+4=8 伤；累计 3 张攻击触发罪卡任务解锁
	var state2 := _make_sin_state()
	state2.debug_force_plays = 0
	state2.hand.clear()
	state2.hand.append(CardDB.get_card("strike"))
	state2.hand.append(CardDB.get_card("strike"))
	state2.hand.append(CardDB.get_card("heavy_strike"))
	state2.stage_card(0)
	state2.merge_into_staged(0, 0)
	check(state2.can_merge_with(state2.hand[0], 0), "强力魔弹可叠进普通魔弹＋普通魔弹（同大类）")
	check(state2.merge_into_staged(0, 0), "三张合成")
	check(state2.staged[0].cost == 6, "三张合成费用 = 1+1+2 原费 + 2 次叠牌费 = 6")
	check(state2.staged[0].display_name == "普通魔弹＋普通魔弹＋强力魔弹", "三张牌名")
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
	check(strike_count == 2 and state3.hand.size() == 3, "拆成两张普通魔弹＋普通防御回手")
	# 槽满仍可叠（不新增卡槽，绕过槽上限）
	var state4 := BattleState.new()
	var deck: Array = []
	for _i in 8:
		deck.append("strike")
	state4.start(deck)
	for _i in BattleConfig.PLAY_ZONE_SIZE:
		state4.stage_card(0)
	check(state4.staged.size() == BattleConfig.PLAY_ZONE_SIZE, "四张摆满（槽满）")
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
	print("[层数据：八层表 / 各层内容池 / 路线随机生成 / 局内进度]")
	check(LayerConfig.MAX_LAYER == 8, "共八层")
	check(LayerConfig.layer_name(1) == "懒惰" and LayerConfig.demon_name(1) == "贝尔芬格", "第 1 层懒惰·贝尔芬格")
	check(LayerConfig.layer_name(2) == "色欲" and LayerConfig.demon_name(2) == "阿斯莫德", "第 2 层色欲·阿斯莫德")
	check(LayerConfig.layer_name(8) == "同位体" and LayerConfig.demon_name(8) == "贝嘉", "第 8 层同位体·贝嘉")
	# 第 2 层池细查（作战 4＋事件 5；层主独立）；L3–7 池完整性与容量由 test_layer_pools_complete 覆盖
	check(LayerConfig.LAYER2_BATTLES.size() == 4, "作战池 4 项")
	check(LayerConfig.LAYER2_EVENTS.size() == 5, "事件池 5 项")
	check(LayerConfig.LAYER2_BOSS.get("boss", false) and String(LayerConfig.LAYER2_BOSS.get("enemy", "")) == "阿斯莫德", "层主独立不入池")
	for battle in LayerConfig.LAYER2_BATTLES:
		check(String(battle.get("type", "")) == LayerConfig.TYPE_BATTLE and String(battle.get("enemy", "")) != "" and int(battle.get("enemy_hp", 0)) > 0 and not (battle.get("enemy_deck", {}) as Dictionary).is_empty(), "作战池字段完整：" + String(battle.get("enemy", "")))
	for event_item in LayerConfig.LAYER2_EVENTS:
		var gp: Dictionary = event_item.get("gameplay", {})
		check(String(event_item.get("title", "")) != "" and String(event_item.get("scene", "")) != "" and not gp.is_empty() and EventGames.validate(gp).is_empty(), "事件池字段完整：" + String(event_item.get("title", "")))
	# 生成器不变量·第 2 层细查（种子化 40 掷）：列数极值 2/4 都出现过；单图 ≤9 节点＝池容量，
	# 全图不重复；同列必不重复
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	var bounds2 := LayerConfig.route_length_range(2)
	var min_cols := 99
	var max_cols := 0
	var min_nodes := 99
	var max_nodes := 0
	for roll in 40:
		var route := LayerConfig.generate_route(2, rng)
		var cols := route.size()
		min_cols = mini(min_cols, cols)
		max_cols = maxi(max_cols, cols)
		check(cols >= bounds2.x and cols <= bounds2.y, "第 2 层列数 2–4（第 %d 掷：%d 列）" % [roll, cols])
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
				check(not seen.has(key), "第 2 层单图不重复：" + key)
				seen[key] = true
	check(min_cols == bounds2.x and max_cols == bounds2.y, "40 掷里 2 列与 4 列都出现过")
	check(min_nodes == LayerConfig.ROUTE_MIN_NODES and max_nodes == LayerConfig.ROUTE_MAX_NODES, "40 掷里 1 节点与 3 节点列都出现过")
	# 全层覆盖（第 2–7 层各 12 掷，聚合断言）：列数落该层区间、末列＝该层层主唯一节点、普通列 1–3、
	# 同列不重复；第 8 层（同位体终局）待专轮，不在内容范围
	var layer_rng := RandomNumberGenerator.new()
	layer_rng.seed = 778899
	for layer in range(2, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		var bounds := LayerConfig.route_length_range(layer)
		var cols_ok := true
		var boss_ok := true
		var columns_ok := true
		var no_dup := true
		for roll in 12:
			var route := LayerConfig.generate_route(layer, layer_rng)
			var cols := route.size()
			if cols < bounds.x or cols > bounds.y:
				cols_ok = false
			var boss_column: Array = route[cols - 1]
			if boss_column.size() != 1 or not boss_column[0].get("boss", false) or String((boss_column[0] as Dictionary).get("enemy", "")) != LayerConfig.demon_name(layer):
				boss_ok = false
			for c in cols - 1:
				var column: Array = route[c]
				if column.size() < LayerConfig.ROUTE_MIN_NODES or column.size() > LayerConfig.ROUTE_MAX_NODES:
					columns_ok = false
				var col_keys := {}
				for stage in column:
					var key := String(stage.get("enemy", stage.get("title", "")))
					if col_keys.has(key):
						no_dup = false
					col_keys[key] = true
		check(cols_ok, "第 %d 层 12 掷列数均落 %d–%d" % [layer, bounds.x, bounds.y])
		check(boss_ok, "第 %d 层末列均为该层层主唯一节点（%s）" % [layer, LayerConfig.demon_name(layer)])
		check(columns_ok, "第 %d 层普通列均 1–3 节点" % layer)
		check(no_dup, "第 %d 层同列均不重复" % layer)
	# 第 8 层（同位体终局）待专轮：不生成路线（生成返回空）
	for _roll in 5:
		check(LayerConfig.generate_route(8, layer_rng).is_empty(), "第 8 层待专轮：生成空路线")
	# 线随层拉长：区间表单调不降＋首尾对照
	check(LayerConfig.route_length_range(2) == Vector2i(2, 4), "第 2 层基准 2–4 列")
	check(LayerConfig.route_length_range(8) == Vector2i(5, 7), "第 8 层拉长到 5–7 列")
	var monotonic := true
	for layer in range(2, LayerConfig.MAX_LAYER):
		var narrow := LayerConfig.route_length_range(layer)
		var wide := LayerConfig.route_length_range(layer + 1)
		if narrow.x > wide.x or narrow.y > wide.y:
			monotonic = false
	check(monotonic, "列数区间随层单调不降（每两层 +1 列）")
	check(LayerConfig.generate_route(1, layer_rng).is_empty(), "教程层不走路线表")
	check(LayerConfig.generate_route(9, layer_rng).is_empty(), "超出第八层返回空路线")
	# 同种子可复现
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	check(_route_signature(LayerConfig.generate_route(2, rng_a)) == _route_signature(LayerConfig.generate_route(2, rng_b)), "同种子同路线")
	check(LayerConfig.transition_lines(2).size() == 3, "第 2 层有上行过渡读白")
	check(LayerConfig.transition_lines(1).is_empty(), "第 1 层过渡走教程结尾读白")
	check(LayerConfig.companion_name(1) == "菲戈蕾" and LayerConfig.companion_name(2) == "莉维娅", "同行者人名表：1＝菲戈蕾／2＝莉维娅（双名制，round11）")
	check(LayerConfig.companion_name(3) == LayerConfig.demon_name(3), "未登记层回退恶魔名")
	var transition2 := "\n".join(PackedStringArray(LayerConfig.transition_lines(2)))
	check(transition2.contains("菲戈蕾") and transition2.contains("莉维娅"), "第 2 层过渡读白含菲戈蕾与莉维娅（净化后人身）")
	# RunState：进层懒生成一次、层内稳定；四态；死亡重掷（重生成）＋夹具行进
	var run := RunState.new()
	check(run.current_layer == 2, "教程完成后的目标是第 2 层")
	check(not run.is_layer_unlocked(2), "未过教程时第 2 层锁定")
	check(run.is_layer_unlocked(1), "教程层始终可进")
	run.tutorial_done = true
	check(run.is_layer_cleared(1), "教程完成后第 1 层已净化")
	check(run.is_layer_unlocked(2), "第 2 层解锁")
	check(not run.is_layer_unlocked(3), "第 3 层未走到仍锁定")
	run.rng.seed = 424242
	var generated := run.current_columns()
	check(generated.size() >= bounds2.x and generated.size() <= bounds2.y and (generated[generated.size() - 1][0] as Dictionary).get("boss", false), "首次读取生成合法路线")
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
	check(String(picked.get("title", "")) == "糖果摊", "选下节点返回该关卡")
	check(run.column_index == 1, "选路推进到第二列")
	check(run.node_state(0, 2) == RunState.NodeState.DONE, "已走节点＝已走")
	check(run.node_state(0, 0) == RunState.NodeState.MISSED, "同列未选＝错失")
	check(run.node_state(1, 1) == RunState.NodeState.CURRENT, "第二列当前可选")
	check(String(run.choose(0).get("enemy", "")) == "糖丝傀儡", "第二列选作战节点")
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
	check(run.is_layer_unlocked(3), "第 3 层解锁（内容楼层）")
	check(not run.is_demo_end(), "第 3 层不是 demo 边界")
	# 连过到第 8 层＝本段内容边界（同位体终局待专轮）
	for _i in range(3, 8):
		run.complete_layer()
	check(run.current_layer == 8, "连过第 3–7 层后上行到第 8 层")
	check(not run.is_layer_unlocked(8) and run.is_demo_end(), "第 8 层锁定＝停在本段内容边界")


# 各层内容池完整性：数量表、容量＝单图最大需求、字段完整、敌牌组 8 张全可载入、事件效果对齐
func test_layer_pools_complete() -> void:
	print("[各层内容池：数量/容量/字段/敌牌组/事件效果]")
	var expected := {2: Vector2i(4, 5), 3: Vector2i(5, 4), 4: Vector2i(5, 7), 5: Vector2i(5, 7), 6: Vector2i(7, 8), 7: Vector2i(8, 7)}
	for layer in range(2, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		var battles: Array = LayerConfig.LAYER_BATTLES[layer]
		var events: Array = LayerConfig.LAYER_EVENTS[layer]
		var want: Vector2i = expected[layer]
		check(battles.size() == want.x and events.size() == want.y, "第 %d 层池数量＝作战 %d＋事件 %d" % [layer, want.x, want.y])
		# 容量：单图最大需求（最大列数−1 列 × 每列上限 3）＝池容量（洗牌全图不重复不发愁）
		var bounds := LayerConfig.route_length_range(layer)
		var capacity := (bounds.y - 1) * LayerConfig.ROUTE_MAX_NODES
		check(battles.size() + events.size() == capacity, "第 %d 层池容量＝单图最大需求 %d" % [layer, capacity])
		var names := {}
		for battle in battles:
			var enemy := String(battle.get("enemy", ""))
			check(String(battle.get("type", "")) == LayerConfig.TYPE_BATTLE and enemy != "" and int(battle.get("enemy_hp", 0)) > 0, "第 %d 层作战字段完整：%s" % [layer, enemy])
			check(not names.has(enemy), "第 %d 层名不重：%s" % [layer, enemy])
			names[enemy] = true
			var deck: Dictionary = battle.get("enemy_deck", {})
			var total := 0
			var deck_ok := true
			for card_id in deck:
				total += int(deck[card_id])
				var card := CardDB.get_card(String(card_id))
				if card == null or card.kind != CardData.Kind.ENEMY:
					deck_ok = false
			check(deck_ok and total == 8, "第 %d 层敌牌组 8 张且全为敌牌：%s" % [layer, enemy])
		for event_item in events:
			var title := String(event_item.get("title", ""))
			var gp: Dictionary = event_item.get("gameplay", {})
			var gp_errors := EventGames.validate(gp)
			var gp_note := "" if gp_errors.is_empty() else "（%s）" % ", ".join(gp_errors)
			check(String(event_item.get("scene", "")) != "" and not gp.is_empty() and gp_errors.is_empty(), "第 %d 层事件玩法合法：%s%s" % [layer, title, gp_note])
			check(not names.has(title), "第 %d 层名不重：%s" % [layer, title])
			names[title] = true


# 事件小玩法纯结算（design-round10 §1/§3）：四模块结算、outcome 词汇、守护校验
func test_event_games_logic() -> void:
	print("[事件小玩法纯逻辑：择一/分拣/配平/揭示＋结果词汇＋守护校验]")
	# 择一
	var pick_gp := {"cards": [
		{"name": "甲", "outcome": {"hp": 1}, "text": "甲文"},
		{"name": "乙", "outcome": {}},
		{"name": "丙", "outcome": {"hp": -2}},
	]}
	var picked := EventGames.resolve_pick(pick_gp, 0)
	check(int((picked.get("outcome", {}) as Dictionary).get("hp", 0)) == 1 and String(picked.get("text", "")) == "甲文", "择一：整卡结果与文本")
	check(EventGames.resolve_pick(pick_gp, 3).is_empty() and EventGames.resolve_pick(pick_gp, -1).is_empty(), "择一：越界返回空")
	# 分拣
	var sort_gp := {"cards": [
		{"left": {"hp": 1}, "right": {}},
		{"left": {}, "right": {"block": 1}},
	]}
	var sorted_outcome: Dictionary = EventGames.resolve_sort(sort_gp, ["left", "right"]).get("outcome", {})
	check(int(sorted_outcome.get("hp", 0)) == 1 and int(sorted_outcome.get("block", 0)) == 1, "分拣：两侧求和")
	check(EventGames.resolve_sort(sort_gp, ["left"]).is_empty(), "分拣：张数不符返回空")
	check(EventGames.resolve_sort(sort_gp, ["left", ""]).is_empty(), "分拣：有卡未放返回空")
	# 配平
	var bal_gp := {"target": 4, "cards": [{"weight": 1}, {"weight": 3}, {"weight": 2}]}
	check(EventGames.balance_sum(bal_gp, [0, 1]) == 4, "配平：Σ 权重")
	check(EventGames.balance_sum(bal_gp, [0, 99, -1]) == 1, "配平：越界下标忽略")
	check(int((EventGames.resolve_balance(bal_gp, [0, 1]).get("outcome", {}) as Dictionary).get("hp", 0)) == 1, "配平：差 0 → hp+1（默认档）")
	check(EventGames.is_empty_outcome(EventGames.resolve_balance(bal_gp, [0, 2]).get("outcome", {})), "配平：差 1 → 无变化")
	check(int((EventGames.resolve_balance(bal_gp, [2]).get("outcome", {}) as Dictionary).get("hp", 0)) == -1, "配平：差 ≥2 → hp−1")
	# 揭示
	var rev_gp := {
		"cards": [{"outcome": {"hp": 1}, "text": "甜"}, {"outcome": {"block": 1}}],
		"finish": {"outcome": {"block": 1}, "text": "补"},
	}
	check(int((EventGames.resolve_reveal_flip(rev_gp, 0).get("outcome", {}) as Dictionary).get("hp", 0)) == 1, "揭示：翻单张结算")
	check(EventGames.resolve_reveal_flip(rev_gp, 9).is_empty(), "揭示：越界返回空")
	var rev_finish := EventGames.resolve_reveal_finish(rev_gp)
	check(int((rev_finish.get("outcome", {}) as Dictionary).get("block", 0)) == 1 and String(rev_finish.get("text", "")) == "补", "揭示：全翻追加奖励")
	check(EventGames.resolve_reveal_finish({"cards": []}).is_empty(), "揭示：无 finish 不追加")
	# outcome 词汇
	check(EventGames.outcome_line({"hp": -1, "block": 2}) == "生命 -1 · 开局格挡 +2", "结果行按词汇拼接")
	check(EventGames.outcome_line({}) == "（这一趟没有留下什么，也没有带走什么。）", "空结果固定读白")
	check(EventGames.add_outcome({"hp": 1}, {"hp": -1, "draw": 1}) == {"draw": 1}, "结果相加：零键丢弃")
	check(EventGames.normalize_outcome({"hp": 2.0, "junk": 9}) == {"hp": 2}, "归一：float 转 int、未知键丢弃")
	# 守护校验
	check(not EventGames.validate({"module": "nope", "cards": [{"outcome": {}}]}).is_empty(), "守护：未知模块报错")
	check(not EventGames.validate({"module": "pick", "cards": [{"outcome": {"hp": -1}}]}).is_empty(), "守护：择一无温和路径报错")
	check(not EventGames.validate({"module": "pick", "cards": [{"outcome": {"hp": 9}}]}).is_empty(), "守护：数值超区间报错")
	var two_draws := {"module": "pick", "cards": [{"outcome": {"draw": 1}}, {"outcome": {"draw": 1}}]}
	check(not EventGames.validate(two_draws).is_empty(), "守护：draw 多于 1 处报错")
	var bad_balance := {"module": "balance", "target": 6, "cards": [{"weight": 1}, {"weight": 2}]}
	check(not EventGames.validate(bad_balance).is_empty(), "守护：配平无温和路径报错")
	var good_sort := {"module": "sort", "left_label": "左", "right_label": "右", "cards": [{"left": {"hp": 1}, "right": {}}]}
	check(EventGames.validate(good_sort).is_empty(), "守护：合法分拣通过")


# 事件玩法数据全量守护（design-round10 §2）：38 事件 validate 全过＋模块分布＋样例细查
func test_event_games_data() -> void:
	print("[事件玩法数据：38 事件守护＋模块分布＋样例]")
	var counts := {"pick": 0, "sort": 0, "balance": 0, "reveal": 0}
	var total := 0
	for layer in range(2, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		for event_item in LayerConfig.LAYER_EVENTS[layer]:
			total += 1
			var title := String(event_item.get("title", ""))
			var gp: Dictionary = event_item.get("gameplay", {})
			var errors := EventGames.validate(gp)
			var note := "" if errors.is_empty() else "（%s）" % ", ".join(errors)
			check(errors.is_empty(), "第 %d 层·%s 玩法合法%s" % [layer, title, note])
			var module := String(gp.get("module", ""))
			counts[module] = int(counts.get(module, 0)) + 1
			if module == "reveal":
				check(String(gp.get("stop_label", "")) != "", "第 %d 层·%s 揭示有收手按钮文案" % [layer, title])
	check(total == 38, "第 2–7 层共 38 个事件")
	check(counts["pick"] == 22 and counts["sort"] == 4 and counts["balance"] == 3 and counts["reveal"] == 9, "模块分布 22/4/3/9")
	var flame: Dictionary = _pool_event("粉焰之墙").get("gameplay", {})
	check(flame.get("finish") is Dictionary and not (flame.get("finish") as Dictionary).is_empty(), "粉焰之墙＝全翻奖励变体")
	check((_pool_event("糖果摊").get("gameplay", {}) as Dictionary).get("finish") == null, "糖果摊＝随时收手变体")
	var tree: Dictionary = _find_event("果子树").get("gameplay", {})
	check(int(tree.get("capacity", 0)) == 2 and String(tree.get("capacity_side", "")) == "left", "果子树：摘下来至多 2 张")
	var scale_gp: Dictionary = _find_event("天平房").get("gameplay", {})
	check(int(scale_gp.get("target", 0)) == 6 and (scale_gp.get("cards", []) as Array).size() == 5, "天平房：目标 6／五件道具")


# 各层层主三键守护（STRIP 死锁防线）：sin_card/strip_lines/purify_lines 必填、罪卡可载入
func test_layer_bosses_complete() -> void:
	print("[各层层主：三键必填（STRIP 死锁防线）/ 恶魔名 / 罪卡可载入]")
	var sin_by_layer := {2: "lust", 3: "gluttony", 4: "greed", 5: "envy", 6: "pride", 7: "anger"}
	for layer in range(2, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		var boss: Dictionary = LayerConfig.LAYER_BOSSES[layer]
		check(not boss.is_empty() and boss.get("boss", false), "第 %d 层层主节点存在" % layer)
		check(String(boss.get("enemy", "")) == LayerConfig.demon_name(layer), "第 %d 层层主名＝%s" % [layer, LayerConfig.demon_name(layer)])
		check(int(boss.get("enemy_hp", 0)) > 0 and not (boss.get("enemy_deck", {}) as Dictionary).is_empty(), "第 %d 层层主血量与敌牌组在" % layer)
		var sin_id := String(boss.get("sin_card", ""))
		check(sin_id == sin_by_layer[layer], "第 %d 层收下罪卡＝%s" % [layer, sin_by_layer[layer]])
		var sin_card := CardDB.get_card(sin_id)
		check(sin_card != null and sin_card.kind == CardData.Kind.SIN, "第 %d 层罪卡数据可载入" % layer)
		# L2 保留既有文案（净化 3 行）；L3–7 为本轮新写（净化 4 行）
		var purify_min := 4 if layer >= 3 else 3
		check((boss.get("strip_lines", []) as Array).size() >= 3, "第 %d 层剥污染读白 ≥3 行" % layer)
		check((boss.get("purify_lines", []) as Array).size() >= purify_min, "第 %d 层净化读白 ≥%d 行" % [layer, purify_min])


# 先行版罪卡数据（design-round8；各具特色，待罪卡专轮替换）：cost 6 / 永久 / 效果与任务参数
func test_sin_cards_data() -> void:
	print("[先行版罪卡：cost 6・永久・效果/任务参数齐备]")
	var configs := {
		"gluttony": ["deal_damage", "heal"],
		"greed": ["deal_damage", "draw_cards"],
		"envy": ["deal_damage", "suppress_enemy_attack"],
		"pride": ["deal_damage"],
		"anger": ["deal_damage", "gain_block"],
	}
	for card_id in configs:
		var card := CardDB.get_card(card_id)
		check(card != null and card.kind == CardData.Kind.SIN, card_id + " 是罪牌")
		if card == null:
			continue
		check(card.cost == 6 and card.permanent, card_id + " cost 6・永久")
		var ops := PackedStringArray()
		for effect in card.effects:
			ops.append(String(effect.get("op", "")))
		for want_op in configs[card_id]:
			check(ops.has(want_op), "%s 效果含 %s" % [card_id, want_op])
		check(BattleConfig.SIN_TASK_CONFIG.has(card_id), card_id + " 有任务参数")


# 内容边界：LAST_PLAYABLE_LAYER=7；第 8 层不生成路线（同位体终局专轮）
func test_last_playable_boundary() -> void:
	print("[内容边界：第 7 层＝本段最后可玩层；第 8 层待专轮]")
	check(LayerConfig.LAST_PLAYABLE_LAYER == 7, "最后可玩层＝7")
	check(LayerConfig.has_content(1) and LayerConfig.has_content(7), "教程层与第 7 层有内容")
	check(not LayerConfig.has_content(8), "第 8 层无内容（待专轮）")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13579
	check(LayerConfig.generate_route(8, rng).is_empty(), "第 8 层不生成路线")
	check(LayerConfig.transition_lines(7).size() == 3, "第 7 层过渡读白兼待续钩子")
	var run := RunState.new()
	run.tutorial_done = true
	run.current_layer = 8
	check(run.is_demo_end(), "停在第 8 层＝demo 边界")
	check(not run.is_layer_unlocked(8), "第 8 层锁定")


# 层内续航（design-round8）：事件效果合入 pending_hp_delta → 入战 HP；clamp/清零/默认值
func test_entry_hp_modifier() -> void:
	print("[层内续航：事件效果合入入场 HP 修正（clamp/清零/入战）]")
	var run := RunState.new()
	check(run.pending_hp_delta == 0 and run.entry_hp() == BattleConfig.PLAYER_MAX_HP, "初始无修正、入场满血")
	run.apply_hp_delta(-1)
	run.apply_hp_delta(-1)
	check(run.pending_hp_delta == -2 and run.entry_hp() == BattleConfig.PLAYER_MAX_HP - 2, "掉血累积")
	run.apply_hp_delta(1)
	check(run.pending_hp_delta == -1, "疗愈抵消掉血")
	run.apply_hp_delta(5)
	check(run.pending_hp_delta == 0, "回血最多抵消到 0（不超满血）")
	run.apply_hp_delta(-30)
	check(run.pending_hp_delta == -19 and run.entry_hp() == 1, "掉血下限 −19（入场至少 1 血）")
	run.reset_layer()
	check(run.pending_hp_delta == 0 and run.entry_hp() == BattleConfig.PLAYER_MAX_HP, "死亡重掷/层完成清零")
	var state := BattleState.new()
	state.start_story(["strike", "strike", "strike", "strike", "strike"], _pool_battle("粉雾歌者"), 8)
	check(state.player_hp == 8, "start_story 带伤入场（8/10）")
	var state2 := BattleState.new()
	state2.start_story(["strike", "strike", "strike", "strike", "strike"], _pool_battle("粉雾歌者"))
	check(state2.player_hp == BattleConfig.PLAYER_MAX_HP, "start_story 默认满血入场")


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
	state.start_story(["strike", "strike", "strike", "strike", "strike"], _pool_battle("粉雾歌者"))
	check(state.mode == BattleState.Mode.STORY, "层战模式")
	check(state.enemy_name == "粉雾歌者" and state.enemy_max_hp == 16, "对手与血量按关卡配置")
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


# L3–7 层层主全链：三键齐备 → 打倒 → STRIP → 收下 → 净化读白 → 结束（STRIP 死锁防线端到端）
func test_boss_strip_flow_layer3() -> void:
	print("[层主净化链 L3–7：打倒 → STRIP → 收下 → 净化读白 → 结束]")
	var sin_by_layer := {3: "gluttony", 4: "greed", 5: "envy", 6: "pride", 7: "anger"}
	for layer in range(3, LayerConfig.LAST_PLAYABLE_LAYER + 1):
		var state := BattleState.new()
		state.start_story(["strike", "strike", "strike", "strike", "strike"], LayerConfig.LAYER_BOSSES[layer])
		check(state.is_boss and state.sin_card_id == sin_by_layer[layer], "第 %d 层层主战收下罪卡＝%s" % [layer, sin_by_layer[layer]])
		state.debug_force_plays = 0
		var safety := 0
		while state.phase == BattleState.Phase.PLAYER and safety < 240:
			safety += 1
			_turn_cycle(state, ["strike"])
		check(state.phase == BattleState.Phase.STRIP, "第 %d 层打倒层主进入净化时刻" % layer)
		check(state.absorb_sin(), "第 %d 层拿起罪卡" % layer)
		check(state.collection.size() == 1 and state.collection[0].id == sin_by_layer[layer], "第 %d 层罪卡进收藏" % layer)
		check(state.phase == BattleState.Phase.DEBRIEF, "第 %d 层进入净化读白" % layer)
		check(state.finish_debrief(), "第 %d 层读完即结束（层战无三问）" % layer)
		check(state.phase == BattleState.Phase.ENDED, "第 %d 层层主战结束" % layer)


func test_multi_enemy_helpers() -> void:
	print("[多敌人：property 退化读写、active 前进、AOE 跳过已倒下、沉睡追伤、治疗封顶]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start_teaching()
	check(state.enemy_name == "蜗牛怪物" and state.enemy_hp == 5 and state.enemy_max_hp == 5, "单敌：property 读首个存活项")
	_teaching_reach_wave2(state)
	check(state.enemies.size() == 3 and state.enemies[0].has("sleeping"), "波 2 三敌（含 sleeping 字段）")
	state.enemies[0]["name"] = "甲"
	state.enemies[1]["name"] = "乙"
	state.enemies[2]["name"] = "丙"
	state.enemy_hp = 2
	check(int(state.enemies[0]["hp"]) == 2 and state.enemy_hp == 2, "property set 写回首个存活项")
	state.enemies[0]["hp"] = 0
	check(state.enemy_name == "乙" and state.enemy_hp == 3, "倒下后 active 前进到下一个存活")
	# AOE 跳过已倒下（甲 0 血不打，乙丙各吃 3 伤）；全灭后 property 回退读第一项
	logs.clear()
	state._apply_effect({"op": "deal_damage", "amount": 3, "target": "all"}, "测试")
	check(_count_log(logs, "甲受到") == 0 and _count_log(logs, "乙受到 3 点伤害。") == 1 and _count_log(logs, "丙受到 3 点伤害。") == 1, "AOE 只打存活的两只")
	check(state.enemy_name == "甲", "全灭后 property 回退第一项")
	# 沉睡追伤：乙丙沉睡 3＋2；甲未沉睡原伤
	state.enemies[0]["hp"] = 3
	state.enemies[0]["sleeping"] = false
	state.enemies[1]["hp"] = 3
	state.enemies[2]["hp"] = 3
	logs.clear()
	state._apply_effect({"op": "deal_damage", "amount": 3, "target": "all", "bonus_vs": "sleeping", "bonus": 2}, "测试")
	check(_count_log(logs, "甲受到 3 点伤害。") == 1 and _count_log(logs, "乙受到 5 点伤害。") == 1 and _count_log(logs, "丙受到 5 点伤害。") == 1, "沉睡 3＋2、未沉睡 3")
	# 治疗封顶（教学战上限 10，用 mode 无关的 player_max_hp 取值）
	state.player_hp = state.player_max_hp()
	logs.clear()
	state._apply_effect({"op": "heal", "amount": 3}, "测试")
	check(state.player_hp == state.player_max_hp() and _log_contains(logs, "没有恢复的必要"), "满血治疗不溢出")
	state.player_hp = state.player_max_hp() - 1
	logs.clear()
	state._apply_effect({"op": "heal", "amount": 3}, "测试")
	check(state.player_hp == state.player_max_hp() and _log_contains(logs, "你恢复了 1 点生命。（生命 10）"), "按缺口封顶恢复")


func test_teaching_battle_logic() -> void:
	print("[蜗牛教学战：单位制 4＋钉死牌组节拍（波 1 补刀 → 波 2 沉睡 → 净化＋强欲魔弹清场）]")
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	state.start_teaching()
	check(state.mode == BattleState.Mode.TEACHING, "教学战模式")
	check(state.max_cost == 4 and state.player_cost == 4, "单位制：魔力总量 4")
	check(state.player_hp == 8, "开局生命 8（摔伤，演示治疗）")
	check(state.enemy_name == "蜗牛怪物" and state.enemy_hp == 5, "波 1：蜗牛怪物 5 血")
	check(state.hand.size() == 5 and state.hand[0].id == "guard" and state.hand[1].id == "strike" and state.hand[2].id == "strike" and state.hand[3].id == "heal" and state.hand[4].id == "strike", "钉死开局手：防御＋魔弹×2＋治疗＋魔弹")
	check(state.draw_pile.size() == 3 and state.draw_pile[0].id == "strike" and state.draw_pile[1].id == "greed_shot" and state.draw_pile[2].id == "cleanse", "牌堆 3 张：魔弹＋强欲魔弹＋净化")
	check(state.enemy_hand.size() == 3, "敌方蜗牛牌组 3 张全入手")
	check(_count_log(logs, String(BattleConfig.TEXT_TEACHING_START[0])) == 1 and _count_log(logs, String(BattleConfig.TEXT_TEACHING_START[1])) == 1 and _count_log(logs, String(BattleConfig.TEXT_TEACHING_START[2])) == 1, "开局三条莉维娅引导语")
	# 回合 1：防住 2 伤蜗牛撞击＋两发魔弹打剩 1 血＋治疗封顶
	state.stage_card(_find_card(state.hand, "guard"))
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "strike"))
	state.stage_card(_find_card(state.hand, "heal"))
	check(state.staged_cost() == 4 and state.commit_staged(), "4 单位打满一批打出")
	check(state.enemy_hp == 1, "两发魔弹 5→1（留一口气）")
	check(state.player_hp == 10 and _log_contains(logs, "你恢复了 2 点生命。（生命 10）"), "治疗按缺口恢复 8→10（封顶 10）")
	check(_log_contains(logs, "它整个被挡住了。"), "2 点格挡正好挡下蜗牛撞击（2 伤）")
	check(state.turn_count == 2 and state.player_cost == 4, "进入第 2 回合，魔力刷新为 4")
	check(_count_log(logs, BattleConfig.TEXT_TEACHING_TURN_KILL) == 1, "莉维娅提示补刀")
	# 回合 2：补刀 → 波 2 三只群怪沉睡登场
	state.stage_card(_find_card(state.hand, "strike"))
	check(state.commit_staged(), "补刀打出")
	check(state.enemies.size() == 3 and state.teaching_wave_index == 1, "波 2：三只蜗牛群怪")
	var all_sleeping := true
	for enemy in state.enemies:
		all_sleeping = all_sleeping and int(enemy["hp"]) == 3 and bool(enemy["sleeping"])
	check(all_sleeping, "群怪 3 血全沉睡（懒惰之力压制）")
	check(state.pending_sleep and state.sleep_deadline_turn == 4, "睡意倒计时＝回合 2＋2")
	check(_count_log(logs, BattleConfig.TEXT_TEACHING_FIRST_FELL) == 1 and _count_log(logs, BattleConfig.TEXT_TEACHING_SLEEP_EVENT) == 1 and _count_log(logs, BattleConfig.TEXT_TEACHING_SLEEP_HINT) == 1, "波 2 登场三条读白")
	check(_count_log(logs, BattleConfig.TEXT_ENEMY_SLEEPING % "蜗牛群怪") == 1, "敌人回合：沉睡不出手")
	check(state.turn_count == 3 and _count_log(logs, BattleConfig.TEXT_TEACHING_TURN_WAVE2) == 1, "第 3 回合提示净化＋强欲魔弹")
	# 回合 3：净化免疫＋强欲魔弹群体追伤清场
	var cleanse_index := _find_card(state.hand, "cleanse")
	var greed_index := _find_card(state.hand, "greed_shot")
	check(cleanse_index >= 0 and greed_index >= 0, "净化与强欲魔弹在手")
	state.stage_card(cleanse_index)
	if greed_index > cleanse_index:
		greed_index -= 1
	state.stage_card(greed_index)
	check(state.staged_cost() == 4, "净化 1＋强欲魔弹 3＝4 单位")
	check(state.commit_staged(), "清场")
	check(state.sleep_immune and not state.pending_sleep, "净化：免疫并清掉待发睡意")
	check(_count_log(logs, BattleConfig.TEXT_CLEANSE_SLEEP) == 1, "净化挡下睡意读白")
	check(_count_log(logs, "蜗牛群怪受到 5 点伤害。") == 3, "强欲魔弹 3＋沉睡追伤 2＝5 × 3")
	check(state.phase == BattleState.Phase.ENDED and _count_log(logs, BattleConfig.TEXT_TEACHING_WIN) == 1, "全灭＝教学战结束")
	check(not state.absorb_sin() and state.collection.is_empty(), "教学战不进净化段、无收藏")


func test_teaching_sleep_timeout() -> void:
	print("[蜗牛教学战·睡意超时：不净化＝第 4 回合被跳过（一次）；净化＝不受影响]")
	# 分支 A：不净化，空过一回合 → 倒计时到点，第 4 回合魔力归零；第 5 回合恢复
	var logs_a: Array = []
	var state_a := BattleState.new()
	state_a.log_event.connect(func(text: String) -> void: logs_a.append(text))
	state_a.start_teaching()
	_teaching_reach_wave2(state_a)
	check(state_a.turn_count == 3 and state_a.player_cost == 4, "到第 3 回合（倒计时剩 1）")
	check(state_a.end_turn(), "空过第 3 回合")
	check(state_a.turn_count == 4 and state_a.player_cost == 0, "第 4 回合：睡意到点，魔力归零")
	check(_count_log(logs_a, BattleConfig.TEXT_SLEEP_SKIP) == 1, "睡意跳过读白出现一次")
	check(not state_a.pending_sleep, "跳过即消耗睡意")
	state_a.end_turn()
	check(state_a.turn_count == 5 and state_a.player_cost == 4, "第 5 回合魔力恢复（走完即解）")
	check(_count_log(logs_a, BattleConfig.TEXT_SLEEP_SKIP) == 1, "此后不再触发")
	# 分支 B：第 3 回合净化 → 第 4 回合不进跳过
	var logs_b: Array = []
	var state_b := BattleState.new()
	state_b.log_event.connect(func(text: String) -> void: logs_b.append(text))
	state_b.start_teaching()
	_teaching_reach_wave2(state_b)
	state_b.stage_card(_find_card(state_b.hand, "cleanse"))
	check(state_b.commit_staged(), "第 3 回合净化")
	check(state_b.turn_count == 4 and state_b.player_cost == 4, "第 4 回合：已免疫，魔力正常")
	check(_count_log(logs_b, BattleConfig.TEXT_SLEEP_SKIP) == 0, "无睡意跳过读白")


func test_battle_scene_tutorial() -> void:
	print("[战斗场景·教程模式：拖拽摆放 → 收回 → 打出 → 完整一局]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	check(packed != null, "battle.tscn 可加载")
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	# 注入确定性卡组：新默认卡组只有 4 张普通魔弹，若开局没摸到会找不到「第一张魔弹」按钮
	scene.configure(BattleState.Mode.TUTORIAL, ["strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
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
	check(play_box.get_child_count() == BattleConfig.PLAY_ZONE_SIZE, "出牌区有 4 个卡槽")
	check(commit_button.disabled and commit_button.text == "打出", "空出牌区时「打出」置灰")
	check(timer_label.text == "剩余 45 秒", "开局计时 45 秒")
	var cost_label := scene.get_node("%CostLabel") as Label
	_check_cost_label(scene, "Cost 6 / 6", "开局 Cost 显示 6/6")
	var first_strike := _first_live_button(hand_box, "普通魔弹")
	check(first_strike != null, "手里有普通魔弹")
	check(first_strike.drag_zone == "hand", "手牌处于可拖状态")
	check(_drag_card_to(scene, first_strike, play_box), "拖手牌到出牌区")
	check(scene.state.staged.size() == 1, "拖拽摆进出牌区")
	_check_cost_label(scene, "Cost 5 / 6", "摆放后可用 Cost 实时下调（5/6，摆放不扣实扣）")
	check(commit_button.text == "打出（Cost -1）", "打出按钮预告合计 Cost")
	var staged_button := _first_live_button(play_box, "普通魔弹")
	check(staged_button != null, "出牌区出现已摆的牌")
	staged_button.pressed.emit()
	check(scene.state.staged.is_empty(), "点击已摆的牌收回")
	_check_cost_label(scene, "Cost 6 / 6", "收回后可用 Cost 实时恢复（6/6）")
	var strike_again := _first_live_button(hand_box, "普通魔弹")
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
	check(scene.state.enemy_hp == BattleConfig.ENEMY_MAX_HP - 2, "普通魔弹照常生效")
	check(scene.state.staged.is_empty(), "打出后出牌区清空")
	_check_cost_label(scene, "Cost 6 / 6", "打出即结束回合，新回合 Cost 重置满")
	check(timer_label.text == "剩余 45 秒", "新回合计时重置")
	check(scene.state.player_hp == BattleConfig.PLAYER_MAX_HP - 2, "打出后对方出了 1 张，打了 2 点")
	check(enemy_hand_label.text == "手牌 8 张", "敌人出 1 张再摸 4 张，手牌显示 8 张")
	check(commit_button.disabled and commit_button.text == "打出", "新回合打出按钮回到初始态")
	check(not end_turn_button.disabled, "新回合结束回合按钮可用")
	var strike_next := _first_live_button(hand_box, "普通魔弹")
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
	check(story.text.contains("白雾"), "净化时刻读白在屏上")
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
	_check_cost_label(scene, "Cost 6 / 6", "练习模式也是同一套 Cost")
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


func test_teaching_battle_scene() -> void:
	print("[教学战场景：拖拽摆放打满 4 单位 → 波 2 群怪列表 → 清场即结束（无覆盖层）]")
	var scene: Variant = (load("res://scenes/battle.tscn") as PackedScene).instantiate()
	scene.configure(BattleState.Mode.TEACHING, [])
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var commit_button := scene.get_node("%CommitButton") as Button
	var ended_calls: Array = []
	scene.battle_ended.connect(func(practice: bool) -> void: ended_calls.append(practice))
	check((scene.get_node("%TurnTimerLabel") as Label).text == "剩余 90 秒", "教学战时限 90 秒")
	_check_cost_label(scene, "Cost 4 / 4", "单位制 4")
	var enemy_list := scene.get_node("EnemyListLabel") as Label
	check(not enemy_list.visible, "单敌时敌人列表隐藏")
	check(not (scene.get_node("%QuitPracticeButton") as Button).visible, "教学战无结束练习按钮")
	check(not (scene.get_node("%Overlay") as Control).visible, "开局无覆盖层")
	# 回合 1：拖 防御＋魔弹×2＋治疗 → Cost 打空 → 打出
	check(_drag_card_to(scene, _first_live_button(hand_box, "普通防御"), play_box), "拖防御进区")
	check(_drag_card_to(scene, _first_live_button(hand_box, "普通魔弹"), play_box), "拖第一张魔弹")
	check(_drag_card_to(scene, _first_live_button(hand_box, "普通魔弹"), play_box), "拖第二张魔弹")
	check(_drag_card_to(scene, _first_live_button(hand_box, "治疗术"), play_box), "拖治疗术")
	check(scene.state.staged_cost() == 4, "4 单位打满")
	_check_cost_label(scene, "Cost 0 / 4", "可用 Cost 归零")
	commit_button.pressed.emit()
	check(scene.state.enemy_hp == 1, "蜗牛 5→1")
	check((scene.get_node("%PlayerHpLabel") as Label).text == "你：10 / 10", "治疗封顶后血线 10")
	# 回合 2：补刀 → 波 2 沉睡登场，右上角逐行显示三只
	check(_drag_card_to(scene, _first_live_button(hand_box, "普通魔弹"), play_box), "拖补刀魔弹")
	commit_button.pressed.emit()
	check(scene.state.teaching_wave_index == 1, "推进到波 2")
	check(enemy_list.visible and enemy_list.text.count("3 / 3") == 3, "敌人列表逐行显示三只 3/3（实际：" + enemy_list.text.replace("\n", "｜") + "）")
	# 回合 3：净化＋强欲魔弹 → 清场结束
	check(_drag_card_to(scene, _first_live_button(hand_box, "净化"), play_box), "拖净化")
	check(_drag_card_to(scene, _first_live_button(hand_box, "强欲魔弹"), play_box), "拖强欲魔弹")
	commit_button.pressed.emit()
	check(scene.state.phase == BattleState.Phase.ENDED, "清场即结束")
	check(ended_calls == [false], "结束上报：非练习")
	check(not (scene.get_node("%Overlay") as Control).visible, "教学战结束不进覆盖层")
	viewport.queue_free()
	await process_frame


func test_prologue_page() -> void:
	print("[初幕演出页：9 拍推进、名牌/立绘切换、末拍「迎战」、结束信号]")
	var page := ProloguePage.new()
	var viewport := _attach_scene(page)
	await process_frame
	var finished_count := [0]
	page.finished.connect(func() -> void: finished_count[0] += 1)
	page.start()
	var text_label := page._text_label as Label
	var speaker_label := page._speaker_label as Label
	var portrait := page._portrait as TextureRect
	var button := page._continue_button as Button
	check(page.visible, "演出页可见")
	check(text_label.text.contains("音海市") and text_label.text.contains("贝嘉"), "第 1 拍：现世·夜（出租屋）")
	check(not speaker_label.visible, "第 1 拍旁白无名牌")
	for _i in 2:
		button.pressed.emit()
	check(speaker_label.visible and speaker_label.text == "菲戈蕾", "第 3 拍：菲戈蕾说话")
	check(text_label.text.contains("丁香紫"), "菲戈蕾立绘拍文案（丁香紫的眼睛）")
	check(portrait.visible == FileAccess.file_exists(PrologueData.BG_DIR + "figelie.png"), "立绘显示随素材在场")
	for _i in 2:
		button.pressed.emit()
	check(speaker_label.text == "莉维娅", "第 5 拍：莉维娅（意识分身）")
	for _i in 2:
		button.pressed.emit()
	check(text_label.text.contains("八层重叠的魔法结界"), "第 7 拍：八层结界与七位魔法少女设定")
	button.pressed.emit()
	check(text_label.text.contains("华丽裙装") and text_label.text.contains("自动变换"), "第 8 拍：力量＝服装变换（新稿，design-round11）")
	button.pressed.emit()
	check(text_label.text.contains("彻底污染") and button.text == "迎战", "末拍：菲戈蕾被彻底污染，按钮＝迎战")
	check(finished_count[0] == 0, "末拍仍在演出中")
	button.pressed.emit()
	check(finished_count[0] == 1, "第 9 次推进发出结束信号")
	viewport.queue_free()
	await process_frame


func test_story_beats() -> void:
	print("[追及/第二幕拍表：字段完整、素材在场、关键句、末拍按钮；演出页换表参数化（design-round11）]")
	check(StoryBeats.CHASE_BEATS.size() >= 8 and StoryBeats.ACT2_BEATS.size() >= 10, "两拍表非空且规模合理")
	var fields_ok := true
	var bgs_ok := true
	var chase_text := ""
	var act2_text := ""
	for beats in [StoryBeats.CHASE_BEATS, StoryBeats.ACT2_BEATS]:
		for beat in beats:
			var text := String(beat.get("text", ""))
			if text == "" or String(beat.get("button_label", "")) == "" or not (beat.get("bg_color") is Color):
				fields_ok = false
			var bg := String(beat.get("bg", ""))
			if bg == "" or not FileAccess.file_exists(StoryBeats.BG_DIR + bg + ".png"):
				bgs_ok = false
	for beat in StoryBeats.CHASE_BEATS:
		chase_text += String(beat.get("text", "")) + "\n"
	for beat in StoryBeats.ACT2_BEATS:
		act2_text += String(beat.get("text", "")) + "\n"
	check(fields_ok, "每拍：文本/按钮/底色齐全")
	check(bgs_ok, "每拍底图素材在场（含 3 张新图）")
	check(chase_text.contains("被污染了，会很痛苦吗") and chase_text.contains("三无") and chase_text.contains("树洞"), "追及段关键句在场（痛苦问答/三无来历/树洞问答）")
	var last_chase: Dictionary = StoryBeats.CHASE_BEATS[StoryBeats.CHASE_BEATS.size() - 1]
	check(String(last_chase.get("bg", "")) == "bg_tree_hollow" and String(last_chase.get("button_label", "")) == "面对她", "追及末拍＝树洞入口，按钮面对她")
	check(act2_text.contains("意识体") and act2_text.contains("强欲") and act2_text.contains("请救救我"), "第二幕关键句在场（意识体/强欲/请救救我）")
	var last_act2: Dictionary = StoryBeats.ACT2_BEATS[StoryBeats.ACT2_BEATS.size() - 1]
	check(String(last_act2.get("button_label", "")) == "进入第二层", "第二幕末拍按钮＝进入第二层")
	# 演出页换表参数化：新建页缺省＝初幕表；传表后按新表推进
	var page := ProloguePage.new()
	var viewport := _attach_scene(page)
	await process_frame
	page.start()
	check((page._text_label as Label).text.contains("音海市"), "无参 start()＝初幕表")
	page.start(StoryBeats.CHASE_BEATS)
	check((page._text_label as Label).text.contains("毫不费力"), "传表 start()＝追及表首拍")
	check(page._beats.size() == StoryBeats.CHASE_BEATS.size(), "换表后按新表推进")
	viewport.queue_free()
	await process_frame


func test_battle_scene_defeat() -> void:
	print("[战斗场景·判负：覆盖层＋battle_lost，不发 battle_ended]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	scene.configure(BattleState.Mode.STORY, ["strike", "strike", "strike", "strike", "strike"], _pool_battle("粉雾歌者"))
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
	print("[层地图页：四态（已净化/当前/未解锁/待续）＋当前层展开路线图（节点四态）]")
	var page := MapPage.new()
	var viewport := _attach_scene(page)
	# SubViewport 不会给直接 Control 子节点自动定尺寸，手动给全屏矩形（真机里由父级布局给）
	page.size = Vector2(1280, 720)
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
	check(layer3 != null and layer3.text.contains("未解锁") and not layer3.disabled, "第 3 层未解锁可点（有内容）")
	layer3.pressed.emit()
	check(page._toast.visible and page._toast.text.contains("先走完"), "点未解锁层提示先走完前面的层")
	var layer8 := _deep_find_button(page, "第 8 层·同位体")
	check(layer8 != null and layer8.text.contains("待续") and not layer8.disabled, "第 8 层待续可点（无内容）")
	layer8.pressed.emit()
	check(page._toast.visible and page._toast.text.contains("待续"), "点待续层提示待续")
	var fog := _deep_find_button(page, "事件·试衣镜")
	var pol1 := _deep_find_button(page, "作战·粉雾歌者")
	var mirror := _deep_find_button(page, "事件·糖果摊")
	check(fog != null and not fog.disabled, "第一列事件节点可选")
	check(pol1 != null and not pol1.disabled, "同列作战节点也可选")
	check(mirror != null and not mirror.disabled, "同列第三个节点可选")
	var echo := _deep_find_button(page, "作战·糖丝傀儡")
	check(echo != null and echo.disabled, "下一列节点未到不可点")
	var boss_node := _deep_find_button(page, "层主战·阿斯莫德")
	check(boss_node != null and boss_node.disabled, "层主战节点未到不可点")
	fog.pressed.emit()
	check(picks == [0], "点击节点发出 node_requested(0)")
	run.choose(0)
	page.build(run)
	await process_frame
	var fog_after := _deep_find_button(page, "事件·试衣镜")
	check(fog_after.text.contains("✓") and fog_after.disabled, "已走节点标 ✓ 不可再点")
	var pol_after := _deep_find_button(page, "作战·粉雾歌者")
	check(pol_after.text.contains("✕") and pol_after.disabled, "同列未选标 ✕ 错失")
	var echo_after := _deep_find_button(page, "作战·糖丝傀儡")
	check(echo_after != null and not echo_after.disabled, "推进后第二列可选")
	var candle_after := _deep_find_button(page, "事件·合唱席")
	check(candle_after != null and not candle_after.disabled, "第二列事件节点可选")
	check(_deep_find_button(page, "返回主菜单") != null and _deep_find_button(page, "进入练习站") != null, "地图底部有练习站与主菜单入口")
	check(page._route_hint.text == MapPage.ROUTE_HINT, "短线（三列 648px）不出现拖动提示")
	await process_frame
	var short_scroll := _deep_find_scroll(page)
	check(short_scroll != null and short_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "短线收起横向滚动条（不常显）")
	viewport.queue_free()
	await process_frame


func test_map_route_scroll() -> void:
	print("[层地图页·路线长线：横向滚动＋拖拽/滚轮＋节点命中＋聚焦当前列]")
	var page := MapPage.new()
	var viewport := _attach_scene(page)
	page.size = Vector2(1280, 720)
	await process_frame
	var run := RunState.new()
	run.tutorial_done = true
	run.route = _long_route()
	run.route_layer = run.current_layer
	var picks: Array = []
	page.node_requested.connect(func(index: int) -> void: picks.append(index))
	page.build(run)
	await process_frame
	await process_frame
	var scroll := _deep_find_scroll(page)
	check(scroll != null, "路线区包在横向滚动容器里")
	var route := _deep_find_route(page)
	check(route != null, "路线图在滚动容器内")
	if scroll == null or route == null:
		viewport.queue_free()
		return
	check(route._content_size.x > scroll.size.x, "长线内容宽 1608px 超视口 %.0fpx" % scroll.size.x)
	check(page._route_hint.text == MapPage.ROUTE_HINT_SCROLL, "溢出时提示可左右拖动")
	check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "纵向不滚动（只横向拉）")
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "长线横向可滚（滚动条显示）")
	# 点击首列节点（真实鼠标事件，非 pressed.emit）
	var pol := _deep_find_button(page, "作战·粉雾歌者")
	check(pol != null, "首列作战节点在屏")
	var center := pol.get_global_rect().get_center()
	_push_mouse_button(viewport, center, true)
	_push_mouse_button(viewport, center, false)
	check(picks == [0], "点击节点发出 node_requested(0)")
	# 起点压在列间隙空白处（列 0 右缘 168 与列 1 左缘 240 之间）拖动
	var blank := route.get_global_transform() * Vector2(204.0, route.size.y / 2.0)
	_push_mouse_button(viewport, blank, true)
	_push_mouse_motion(viewport, blank + Vector2(-80, 0))
	check(scroll.scroll_horizontal > 0, "空白处按住左拖＝横向拉动（scroll=%d）" % scroll.scroll_horizontal)
	var after_drag := scroll.scroll_horizontal
	_push_mouse_button(viewport, blank + Vector2(-80, 0), false)
	_push_mouse_motion(viewport, blank + Vector2(-160, 0))
	check(scroll.scroll_horizontal == after_drag, "松开后移动不再拉动")
	# 滚动后节点仍可点中（按钮跟着内容位移）
	center = pol.get_global_rect().get_center()
	_push_mouse_button(viewport, center, true)
	_push_mouse_button(viewport, center, false)
	check(picks == [0, 0], "滚动后点节点仍命中")
	# 滚轮＝横向拉动（事件从 PASS 按钮冒泡到路线图）
	scroll.scroll_horizontal = 0
	_push_wheel(viewport, pol.get_global_rect().get_center(), true)
	check(scroll.scroll_horizontal == 180, "滚轮下滚＝右移一格（180px）")
	_push_wheel(viewport, blank, false)
	check(scroll.scroll_horizontal == 0, "滚轮上滚回退")
	# 返回地图聚焦当前列：进度到第 4 列后重建，滚动位置自动带过去
	var chosen: Array[int] = [0, 0, 0]
	run.chosen = chosen
	run.column_index = 3
	page.build(run)
	await process_frame
	await process_frame
	var scroll2 := _deep_find_scroll(page)
	check(scroll2 != null and scroll2.scroll_horizontal > 0, "重建后当前列（第 4 列）自动带进视野")
	viewport.queue_free()
	await process_frame


func test_event_page() -> void:
	print("[事件页：小玩法结算 → 就地反馈（＋game_resolved）→ 完成]")
	var page := EventPage.new()
	var viewport := _attach_scene(page)
	await process_frame
	var done: Array = []
	var resolved: Array = []
	page.completed.connect(func() -> void: done.append(true))
	page.game_resolved.connect(func(outcome: Dictionary) -> void: resolved.append(outcome))
	var stage: Dictionary = _pool_event("试衣镜")
	page.show_event(stage)
	await process_frame
	check(page._title.text == "试衣镜", "标题按关卡")
	check(page._scene.text.contains("试衣镜"), "场景说明在屏上")
	var panel := page._panel as PickPanel
	check(panel != null, "注入择一小玩法面板")
	var complete_button := page._complete_button as Button
	check(complete_button.disabled, "未结算不能完成")
	panel.select(0)
	check(complete_button.disabled, "选中还没执行＝不能完成")
	panel._on_exec_pressed()
	check(not complete_button.disabled, "结算后可以完成")
	check(page._pending_outcome == {"hp": 1}, "结算结果记入待完成 outcome")
	check(page._feedback.text.contains("布料软得像雾"), "结算读白在屏")
	panel._on_exec_pressed()
	check(page._pending_outcome == {"hp": 1}, "重复执行被挡（已提交）")
	complete_button.pressed.emit()
	check(done == [true], "发出 completed")
	check(resolved == [{"hp": 1}], "先发出 game_resolved（带 outcome）")
	# 第二个事件（合唱席）重开：面板替换、反馈清空、完成复位
	var candle: Dictionary = _pool_event("合唱席")
	page.show_event(candle)
	await process_frame
	check(page._title.text == "合唱席", "第二列事件节点数据完整")
	check(page._panel is PickPanel and page._panel != panel, "第二个事件注入新面板")
	check(page._pending_outcome.is_empty() and complete_button.disabled, "重开后待完成结果清空、完成按钮复位")
	check(page._feedback.text == "", "重开后反馈清空")
	viewport.queue_free()
	await process_frame


# 事件效果结算链（design-round10 §4）：小玩法 outcome → 完成落账 → 下一战落地（hp 续航＋block/draw 轻增益＋消费）
func test_event_effect_flow() -> void:
	print("[事件效果结算：揭示全翻 → 层内续航＋下一战轻增益 → 入战消费]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	await process_frame
	main.run.tutorial_done = true
	main.run.route = [[_pool_event("粉焰之墙")], [_pool_battle("糖丝傀儡")]]
	main.run.route_layer = main.run.current_layer
	main._open_map()
	var map_page := main.get_node("%MapPage") as Control
	var event_page := main.get_node("%EventPage") as Control
	var confirm_primary := main.get_node("%ConfirmPrimaryButton") as Button
	var flame := _deep_find_button(map_page, "事件·粉焰之墙")
	check(flame != null and not flame.disabled, "第一列事件节点当前可点")
	flame.pressed.emit()
	confirm_primary.pressed.emit()
	check(event_page.visible, "进入事件页")
	await process_frame
	await process_frame
	var reveal := event_page._panel as RevealPanel
	check(reveal != null, "注入揭示小玩法面板")
	# 真实鼠标拖出第一张（温）：松手任意处＝翻面
	var prop0 := reveal._props[0] as EventPropCard
	_mouse_drag(viewport, prop0.get_global_rect().get_center(), prop0.get_global_rect().get_center() + Vector2(90.0, 90.0))
	check(reveal.flipped_indices() == [0], "拖出的牌翻面（真实鼠标）")
	check((event_page._complete_button as Button).disabled, "只翻一张还没结算＝不能完成")
	# 翻完剩余两张 → reveal+finish 变体自动结算
	reveal.flip(1)
	reveal.flip(2)
	check(reveal.flipped_indices() == [0, 1, 2], "三张全翻")
	check(event_page._pending_outcome == {"hp": -1, "block": 1}, "全翻＝逐卡 Σ＋奖励（生命−1・格挡+1）")
	check(event_page._feedback.text.contains("你伸手碰过每一簇火"), "全翻奖励读白在屏")
	check(event_page._feedback.text.contains("生命 -1 · 开局格挡 +1"), "自动结果行在屏")
	reveal.flip(0)
	check(reveal.flipped_indices() == [0, 1, 2], "重复翻同一张幂等")
	check(main.run.pending_hp_delta == 0 and main.run.pending_block == 0, "完成前不落账（game_resolved 在完成时发）")
	(event_page._complete_button as Button).pressed.emit()
	check(map_page.visible, "事件完成回地图")
	check(main.run.pending_hp_delta == -1, "hp 修正落账（层内续航 −1）")
	check(main.run.pending_block == 1, "格挡落账（下一战 +1）")
	# 第二列·作战（糖丝傀儡）：带伤入场 19/20，开局格挡 +1 并在开战时消费
	var echo := _deep_find_button(map_page, "作战·糖丝傀儡")
	echo.pressed.emit()
	confirm_primary.pressed.emit()
	await process_frame
	var battle_host := main.get_node("%BattleHost") as Control
	check(battle_host.get_child_count() == 1, "进入战斗位")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.enemy_name == "糖丝傀儡", "第二列作战按节点")
	check(battle.state.player_hp == BattleConfig.PLAYER_MAX_HP - 1, "带伤入场（你：19 / 20）")
	check((battle.get_node("%PlayerHpLabel") as Label).text == "你：19 / 20", "入战 HUD 显示带伤入场")
	check(battle.state.player_block == 1, "开局格挡 +1 已上手")
	check(battle.state.hand.size() == BattleConfig.HAND_SIZE, "起手张数＝默认（本场无多抽）")
	var battle_log := battle.get_node("%LogText") as RichTextLabel
	check(battle_log.get_parsed_text().contains("备战：开局 +1 格挡"), "备战日志行在战斗日志")
	check(main.run.pending_block == 0 and main.run.pending_draw == 0, "轻增益开战即消费")
	check(main.run.pending_hp_delta == -1, "hp 修正不随开战消费（层内保留）")
	viewport.queue_free()
	await process_frame


# 四模块面板交互（design-round10 §1/§5）：真实鼠标拖拽走引擎投放链（含槽位 PanelContainer 穿透）
func test_event_panels() -> void:
	print("[小玩法面板：择一/分拣（含容量拒收）/配平（含取下）/揭示——真实鼠标拖拽]")
	var page := EventPage.new()
	var viewport := _attach_scene(page)
	await process_frame
	await process_frame
	var resolved: Array = []
	page.game_resolved.connect(func(outcome: Dictionary) -> void: resolved.append(outcome))
	var complete_button := page._complete_button as Button
	# 择一（试衣镜）：拖第一张进行动槽 → 执行 → 完成
	page.show_event(_pool_event("试衣镜"))
	await process_frame
	await process_frame
	var pick := page._panel as PickPanel
	check(pick != null, "择一面板在")
	_mouse_drag(viewport, (pick._props[0] as EventPropCard).get_global_rect().get_center(), pick._slot.get_global_rect().get_center())
	check(pick._selected == 0, "择一：拖进行动槽即选中（引擎投放链打到面板）")
	pick._on_exec_pressed()
	check(page._pending_outcome == {"hp": 1}, "择一：执行结算")
	complete_button.pressed.emit()
	# 分拣（果子树）：左筐容量 2（第三张被拒）；全放好才能收好
	page.show_event(_find_event("果子树"))
	await process_frame
	await process_frame
	var sort_panel := page._panel as SortPanel
	check(sort_panel != null, "分拣面板在")
	var props := sort_panel._props
	var left_center := sort_panel._left_slot.get_global_rect().get_center()
	var right_center := sort_panel._right_slot.get_global_rect().get_center()
	_mouse_drag(viewport, (props[0] as EventPropCard).get_global_rect().get_center(), left_center)
	_mouse_drag(viewport, (props[1] as EventPropCard).get_global_rect().get_center(), left_center)
	check(sort_panel.side_of(0) == "left" and sort_panel.side_of(1) == "left", "分拣：两张进左筐")
	check((sort_panel._done_button as Button).disabled, "分拣：没放完不能收好")
	_mouse_drag(viewport, (props[2] as EventPropCard).get_global_rect().get_center(), left_center)
	check(sort_panel.side_of(2) == "", "分拣：左筐超容量被拒")
	_mouse_drag(viewport, (props[2] as EventPropCard).get_global_rect().get_center(), right_center)
	_mouse_drag(viewport, (props[3] as EventPropCard).get_global_rect().get_center(), right_center)
	check(sort_panel.side_of(2) == "right" and sort_panel.side_of(3) == "right", "分拣：其余进右筐")
	check(not (sort_panel._done_button as Button).disabled, "分拣：全放好可以收好")
	(sort_panel._done_button as Button).pressed.emit()
	check(page._pending_outcome == {"draw": 1}, "分拣：收好结算（树顶留树上＝起手多抽 1）")
	complete_button.pressed.emit()
	# 配平（天平房）：上盘/拖回取下往返；凑满目标 → 称量
	page.show_event(_find_event("天平房"))
	await process_frame
	await process_frame
	var bal := page._panel as BalancePanel
	check(bal != null, "配平面板在")
	var bal_props := bal._props
	_mouse_drag(viewport, (bal_props[0] as EventPropCard).get_global_rect().get_center(), bal._pan.get_global_rect().get_center())
	check(bal.pan_indices() == [0], "配平：金币上盘")
	_mouse_drag(viewport, (bal_props[0] as EventPropCard).get_global_rect().get_center(), bal._shelf.get_global_rect().get_center())
	check(bal.pan_indices().is_empty(), "配平：拖回架上取下")
	_mouse_drag(viewport, (bal_props[2] as EventPropCard).get_global_rect().get_center(), bal._pan.get_global_rect().get_center())
	_mouse_drag(viewport, (bal_props[3] as EventPropCard).get_global_rect().get_center(), bal._pan.get_global_rect().get_center())
	_mouse_drag(viewport, (bal_props[4] as EventPropCard).get_global_rect().get_center(), bal._pan.get_global_rect().get_center())
	check(bal.pan_indices() == [2, 3, 4], "配平：三件上盘（3+2+1＝6）")
	check(bal._pan_label.text.contains("差 0"), "配平：实时差值归零")
	(bal._weigh_button as Button).pressed.emit()
	check(page._pending_outcome == {"hp": 1}, "配平：分毫不差 → 生命+1")
	complete_button.pressed.emit()
	# 揭示（糖果摊）：拖一张翻开、随时收手
	page.show_event(_pool_event("糖果摊"))
	await process_frame
	await process_frame
	var reveal := page._panel as RevealPanel
	check(reveal != null, "揭示面板在")
	var candy := reveal._props[1] as EventPropCard
	var candy_center := candy.get_global_rect().get_center()
	_mouse_drag(viewport, candy_center, candy_center + Vector2(90.0, 90.0))
	check(reveal.flipped_indices() == [1], "揭示：拖出即翻（糖纸）")
	check(complete_button.disabled, "揭示：还没收手不能完成")
	(reveal._stop_button as Button).pressed.emit()
	check(page._pending_outcome == {"hp": 1}, "揭示：收手结算已翻的账")
	check(page._feedback.text.contains("手背于是轻快了一点"), "揭示：逐卡读白在屏")
	complete_button.pressed.emit()
	check(resolved == [{"hp": 1}, {"draw": 1}, {"hp": 1}, {"hp": 1}], "四次结算 payload 依次累积")
	viewport.queue_free()
	await process_frame


# 轻增益生命周期（design-round10 §4）：累加封顶 → story 开战消费 → 层重置清零；练习不消费
func test_event_buff_lifecycle() -> void:
	print("[轻增益生命周期：累加封顶/消费/层重置；story 领 buff、练习不吃、地图备战线]")
	var run := RunState.new()
	run.apply_outcome({"block": 2})
	run.apply_outcome({"block": 1})
	check(run.pending_block == 3, "格挡累加")
	run.apply_outcome({"block": 2})
	check(run.pending_block == BattleConfig.PREP_BLOCK_CAP, "格挡封顶 %d" % BattleConfig.PREP_BLOCK_CAP)
	run.apply_outcome({"draw": 1})
	run.apply_outcome({"draw": 1})
	run.apply_outcome({"draw": 1})
	check(run.pending_draw == BattleConfig.PREP_DRAW_CAP, "多抽封顶 %d" % BattleConfig.PREP_DRAW_CAP)
	run.apply_hp_delta(-2)
	check(run.pending_hp_delta == -2 and run.entry_hp() == BattleConfig.PLAYER_MAX_HP - 2, "hp 修正与轻增益互不干扰")
	run.consume_buffs()
	check(run.pending_block == 0 and run.pending_draw == 0 and run.pending_hp_delta == -2, "消费只清轻增益、血修正保留")
	run.reset_layer()
	check(run.pending_block == 0 and run.pending_draw == 0 and run.pending_hp_delta == 0, "层重置全清")
	# 战斗侧：story 开局领格挡＋多抽并留日志
	var logs: Array = []
	var state := BattleState.new()
	state.log_event.connect(func(text: String) -> void: logs.append(text))
	var deck: Array = []
	for i in BattleConfig.DECK_SIZE:
		deck.append("strike")
	state.start_story(deck, _pool_battle("糖丝傀儡"), BattleConfig.PLAYER_MAX_HP - 2, 1, 1)
	check(state.player_hp == BattleConfig.PLAYER_MAX_HP - 2, "story 带伤入场")
	check(state.player_block == 1, "story 开局格挡 1")
	check(state.hand.size() == BattleConfig.HAND_SIZE + 1, "story 起手多抽 1")
	check(_log_contains(logs, "备战：开局 +1 格挡，起手多抽 1 张"), "备战日志行按轻增益拼装")
	# 练习不吃：默认满血默认手牌、无备战日志
	var practice_logs: Array = []
	var practice := BattleState.new()
	practice.log_event.connect(func(text: String) -> void: practice_logs.append(text))
	practice.start_practice(deck)
	check(practice.player_hp == BattleConfig.PLAYER_MAX_HP and practice.hand.size() == BattleConfig.HAND_SIZE, "练习默认满血默认手牌")
	check(not _log_contains(practice_logs, "备战："), "练习不出备战日志")
	# 地图备战线：有待用轻增益时显示，消费后收起
	var map_page := MapPage.new()
	var map_viewport := _attach_scene(map_page)
	await process_frame
	var buff_run := RunState.new()
	buff_run.apply_outcome({"block": 2, "draw": 1})
	map_page.build(buff_run)
	check(map_page._buff_line.visible and map_page._buff_line.text.contains("开局格挡 +2") and map_page._buff_line.text.contains("起手多抽 1 张"), "地图备战线显示轻增益")
	buff_run.consume_buffs()
	map_page.build(buff_run)
	check(not map_page._buff_line.visible, "消费后备战线收起")
	map_viewport.queue_free()
	await process_frame
	# 练习战不消费（E2E）：备着增益进练习，增益仍在
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	await process_frame
	main.run.apply_outcome({"block": 2, "draw": 1})
	main._on_practice_start_requested()
	check(main.run.pending_block == 2 and main.run.pending_draw == 1, "练习开战不消费轻增益")
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
	var strike_button := _first_live_button(scene.get_node("%HandBox") as Control, "普通魔弹")
	check(_drag_card_to(scene, strike_button, scene.get_node("%PlayBox") as HBoxContainer), "拖一张普通魔弹进出牌区")
	check(scene.state.staged.size() == 1, "摆了一张普通魔弹")
	scene.turn_time_left = 0.0
	await process_frame
	await process_frame
	check(scene.state.staged.is_empty(), "到点自动结算出牌区")
	check(scene.state.enemy_hp == BattleConfig.PRACTICE_ENEMY_HP - 2, "摆放的普通魔弹已结算")
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
	# 注入确定性卡组：新默认卡组只有 4 张普通魔弹，若开局没摸到会找不到按钮
	scene.configure(BattleState.Mode.TUTORIAL, ["strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var discard_zone := scene.get_node("%DiscardZone") as PanelContainer
	var discard_zone_label := scene.get_node("%DiscardZoneLabel") as Label
	var cost_label := scene.get_node("%CostLabel") as Label
	check(play_box.size.x > scene.size.x * 0.6, "出牌区有实际宽度（可承接拖放）")
	check((scene.get_node("HandScroll") as ScrollContainer).size.x > scene.size.x * 0.6, "手牌区横跨屏幕底部")
	var strike_button := _first_live_button(hand_box, "普通魔弹")
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
	var play_strike := _first_live_button(play_box, "普通魔弹")
	check(play_strike != null and play_strike.drag_zone == "play", "出牌区的牌可拖")
	check(_drag_card_to(scene, play_strike, hand_box), "拖回手牌区可以收回")
	check(scene.state.staged.is_empty(), "拖回后出牌区清空")
	check(_count_live_card_buttons(hand_box) == 5, "手牌回到五张")
	scene.state.gain_card(CardDB.get_card("wrath"))
	# 本测试只验拖拽/悬停 UI：钉死罪卡为本场检定对象并解锁，不混入封印逻辑
	scene.state.deck_sin_id = "wrath"
	scene.state.sin_available = true
	_check_cost_label(scene, "Cost 6 / 6", "弃牌前 Cost 6 / 6")
	var wrath_button := _first_live_button(hand_box, "懒惰")
	check(wrath_button != null, "手里出现懒惰")
	# 悬停反馈：模拟拖拽开始状态（与引擎通知同路径），检查高亮与弃牌收益预告
	var play_panel := scene.get_node("%PlayZonePanel") as PanelContainer
	var play_base_border: Color = (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var discard_base_border: Color = (discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	scene._drag_zone_source = "hand"
	var wrath_data: Variant = wrath_button._get_drag_data(Vector2.ZERO)
	var discard_point: Vector2 = scene.get_global_transform().affine_inverse() * discard_zone.get_global_rect().get_center()
	check(scene._can_drop_data(discard_point, wrath_data), "懒惰能投放到弃牌区")
	check(scene._drag_target_now == "discard", "悬停目标记录为弃牌区")
	check(discard_zone_label.text.contains("弃掉「懒惰」") and discard_zone_label.text.contains("Cost +5"), "弃牌区预告弃牌收益（懒惰 → Cost +5）")
	check((discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color != discard_base_border, "悬停的弃牌区边框亮起")
	check((play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color != play_base_border, "可投放的出牌区边框提示")
	check(scene._can_drop_data(outside_point, wrath_data), "拖到空白处也接受（自动摆进出牌区）")
	check(scene._drag_target_now == "play", "离开弃牌区后悬停目标记为出牌区")
	check(not discard_zone_label.text.contains("弃掉「懒惰」"), "离开弃牌区后预告收起")
	scene._notification(Control.NOTIFICATION_DRAG_END)
	check((discard_zone.get_theme_stylebox("panel") as StyleBoxFlat).border_color == discard_base_border and (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == play_base_border, "拖拽结束高亮复位")
	check(_drag_card_to(scene, wrath_button, discard_zone), "拖懒惰到弃牌区")
	_check_cost_label(scene, "Cost 11 / 6", "弃 6 费牌 +5，Cost 超上限（11/6）")
	check(discard_zone_label.text.contains("+5"), "弃牌区显示本回合已获得 +5")
	check(_find_card(scene.state.discard_pile, "wrath") >= 0, "弃掉的懒惰进弃牌堆")
	var strike_to_discard := _first_live_button(hand_box, "普通魔弹")
	check(_drag_card_to(scene, strike_to_discard, discard_zone), "1 费牌也能拖去弃掉")
	_check_cost_label(scene, "Cost 11 / 6", "1 费牌弃掉 +0，Cost 不变")
	var play_strike2 := _first_live_button(hand_box, "普通魔弹")
	check(_drag_card_to(scene, play_strike2, play_box), "摆一张普通魔弹准备打出")
	scene.state.debug_force_plays = 0
	(scene.get_node("%CommitButton") as Button).pressed.emit()
	check(scene.state.staged.is_empty(), "打出后出牌区清空")
	check(scene.state.phase == BattleState.Phase.PLAYER, "打出即结束回合，回到新回合")
	_check_cost_label(scene, "Cost 6 / 6", "新回合 Cost 重置回 6 / 6")
	check(discard_zone_label.text.contains("+0"), "弃牌区回合计数归零")
	var strike_after_commit := _first_live_button(hand_box, "普通魔弹")
	check(strike_after_commit != null, "新回合手里仍有普通魔弹")
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
	# 拖叠：两张普通魔弹合成一张（费用 3）
	var strike_a := _first_live_button(hand_box, "普通魔弹")
	check(_drag_card_to(scene, strike_a, play_box), "摆第一张普通魔弹")
	_check_cost_label(scene, "Cost 5 / 6", "摆放后可用 Cost 5/6")
	await process_frame  # 等容器重排完成，新卡牌 rect 才可命中
	var strike_b := _first_live_button(hand_box, "普通魔弹")
	check(strike_b != null, "手里还有第二张普通魔弹")
	var staged_button := _first_live_button(play_box, "普通魔弹")
	var drag_data: Variant = strike_b._get_drag_data(Vector2.ZERO)
	var staged_point: Vector2 = scene.get_global_transform().affine_inverse() * staged_button.get_global_rect().get_center()
	check(scene._can_drop_data(staged_point, drag_data), "悬停同类已摆牌被接受")
	check((staged_button as CardButton).is_merge_highlighted(), "可叠目标描金高亮")
	scene._drop_data(staged_point, drag_data)
	check(scene.state.staged.size() == 1, "合成为一张，占同一卡槽")
	check(scene.state.staged[0].display_name == "普通魔弹＋普通魔弹" and scene.state.staged[0].cost == 3, "合成牌 普通魔弹＋普通魔弹，费用 3")
	check(_count_live_card_buttons(hand_box) == 3, "手牌消耗一张（5→4→3）")
	_check_cost_label(scene, "Cost 3 / 6", "合成后出牌区合计 3，可用 Cost 3/6")
	var merged_button := _first_live_button(play_box, "普通魔弹＋普通魔弹")
	check(merged_button != null, "出牌区显示合成牌")
	# 拖回拆开：两张原牌回手，费用不花
	check(_drag_card_to(scene, merged_button, hand_box), "拖回手牌区")
	check(scene.state.staged.is_empty(), "出牌区清空")
	check(_count_live_card_buttons(hand_box) == 5, "拆开回手两张，手牌回到 5")
	_check_cost_label(scene, "Cost 6 / 6", "拆开后 Cost 复原 6/6")
	# 增幅牌：灰显、不可摆、拖拽悬停出现触发预告
	var quench_button := _first_live_button(hand_box, "灼印")
	check(quench_button != null and quench_button.modulate.r < 1.0, "增幅牌灰显（不可摆放）")
	check(quench_button.tooltip_text.contains("不能打出"), "增幅牌提示说明玩法")
	var quench_data: Variant = quench_button._get_drag_data(Vector2.ZERO)
	var discard_point: Vector2 = scene.get_global_transform().affine_inverse() * discard_zone.get_global_rect().get_center()
	check(scene._can_drop_data(discard_point, quench_data), "增幅牌只能投弃牌区")
	check(scene._drag_target_now == "discard", "悬停目标为弃牌区")
	check(discard_zone_label.text.contains("弃掉「灼印」") and discard_zone_label.text.contains("本回合伤害 +3"), "弃牌预告显示触发效果")
	scene._drop_data(discard_point, quench_data)
	check(scene.state.turn_attack_bonus == 3, "弃掉灼印，本回合伤害 +3")
	check(block_label.text.contains("本回合攻击 +3"), "状态行显示本回合加成")
	check(_find_card(scene.state.discard_pile, "quench") >= 0, "灼印进弃牌堆")
	# 加成在打出时生效（2+2=4），下一回合回归
	var strike_c := _first_live_button(hand_box, "普通魔弹")
	check(_drag_card_to(scene, strike_c, play_box), "摆一张普通魔弹吃加成")
	(scene.get_node("%CommitButton") as Button).pressed.emit()
	check(scene.state.enemy_hp == BattleConfig.PRACTICE_ENEMY_HP - 5, "普通魔弹 2+3=5 伤（木桩 60→55）")
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
	# 注入确定性卡组：新默认卡组只有 4 张普通魔弹，若开局没摸到会找不到按钮
	scene.configure(BattleState.Mode.TUTORIAL, ["strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
	var viewport := _attach_scene(scene)
	await process_frame
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	var play_panel := scene.get_node("%PlayZonePanel") as PanelContainer
	var play_base_border: Color = (play_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var strike_button := _first_live_button(hand_box, "普通魔弹")
	check(strike_button != null, "手里有普通魔弹")
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
	_check_cost_label(scene, "Cost 5 / 6", "引擎级拖拽摆放后左上角可用 Cost 实时下调（5/6）")
	if scene.state.staged.size() == 1:
		check(scene.state.staged[0].id == "strike", "放进去的正是被拖的普通魔弹")
	check(_count_live_card_buttons(hand_box) == 4, "手牌跟着少一张")
	# 出牌区拖回手牌（撤回），同样走引擎级真实拖拽
	var staged_button := _first_live_button(play_box, "普通魔弹")
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
		_check_cost_label(scene, "Cost 6 / 6", "引擎级拖回后左上角可用 Cost 实时恢复（6/6）")
		check(_count_live_card_buttons(hand_box) == 5, "手牌恢复五张")
	# 弃牌区同样走引擎级真实拖拽（PanelContainer 默认 STOP 会静默拦截投放，2026-10-03 修复）
	scene.state.gain_card(CardDB.get_card("wrath"))
	await process_frame
	var wrath_button := _first_live_button(hand_box, "懒惰")
	check(wrath_button != null, "手里出现懒惰")
	if wrath_button != null:
		var discard_to: Vector2 = (scene.get_node("%DiscardZone") as PanelContainer).get_global_rect().get_center()
		var wrath_from: Vector2 = wrath_button.get_global_rect().get_center()
		_push_mouse_button(viewport, wrath_from, true)
		_push_mouse_motion(viewport, wrath_from + Vector2(10.0, -10.0))
		_push_mouse_motion(viewport, discard_to)
		check(scene._drag_target_now == "discard", "引擎拖拽悬停弃牌区")
		_push_mouse_button(viewport, discard_to, false)
		_check_cost_label(scene, "Cost 11 / 6", "引擎级拖拽弃牌 +5（11/6）")
		check(_find_card(scene.state.discard_pile, "wrath") >= 0, "懒惰经引擎拖拽进了弃牌堆")
	# 手牌拖出后在非弃牌区松手（例：日志区）＝自动摆进出牌区（日志区控件必须 IGNORE，否则引擎拖放被静默拦截）
	var strike_free := _first_live_button(hand_box, "普通魔弹")
	check(strike_free != null, "手里还有普通魔弹可拖")
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
	# 引擎级拖叠：手里剩下的普通魔弹拖到出牌区已摆的普通魔弹上 → 合成一张（描金高亮 → 松手合成）
	var merge_from_button := _first_live_button(hand_box, "普通魔弹")
	check(merge_from_button != null, "手里还有普通魔弹可拖（用于叠）")
	if merge_from_button != null and scene.state.staged.size() == 1:
		var staged_target := _first_live_button(play_box, "普通魔弹")
		check(staged_target != null, "出牌区有普通魔弹作为叠合目标")
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
			_check_cost_label(scene, "Cost 8 / 6", "合成后出牌区 3，可用 Cost 8（11-3）")
	viewport.queue_free()
	await process_frame


func test_scene_hover_scale() -> void:
	print("[卡牌悬停：动态放大，移开缩回]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	# 注入确定性卡组：新默认卡组只有 4 张普通魔弹，若开局没摸到会找不到按钮
	scene.configure(BattleState.Mode.TUTORIAL, ["strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
	var viewport := _attach_scene(scene)
	await process_frame
	var hand_box := scene.get_node("%HandBox") as Control
	var card_button := _first_live_button(hand_box, "普通魔弹")
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
	print("[扇形手牌：7 张上限内完整排开；超限窗口仍全可见；拖拽不破坏]")
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
	check(no_overlap, "≤7 张不叠压：相邻步进 118")
	for _i in 2:
		scene.state.gain_card(CardDB.get_card("strike"))
	await process_frame
	await process_frame
	var scroll_rect: Rect2 = hand_scroll.get_global_rect()
	var full := _live_hand_cards(hand_box)
	check(full.size() == 7, "7 张到上限，牌面全部生成")
	var full_step := true
	var full_inside := true
	for i in full.size():
		if i > 0 and not is_equal_approx(full[i].position.x - full[i - 1].position.x, 118.0):
			full_step = false
		var full_rect: Rect2 = full[i].get_global_rect()
		if full_rect.position.x < scroll_rect.position.x - 0.5 or full_rect.end.x > scroll_rect.end.x + 0.5 \
				or full_rect.position.y < scroll_rect.position.y - 0.5 or full_rect.end.y > scroll_rect.end.y + 0.5:
			full_inside = false
	check(full_step, "上限内 7 张仍不叠压（步进 118）")
	check(full_inside, "7 张全部含于手牌区内")
	# 上限内无强制弃牌页遮挡：走引擎级真实拖拽（最右卡）
	var rightmost: CardButton = full[6]
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
	check(after.size() == 6, "拖走一张后剩 6 张")
	# 第二张走数据链直接投放（与应用级路径同源）
	var leftmost: CardButton = after[0]
	check(_drag_card_to(scene, leftmost, play_box), "第二张拖拽数据链完好")
	check(scene.state.staged.size() == 2, "第二张也摆进了出牌区")
	await process_frame
	await process_frame
	var rest := _live_hand_cards(hand_box)
	check(rest.size() == 5, "收走两张后剩 5 张")
	var rest_step_ok := true
	var rest_inside := true
	for i in rest.size():
		if i > 0 and not is_equal_approx(rest[i].position.x - rest[i - 1].position.x, 118.0):
			rest_step_ok = false
		var rest_rect: Rect2 = rest[i].get_global_rect()
		if rest_rect.position.x < scroll_rect.position.x - 0.5 or rest_rect.end.x > scroll_rect.end.x + 0.5:
			rest_inside = false
	check(rest_step_ok, "5 张重排后步进仍 118")
	check(rest_inside, "重排后仍全部在手牌区内")
	# 超限窗口（10 张）：临时叠压、全部可见（此时强制弃牌页在场，弃牌走弃牌页）
	for _i in 5:
		scene.state.gain_card(CardDB.get_card("strike"))
	await process_frame
	await process_frame
	var over := _live_hand_cards(hand_box)
	check(over.size() == 10, "超限窗口 10 张牌面全部生成")
	var expected_step: float = (hand_box.size.x - 20.0 - 118.0) / 9.0
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
	check(monotonic, "10 张从左到右递增")
	check(even, "10 张均等步进叠压（约 %.1f px）" % expected_step)
	check(inside, "10 张全部含于手牌区内")
	viewport.queue_free()
	await process_frame


func test_scene_pile_counts() -> void:
	print("[牌堆/弃牌堆计数：随弃牌、打出、摸牌洗回实时同步]")
	var packed := load("res://scenes/battle.tscn") as PackedScene
	if packed == null:
		return
	var scene: Variant = packed.instantiate()
	# 注入确定性卡组：新默认卡组只有 4 张普通魔弹，若开局没摸到会找不到按钮
	scene.configure(BattleState.Mode.TUTORIAL, ["strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard"])
	var viewport := _attach_scene(scene)
	await process_frame
	await process_frame
	var hand_count := scene.get_node("%HandCountLabel") as Label
	var pile_count := scene.get_node("%PileCountLabel") as Label
	var hand_box := scene.get_node("%HandBox") as Control
	var discard_zone := scene.get_node("%DiscardZone") as PanelContainer
	var play_box := scene.get_node("%PlayBox") as HBoxContainer
	check(hand_count.text == "手牌 5/7", "开局：手牌 5/7")
	check(pile_count.text == "牌堆 3　弃牌堆 0", "开局：牌堆 3、弃牌堆 0")
	scene.state.debug_force_plays = 0
	var to_discard: CardButton = _live_hand_cards(hand_box)[0]
	check(_drag_card_to(scene, to_discard, discard_zone), "拖一张进弃牌区换 Cost")
	await process_frame
	check(hand_count.text == "手牌 4/7", "弃牌后手牌 4/7")
	check(pile_count.text == "牌堆 3　弃牌堆 1", "弃牌后：牌堆 3、弃牌堆 1")
	var strike_button := _first_live_button(hand_box, "普通魔弹")
	check(strike_button != null, "手里还有普通魔弹")
	if strike_button != null:
		check(_drag_card_to(scene, strike_button, play_box), "摆一张普通魔弹")
		(scene.get_node("%CommitButton") as Button).pressed.emit()
		await process_frame
		check(pile_count.text == "牌堆 1　弃牌堆 0", "打出并摸 4 张后：牌堆 1、弃牌堆 0（弃牌堆洗回补足摸牌）")
	var victim: CardButton = _live_hand_cards(hand_box)[0]
	check(_drag_card_to(scene, victim, discard_zone), "再弃一张")
	await process_frame
	check(pile_count.text == "牌堆 1　弃牌堆 1", "弃牌后：牌堆 1、弃牌堆 1")
	var hand_before: int = scene.state.hand.size()
	(scene.get_node("%EndTurnButton") as Button).pressed.emit()
	await process_frame
	check(scene.state.hand.size() == hand_before + 2, "空过一轮摸 2 张（弃牌堆洗回补足）")
	check(pile_count.text == "牌堆 0　弃牌堆 0", "洗回后摸完：牌堆 0、弃牌堆 0")
	check(pile_count.text == "牌堆 %d　弃牌堆 %d" % [scene.state.draw_pile.size(), scene.state.discard_pile.size()], "显示与 state 完全一致")
	viewport.queue_free()
	await process_frame


func test_scene_forced_discard() -> void:
	print("[手牌上限 7：超限强制弹出弃牌页]")
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
	check(hand_count.text == "手牌 5/7", "开局计数 5/7")
	check(not hand_count.has_theme_color_override("font_color"), "未满上限不标警示色")
	check(pile_count.text == "牌堆 5　弃牌堆 0", "开局牌堆/弃牌堆 5 / 0")
	for _i in 2:
		scene.state.gain_card(CardDB.get_card("strike"))
	check(scene.state.hand.size() == BattleConfig.HAND_LIMIT, "手牌到上限 7 张")
	check(hand_count.text == "手牌 7/7", "到上限计数 7/7")
	check(hand_count.has_theme_color_override("font_color"), "到上限计数变警示色")
	check(not overlay.visible, "到上限还不够，不弹")
	scene.state.gain_card(CardDB.get_card("strike"))
	check(scene.state.hand.size() == 8, "第 8 张超出上限")
	check(hand_count.text == "手牌 8/7", "超限计数 8/7")
	check(overlay.visible and discard_scroll.visible, "强制弹出弃牌页")
	check(story.text.contains("还差 1 张"), "提示还差 1 张")
	check(discard_box.get_child_count() == 8, "列出全部 8 张手牌")
	var first_discard := discard_box.get_child(0) as Button
	first_discard.pressed.emit()
	check(scene.state.hand.size() == BattleConfig.HAND_LIMIT, "弃掉 1 张后回到上限")
	check(hand_count.text == "手牌 7/7", "弃回后计数 7/7")
	check(not overlay.visible, "弃牌页自动关闭")
	check(scene.state.discard_pile.size() == 1, "弃掉的牌进了弃牌堆")
	check(pile_count.text == "牌堆 5　弃牌堆 1", "弃牌堆计数 5 / 1")
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
	print("[主流程：初幕演出 → 教学战 → 教学说明 → 练习站 → 木桩 → 追及 → 教程战 → 三问 → 层地图 → 返回主菜单]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var prologue_page := main.get_node("%ProloguePage") as Control
	var prologue_button := prologue_page._continue_button as Button
	var prologue_text := prologue_page._text_label as Label
	var story_page := main.get_node("%StoryPage") as Control
	var practice_page := main.get_node("%PracticePage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	check(prologue_page.visible, "无档开场＝初幕演出页")
	check(not story_page.visible, "初幕期间读白页不出现")
	check(prologue_text.text.contains("音海市"), "初幕第 1 拍：现世·夜（出租屋）")
	# 9 拍：按 8 次到末拍「迎战」，再按 1 次结束演出
	for _i in 8:
		prologue_button.pressed.emit()
	check(prologue_button.text == "迎战", "演出到末拍，按钮＝迎战")
	check(prologue_text.text.contains("彻底污染"), "末拍：菲戈蕾被懒惰的力量彻底污染")
	prologue_button.pressed.emit()
	check(battle_host.get_child_count() == 1, "演出结束直接进入蜗牛教学战")
	var teach_battle: Variant = battle_host.get_child(0)
	check(teach_battle.state.mode == BattleState.Mode.TEACHING, "蜗牛教学战模式")
	check((teach_battle.get_node("%EnemyNameLabel") as Label).text == "蜗牛怪物", "教学战波 1＝蜗牛怪物")
	_check_cost_label(teach_battle, "Cost 4 / 4", "教学战单位制 4")
	check((teach_battle.get_node("%TurnTimerLabel") as Label).text == "剩余 90 秒", "教学战时限 90 秒")
	await process_frame
	_drive_teaching_victory(teach_battle)
	check(teach_battle.state.phase == BattleState.Phase.ENDED, "教学战三回合收尾")
	await process_frame
	check(story_page.visible and story.text.contains("练习站"), "教学战后进教学说明（指引去练习站）")
	check(primary.text == "去练习站" and secondary.visible, "教学说明按钮：去练习站／直接前进")
	primary.pressed.emit()
	check(practice_page.visible, "进入练习站")
	var warehouse := main.get_node("%WarehouseList") as VBoxContainer
	check(_first_live_button(warehouse, "「普通魔弹」") != null, "仓库里有普通魔弹")
	for i in 4:
		var strike_button := _first_live_button(warehouse, "「普通魔弹」")
		check(strike_button != null, "第 %d 张普通魔弹按钮在场" % (i + 1))
		if strike_button != null:
			strike_button.pressed.emit()
	for i in 2:
		var heavy_button := _first_live_button(warehouse, "「强力魔弹」")
		check(heavy_button != null, "第 %d 张强力魔弹按钮在场" % (i + 1))
		if heavy_button != null:
			heavy_button.pressed.emit()
	for i in 3:
		var guard_button := _first_live_button(warehouse, "「普通防御」")
		check(guard_button != null, "第 %d 张普通防御按钮在场" % (i + 1))
		if guard_button != null:
			guard_button.pressed.emit()
	var heal_button := _first_live_button(warehouse, "「治疗术」")
	check(heal_button != null, "治疗术按钮在场")
	if heal_button != null:
		heal_button.pressed.emit()
	var start_button := main.get_node("%StartPracticeButton") as Button
	check((main.get_node("%DeckCountLabel") as Label).text == "卡组 10 / 10", "卡组计数更新（4 魔弹＋2 强弹＋3 防御＋1 治疗）")
	check(not start_button.disabled, "10 张组好后可开打")
	start_button.pressed.emit()
	check(battle_host.get_child_count() == 1, "练习战进入战斗位")
	var practice_battle: Variant = battle_host.get_child(0)
	check(practice_battle.state.mode == BattleState.Mode.PRACTICE, "是练习模式")
	check(practice_battle.state.enemy_name == "木桩", "对手是木桩")
	await process_frame
	_press_strikes_until_over(practice_battle)
	check(practice_battle.state.phase == BattleState.Phase.ENDED, "木桩被打倒")
	var practice_continue := practice_battle.get_node("%ContinueButton") as Button
	check(practice_continue.text == "返回练习站", "练习结束按钮")
	practice_continue.pressed.emit()
	check(practice_page.visible, "回到练习站")
	await process_frame
	check(battle_host.get_child_count() == 0, "练习战斗已释放")
	(main.get_node("%LeavePracticeButton") as Button).pressed.emit()
	check(prologue_page.visible, "离开练习站后进入追及演出（design-round11）")
	check(prologue_text.text.contains("朝着菲戈蕾所在的方向前进") and not prologue_text.text.contains("净化时刻"), "追及开场拍＋告知边界（不提前提净化）")
	for _i in StoryBeats.CHASE_BEATS.size():
		prologue_button.pressed.emit()
	check(story_page.visible, "追及演出结束进入层主战前读白")
	check(story.text.contains("清空") and story.text.contains("菲戈蕾"), "临战读白：菲戈蕾、目标清空血量")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "教程战进入战斗位")
	var battle2: Variant = battle_host.get_child(0)
	check(battle2.state.mode == BattleState.Mode.TUTORIAL, "是教程模式")
	check(battle2.state.enemy_name == "贝尔芬格", "对手是贝尔芬格")
	_check_cost_label(battle2, "Cost 6 / 6", "教程战恢复 Cost 6 体系")
	check(battle2.state.draw_pile.size() + battle2.state.hand.size() == BattleConfig.DECK_SIZE, "教程战用练习站自组的 10 张卡组")
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
	var map_page := main.get_node("%MapPage") as Control
	check(prologue_page.visible, "教程战结束进入第二幕演出（design-round11，取代旧过渡页）")
	check(prologue_text.text.contains("第二层"), "第二幕开场拍：大树出口过夜")
	check(main.run.tutorial_done, "教程标记完成")
	check(main.run.companions.has("菲戈蕾"), "菲戈蕾入同行列")
	check(main.pool.owned_count("wrath") == 1, "懒惰罪卡入库")
	check(not main.run.act2_done, "第二幕未看完前不置位")
	for _i in StoryBeats.ACT2_BEATS.size():
		prologue_button.pressed.emit()
	check(main.run.act2_done, "第二幕看完置位")
	check(map_page.visible, "第二幕结束直达层地图")
	var layer1_row := _deep_find_button(map_page, "第 1 层·懒惰")
	check(layer1_row != null and layer1_row.text.contains("已净化"), "第 1 层已净化")
	var layer2_row := _deep_find_button(map_page, "第 2 层·色欲")
	check(layer2_row != null and layer2_row.text.contains("当前"), "第 2 层当前")
	var layer3_row := _deep_find_button(map_page, "第 3 层·暴食")
	check(layer3_row != null and layer3_row.text.contains("未解锁"), "第 3 层未解锁（内容楼层，前面未走完）")
	var map_practice_button := _deep_find_button(map_page, "进入练习站")
	check(map_practice_button != null, "地图保留练习站入口")
	var map_title_button := _deep_find_button(map_page, "返回主菜单")
	check(map_title_button != null, "地图有返回主菜单入口（原「返回菜单」）")
	map_title_button.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and String(current_scene.scene_file_path) == "res://scenes/main_menu.tscn", "地图返回主菜单＝切回标题页")
	viewport.queue_free()
	await process_frame


func test_main_flow_skip_practice() -> void:
	print("[主流程·跳过练习：教学说明直接前进，用默认卡组打教程战]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var story_page := main.get_node("%StoryPage") as Control
	var primary := main.get_node("%PrimaryButton") as Button
	var secondary := main.get_node("%SecondaryButton") as Button
	var story := main.get_node("%StoryText") as Label
	var battle_host := main.get_node("%BattleHost") as Control
	check(not MAIN_FLOW_SCRIPT.open_practice_on_ready, "常规启动不带练习站直开标记")
	var prologue_page := main.get_node("%ProloguePage") as Control
	var prologue_button := prologue_page._continue_button as Button
	for _i in 9:
		prologue_button.pressed.emit()
	check(battle_host.get_child_count() == 1, "初幕结束进入教学战")
	var teach_battle: Variant = battle_host.get_child(0)
	await process_frame
	_drive_teaching_victory(teach_battle)
	await process_frame
	check(story_page.visible and story.text.contains("练习站"), "教学说明在屏")
	secondary.pressed.emit()
	check(prologue_page.visible, "「直接前进」＝追及演出在屏（design-round11）")
	check((prologue_page._text_label as Label).text.contains("朝着菲戈蕾所在的方向前进"), "追及开场拍")
	for _i in StoryBeats.CHASE_BEATS.size():
		prologue_button.pressed.emit()
	check(story_page.visible and story.text.contains("清空") and story.text.contains("菲戈蕾"), "追及演出完＝临战读白在屏")
	primary.pressed.emit()
	check(battle_host.get_child_count() == 1, "直接进入教程战")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.mode == BattleState.Mode.TUTORIAL, "教程模式")
	check(battle.state.hand.size() == BattleConfig.HAND_SIZE, "没组卡时用默认卡组，开局手牌 5 张")
	viewport.queue_free()
	await process_frame


func test_act2_gating() -> void:
	print("[第二幕门控：有档未看→补演第二幕；act2_done→直达地图；读档还原（design-round11）]")
	var path := "user://save_test_act2.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.disabled = false
	SaveGame.save_path = path
	# 一：教程完成 + 第二幕未看 → 启动补演第二幕 → 演完进地图并落盘
	var run := RunState.new()
	run.tutorial_done = true
	SaveGame.save_progress(run, CardPool.new())
	var main1: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport1 := _attach_scene(main1)
	await process_frame
	var prologue1 := main1.get_node("%ProloguePage") as Control
	var map1 := main1.get_node("%MapPage") as Control
	check(prologue1.visible and not map1.visible, "有档未看第二幕：启动演第二幕")
	check((prologue1._text_label as Label).text.contains("我们今晚先在这里休息一下"), "首拍＝大树出口过夜")
	for _i in StoryBeats.ACT2_BEATS.size():
		(prologue1._continue_button as Button).pressed.emit()
	check(main1.run.act2_done and map1.visible, "演完置位并进地图")
	viewport1.queue_free()
	await process_frame
	# 二：act2_done 已落盘 → 重启直达地图不重看
	var main2: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport2 := _attach_scene(main2)
	await process_frame
	var map2 := main2.get_node("%MapPage") as Control
	check(map2.visible and not (main2.get_node("%ProloguePage") as Control).visible, "act2_done 档：直达地图不重看")
	check(main2.run.act2_done, "读档还原 act2_done")
	viewport2.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_path = SaveGame.DEFAULT_SAVE_PATH
	SaveGame.disabled = true


func test_main_menu_practice_entry() -> void:
	print("[主菜单练习站入口：标题页按钮直开练习站 → 离开回主菜单]")
	var menu: Variant = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	var menu_viewport := _attach_scene(menu)
	var practice_button := menu.get_node("VBoxContainer/Button2") as Button
	check(practice_button != null and practice_button.text == "练习站", "标题页第二按钮＝练习站（原空壳「选项」替换）")
	practice_button.pressed.emit()
	await process_frame
	await process_frame
	var live_main: Variant = current_scene
	var reached_main := live_main != null and String(live_main.scene_file_path) == "res://scenes/main.tscn"
	check(reached_main, "练习站按钮进入主场景")
	if reached_main:
		check((live_main.get_node("%PracticePage") as Control).visible, "进入即是练习站页（跳过初幕/路线）")
		check(not MAIN_FLOW_SCRIPT.open_practice_on_ready, "启动标记已消费")
		(live_main.get_node("%LeavePracticeButton") as Button).pressed.emit()
		await process_frame
		await process_frame
		check(current_scene != null and String(current_scene.scene_file_path) == "res://scenes/main_menu.tscn", "离开练习站回主菜单")
	menu_viewport.queue_free()
	await process_frame


func test_main_flow_layer2() -> void:
	print("[第二层路线全流程：夹具选路（含死亡重掷）→ 层主战 → 上行 → 地图（第 3 层解锁）]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	var map_page := main.get_node("%MapPage") as Control
	var event_page := main.get_node("%EventPage") as Control
	var transition_page := main.get_node("%TransitionPage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	await process_frame
	# 跳过教程（教程战已由主流程测试覆盖）：置教程完成＋注入夹具路线（层内流程走指定节点）＋固定随机源（死亡重掷断言可复现）
	main.run.tutorial_done = true
	main.run.route = _fixture_route()
	main.run.route_layer = main.run.current_layer
	main.run.rng.seed = 20261005
	main._open_map()
	check(map_page.visible, "置教程完成后直达层地图")
	# 第一列·事件（试衣镜）：点节点＝弹确认窗，确认主按钮才入关（design-round5.md §0.2/0.4）
	var overlay := main.get_node("%ConfirmOverlay") as Control
	var confirm_title := main.get_node("%ConfirmTitle") as Label
	var confirm_primary := main.get_node("%ConfirmPrimaryButton") as Button
	var fog := _deep_find_button(map_page, "事件·试衣镜")
	check(fog != null and not fog.disabled, "第一列事件节点当前可点")
	fog.pressed.emit()
	check(overlay.visible, "点节点先弹确认窗（不直接入关）")
	check(confirm_title.text == "进入「事件·试衣镜」？", "确认窗标题＝类型·名称")
	check(confirm_primary.text == "进入事件", "事件节点主按钮＝进入事件")
	check(main.run.column_index == 0 and main.run.chosen.is_empty(), "弹窗未落账（选择推迟到确认）")
	confirm_primary.pressed.emit()
	check(not overlay.visible, "确认后确认窗关闭")
	check(event_page.visible, "进入事件页")
	check(event_page._title.text == "试衣镜", "事件标题按节点")
	var fog_panel := event_page._panel as PickPanel
	check(fog_panel != null, "试衣镜＝择一小玩法")
	fog_panel.select(0)
	fog_panel._on_exec_pressed()
	check(not (event_page._complete_button as Button).disabled, "择一结算后可以完成")
	(event_page._complete_button as Button).pressed.emit()
	check(map_page.visible, "事件完成回地图")
	check(main.run.column_index == 1, "选路推进到第二列")
	# 第二列·作战（糖丝傀儡）→ 故意判负，验证死亡回层首重选
	var echo := _deep_find_button(map_page, "作战·糖丝傀儡")
	check(echo != null and not echo.disabled, "第二列作战节点当前可点")
	echo.pressed.emit()
	check(overlay.visible, "作战节点也弹确认窗")
	check(confirm_primary.text == "开始战斗", "作战节点主按钮＝开始战斗")
	confirm_primary.pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 1, "第二列作战进入战斗位")
	var lost_battle: Variant = battle_host.get_child(0)
	check(lost_battle.state.mode == BattleState.Mode.STORY, "层战模式")
	check(lost_battle.state.enemy_name == "糖丝傀儡" and lost_battle.state.enemy_max_hp == 18, "第二列作战按节点配置")
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
	# 重掷已断言；重新注入夹具，继续走固定节点（第一列·作战：粉雾歌者）
	main.run.route = _fixture_route()
	main.run.route_layer = main.run.current_layer
	main._open_map()
	var pol := _deep_find_button(map_page, "作战·粉雾歌者")
	check(pol != null and not pol.disabled, "第一列作战节点当前可点")
	pol.pressed.emit()
	check(overlay.visible, "重掷后作战节点仍走确认窗")
	confirm_primary.pressed.emit()
	await process_frame
	check(battle_host.get_child_count() == 1, "小怪战进入战斗位")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.enemy_name == "粉雾歌者" and battle.state.enemy_max_hp == 16, "小怪按节点配置")
	battle.state.debug_force_plays = 0
	_press_strikes_until_over(battle)
	check(battle.state.phase == BattleState.Phase.ENDED, "小怪战打完直接结束（不过净化）")
	await process_frame
	check(battle_host.get_child_count() == 0, "小怪战已释放")
	check(map_page.visible and main.run.column_index == 1, "小怪战胜利回地图、进入第二列")
	# 第二列改选·事件（合唱席）
	var candle := _deep_find_button(map_page, "事件·合唱席")
	check(candle != null and not candle.disabled, "第二列事件节点当前可点")
	candle.pressed.emit()
	check(overlay.visible, "第二列事件也弹确认窗")
	confirm_primary.pressed.emit()
	check(event_page._title.text == "合唱席", "第二列事件标题")
	_complete_pick_event(event_page, 1)
	check(map_page.visible and main.run.column_index == 2, "事件关走完进入第三列（层主战）")
	# 第三列·层主战（阿斯莫德）
	var boss_node := _deep_find_button(map_page, "层主战·阿斯莫德")
	check(boss_node != null and not boss_node.disabled, "层主战节点当前可点")
	boss_node.pressed.emit()
	check(overlay.visible, "层主战也弹确认窗")
	check(confirm_title.text == "进入「层主战·阿斯莫德」？", "层主战标题按节点")
	confirm_primary.pressed.emit()
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
	check((boss_battle.get_node("%StoryText") as Label).text.contains("莉维娅") and (boss_battle.get_node("%StoryText") as Label).text.contains("找到我了"), "净化读白：人身名莉维娅＋第二幕回调（design-round11）")
	(boss_battle.get_node("%ContinueButton") as Button).pressed.emit()
	check(boss_battle.state.phase == BattleState.Phase.ENDED, "层战净化读完直接结束（无三问）")
	await process_frame
	check(transition_page.visible, "路线走完进入上行过渡页")
	check((transition_page._read_text as Label).text.contains("莉维娅"), "上行读白在屏（净化后人身名）")
	_first_live_button(transition_page, "继续").pressed.emit()
	check(map_page.visible, "上行后回地图")
	check(main.run.current_layer == 3, "上行到第 3 层")
	check(not main.run.is_demo_end(), "第 3 层不是内容边界")
	check(main.run.chosen.is_empty() and main.run.column_index == 0, "上行后选路记录清空")
	check(_deep_find_button(map_page, "第 2 层·色欲").text.contains("已净化"), "第 2 层已净化")
	var layer3_after := _deep_find_button(map_page, "第 3 层·暴食")
	check(layer3_after != null and layer3_after.text.contains("当前"), "第 3 层解锁＝当前层并展开路线")
	var layer8_after := _deep_find_button(map_page, "第 8 层·同位体")
	check(layer8_after != null and layer8_after.text.contains("待续"), "第 8 层待续（本段内容边界）")
	check(main.run.sin_cards == ["lust"], "色欲入局内收集")
	check(main.run.companions.has("莉维娅"), "莉维娅入同行列（净化后人身名）")
	check(main.pool.owned_count("lust") == 1, "罪卡入仓库")
	viewport.queue_free()
	await process_frame


func test_confirm_deck_flow() -> void:
	print("[确认窗·选择牌组：跳组卡界面 → 离开回地图重弹 → 确认入战用新卡组]")
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	await process_frame
	main.run.tutorial_done = true
	main.run.route = _fixture_route()
	main.run.route_layer = main.run.current_layer
	main._open_map()
	var map_page := main.get_node("%MapPage") as Control
	var practice_page := main.get_node("%PracticePage") as Control
	var overlay := main.get_node("%ConfirmOverlay") as Control
	var confirm_title := main.get_node("%ConfirmTitle") as Label
	var confirm_primary := main.get_node("%ConfirmPrimaryButton") as Button
	var choose_deck := main.get_node("%ChooseDeckButton") as Button
	var pol := _deep_find_button(map_page, "作战·粉雾歌者")
	check(pol != null and not pol.disabled, "第一列作战节点可点")
	pol.pressed.emit()
	check(overlay.visible, "弹确认窗")
	check(confirm_title.text == "进入「作战·粉雾歌者」？", "标题＝进入「类型·名称」？")
	check(choose_deck.text == "选择牌组", "副按钮＝选择牌组（无取消键）")
	check(main.run.chosen.is_empty() and main.run.column_index == 0, "弹窗未落账")
	# 选择牌组 → 组卡界面（练习站）
	choose_deck.pressed.emit()
	check(not overlay.visible, "跳组卡时确认窗收起")
	check(practice_page.visible, "进入组卡界面")
	var warehouse := main.get_node("%WarehouseList") as VBoxContainer
	check(_first_live_button(warehouse, "「普通魔弹」") != null, "组卡界面仓库在屏")
	for i in 4:
		var strike_button := _first_live_button(warehouse, "「普通魔弹」")
		if strike_button != null:
			strike_button.pressed.emit()
	for i in 2:
		var heavy_button := _first_live_button(warehouse, "「强力魔弹」")
		if heavy_button != null:
			heavy_button.pressed.emit()
	for i in 3:
		var guard_button := _first_live_button(warehouse, "「普通防御」")
		if guard_button != null:
			guard_button.pressed.emit()
	var heal_button := _first_live_button(warehouse, "「治疗术」")
	if heal_button != null:
		heal_button.pressed.emit()
	check((main.get_node("%DeckCountLabel") as Label).text == "卡组 10 / 10", "组卡生效（10/10）")
	check(main.run.chosen.is_empty() and main.run.column_index == 0, "组卡期间选择仍未落账")
	# 离开 → 回地图并重新弹出同节点确认窗
	(main.get_node("%LeavePracticeButton") as Button).pressed.emit()
	check(map_page.visible, "离开组卡回地图")
	check(overlay.visible, "回地图重新弹出该节点确认窗")
	check(confirm_title.text == "进入「作战·粉雾歌者」？", "重弹仍是原节点")
	# 确认 → 落账入战，用刚组的卡组
	confirm_primary.pressed.emit()
	check(not overlay.visible, "确认后弹窗关闭")
	check(main.run.column_index == 1 and main.run.chosen == [1], "确认落账并推进（粉雾歌者＝列内下标 1）")
	await process_frame
	var battle_host := main.get_node("%BattleHost") as Control
	check(battle_host.get_child_count() == 1, "进入战斗位")
	var battle: Variant = battle_host.get_child(0)
	check(battle.state.enemy_name == "粉雾歌者", "按节点配置对手")
	check(battle.state.draw_pile.size() + battle.state.hand.size() == BattleConfig.DECK_SIZE, "用组卡界面组的 10 张卡组")
	viewport.queue_free()
	await process_frame


func test_teaching_defeat_restart() -> void:
	print("[教学战失败：判负覆盖层→再来一次重开本战；教程层主战失败回追及段（不重看初幕）]")
	SaveGame.disabled = true
	var main: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport := _attach_scene(main)
	await process_frame
	var prologue_page := main.get_node("%ProloguePage") as Control
	var battle_host := main.get_node("%BattleHost") as Control
	for _i in 9:
		(prologue_page._continue_button as Button).pressed.emit()
	check(battle_host.get_child_count() == 1, "初幕走完进入教学战")
	var first: Variant = battle_host.get_child(0)
	check(first.state.mode == BattleState.Mode.TEACHING and first.state.player_hp == 8, "教学战首战：8 血")
	# 打空自己的血 → 判负覆盖层（教学文案＋「再来一次」）
	first.state._damage_player(99)
	check(first.state.phase == BattleState.Phase.DEFEAT, "生命归零判负")
	var overlay := first.get_node("%Overlay") as Control
	var continue_button := first.get_node("%ContinueButton") as Button
	check(overlay.visible, "判负覆盖层出现")
	check((first.get_node("%StoryText") as Label).text == BattleConfig.TEXT_DEFEAT_TEACHING, "判负读白＝教学文案")
	check(continue_button.text == BattleConfig.TEXT_DEFEAT_RETRY, "按钮＝再来一次")
	continue_button.pressed.emit()
	check(main._battle != null and main._battle != first, "重开新战实例")
	check(main._battle.state.player_hp == 8 and main._battle.state.mode == BattleState.Mode.TEACHING, "满状态重开本战")
	await process_frame
	check(battle_host.get_child_count() == 1 and battle_host.get_child(0) == main._battle, "旧战释放、新战入场")
	check(not prologue_page.visible, "不重看初幕演出")
	# 教程层主战失败 → 回追及段读白（TEXT_TRANSFORM，而非初幕）
	main._battle_context = "tutorial"
	main._on_battle_lost()
	await process_frame
	var story_page := main.get_node("%StoryPage") as Control
	var story := main.get_node("%StoryText") as Label
	check(story_page.visible and story.text.contains("清空"), "回追及段（目标清空血量）")
	check(story.text.contains("菲戈蕾") and not story.text.contains("音海市"), "追及段不重看初幕")
	check((main.get_node("%PrimaryButton") as Button).text == "打倒她", "追及段主按钮＝打倒她")
	check(battle_host.get_child_count() == 0, "战斗位已清空")
	viewport.queue_free()
	await process_frame


func test_save_roundtrip() -> void:
	print("[存档：写盘→读档→还原（进度＋卡池＋路线＋类型归一）；坏档容错]")
	var path := "user://save_test_roundtrip.json"
	SaveGame.disabled = false
	SaveGame.save_path = path
	var run := RunState.new()
	run.tutorial_done = true
	run.current_layer = 2
	var chosen: Array[int] = [1]
	run.chosen = chosen
	run.column_index = 1
	run.collect_sin("lust")
	run.add_companion("菲戈蕾")
	run.route = _fixture_route()
	run.route_layer = 2
	run.apply_hp_delta(-2)
	run.apply_outcome({"block": 2, "draw": 1})
	run.act2_done = true
	var pool := CardPool.new()
	pool.collect_sin("lust")
	pool.add_to_deck("strike")
	SaveGame.save_progress(run, pool)
	check(FileAccess.file_exists(path), "写盘成文件")
	var data := SaveGame.load_progress()
	check(not data.is_empty(), "读档非空")
	var run2 := RunState.new()
	var pool2 := CardPool.new()
	SaveGame.apply_progress(data, run2, pool2)
	check(run2.tutorial_done and run2.current_layer == 2, "进度还原")
	check(run2.column_index == 1 and run2.chosen == [1], "选路还原")
	check(run2.sin_cards == ["lust"] and run2.companions == ["菲戈蕾"], "收集还原")
	check(pool2.owned_count("lust") == 1, "仓库罪卡还原")
	check(pool2.deck == ["strike"], "卡组还原")
	check(_route_signature(run2.route) == _route_signature(_fixture_route()), "路线还原")
	check(run2.route_layer == 2 and run2.current_columns() == run2.route, "路线层号还原且不重生成")
	check(run2.pending_hp_delta == -2, "层内续航修正还原")
	check(run2.pending_block == 2 and run2.pending_draw == 1, "下一战轻增益还原")
	check(run2.act2_done, "第二幕标记还原")
	# 旧档缺 pending 系列/act2_done 键：缺省 0/false（VERSION 2 加键向后兼容）
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("pending_hp_delta")
	legacy.erase("pending_block")
	legacy.erase("pending_draw")
	legacy.erase("act2_done")
	var run3 := RunState.new()
	SaveGame.apply_progress(legacy, run3, CardPool.new())
	check(run3.pending_hp_delta == 0 and run3.pending_block == 0 and run3.pending_draw == 0, "旧档缺 pending 键默认 0")
	check(not run3.act2_done, "旧档缺 act2_done 默认 false（补看一次第二幕）")
	var battle_node: Dictionary = run2.route[0][1]
	check(typeof(battle_node.get("enemy_hp")) == TYPE_INT, "节点血量回读为 int（JSON float 已归一）")
	var enemy_deck: Dictionary = battle_node.get("enemy_deck", {})
	check(typeof(enemy_deck.get("enemy_strike")) == TYPE_INT, "敌方卡组计数回读为 int")
	# 教程未过不写盘
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_progress(RunState.new(), CardPool.new())
	check(not FileAccess.file_exists(path), "教程未过不写盘")
	# 坏档容错
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ 不是合法 JSON")
	file.close()
	check(SaveGame.load_progress().is_empty(), "坏档拒载（空字典）")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_path = SaveGame.DEFAULT_SAVE_PATH
	SaveGame.disabled = true


func test_main_flow_save_resume() -> void:
	print("[存档启动：教程完成写盘 → 重启直达路线 → 走一步再重启续到该列]")
	var path := "user://save_test_resume.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.disabled = false
	SaveGame.save_path = path
	# 一：无档启动（从初幕演出走）→ 教程收尾即落盘
	var main1: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport1 := _attach_scene(main1)
	await process_frame
	check((main1.get_node("%ProloguePage") as Control).visible and not (main1.get_node("%StoryPage") as Control).visible, "无档启动走初幕演出")
	main1._finish_tutorial()
	check(FileAccess.file_exists(path), "教程完成即写盘")
	# 教程收尾进第二幕演出（design-round11）→ 按完置位 act2_done 并落盘
	var prologue1 := main1.get_node("%ProloguePage") as Control
	check(prologue1.visible, "教程收尾进第二幕演出")
	check(not main1.run.act2_done, "收尾时 act2_done 未置位")
	for _i in StoryBeats.ACT2_BEATS.size():
		(prologue1._continue_button as Button).pressed.emit()
	check(main1.run.act2_done, "第二幕看完置位")
	check(bool(SaveGame.load_progress().get("act2_done", false)), "act2_done 落盘")
	viewport1.queue_free()
	await process_frame
	# 二：重启直达路线（跳过初幕与第二幕）
	var main2: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport2 := _attach_scene(main2)
	await process_frame
	var map2 := main2.get_node("%MapPage") as Control
	check(map2.visible and not (main2.get_node("%ProloguePage") as Control).visible, "有档启动直达路线（第二幕不重看）")
	check(main2.run.tutorial_done and main2.run.companions.has("菲戈蕾"), "进度还原")
	check(not (main2.get_node("%ConfirmOverlay") as Control).visible, "直达不出弹窗")
	# 三：走一步（事件）→ 自动存盘 → 再重启续到第二列
	main2.run.route = _fixture_route()
	main2.run.route_layer = main2.run.current_layer
	main2._open_map()
	var fog2 := _deep_find_button(map2, "事件·试衣镜")
	check(fog2 != null and not fog2.disabled, "续玩：第一列节点可点")
	fog2.pressed.emit()
	(main2.get_node("%ConfirmPrimaryButton") as Button).pressed.emit()
	var event_page2 := main2.get_node("%EventPage") as Control
	check(event_page2.visible, "确认后进入事件页")
	_complete_pick_event(event_page2, 0)
	check(main2.run.column_index == 1, "走完一步推进到第二列")
	viewport2.queue_free()
	await process_frame
	var main3: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var viewport3 := _attach_scene(main3)
	await process_frame
	var map3 := main3.get_node("%MapPage") as Control
	check(map3.visible, "再重启仍直达路线")
	check(main3.run.column_index == 1 and main3.run.chosen == [0], "中途进度续到第二列")
	var fog3 := _deep_find_button(map3, "事件·试衣镜")
	check(fog3 != null and fog3.text.contains("✓"), "已走节点续档后标 ✓")
	var echo3 := _deep_find_button(map3, "作战·糖丝傀儡")
	check(echo3 != null and not echo3.disabled, "第二列续档后可直接继续")
	viewport3.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_path = SaveGame.DEFAULT_SAVE_PATH
	SaveGame.disabled = true
