extends Control

const OVERLAY_NONE := ""
const OVERLAY_STRIP := "strip"
const OVERLAY_PURIFY := "purify"
const OVERLAY_DEBRIEF := "debrief"
const OVERLAY_PRACTICE_END := "practice_end"
const OVERLAY_DISCARD := "discard"

const TIMER_WARN_SECONDS := 10.0
const TIMER_WARN_COLOR := Color(1.0, 0.35, 0.3)
const HAND_COUNT_WARN_COLOR := Color(1.0, 0.72, 0.4, 1.0)
const HIGHLIGHT_HOVER_BORDER := Color(1.0, 0.87, 0.55, 1.0)
const HIGHLIGHT_DROPPABLE_BORDER := Color(0.72, 0.84, 1.0, 1.0)

const FAN_STEP_MAX := 118.0
const FAN_STEP_MIN := 42.0
const FAN_PAD := 10.0
const FAN_CARD_SIZE := Vector2(118, 142)
const FAN_BOTTOM_MARGIN := 12.0

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_EXTS: Array[String] = [".ogg", ".wav", ".mp3"]
const SFX_BY_CARD := {"strike": "sfx_hit", "guard": "sfx_guard", "call": "sfx_call"}

signal battle_ended(practice: bool)

@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var enemy_hp_label: Label = %EnemyHpLabel
@onready var enemy_hand_label: Label = %EnemyHandLabel
@onready var log_text: RichTextLabel = %LogText
@onready var player_hp_label: Label = %PlayerHpLabel
@onready var player_block_label: Label = %PlayerBlockLabel
@onready var cost_label: Label = %CostLabel
@onready var pile_count_label: Label = %PileCountLabel
@onready var hand_count_label: Label = %HandCountLabel
@onready var hand_box: Control = %HandBox
@onready var play_box: HBoxContainer = %PlayBox
@onready var commit_button: Button = %CommitButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var turn_timer_label: Label = %TurnTimerLabel
@onready var quit_practice_button: Button = %QuitPracticeButton
@onready var overlay: Control = %Overlay
@onready var story_text: Label = %StoryText
@onready var absorb_button: Button = %AbsorbButton
@onready var continue_button: Button = %ContinueButton
@onready var discard_scroll: ScrollContainer = %DiscardScroll
@onready var discard_box: VBoxContainer = %DiscardBox
@onready var discard_zone: PanelContainer = %DiscardZone
@onready var discard_zone_label: Label = %DiscardZoneLabel
@onready var play_zone_panel: PanelContainer = %PlayZonePanel
@onready var hand_scroll: ScrollContainer = $HandScroll

var state: BattleState
var overlay_mode := OVERLAY_NONE
var debrief_index := 0
var turn_time_left := BattleConfig.TURN_TIME_LIMIT
var _turn_discard_gain := 0
var _drag_zone_source := ""
var _drag_target_now := ""
var _drag_stageable := false
var _zone_base_styles := {}
var _zone_hover_styles := {}
var _zone_droppable_styles := {}
var _sfx_players := {}

var _battle_mode := BattleState.Mode.TUTORIAL
var _deck: Array = []
var _finished_reported := false


func configure(battle_mode: int, deck: Array) -> void:
	_battle_mode = battle_mode
	_deck = deck


