class_name CardButton
extends Button

var card: CardData = null


func setup(card_data: CardData) -> void:
	card = card_data
	text = "%s\n\n%s" % [card.display_name, card.text]
	tooltip_text = card.flavor
	custom_minimum_size = Vector2(196, 150)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 15)
