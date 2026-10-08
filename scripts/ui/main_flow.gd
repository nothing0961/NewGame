extends Control

const BATTLE_SCENE := preload("res://scenes/battle.tscn")

enum Page { STORY, PRACTICE, BATTLE, MAP, EVENT, TRANSITION, PROLOGUE }

# 主菜单「练习站」入口标记：主菜单置位 → 本场景 _ready 消费后直开练习站（离开时回主菜单）
static var open_practice_on_ready := false

@onready var story_page: Control = %StoryPage
@onready var story_text: Label = %StoryText
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton
@onready var battle_host: Control = %BattleHost
@onready var practice_page = %PracticePage
@onready var map_page: MapPage = %MapPage
@onready var event_page: EventPage = %EventPage
@onready var transition_page: TransitionPage = %TransitionPage
@onready var prologue_page: ProloguePage = %ProloguePage
@onready var confirm_overlay: Control = %ConfirmOverlay
@onready var confirm_title: Label = %ConfirmTitle
@onready var confirm_primary_button: Button = %ConfirmPrimaryButton
@onready var choose_deck_button: Button = %ChooseDeckButton

var pool := CardPool.new()
var run := RunState.new()
var _primary_action: Callable = Callable()
var _secondary_action: Callable = Callable()
var _practice_return: Callable = Callable()
var _battle_context := ""  # "tutorial" / "story" / "practice" / "teaching"
var _battle: Control = null
# 确认窗待定节点：点节点只备忘，确认主按钮才 choose 落账（design-round5.md §0.4）
var _pending_node_index := -1
var _pending_stage: Dictionary = {}


func _ready() -> void:
	practice_page.setup(pool)
	practice_page.start_practice_requested.connect(_on_practice_start_requested)
	practice_page.leave_requested.connect(_on_practice_leave_requested)
	map_page.node_requested.connect(_on_map_node_requested)
	map_page.practice_requested.connect(_open_practice_from_map)
	map_page.menu_requested.connect(_return_to_title)
	event_page.completed.connect(_on_event_completed)
	event_page.game_resolved.connect(_on_event_resolved)
	transition_page.continued.connect(_open_map)
	prologue_page.finished.connect(_on_prologue_finished)
	confirm_primary_button.pressed.connect(_on_confirm_primary)
	choose_deck_button.pressed.connect(_on_confirm_deck)
	if open_practice_on_ready:
		open_practice_on_ready = false
		_practice_return = _return_to_title
		_open_practice()
	else:
		# 进度存档：教程已过＝直达路线（design-round5.md §0.1）
		if not SaveGame.disabled:
			var data := SaveGame.load_progress()
			if not data.is_empty():
				SaveGame.apply_progress(data, run, pool)
		if run.tutorial_done:
			_open_map()
		else:
			_show_prologue()


# 初幕演出（design-round6）：小组脚本全文分拍；演出结束直接进蜗牛教学战
func _show_prologue() -> void:
	prologue_page.start()
	_show_page(Page.PROLOGUE)


func _on_prologue_finished() -> void:
	_start_teaching_battle()


# 蜗牛教学战（单位制 4；胜利后进教学说明）
func _start_teaching_battle() -> void:
	_battle_context = "teaching"
	_start_battle(BattleState.Mode.TEACHING, [])


func _show_teach() -> void:
	_show_story(BattleConfig.TEXT_TEACH, "去练习站", _open_practice_from_teach, "直接前进", _show_transform)


func _open_practice_from_teach() -> void:
	_practice_return = _show_transform
	_open_practice()


func _open_practice_from_map() -> void:
	_practice_return = _open_map
	_open_practice()


func _open_practice() -> void:
	practice_page.rebuild()
	_show_page(Page.PRACTICE)


func _on_practice_start_requested() -> void:
	_battle_context = "practice"
	_start_battle(BattleState.Mode.PRACTICE, pool.deck.duplicate())


func _on_practice_leave_requested() -> void:
	SaveGame.save_progress(run, pool)
	if _practice_return.is_valid():
		_practice_return.call()
	else:
		_return_to_title()


func _show_transform() -> void:
	_show_story(BattleConfig.TEXT_TRANSFORM, "打倒她", _start_tutorial_battle)


func _start_tutorial_battle() -> void:
	var deck: Array = []
	if pool.is_deck_valid():
		deck = pool.deck.duplicate()
	_battle_context = "tutorial"
	_start_battle(BattleState.Mode.TUTORIAL, deck)


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# —— 层循环（design/design-round3.md）——

func _open_map() -> void:
	map_page.build(run)
	_show_page(Page.MAP)


# 点节点＝弹确认窗（不直接入关）；choose 落账推迟到确认主按钮（design-round5.md §0.2/0.4）
func _on_map_node_requested(index: int) -> void:
	var column := run.current_column()
	if index < 0 or index >= column.size():
		return
	_pending_node_index = index
	_pending_stage = column[index]
	_show_confirm_dialog()


func _show_confirm_dialog() -> void:
	var is_battle := String(_pending_stage.get("type", "")) == LayerConfig.TYPE_BATTLE
	confirm_title.text = "进入「%s」？" % LayerConfig.node_label(_pending_stage)
	confirm_primary_button.text = "开始战斗" if is_battle else "进入事件"
	confirm_overlay.visible = true


func _on_confirm_primary() -> void:
	confirm_overlay.visible = false
	var index := _pending_node_index
	_pending_node_index = -1
	_pending_stage = {}
	_enter_stage(run.choose(index))