func _ready() -> void:
	state = BattleState.new()
	state.log_event.connect(_on_log)
	state.stats_changed.connect(_sync_ui)
	state.phase_changed.connect(_on_phase)
	state.card_staged.connect(_on_card_staged)
	state.card_recalled.connect(_on_card_recalled)
	state.card_played.connect(_on_card_played)
	state.card_discarded.connect(_on_card_discarded)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	commit_button.pressed.connect(_on_commit_pressed)
	absorb_button.pressed.connect(_on_absorb_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_practice_button.pressed.connect(_on_quit_practice_pressed)
	quit_practice_button.visible = _battle_mode == BattleState.Mode.PRACTICE
	absorb_button.text = "拿起 %s" % CardDB.get_card("wrath").display_name
	_setup_zone_styles()
	hand_box.resized.connect(_layout_hand)
	if _battle_mode == BattleState.Mode.PRACTICE:
		state.start_practice(_deck)
	else:
		state.start(_deck)
	_layout_hand.call_deferred()


func _process(delta: float) -> void:
	if state == null or state.phase != BattleState.Phase.PLAYER:
		return
	if overlay.visible:
		return
	turn_time_left = max(0.0, turn_time_left - delta)
	_update_timer_label()
	if turn_time_left <= 0.0:
		state.end_turn()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_layout_hand()
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		_drag_zone_source = ""
		_drag_stageable = false
		if typeof(data) == TYPE_DICTIONARY:
			var info := data as Dictionary
			_drag_zone_source = String(info.get("zone", ""))
			if _drag_zone_source == "hand":
				_drag_stageable = _stageable_from_data(info)
		_drag_target_now = ""
		_refresh_zone_highlight()
		_update_discard_zone()
	elif what == NOTIFICATION_DRAG_END:
		_drag_zone_source = ""
		_drag_stageable = false
		_drag_target_now = ""
		_refresh_zone_highlight()
		_update_discard_zone()


func _on_log(text: String) -> void:
	log_text.append_text(text + "\n")


func _sync_ui() -> void:
	enemy_name_label.text = state.enemy_name
	enemy_hp_label.text = "生命 %d / %d" % [state.enemy_hp, state.enemy_max_hp]
	enemy_hand_label.text = "手牌 %d 张" % state.enemy_hand.size()
	enemy_hand_label.visible = state.mode == BattleState.Mode.TUTORIAL
	player_hp_label.text = "你：%d / %d" % [state.player_hp, BattleConfig.PLAYER_MAX_HP]
	cost_label.text = "Cost %d / %d" % [state.player_cost, BattleConfig.PLAYER_MAX_COST]
	var block_line := "护住 %d" % state.player_block
	if state.attack_bonus > 0:
		block_line += "　攻击 +%d" % state.attack_bonus
	player_block_label.text = block_line
	hand_count_label.text = "手牌 %d/%d" % [state.hand.size(), BattleConfig.HAND_LIMIT]
	if state.hand.size() >= BattleConfig.HAND_LIMIT:
		hand_count_label.add_theme_color_override("font_color", HAND_COUNT_WARN_COLOR)
	else:
		hand_count_label.remove_theme_color_override("font_color")
	pile_count_label.text = "牌堆 %d　弃牌堆 %d" % [state.draw_pile.size(), state.discard_pile.size()]
	end_turn_button.disabled = state.phase != BattleState.Phase.PLAYER
	_rebuild_hand()
	_rebuild_play_zone()
	_update_commit_button()
	if state.needs_discard() and overlay_mode != OVERLAY_DISCARD:
		_set_overlay(OVERLAY_DISCARD)
	elif overlay_mode == OVERLAY_DISCARD and not state.needs_discard():
		_set_overlay(OVERLAY_NONE)
	elif overlay_mode == OVERLAY_DISCARD:
		_rebuild_discard_list()


func _rebuild_hand() -> void:
	for child in hand_box.get_children():
		child.hide()
		child.queue_free()
	for i in state.hand.size():
		var card: CardData = state.hand[i]
		var button := CardButton.new()
		button.setup(card)
		button.tooltip_text = card.flavor + "\n拖拽：松手自动摆进出牌区；拖到弃牌区＝弃掉换 Cost"
		if state.phase == BattleState.Phase.PLAYER:
			button.drag_zone = "hand"
			button.drag_index = i
		else:
			button.disabled = true
		if not state.can_stage(card):
			button.modulate = Color(0.55, 0.55, 0.55)
		hand_box.add_child(button)
	_layout_hand()


# 扇形叠压：8 张上限内完整排开（步进 118），超限弃牌窗口（9–11 张）逐张收窄全部可见
func _layout_hand() -> void:
	if hand_box == null or hand_box.size.x < 10.0:
		return
	var cards: Array[CardButton] = []
	for child in hand_box.get_children():
		if child is CardButton and not child.is_queued_for_deletion():
			cards.append(child)
	var n := cards.size()
	if n == 0:
		return
	var step := FAN_STEP_MAX
	if n > 1:
		step = clampf((hand_box.size.x - 2.0 * FAN_PAD - FAN_CARD_SIZE.x) / float(n - 1), FAN_STEP_MIN, FAN_STEP_MAX)
	var start_x := (hand_box.size.x - (FAN_CARD_SIZE.x + step * float(n - 1))) * 0.5
	var base_y := hand_box.size.y - FAN_CARD_SIZE.y - FAN_BOTTOM_MARGIN
	for i in n:
		var button := cards[i]
		button.fan_arranged = true
		button.fan_base_position = Vector2(start_x + step * float(i), base_y)
		button.size = FAN_CARD_SIZE
		button.position = button.fan_base_position


func _rebuild_play_zone() -> void:
	for child in play_box.get_children():
		child.hide()
		child.queue_free()
	var staging_locked := state.phase != BattleState.Phase.PLAYER
	for i in BattleConfig.PLAY_ZONE_SIZE:
		if i < state.staged.size():
			var card: CardData = state.staged[i]
			var card_button := CardButton.new()
			card_button.setup(card)
			card_button.text = "%s\n\n（点击收回）" % card.display_name
			card_button.tooltip_text = "点击收回，或拖回手牌区"
			card_button.drag_zone = "play"
			card_button.drag_index = i
			card_button.disabled = staging_locked
			card_button.pressed.connect(_on_staged_pressed.bind(i))
			play_box.add_child(card_button)
		else:
			var slot := Button.new()
			slot.text = "空位"
			slot.disabled = true
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.custom_minimum_size = Vector2(118, 96)
			slot.add_theme_font_size_override("font_size", 13)
			var slot_style := StyleBoxFlat.new()
			slot_style.bg_color = Color(0.1, 0.095, 0.14, 0.4)
			slot_style.border_color = Color(0.3, 0.28, 0.4, 0.5)
			slot_style.set_border_width_all(1)
			slot_style.set_corner_radius_all(6)
			slot_style.set_content_margin_all(0)
			slot.add_theme_stylebox_override("disabled", slot_style)
			slot.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.52))
			play_box.add_child(slot)


