class_name PickPanel
extends EventGamePanel

# 择一（design-round10 §1.1）：道具牌一排；拖一张进「行动槽」（单槽，可再拖换）；「执行」结算。

const SLOT_SIZE := Vector2(146, 191)

var _cards: Array = []
var _props: Array[EventPropCard] = []
var _slot: PanelContainer
var _slot_label: Label
var _exec_button: Button
var _selected := -1


func build(gp: Dictionary) -> void:
	_cards = gp.get("cards", [])
	var shelf := HBoxContainer.new()
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_theme_constant_override("separation", 14)
	add_child(shelf)
	for i in _cards.size():
		var data: Dictionary = _cards[i]
		var prop := make_prop(String(data.get("name", "")), String(data.get("sub", "")))
		prop.prop_index = i
		shelf.add_child(prop)
		_props.append(prop)
	var lower := HBoxContainer.new()
	lower.alignment = BoxContainer.ALIGNMENT_CENTER
	lower.add_theme_constant_override("separation", 24)
	add_child(lower)
	_slot = make_slot(SLOT_SIZE)
	lower.add_child(_slot)
	_slot_label = make_centered_label(14, Color(0.6, 0.58, 0.72))
	_slot_label.text = "行动槽\n\n把一张牌拖到这里"
	_slot.add_child(_slot_label)
	_exec_button = Button.new()
	_exec_button.text = "执行"
	_exec_button.custom_minimum_size = Vector2(120, 48)
	_exec_button.disabled = true
	_exec_button.pressed.connect(_on_exec_pressed)
	lower.add_child(_exec_button)


func select(index: int) -> void:
	if is_committed() or index < 0 or index >= _props.size():
		return
	_selected = index
	_slot_label.text = String((_cards[index] as Dictionary).get("name", ""))
	for i in _props.size():
		_props[i].modulate = Color.WHITE if i == index else DISABLED_TINT
	_exec_button.disabled = false


func _on_exec_pressed() -> void:
	if is_committed() or _selected < 0:
		return
	var result := EventGames.resolve_pick(gameplay, _selected)
	if result.is_empty():
		return
	for i in _props.size():
		_props[i].draggable = false
		_props[i].modulate = Color.WHITE if i == _selected else Color(0.5, 0.5, 0.5)
	_exec_button.disabled = true
	var outcome: Dictionary = result.get("outcome", {})
	var lines: Array = [String(result.get("text", ""))]
	settle(outcome, lines)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_committed() or not is_prop_data(data):
		return false
	return point_in_control(at_position, _slot)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if is_committed() or not is_prop_data(data):
		return
	if not point_in_control(at_position, _slot):
		return
	select(int((data as Dictionary).get("index", -1)))