# 「选择牌组」＝跳练习站组卡；离开后回地图并重新弹同节点确认窗（pending 保留、未落账）
func _on_confirm_deck() -> void:
	confirm_overlay.visible = false
	_practice_return = _return_from_deck_edit
	_open_practice()


func _return_from_deck_edit() -> void:
	_open_map()
	if _pending_node_index >= 0:
		_show_confirm_dialog()


func _enter_stage(stage: Dictionary) -> void:
	if stage.is_empty():
		_open_map()
		return
	if String(stage.get("type", "")) == LayerConfig.TYPE_BATTLE:
		var deck: Array = []
		if pool.is_deck_valid():
			deck = pool.deck.duplicate()
		_battle_context = "story"
		# 轻增益（design-round10 §4）：story 开局读取并即刻消费；教学/练习/教程战不传不消耗
		_start_battle(BattleState.Mode.STORY, deck, stage, run.entry_hp(), run.entry_block(), run.entry_draw())
		run.consume_buffs()
	else:
		event_page.show_event(stage)
		_show_page(Page.EVENT)


func _on_event_completed() -> void:
	_after_route_step()


# 事件结算落账（design-round10 §4）：outcome 词汇 {hp,block,draw}，由 RunState 归一与 clamp
func _on_event_resolved(outcome: Dictionary) -> void:
	run.apply_outcome(outcome)


# 一步走完：路线走完＝层完成（上行过渡），否则回地图继续选路；走完即存盘（design-round5.md §1）
func _after_route_step() -> void:
	if run.is_route_finished():
		var layer := run.current_layer
		run.complete_layer()
		_show_transition(LayerConfig.transition_lines(layer))
	else:
		_open_map()
	SaveGame.save_progress(run, pool)


func _start_battle(mode: int, deck: Array, stage: Dictionary = {}, entry_hp := -1, entry_block := 0, entry_draw := 0) -> void:
	_battle = BATTLE_SCENE.instantiate()
	_battle.configure(mode, deck, stage, entry_hp, entry_block, entry_draw)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.battle_lost.connect(_on_battle_lost)
	_show_page(Page.BATTLE)
	battle_host.add_child(_battle)


func _free_battle() -> void:
	for child in battle_host.get_children():
		child.queue_free()
	_battle = null


func _collect_from_battle() -> Array[String]:
	var ids: Array[String] = []
	if _battle != null:
		ids = _battle.collected_sin_ids()
	for id in ids:
		run.collect_sin(id)
		pool.collect_sin(id)
	return ids


func _on_battle_ended(practice: bool) -> void:
	var collected := _collect_from_battle()
	_free_battle()
	if practice:
		_open_practice()
		return
	if _battle_context == "teaching":
		_show_teach()
	elif _battle_context == "tutorial":
		_finish_tutorial()
	else:
		_finish_story_stage(collected)


func _finish_tutorial() -> void:
	run.tutorial_done = true
	run.add_companion(LayerConfig.LAYER1_COMPANION)
	SaveGame.save_progress(run, pool)
	_show_transition(BattleConfig.TEXT_ENDING)


func _finish_story_stage(collected: Array[String]) -> void:
	if not collected.is_empty():
		run.add_companion(LayerConfig.demon_name(run.current_layer))
	_after_route_step()


func _on_battle_lost() -> void:
	_free_battle()
	if _battle_context == "teaching":
		# 教学战失败＝原地重开本战（design-round6；不重看初幕演出）
		_start_teaching_battle()
	elif _battle_context == "tutorial":
		# 教程层主战失败＝回追及段重来（design-round6；不再回初幕演出）
		_show_transform()
	else:
		# 死亡回层首＝回第一列重新选路（design-round4.md §0）
		run.reset_layer()
		_open_map()
		SaveGame.save_progress(run, pool)


func _show_transition(lines: Array) -> void:
	transition_page.show_transition(lines)
	_show_page(Page.TRANSITION)


func _show_story(lines: Array, primary_label: String, primary_action: Callable, secondary_label: String = "", secondary_action: Callable = Callable()) -> void:
	story_text.text = "\n\n".join(PackedStringArray(lines))
	_primary_action = _set_button(primary_button, primary_label, primary_action, _primary_action)
	if secondary_label == "":
		secondary_button.visible = false
		_secondary_action = _disconnect_button(secondary_button, _secondary_action)
	else:
		secondary_button.visible = true
		_secondary_action = _set_button(secondary_button, secondary_label, secondary_action, _secondary_action)
	_show_page(Page.STORY)


func _set_button(button: Button, label: String, action: Callable, previous: Callable) -> Callable:
	button.text = label
	if previous.is_valid() and button.pressed.is_connected(previous):
		button.pressed.disconnect(previous)
	if action.is_valid() and not button.pressed.is_connected(action):
		button.pressed.connect(action)
	return action


func _disconnect_button(button: Button, previous: Callable) -> Callable:
	if previous.is_valid() and button.pressed.is_connected(previous):
		button.pressed.disconnect(previous)
	return Callable()


func _show_page(page: int) -> void:
	story_page.visible = page == Page.STORY
	practice_page.visible = page == Page.PRACTICE
	map_page.visible = page == Page.MAP
	event_page.visible = page == Page.EVENT
	transition_page.visible = page == Page.TRANSITION
	prologue_page.visible = page == Page.PROLOGUE