func _update_commit_button() -> void:
	if state.staged.is_empty():
		commit_button.text = "打出"
		commit_button.disabled = true
	else:
		commit_button.text = "打出（Cost -%d）" % state.staged_cost()
		commit_button.disabled = state.phase != BattleState.Phase.PLAYER


func _on_staged_pressed(index: int) -> void:
	state.recall_card(index)


# 手牌拖出即视为要打出：除弃牌区外，放手在任何位置都自动摆进出牌区
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var info := data as Dictionary
	var zone := String(info.get("zone", ""))
	var target := _drop_target_at(at_position)
	var accepted := false
	var hover := ""
	if zone == "hand":
		_drag_stageable = _stageable_from_data(info)
		if target == "discard":
			accepted = true
			hover = "discard"
		elif _drag_stageable:
			accepted = true
			hover = "play"
	elif zone == "play" and target == "hand":
		accepted = true
		hover = "hand"
	if hover != _drag_target_now:
		_drag_target_now = hover
		_refresh_zone_highlight()
		_update_discard_zone(info if hover == "discard" else null)
	return accepted


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var zone := String(data.get("zone", ""))
	var index := int(data.get("index", -1))
	if zone == "hand":
		if _drop_target_at(at_position) == "discard":
			_discard_for_cost(index)
		else:
			state.stage_card(index)
	elif zone == "play" and _drop_target_at(at_position) == "hand":
		state.recall_card(index)


func _stageable_from_data(data: Dictionary) -> bool:
	var index := int(data.get("index", -1))
	if index < 0 or index >= state.hand.size():
		return false
	return state.can_stage(state.hand[index])


func _drop_target_at(at_position: Vector2) -> String:
	var global_point := get_global_transform() * at_position
	if play_box.get_global_rect().has_point(global_point):
		return "play"
	if discard_zone.get_global_rect().has_point(global_point):
		return "discard"
	if hand_box.get_global_rect().has_point(global_point):
		return "hand"
	return ""


