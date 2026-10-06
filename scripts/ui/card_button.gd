class_name CardButton
extends Button

const CARD_SIZE := Vector2(118, 171)
const FRAME_DIR := "res://assets/sprites/cards/"
const HOVER_SCALE := 1.12
const HOVER_TWEEN_TIME := 0.08
const HOVER_LIFT := 26.0

# 卡框四色：红攻／蓝防／黄功能（增幅并入功能，同用黄框）／紫罪卡
const COST_INK := Color(0.47, 0.27, 0.10)
const NAME_INK := Color(0.42, 0.26, 0.10)
const TEXT_INK := Color(0.30, 0.23, 0.20)
const HINT_INK := Color(0.42, 0.31, 0.18, 0.9)

static var _frame_cache: Dictionary = {}

var card: CardData = null
var drag_zone := ""  # "hand"（手牌）或 "play"（出牌区）；空串＝不可拖
var drag_index := -1
var fan_arranged := false  # 由 BattleScreen._layout_hand 置位：扇形手牌才做悬停抬升
var fan_base_position := Vector2.ZERO
var _scale_tween: Tween
var _frame_rect: TextureRect = null
var _highlight_panel: Panel = null


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
	if _frame_rect != null:
		_frame_rect.modulate = Color(1.06, 1.06, 1.06)
	_animate_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	z_index = 0
	if fan_arranged:
		position = fan_base_position
	if _frame_rect != null:
		_frame_rect.modulate = Color.WHITE
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


# 拖叠目标高亮：描金边框面板置顶（拖拽中悬停信号不触发，需外力设置）
func set_merge_highlight(on: bool) -> void:
	if _highlight_panel == null:
		return
	_highlight_panel.visible = on
	z_index = 1 if on else 0


func is_merge_highlighted() -> bool:
	return _highlight_panel != null and _highlight_panel.visible


func set_hint(text: String) -> void:
	var label := Label.new()
	label.name = "HintLabel"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", HINT_INK)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 16.0
	label.offset_top = 127.0
	label.offset_right = 102.0
	label.offset_bottom = 143.0
	add_child(label)


func setup(card_data: CardData) -> void:
	card = card_data
	tooltip_text = card.flavor
	custom_minimum_size = CARD_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child in get_children():
		child.queue_free()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build_frame()
	_build_cost_label()
	_build_name_label()
	_build_text_label()
	_build_highlight()
	# PASS：不拦截拖放（否则引擎的拖放遍历会在按钮处中断，永远问不到 BattleScreen）
	mouse_filter = Control.MOUSE_FILTER_PASS


func _build_frame() -> void:
	_frame_rect = TextureRect.new()
	_frame_rect.texture = _frame_texture(card.kind)
	_frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame_rect)


func _build_cost_label() -> void:
	var label := Label.new()
	label.name = "CostBadge"
	label.text = str(card.cost)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COST_INK)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 4.0
	label.offset_top = 7.0
	label.offset_right = 38.0
	label.offset_bottom = 37.0
	add_child(label)


func _build_name_label() -> void:
	var label := Label.new()
	label.name = "NameBanner"
	label.text = card.display_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 合成牌名可能很长（普通魔弹＋强力魔弹＋普通魔弹），字号随字数收缩
	label.add_theme_font_size_override("font_size", clampi(17 - card.display_name.length(), 10, 14))
	label.add_theme_color_override("font_color", NAME_INK)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 35.0
	label.offset_top = 14.0
	label.offset_right = 104.0
	label.offset_bottom = 30.0
	add_child(label)


func _build_text_label() -> void:
	var label := Label.new()
	label.name = "EffectText"
	label.text = card.text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", TEXT_INK)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 16.0
	label.offset_top = 29.0
	label.offset_right = 102.0
	label.offset_bottom = 118.0
	add_child(label)


func _build_highlight() -> void:
	_highlight_panel = Panel.new()
	_highlight_panel.name = "MergeHighlight"
	_highlight_panel.visible = false
	_highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(1.0, 0.87, 0.55, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	_highlight_panel.add_theme_stylebox_override("panel", style)
	add_child(_highlight_panel)


# 卡框 PNG 直读：Maker 产出的素材无需编辑器导入即可加载（与音频 load_from_file 同法）
static func _frame_texture(kind: int) -> Texture2D:
	var file_name := "frame_utility"
	match kind:
		CardData.Kind.ATTACK:
			file_name = "frame_attack"
		CardData.Kind.DEFENSE:
			file_name = "frame_defense"
		CardData.Kind.SIN:
			file_name = "frame_sin"
		CardData.Kind.CORE:
			file_name = "frame_sin"
	if _frame_cache.has(file_name):
		return _frame_cache[file_name] as Texture2D
	var texture: Texture2D = null
	var path := FRAME_DIR + file_name + ".png"
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_frame_cache[file_name] = texture
	return texture
