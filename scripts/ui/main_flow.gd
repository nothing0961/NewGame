extends Control

const BATTLE_SCENE := preload("res://scenes/battle.tscn")

enum Page { STORY, MENU, PRACTICE, BATTLE, MAP, EVENT, TRANSITION }

@onready var story_page: Control = %StoryPage
@onready var story_text: Label = %StoryText
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton
@onready var battle_host: Control = %BattleHost
@onready var practice_page = %PracticePage
@onready var menu_page: Control = %MenuPage
@onready var menu_continue_button: Button = %MenuContinueButton
@onready var menu_practice_button: Button = %MenuPracticeButton
@onready var menu_restart_button: Button = %MenuRestartButton
@onready var map_page: MapPage = %MapPage
@onready var event_page: EventPage = %EventPage
@onready var transition_page: TransitionPage = %TransitionPage

var pool := CardPool.new()
var run := RunState.new()
var _primary_action: Callable = Callable()
var _secondary_action: Callable = Callable()
var _practice_return: Callable = Callable()
var _teach_seen := false
var _battle_context := ""  # "tutorial" / "story" / "practice"
var _battle: Control = null


func _ready() -> void:
	practice_page.setup(pool)
	practice_page.start_practice_requested.connect(_on_practice_start_requested)
	practice_page.leave_requested.connect(_on_practice_leave_requested)
	menu_continue_button.pressed.connect(_on_continue_story_pressed)
	menu_practice_button.pressed.connect(_open_practice_from_menu)
	menu_restart_button.pressed.connect(_restart)
	map_page.node_requested.connect(_on_map_node_requested)
	map_page.practice_requested.connect(_open_practice_from_map)
	map_page.menu_requested.connect(_show_entry_menu)
	event_page.completed.connect(_on_event_completed)
	transition_page.continued.connect(_open_map)
	_show_intro()


func _show_intro() -> void:
	_show_story(BattleConfig.TEXT_INTRO, "继续", _show_entry_menu)


# 入口页：练习站独立于剧情，随时可进
func _show_entry_menu() -> void:
	if run.tutorial_done:
		menu_continue_button.text = "继续剧情"
	elif _teach_seen:
		menu_continue_button.text = "继续剧情（前往台阶）"
	else:
		menu_continue_button.text = "继续剧情"
	_show_page(Page.MENU)


func _on_continue_story_pressed() -> void:
	if run.tutorial_done:
		_open_map()
	elif _teach_seen:
		_show_transform()
	else:
		_show_teach()


func _show_teach() -> void:
	_teach_seen = true
	_show_story(BattleConfig.TEXT_TEACH, "去练习站", _open_practice_from_teach, "直接去台阶", _show_transform)


func _open_practice_from_menu() -> void:
	_practice_return = _show_entry_menu
	_open_practice()


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
	if _practice_return.is_valid():
		_practice_return.call()
	else:
		_show_entry_menu()


func _show_transform() -> void:
	_show_story(BattleConfig.TEXT_TRANSFORM, "打倒她", _start_tutorial_battle)


func _start_tutorial_battle() -> void:
	var deck: Array = []
	if pool.is_deck_valid():
		deck = pool.deck.duplicate()
	_battle_context = "tutorial"
	_start_battle(BattleState.Mode.TUTORIAL, deck)


func _restart() -> void:
	get_tree().reload_current_scene()


# —— 层循环（design/design-round3.md）——

func _open_map() -> void:
	map_page.build(run)
	_show_page(Page.MAP)


# 选路即入关：choose() 记录选择并推进当前列（design-round4.md §1）
func _on_map_node_requested(index: int) -> void:
	_enter_stage(run.choose(index))


func _enter_stage(stage: Dictionary) -> void:
	if stage.is_empty():
		_open_map()
		return
	if String(stage.get("type", "")) == LayerConfig.TYPE_BATTLE:
		var deck: Array = []
		if pool.is_deck_valid():
			deck = pool.deck.duplicate()
		_battle_context = "story"
		_start_battle(BattleState.Mode.STORY, deck, stage)
	else:
		event_page.show_event(stage)
		_show_page(Page.EVENT)


func _on_event_completed() -> void:
	_after_route_step()


# 一步走完：路线走完＝层完成（上行过渡），否则回地图继续选路
func _after_route_step() -> void:
	if run.is_route_finished():
		var layer := run.current_layer
		run.complete_layer()
		_show_transition(LayerConfig.transition_lines(layer))
	else:
		_open_map()


func _start_battle(mode: int, deck: Array, stage: Dictionary = {}) -> void:
	_battle = BATTLE_SCENE.instantiate()
	_battle.configure(mode, deck, stage)
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
	if _battle_context == "tutorial":
		_finish_tutorial()
	else:
		_finish_story_stage(collected)


func _finish_tutorial() -> void:
	run.tutorial_done = true
	run.add_companion(LayerConfig.demon_name(LayerConfig.TUTORIAL_LAYER))
	_show_transition(BattleConfig.TEXT_ENDING)


func _finish_story_stage(collected: Array[String]) -> void:
	if not collected.is_empty():
		run.add_companion(LayerConfig.demon_name(run.current_layer))
	_after_route_step()


func _on_battle_lost() -> void:
	_free_battle()
	if _battle_context == "tutorial":
		# 教程层首段＝召唤告知（提案待复核，design/design-round3.md §5）
		_show_intro()
	else:
		# 死亡回层首＝回第一列重新选路（design-round4.md §0）
		run.reset_layer()
		_open_map()


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
	menu_page.visible = page == Page.MENU
	practice_page.visible = page == Page.PRACTICE
	map_page.visible = page == Page.MAP
	event_page.visible = page == Page.EVENT
	transition_page.visible = page == Page.TRANSITION