func _zone_visual(zone: String) -> Control:
	match zone:
		"play":
			return play_zone_panel
		"discard":
			return discard_zone
		"hand":
			return hand_scroll
	return null


# 高亮走面板边框换色（modulate 乘在暗底板上几乎看不见）
func _setup_zone_styles() -> void:
	for zone in ["play", "discard", "hand"]:
		var visual: Control = _zone_visual(zone)
		if visual == null:
			continue
		var base := visual.get_theme_stylebox("panel")
		if base == null:
			continue
		_zone_base_styles[zone] = base
		var hover: StyleBoxFlat = base.duplicate()
		hover.border_color = HIGHLIGHT_HOVER_BORDER
		hover.bg_color = hover.bg_color.lightened(0.18)
		_zone_hover_styles[zone] = hover
		var droppable: StyleBoxFlat = base.duplicate()
		droppable.border_color = HIGHLIGHT_DROPPABLE_BORDER
		_zone_droppable_styles[zone] = droppable


func _refresh_zone_highlight() -> void:
	var droppable: Array[String] = []
	if _drag_zone_source == "hand":
		if _drag_stageable:
			droppable = ["play", "discard"]
		else:
			droppable = ["discard"]
	elif _drag_zone_source == "play":
		droppable = ["hand"]
	for zone in ["play", "discard", "hand"]:
		if not _zone_base_styles.has(zone):
			continue
		var visual: Control = _zone_visual(zone)
		var style: StyleBox = _zone_base_styles[zone]
		if _drag_zone_source != "":
			if zone == _drag_target_now:
				style = _zone_hover_styles[zone]
			elif zone in droppable:
				style = _zone_droppable_styles[zone]
		visual.add_theme_stylebox_override("panel", style)


func _discard_for_cost(index: int) -> void:
	var gain := state.discard_for_cost(index)
	if gain >= 0:
		_turn_discard_gain += gain
		_update_discard_zone()


func _update_discard_zone(drag_data: Variant = null) -> void:
	var hover_preview := ""
	if typeof(drag_data) == TYPE_DICTIONARY:
		var card_id := String((drag_data as Dictionary).get("card_id", ""))
		if card_id != "":
			var card: CardData = CardDB.get_card(card_id)
			if card != null:
				hover_preview = "\n\n弃掉「%s」\n获得 Cost +%d" % [card.display_name, card.cost - 1]
	discard_zone_label.text = "弃牌区\n\n把手牌拖到这里弃掉\n获得（牌的 Cost - 1）点 Cost\n\n本回合已获得 +%d%s" % [_turn_discard_gain, hover_preview]


func _on_commit_pressed() -> void:
	state.commit_staged()


func _on_end_turn_pressed() -> void:
	if state.phase != BattleState.Phase.PLAYER:
		return
	state.end_turn()


func _on_absorb_pressed() -> void:
	if state.absorb_wrath():
		_play_sfx("sfx_absorb")


func _on_quit_practice_pressed() -> void:
	if _battle_mode != BattleState.Mode.PRACTICE:
		return
	if state.phase == BattleState.Phase.ENDED:
		return
	_finish(true)


func _on_continue_pressed() -> void:
	match overlay_mode:
		OVERLAY_PURIFY:
			debrief_index = 0
			_set_overlay(OVERLAY_DEBRIEF)
		OVERLAY_DEBRIEF:
			debrief_index += 1
			if debrief_index < BattleConfig.TEXT_DEBRIEF.size():
				_show_debrief_question()
			else:
				state.finish_debrief()
		OVERLAY_PRACTICE_END:
			_finish(true)
		_:
			_set_overlay(OVERLAY_NONE)


func _on_phase(phase: int) -> void:
	turn_timer_label.visible = phase == BattleState.Phase.PLAYER
	match phase:
		BattleState.Phase.PLAYER:
			_set_overlay(OVERLAY_NONE)
			turn_time_left = BattleConfig.TURN_TIME_LIMIT
			_update_timer_label()
			_turn_discard_gain = 0
			_update_discard_zone()
		BattleState.Phase.STRIP:
			_set_overlay(OVERLAY_STRIP)
			_play_sfx("sfx_strip")
		BattleState.Phase.DEBRIEF:
			_set_overlay(OVERLAY_PURIFY)
		BattleState.Phase.ENDED:
			if _battle_mode == BattleState.Mode.PRACTICE:
				_set_overlay(OVERLAY_PRACTICE_END)
			else:
				_set_overlay(OVERLAY_NONE)
				_finish(false)


