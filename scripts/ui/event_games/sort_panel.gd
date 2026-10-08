class_name SortPanel
extends EventGamePanel

# 分拣（design-round10 §1.2）：全部拖进两筐之一（可选单侧容量上限，拖超被拒）；放完才能「收好」。
# 卡不进筐内叠放（大牌叠放会溢出）——落筐＝卡面染色＋筐内名单；再拖可换筐，拖回架上取消。

const BASKET_SIZE := Vector2(240, 150)
const TINT_LEFT := Color(0.74, 0.84, 1.0)
const TINT_RIGHT := Color(1.0, 0.85, 0.7)

var _cards: Array = []
var _props: Array[EventPropCard] = []
var _sides: Array = []  # 与 cards 下标对齐；""＝未放 / "left" / "right"
var _shelf: HBoxContainer
var _left_slot: PanelContainer
var _right_slot: PanelContainer
var _left_label: Label
var _right_label: Label
var _done_button: Button
var _capacity := 0
var _capacity_side := ""


func build(gp: Dictionary) -> void:
	_cards = gp.get("cards", [])
	_capacity = int(gp.get("capacity", 0))
	_capacity_side = String(gp.get("capacity_side", ""))
	for i in _cards.size():
		_sides.append("")
	_shelf = HBoxContainer.new()
	_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf.add_theme_constant_override("separation", 14)
	add_child(_shelf)
	for i in _cards.size():
		var data: Dictionary = _cards[i]
		var prop := make_prop(String(data.get("name", "")), String(data.get("sub", "")))
		prop.prop_index = i
		_shelf.add_child(prop)
		_props.append(prop)
	var baskets := HBoxContainer.new()
	baskets.alignment = BoxContainer.ALIGNMENT_CENTER
	baskets.add_theme_constant_override("separation", 32)
	add_child(baskets)
	_left_slot = make_slot(BASKET_SIZE)
	baskets.add_child(_left_slot)
	_left_label = make_centered_label(14)
	_left_slot.add_child(_left_label)
	_right_slot = make_slot(BASKET_SIZE)
	baskets.add_child(_right_slot)
	_right_label = make_centered_label(14)
	_right_slot.add_child(_right_label)
	_done_button = Button.new()
	_done_button.text = "收好"
	_done_button.custom_minimum_size = Vector2(140, 44)
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.disabled = true
	_done_button.pressed.connect(_on_done_pressed)
	add_child(_done_button)
	_refresh()


func side_of(index: int) -> String:
	if index < 0 or index >= _sides.size():
		return ""
	return String(_sides[index])


func _side_count(side: String, exclude := -1) -> int:
	var count := 0
	for i in _sides.size():
		if i != exclude and String(_sides[i]) == side:
			count += 1
	return count


func _can_accept(index: int, side: String) -> bool:
	if _capacity <= 0 or _capacity_side != side:
		return true
	return _side_count(side, index) < _capacity


func _assign(index: int, side: String) -> void:
	if not _can_accept(index, side):
		return
	_sides[index] = side
	_props[index].modulate = TINT_LEFT if side == "left" else TINT_RIGHT
	_refresh()


func _clear_side(index: int) -> void:
	_sides[index] = ""
	_props[index].modulate = Color.WHITE
	_refresh()


func _basket_text(side: String) -> String:
	var title := String(gameplay.get("%s_label" % side, ""))
	if _capacity > 0 and _capacity_side == side:
		title += "（至多 %d 张）" % _capacity
	var names := PackedStringArray()
	for i in _cards.size():
		if String(_sides[i]) == side:
			names.append(String((_cards[i] as Dictionary).get("name", "")))
	if names.is_empty():
		return "%s\n\n（还没放东西）" % title
	return "%s\n\n%s" % [title, "、".join(names)]


func _refresh() -> void:
	_left_label.text = _basket_text("left")
	_right_label.text = _basket_text("right")
	var all_placed := true
	for side in _sides:
		if String(side) == "":
			all_placed = false
			break
	_done_button.disabled = not all_placed or is_committed()


func _on_done_pressed() -> void:
	if is_committed():
		return
	var sides := _sides.duplicate()
	for side in sides:
		if String(side) == "":
			return
	var result := EventGames.resolve_sort(gameplay, sides)
	if result.is_empty():
		return
	for prop in _props:
		prop.draggable = false
	_done_button.disabled = true
	var outcome: Dictionary = result.get("outcome", {})
	var lines: Array = [String(result.get("text", ""))]
	settle(outcome, lines)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_committed() or not is_prop_data(data):
		return false
	var index := int((data as Dictionary).get("index", -1))
	if index < 0 or index >= _cards.size():
		return false
	if point_in_control(at_position, _left_slot):
		return _can_accept(index, "left")
	if point_in_control(at_position, _right_slot):
		return _can_accept(index, "right")
	return point_in_control(at_position, _shelf)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if is_committed() or not is_prop_data(data):
		return
	var index := int((data as Dictionary).get("index", -1))
	if index < 0 or index >= _cards.size():
		return
	if point_in_control(at_position, _left_slot):
		_assign(index, "left")
	elif point_in_control(at_position, _right_slot):
		_assign(index, "right")
	elif point_in_control(at_position, _shelf):
		_clear_side(index)
