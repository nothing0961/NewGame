extends Control

const BATTLE_SCENE := preload("res://scenes/battle.tscn")

enum Page { STORY, PRACTICE, BATTLE }

@onready var story_page: Control = %StoryPage
@onready var story_text: Label = %StoryText
@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton
@onready var battle_host: Control = %BattleHost
@onready var practice_page = %PracticePage

var pool := CardPool.new()
var _primary_action: Callable = Callable()
var _secondary_action: Callable = Callable()


func _ready() -> void:
	practice_page.setup(pool)
	practice_page.start_practice_requested.connect(_on_practice_start_requested)
	practice_page.leave_requested.connect(_on_practice_leave_requested)
	_show_intro()


func _show_intro() -> void:
	_show_story(BattleConfig.TEXT_INTRO, "继续", _show_teach)


func _show_teach() -> void:
	_show_story(BattleConfig.TEXT_TEACH, "去练习站", _open_practice, "直接去台阶", _show_transform)


func _open_practice() -> void:
	practice_page.rebuild()
	_show_page(Page.PRACTICE)


func _on_practice_start_requested() -> void:
	_start_battle(BattleState.Mode.PRACTICE, pool.deck.duplicate())


func _on_practice_leave_requested() -> void:
	_show_transform()


func _show_transform() -> void:
	_show_story(BattleConfig.TEXT_TRANSFORM, "打倒她", _start_tutorial_battle)


func _start_tutorial_battle() -> void:
	var deck: Array = []
	if pool.is_deck_valid():
		deck = pool.deck.duplicate()
	_start_battle(BattleState.Mode.TUTORIAL, deck)


func _show_ending() -> void:
	_show_story(BattleConfig.TEXT_ENDING, "重新开始", _restart)


func _restart() -> void:
	get_tree().reload_current_scene()


func _start_battle(mode: int, deck: Array) -> void:
	var battle := BATTLE_SCENE.instantiate()
	battle.configure(mode, deck)
	battle.battle_ended.connect(_on_battle_ended)
	_show_page(Page.BATTLE)
	battle_host.add_child(battle)


func _on_battle_ended(practice: bool) -> void:
	for child in battle_host.get_children():
		child.queue_free()
	if practice:
		_open_practice()
	else:
		_show_ending()


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
