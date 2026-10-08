class_name BalancePanel
extends EventGamePanel

# 配平（design-round10 §1.3）：带数字道具牌拖上秤盘凑目标值（可拖回）；「称量」结算。
# 数字＝weight，直接占 cost 角标位显示；落盘＝卡面染色＋盘内清单＋实时差值。

const PAN_SIZE := Vector2(460, 120)
const TINT_PAN := Color(0.78, 0.95, 0.8)

var _cards: Array = []
var _props: Array[EventPropCard] = []
var _on_pan: Array = []  # 盘上卡下标（有序＝放牌顺序）
var _shelf: HBoxContainer
var _pan: PanelContainer
var _pan_label: Label
var _weigh_button: Button
var _target := 0


func build(gp: Dictionary) -> void:
	_cards = gp.get("cards", [])
	_target = int(gp.get("target", 0))
	_shelf = HBoxContainer.new()
	_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf.add_theme_constant_override("separation", 14)
	add_child(_shelf)
	for i in _cards.size():
		var data: Dictionary = _cards[i]
		var prop := make_prop(String(data.get("name", "")), String(data.get("sub", "")), "", int(data.get("weight", 0)))
		prop.prop_index = i
		_shelf.add_child(prop)
		_props.append(prop)
	_pan = make_slot(PAN_SIZE)
	add_child(_pan)
	_pan_label = make_centered_label(15)
	_pan.add_child(_pan_label)
	_weigh_button = Button.new()
	_weigh_button.text = "称量"
	_weigh_button.custom_minimum_size = Vector2(140, 44)
	_weigh_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weigh_button.disabled = true
	_weigh_button.pressed.connect(_on_weigh_pressed)
	add_child(_weigh_button)
	_refresh()


func pan_indices() -> Array:
	return _on_pan.duplicate()


func _place(index: int) -> void:
	if _on_pan.has(index):
		return
	_on_pan.append(index)
	_props[index].modulate = TINT_PAN
	_refresh()


func _remove(index: int) -> void:
	if not _on_pan.has(index):
		return
	_on_pan.erase(index)
	_props[index].modulate = Color.WHITE
	_refresh()


func _refresh() -> void:
	var sum := EventGames.balance_sum(gameplay, _on_pan)
	var names := PackedStringArray()
	for index in _on_pan:
		var data: Dictionary = _cards[index]
		names.append("%s %d" % [String(data.get("name", "")), int(data.get("weight", 0))])
	var body := "秤盘空着——把牌拖上来" if names.is_empty() else "秤盘：" + "、".join(names)
	_pan_label.text = "%s\n合计 %d · 目标 %d · 差 %d" % [body, sum, _target, absi(sum - _target)]
	_weigh_button.disabled = _on_pan.is_empty() or is_committed()


func _on_weigh_pressed() -> void:
	if is_committed() or _on_pan.is_empty():
		return
	var result := EventGames.resolve_balance(gameplay, _on_pan)
	if result.is_empty():
		return
	for prop in _props:
		prop.draggable = false
	_weigh_button.disabled = true
	var outcome: Dictionary = result.get("outcome", {})
	var lines: Array = [String(gameplay.get("settle", "")), String(result.get("text", ""))]
	settle(outcome, lines)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_committed() or not is_prop_data(data):
		return false
	if point_in_control(at_position, _pan):
		return true
	return point_in_control(at_position, _shelf)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if is_committed() or not is_prop_data(data):
		return
	var index := int((data as Dictionary).get("index", -1))
	if index < 0 or index >= _cards.size():
		return
	if point_in_control(at_position, _pan):
		_place(index)
	elif point_in_control(at_position, _shelf):
		_remove(index)
