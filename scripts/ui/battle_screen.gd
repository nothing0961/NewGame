extends Control

const OVERLAY_NONE := ""
const OVERLAY_INTRO := "intro"
const OVERLAY_STRIP := "strip"
const OVERLAY_PURIFY := "purify"
const OVERLAY_DEBRIEF := "debrief"

@onready var enemy_hp_label: Label = %EnemyHpLabel
@onready var log_text: RichTextLabel = %LogText
@onready var player_hp_label: Label = %PlayerHpLabel
@onready var player_block_label: Label = %PlayerBlockLabel
@onready var hand_box: HBoxContainer = %HandBox
@onready var end_turn_button: Button = %EndTurnButton
@onready var overlay: Control = %Overlay
@onready var story_text: Label = %StoryText
@onready var absorb_button: Button = %AbsorbButton
@onready var continue_button: Button = %ContinueButton

var state: BattleState
var overlay_mode := OVERLAY_NONE
var debrief_index := 0


func _ready() -> void:
	state = BattleState.new()
	state.log_event.connect(_on_log)
	state.stats_changed.connect(_sync_ui)
	state.phase_changed.connect(_on_phase)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	absorb_button.pressed.connect(_on_absorb_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	state.start()
	_set_overlay(OVERLAY_INTRO)


func _on_log(text: String) -> void:
	log_text.append_text(text + "\n")


func _sync_ui() -> void:
	enemy_hp_label.text = "生命 %d / %d" % [state.enemy_hp, BattleConfig.ENEMY_MAX_HP]
	player_hp_label.text = "你：%d / %d" % [state.player_hp, BattleConfig.PLAYER_MAX_HP]
	var block_line := "护住 %d" % state.player_block
	if state.attack_bonus > 0:
		block_line += "　攻击 +%d" % state.attack_bonus
	player_block_label.text = block_line
	end_turn_button.disabled = state.phase != BattleState.Phase.PLAYER
	_rebuild_hand()


func _rebuild_hand() -> void:
	for child in hand_box.get_children():
		child.hide()
		child.queue_free()
	for i in state.hand.size():
		var button := CardButton.new()
		button.setup(state.hand[i])
		button.disabled = state.phase != BattleState.Phase.PLAYER
		button.pressed.connect(_on_card_pressed.bind(i))
		hand_box.add_child(button)


func _on_card_pressed(index: int) -> void:
	if state.phase != BattleState.Phase.PLAYER:
		return
	state.play_card(index)


func _on_end_turn_pressed() -> void:
	if state.phase != BattleState.Phase.PLAYER:
		return
	state.end_turn()


func _on_absorb_pressed() -> void:
	state.absorb_wrath()


func _on_continue_pressed() -> void:
	match overlay_mode:
		OVERLAY_INTRO:
			_set_overlay(OVERLAY_NONE)
		OVERLAY_PURIFY:
			debrief_index = 0
			_set_overlay(OVERLAY_DEBRIEF)
		OVERLAY_DEBRIEF:
			debrief_index += 1
			if debrief_index < BattleConfig.TEXT_DEBRIEF.size():
				_show_debrief_question()
			else:
				state.finish_debrief()
		_:
			_set_overlay(OVERLAY_NONE)


func _on_phase(phase: int) -> void:
	match phase:
		BattleState.Phase.STRIP:
			_set_overlay(OVERLAY_STRIP)
		BattleState.Phase.DEBRIEF:
			_set_overlay(OVERLAY_PURIFY)
		_:
			_set_overlay(OVERLAY_NONE)


func _set_overlay(mode: String) -> void:
	overlay_mode = mode
	overlay.visible = mode != OVERLAY_NONE
	absorb_button.visible = mode == OVERLAY_STRIP
	continue_button.visible = mode == OVERLAY_INTRO or mode == OVERLAY_PURIFY or mode == OVERLAY_DEBRIEF
	match mode:
		OVERLAY_INTRO:
			story_text.text = "\n".join(PackedStringArray(BattleConfig.TEXT_INTRO))
		OVERLAY_STRIP:
			story_text.text = "\n".join(PackedStringArray(BattleConfig.TEXT_STRIP))
		OVERLAY_PURIFY:
			story_text.text = "\n".join(PackedStringArray(BattleConfig.TEXT_PURIFY))
		OVERLAY_DEBRIEF:
			_show_debrief_question()


func _show_debrief_question() -> void:
	story_text.text = BattleConfig.TEXT_DEBRIEF[debrief_index]
