extends Control

signal start_practice_requested()
signal leave_requested()

@onready var warehouse_list: VBoxContainer = %WarehouseList
@onready var deck_list: VBoxContainer = %DeckList
@onready var deck_count_label: Label = %DeckCountLabel
@onready var deck_hint: Label = %DeckHint
@onready var start_practice_button: Button = %StartPracticeButton
@onready var leave_practice_button: Button = %LeavePracticeButton

var pool: CardPool


func setup(card_pool: CardPool) -> void:
	pool = card_pool
	rebuild()


func _ready() -> void:
	start_practice_button.pressed.connect(_on_start_pressed)
	leave_practice_button.pressed.connect(_on_leave_pressed)


func rebuild() -> void:
	if pool == null:
		return
	for child in warehouse_list.get_children():
		child.hide()
		child.queue_free()
	for child in deck_list.get_children():
		child.hide()
		child.queue_free()
	for card_id in BattleConfig.WAREHOUSE_INITIAL:
		warehouse_list.add_child(_make_warehouse_button(String(card_id)))
	for card_id in pool.deck:
		deck_list.add_child(_make_deck_button(String(card_id)))
	deck_count_label.text = "卡组 %d / %d" % [pool.deck.size(), BattleConfig.DECK_SIZE]
	start_practice_button.disabled = not pool.is_deck_valid()
	deck_hint.text = _hint_text()


func _make_warehouse_button(card_id: String) -> Button:
	var card := CardDB.get_card(card_id)
	var button := Button.new()
	button.text = "【%s】「%s」 Cost %d　仓库 ×%d　已入卡组 %d\n%s" % [card.kind_label(), card.display_name, card.cost, pool.owned_count(card_id), pool.deck_count(card_id), card.text]
	button.disabled = not pool.can_add(card_id)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_warehouse_card_pressed.bind(card_id))
	return button


func _make_deck_button(card_id: String) -> Button:
	var card := CardDB.get_card(card_id)
	var button := Button.new()
	button.text = "【%s】「%s」 Cost %d　（点击移出）\n%s" % [card.kind_label(), card.display_name, card.cost, card.text]
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_deck_card_pressed.bind(card_id))
	return button


func _on_warehouse_card_pressed(card_id: String) -> void:
	if pool.add_to_deck(card_id):
		rebuild()


func _on_deck_card_pressed(card_id: String) -> void:
	if pool.remove_from_deck(card_id):
		rebuild()


func _on_start_pressed() -> void:
	if pool.is_deck_valid():
		start_practice_requested.emit()


func _on_leave_pressed() -> void:
	leave_requested.emit()


func _hint_text() -> String:
	if pool.deck.size() < BattleConfig.DECK_SIZE:
		return "还差 %d 张——点击左边仓库里的牌加入卡组。" % (BattleConfig.DECK_SIZE - pool.deck.size())
	if not pool.is_deck_valid():
		return "卡组里至少要有一张能打伤害的牌（比如「打击」）。"
	return "卡组就绪，可以开打了。"
