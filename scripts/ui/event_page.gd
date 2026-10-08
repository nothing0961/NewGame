class_name EventPage
extends Control

# 事件页＝容器（design/design-round3.md §4）：标题＋场景说明＋玩法区（宿主，注入小玩法模块）＋完成按钮。
# 玩法＝四模块拖拽小游戏（design-round10.md）：交互在 event_games/，结算走 EventGames 纯函数；
# game_resolved 携带 outcome 交 main_flow 落账（完成按钮先发 game_resolved 再发 completed）。

signal completed()
signal game_resolved(outcome: Dictionary)

var _title: Label
var _scene: Label
var _play_box: VBoxContainer
var _feedback: Label
var _complete_button: Button
var _panel: EventGamePanel = null
var _pending_outcome: Dictionary = {}


func _ready() -> void:
	_build_static_ui()


func _build_static_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 160)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 160)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(760, 0)
	center.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title)
	_scene = Label.new()
	_scene.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scene.add_theme_font_size_override("font_size", 18)
	_scene.add_theme_constant_override("line_spacing", 8)
	vbox.add_child(_scene)
	var play_panel := PanelContainer.new()
	vbox.add_child(play_panel)
	var play_margin := MarginContainer.new()
	play_margin.add_theme_constant_override("margin_left", 20)
	play_margin.add_theme_constant_override("margin_top", 16)
	play_margin.add_theme_constant_override("margin_right", 20)
	play_margin.add_theme_constant_override("margin_bottom", 16)
	play_panel.add_child(play_margin)
	var play_box := VBoxContainer.new()
	play_box.add_theme_constant_override("separation", 10)
	play_margin.add_child(play_box)
	_play_box = VBoxContainer.new()
	_play_box.add_theme_constant_override("separation", 8)
	play_box.add_child(_play_box)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 16)
	_feedback.add_theme_constant_override("line_spacing", 6)
	play_box.add_child(_feedback)
	_complete_button = Button.new()
	_complete_button.text = "完成"
	_complete_button.custom_minimum_size = Vector2(240, 48)
	_complete_button.disabled = true
	_complete_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_complete_button.pressed.connect(_on_complete_pressed)
	vbox.add_child(_complete_button)


func show_event(stage: Dictionary) -> void:
	_title.text = String(stage.get("title", ""))
	_scene.text = String(stage.get("scene", ""))
	_feedback.text = ""
	_complete_button.disabled = true
	_pending_outcome = {}
	if _panel != null and is_instance_valid(_panel):
		_panel.hide()
		_panel.queue_free()
	_panel = null
	var gp: Dictionary = stage.get("gameplay", {})
	if gp.is_empty():
		_feedback.text = "（事件内容缺失）"
		_complete_button.disabled = false
		return
	_panel = EventGamePanel.create_panel(gp)
	_play_box.add_child(_panel)
	_panel.settled.connect(_on_game_settled)
	_panel.setup(gp)


func _on_game_settled(outcome: Dictionary, lines: PackedStringArray) -> void:
	_pending_outcome = outcome
	_feedback.text = "\n".join(lines)
	_complete_button.disabled = false


func _on_complete_pressed() -> void:
	_complete_button.disabled = true
	game_resolved.emit(_pending_outcome)
	completed.emit()