func _finish(practice: bool) -> void:
	if _finished_reported:
		return
	_finished_reported = true
	battle_ended.emit(practice)


func _set_overlay(mode: String) -> void:
	overlay_mode = mode
	overlay.visible = mode != OVERLAY_NONE
	absorb_button.visible = mode == OVERLAY_STRIP
	continue_button.visible = mode == OVERLAY_PURIFY or mode == OVERLAY_DEBRIEF or mode == OVERLAY_PRACTICE_END
	continue_button.text = "返回练习站" if mode == OVERLAY_PRACTICE_END else "继续"
	discard_scroll.visible = mode == OVERLAY_DISCARD
	match mode:
		OVERLAY_STRIP:
			story_text.text = "\n".join(PackedStringArray(BattleConfig.TEXT_STRIP))
		OVERLAY_PURIFY:
			story_text.text = "\n".join(PackedStringArray(BattleConfig.TEXT_PURIFY))
		OVERLAY_DEBRIEF:
			_show_debrief_question()
		OVERLAY_PRACTICE_END:
			story_text.text = BattleConfig.TEXT_PRACTICE_END
		OVERLAY_DISCARD:
			_rebuild_discard_list()


func _show_debrief_question() -> void:
	story_text.text = BattleConfig.TEXT_DEBRIEF[debrief_index]


func _rebuild_discard_list() -> void:
	story_text.text = BattleConfig.TEXT_DISCARD % [BattleConfig.HAND_LIMIT, state.hand.size() - BattleConfig.HAND_LIMIT]
	for child in discard_box.get_children():
		child.hide()
		child.queue_free()
	for i in state.hand.size():
		var card: CardData = state.hand[i]
		var button := Button.new()
		button.text = "「%s」 Cost %d　%s" % [card.display_name, card.cost, card.text]
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_discard_pressed.bind(i))
		discard_box.add_child(button)


func _on_discard_pressed(index: int) -> void:
	state.discard_from_hand(index)


func _on_card_staged(_card: CardData) -> void:
	_play_sfx("sfx_stage")


func _on_card_recalled(_card: CardData) -> void:
	_play_sfx("sfx_recall")


func _on_card_played(card: CardData) -> void:
	var sfx := String(SFX_BY_CARD.get(card.id, ""))
	if sfx != "":
		_play_sfx(sfx)


func _on_card_discarded(_card: CardData) -> void:
	_play_sfx("sfx_discard")


# 音效文件缺失时静默跳过（音效资源走 Maker 管线后续生成）
func _play_sfx(sfx_name: String) -> void:
	if not _sfx_players.has(sfx_name):
		var stream := _load_sfx(sfx_name)
		if stream == null:
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		_sfx_players[sfx_name] = player
	(_sfx_players[sfx_name] as AudioStreamPlayer).play()


# 用 load_from_file 直读：Maker 产出的音频文件无需编辑器导入即可加载
func _load_sfx(sfx_name: String) -> AudioStream:
	for ext in SFX_EXTS:
		var path := SFX_DIR + sfx_name + ext
		if not FileAccess.file_exists(path):
			continue
		match ext:
			".wav":
				return AudioStreamWAV.load_from_file(path)
			".mp3":
				return AudioStreamMP3.load_from_file(path)
			".ogg":
				return AudioStreamOggVorbis.load_from_file(path)
	return null


func _update_timer_label() -> void:
	turn_timer_label.text = "剩余 %d 秒" % int(ceil(turn_time_left))
	if turn_time_left <= TIMER_WARN_SECONDS:
		turn_timer_label.add_theme_color_override("font_color", TIMER_WARN_COLOR)
	else:
		turn_timer_label.remove_theme_color_override("font_color")
