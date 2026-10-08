class_name EventGamePanel
extends VBoxContainer

# 事件小玩法控件基类（design/design-round10.md §5）：UI 只做交互与呈现，结算走 EventGames 纯函数。
# 拖放＝面板级 _can_drop_data/_drop_data ＋子控件矩形命中（与 battle_screen 同式，测试可直接调）。

signal settled(outcome: Dictionary, lines: PackedStringArray)

const HINT_COLOR := Color(0.78, 0.72, 0.62)
const SLOT_BG := Color(0.1, 0.095, 0.14, 0.55)
const SLOT_BORDER := Color(0.34, 0.32, 0.46, 0.7)
const DISABLED_TINT := Color(0.62, 0.62, 0.62)

var gameplay: Dictionary = {}
var hint_label: Label = null
var _committed := false


static func create_panel(gp: Dictionary) -> EventGamePanel:
	match String(gp.get("module", "")):
		EventGames.MODULE_PICK:
			return PickPanel.new()
		EventGames.MODULE_SORT:
			return SortPanel.new()
		EventGames.MODULE_BALANCE:
			return BalancePanel.new()
		EventGames.MODULE_REVEAL:
			return RevealPanel.new()
	return EventGamePanel.new()


func setup(gp: Dictionary) -> void:
	gameplay = gp
	add_theme_constant_override("separation", 10)
	var hint := String(gp.get("hint", ""))
	if hint != "":
		hint_label = Label.new()
		hint_label.text = hint
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.add_theme_color_override("font_color", HINT_COLOR)
		add_child(hint_label)
	build(gp)


# 子类实现：搭交互控件（此时 gameplay 已就位）
func build(_gp: Dictionary) -> void:
	pass


# 子类结算入口；结果行（含空结果读白）由本函数统一补在读白之后
func settle(outcome: Dictionary, lines: Array) -> void:
	if _committed:
		return
	_committed = true
	var out_lines := PackedStringArray()
	for line in lines:
		var text := String(line)
		if text != "":
			out_lines.append(text)
	out_lines.append(EventGames.outcome_line(outcome))
	settled.emit(outcome, out_lines)


func is_committed() -> bool:
	return _committed


# 道具牌合成：name＝名条；sub＝卡面正文（动作/描述行）；badge ≥ 0 时角标显示数字（balance 权重）
func make_prop(name: String, sub: String, tooltip := "", badge := -1) -> EventPropCard:
	var card := CardData.new()
	card.id = "event_prop"
	card.display_name = name
	card.kind = CardData.Kind.UTILITY
	card.cost = badge
	card.text = sub
	card.flavor = tooltip if tooltip != "" else sub
	var prop := EventPropCard.new()
	prop.setup(card)
	return prop


func make_slot(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	# 穿透投放：PanelContainer 默认 STOP，引擎沿父链问 _can_drop_data 的走链会在此断掉
	# （与弃牌区/日志区同型修复）；落点判定由面板级 _can_drop_data 负责
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = SLOT_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func make_centered_label(font_size := 14, color := Color(0.85, 0.82, 0.9)) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# 拖放命中：面板本地坐标 → 全局坐标点是否落在某控件矩形内（battle_screen._drop_target_at 同式）
func point_in_control(at_position: Vector2, control: Control) -> bool:
	var global_point := get_global_transform() * at_position
	return control.get_global_rect().has_point(global_point)


static func is_prop_data(data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and bool((data as Dictionary).get("event_prop", false))
