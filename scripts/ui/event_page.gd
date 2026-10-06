class_name EventPage
extends Control

# 事件页＝容器（design/design-round3.md §4）：标题＋场景说明＋玩法区（宿主，可注入小玩法模块）＋完成按钮。
# 现为最小三选一交互（选一个→就地反馈→可完成）；选项附轻量效果（design-round8，由 main_flow 经 choice_chosen 结算）。

signal completed()
signal choice_chosen(index: int)

var _title: Label
var _scene: Label
var _choices_box: VBoxContainer
var _feedback: Label
var _complete_button: Button
var _chosen := -1


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
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	play_box.add_child(_choices_box)
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
	_complete_button.pressed.connect(func() -> void: completed.emit())
	vbox.add_child(_complete_button)


func show_event(stage: Dictionary) -> void:
	_title.text = String(stage.get("title", ""))
	_scene.text = String(stage.get("scene", ""))
	_chosen = -1
	_feedback.text = ""
	_complete_button.disabled = true
	for child in _choices_box.get_children():
		child.hide()
		child.queue_free()
	var choices: Array = stage.get("choices", [])
	var feedback: Array = stage.get("feedback", [])
	for i in choices.size():
		var button := Button.new()
		button.text = "· %s" % String(choices[i])
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_choice.bind(i, feedback))
		_choices_box.add_child(button)


func _on_choice(index: int, feedback: Array) -> void:
	if _chosen >= 0:
		return  # 三选一，只能选一次
	_chosen = index
	if index < feedback.size():
		_feedback.text = String(feedback[index])
	_complete_button.disabled = false
	for child in _choices_box.get_children():
		if child is Button:
			child.disabled = true
	choice_chosen.emit(index)
