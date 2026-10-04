class_name CardButton
extends Button

const HOVER_SCALE := 1.12
const HOVER_TWEEN_TIME := 0.08
const HOVER_LIFT := 26.0

var card: CardData = null
var drag_zone := ""  # "hand"（手牌）或 "play"（出牌区）；空串＝不可拖
var drag_index := -1
var fan_arranged := false  # 由 BattleScreen._layout_hand 置位：扇形手牌才做悬停抬升
var fan_base_position := Vector2.ZERO
var _scale_tween: Tween
var _base_normal_style: StyleBoxFlat


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func _on_mouse_entered() -> void:
	if disabled:
		return
	z_index = 1
	if fan_arranged:
		position.y = fan_base_position.y - HOVER_LIFT
	_animate_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	z_index = 0
	if fan_arranged:
		position = fan_base_position
	_animate_scale(1.0)


func _animate_scale(target: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(target, target), HOVER_TWEEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or drag_zone == "" or card == null:
		return null
	# 拖拽预览只在真实拖拽中设置（该引擎调用也可能被测试等外部直接触发）
	if get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = card.display_name
		preview.add_theme_font_size_override("font_size", 18)
		set_drag_preview(preview)
	return {"zone": drag_zone, "index": drag_index, "card_id": card.id}


# 拖叠目标高亮：正常态描金边框＋置顶（拖拽中悬停信号不触发，需外力设置）
func set_merge_highlight(on: bool) -> void:
	if _base_normal_style == null:
		return
	if on:
		var highlighted: StyleBoxFlat = _base_normal_style.duplicate()
		highlighted.border_color = Color(1.0, 0.87, 0.55)
		highlighted.set_border_width_all(2)
		add_theme_stylebox_override("normal", highlighted)
		z_index = 1
	else:
		add_theme_stylebox_override("normal", _base_normal_style)
		z_index = 0


func _make_style(bg: Color, border: Color, corner := 6, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(8)
	return style


func sin_style(bg: Color, border: Color) -> StyleBoxFlat:
	return _make_style(bg, border, 12, 2)


func setup(card_data: CardData) -> void:
	card = card_data
	text = "%s\n%s" % [card.display_name, card.text]
	tooltip_text = card.flavor
	custom_minimum_size = Vector2(118, 142)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 13)
	if card.kind == CardData.Kind.SIN:
		var frame := Color(0.46, 0.21, 0.16)
		add_theme_stylebox_override("normal", sin_style(Color(0.21, 0.12, 0.11), frame))
		add_theme_stylebox_override("hover", sin_style(Color(0.27, 0.15, 0.13), frame.lightened(0.2)))
		add_theme_stylebox_override("pressed", sin_style(Color(0.18, 0.1, 0.09), frame.darkened(0.2)))
		add_theme_stylebox_override("disabled", sin_style(Color(0.14, 0.1, 0.1), Color(0.3, 0.17, 0.14)))
	elif card.kind == CardData.Kind.AMPLIFY:
		var amp_frame := Color(0.22, 0.5, 0.47)
		add_theme_stylebox_override("normal", _make_style(Color(0.1, 0.19, 0.19), amp_frame))
		add_theme_stylebox_override("hover", _make_style(Color(0.13, 0.25, 0.24), amp_frame.lightened(0.2)))
		add_theme_stylebox_override("pressed", _make_style(Color(0.08, 0.16, 0.15), amp_frame.darkened(0.2)))
		add_theme_stylebox_override("disabled", _make_style(Color(0.09, 0.14, 0.14), Color(0.22, 0.33, 0.32)))
	else:
		add_theme_stylebox_override("normal", _make_style(Color(0.17, 0.16, 0.22), Color(0.4, 0.37, 0.52)))
		add_theme_stylebox_override("hover", _make_style(Color(0.22, 0.2, 0.29), Color(0.55, 0.5, 0.72)))
		add_theme_stylebox_override("pressed", _make_style(Color(0.14, 0.13, 0.19), Color(0.45, 0.4, 0.6)))
		add_theme_stylebox_override("disabled", _make_style(Color(0.12, 0.115, 0.16), Color(0.25, 0.24, 0.32)))
	_base_normal_style = get_theme_stylebox("normal") as StyleBoxFlat
	add_theme_color_override("font_color", Color(0.9, 0.89, 0.94))
	add_theme_color_override("font_disabled_color", Color(0.55, 0.54, 0.6))
	# PASS：不拦截拖放（否则引擎的拖放遍历会在按钮处中断，永远问不到 BattleScreen）
	mouse_filter = Control.MOUSE_FILTER_PASS
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = str(card.cost)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	cost_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cost_label.offset_left = 6.0
	cost_label.offset_top = 2.0
	cost_label.offset_right = 40.0
	cost_label.offset_bottom = 28.0
	add_child(cost_label)
