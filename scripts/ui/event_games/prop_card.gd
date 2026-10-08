class_name EventPropCard
extends CardButton

# 事件道具牌（design/design-round10.md §1）：卡框视觉复用 CardButton，运行时合成、不入卡池/仓库/存档。
# 拖拽载荷＝事件模块自定义字典 {"event_prop","index"}；cost<0 无费用角标（CardButton 收紧）；
# balance 的 weight 直接放在角标位显示数字；reveal 背面藏字面盖「？」。

const BACK_MARK_TEXT := "？"

var prop_index := -1
var draggable := true
var on_drag_ended: Callable = Callable()
var _drag_active := false
var _back_mark: Label = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or card == null:
		return null
	# 与 CardButton 同式：预览只在真实拖拽中设置（该方法可被测试等外部直接调用）
	if get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = card.display_name
		preview.add_theme_font_size_override("font_size", 18)
		set_drag_preview(preview)
	return {"event_prop": true, "index": prop_index}


# 认领自己的拖拽：DRAG_BEGIN 广播比对载荷（不依赖 gui_is_dragging 时序）；
# DRAG_END 广播到所有节点，_drag_active 置位者即被拖过的本牌（reveal「拖出即翻」用）
func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY:
			var info := data as Dictionary
			if bool(info.get("event_prop", false)) and int(info.get("index", -1)) == prop_index:
				_drag_active = true
	elif what == NOTIFICATION_DRAG_END:
		if _drag_active:
			_drag_active = false
			if on_drag_ended.is_valid():
				on_drag_ended.call(prop_index)


# 背面：藏三行字面、盖上「？」（reveal 翻面前）
func set_face_down(on: bool) -> void:
	if _back_mark == null:
		_back_mark = Label.new()
		_back_mark.name = "BackMark"
		_back_mark.text = BACK_MARK_TEXT
		_back_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_back_mark.add_theme_font_size_override("font_size", 46)
		_back_mark.add_theme_color_override("font_color", Color(0.55, 0.47, 0.38))
		_back_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_back_mark)
	_back_mark.visible = on
	for child_name in ["CostBadge", "NameBanner", "EffectText"]:
		var child := get_node_or_null(NodePath(child_name))
		if child != null:
			(child as CanvasItem).visible = not on
