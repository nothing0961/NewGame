class_name RevealPanel
extends EventGamePanel

# 揭示（design-round10 §1.4）：3–5 张背面牌一排；拖出一张（松手于任意处）→翻面并立即结算该张；
# 「收手」随时停；变体 reveal+finish：全翻完追加奖励并自动结算。逐卡 text 按翻序显示。

var _cards: Array = []
var _props: Array[EventPropCard] = []
var _flipped: Array = []  # 已翻卡下标（翻序）
var _total_outcome := {}
var _lines: Array = []
var _log_label: Label
var _stop_button: Button
var _finish: Dictionary = {}


func build(gp: Dictionary) -> void:
	_cards = gp.get("cards", [])
	var finish_raw: Variant = gp.get("finish")
	if finish_raw is Dictionary:
		_finish = finish_raw
	var shelf := HBoxContainer.new()
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_theme_constant_override("separation", 14)
	add_child(shelf)
	for i in _cards.size():
		var data: Dictionary = _cards[i]
		var prop := make_prop(String(data.get("name", "")), String(data.get("sub", "")))
		prop.prop_index = i
		prop.set_face_down(true)
		prop.on_drag_ended = _on_prop_drag_ended
		shelf.add_child(prop)
		_props.append(prop)
	_log_label = make_centered_label(15)
	_log_label.custom_minimum_size = Vector2(0, 52)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_log_label)
	_stop_button = Button.new()
	_stop_button.text = String(gp.get("stop_label", "收手"))
	_stop_button.custom_minimum_size = Vector2(140, 44)
	_stop_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stop_button.pressed.connect(_on_stop_pressed)
	add_child(_stop_button)
	_update_log()


func flipped_indices() -> Array:
	return _flipped.duplicate()


# 真实拖拽松手回调（任意落点）；与 _drop_data 直调路径合流，重复翻同一张会被幂等挡下
func _on_prop_drag_ended(index: int) -> void:
	if is_committed():
		return
	flip(index)


func flip(index: int) -> void:
	if is_committed() or index < 0 or index >= _cards.size():
		return
	if _flipped.has(index):
		return
	_flipped.append(index)
	var prop := _props[index]
	prop.set_face_down(false)
	prop.draggable = false
	var data: Dictionary = _cards[index]
	_total_outcome = EventGames.add_outcome(_total_outcome, EventGames.normalize_outcome(data.get("outcome", {})))
	var text := String(data.get("text", ""))
	if text != "":
		_lines.append(text)
	_update_log()
	if _flipped.size() >= _cards.size() and not _finish.is_empty():
		var bonus := EventGames.resolve_reveal_finish(gameplay)
		if not bonus.is_empty():
			_total_outcome = EventGames.add_outcome(_total_outcome, bonus.get("outcome", {}))
			var bonus_text := String(bonus.get("text", ""))
			if bonus_text != "":
				_lines.append(bonus_text)
		_settle_now()


func _on_stop_pressed() -> void:
	_settle_now()


func _settle_now() -> void:
	if is_committed():
		return
	for prop in _props:
		prop.draggable = false
	_stop_button.disabled = true
	settle(_total_outcome, _lines.duplicate())


func _update_log() -> void:
	if _lines.is_empty():
		_log_label.text = "背面朝上——拖走一张就翻开它。"
	else:
		_log_label.text = "翻开了 %d 张：\n%s" % [_flipped.size(), "\n".join(PackedStringArray(_lines))]


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_committed() or not is_prop_data(data):
		return false
	# 揭示没有落点概念：拖完松手即翻（真实拖拽走 on_drag_ended；此处供直接调用路径）
	return get_global_rect().has_point(get_global_transform() * at_position)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if is_committed() or not is_prop_data(data):
		return
	if not _can_drop_data(at_position, data):
		return
	flip(int((data as Dictionary).get("index", -1)))
