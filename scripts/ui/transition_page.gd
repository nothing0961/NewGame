class_name TransitionPage
extends Control

# 上行过渡页（design/design-round3.md §3）：过渡插画底图＋读白区（同行层主对话）＋「继续」→ 层地图。
# 插画＝Maker 生成的通用「上行」意象（无文字）；文件缺失时静默回退纯色底。

signal continued()

const ILLUSTRATION_PATH := "res://assets/sprites/ui/transition_climb.png"

var _illustration: TextureRect
var _read_text: Label


func _ready() -> void:
	_build_static_ui()
	_apply_illustration()


func _build_static_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.07, 0.06, 0.1, 1.0)
	add_child(bg)
	_illustration = TextureRect.new()
	_illustration.set_anchors_preset(Control.PRESET_FULL_RECT)
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illustration.visible = false
	add_child(_illustration)
	var read_panel := PanelContainer.new()
	read_panel.anchor_left = 0.08
	read_panel.anchor_top = 1.0
	read_panel.anchor_right = 0.92
	read_panel.anchor_bottom = 1.0
	read_panel.offset_top = -320.0
	read_panel.offset_bottom = -140.0
	add_child(read_panel)
	var read_margin := MarginContainer.new()
	read_margin.add_theme_constant_override("margin_left", 24)
	read_margin.add_theme_constant_override("margin_top", 18)
	read_margin.add_theme_constant_override("margin_right", 24)
	read_margin.add_theme_constant_override("margin_bottom", 18)
	read_panel.add_child(read_margin)
	_read_text = Label.new()
	_read_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_read_text.add_theme_font_size_override("font_size", 20)
	read_margin.add_child(_read_text)
	var continue_button := Button.new()
	continue_button.text = "继续"
	continue_button.custom_minimum_size = Vector2(240, 52)
	continue_button.anchor_left = 0.5
	continue_button.anchor_top = 1.0
	continue_button.anchor_right = 0.5
	continue_button.anchor_bottom = 1.0
	continue_button.offset_left = -120.0
	continue_button.offset_top = -110.0
	continue_button.offset_right = 120.0
	continue_button.offset_bottom = -58.0
	continue_button.pressed.connect(func() -> void: continued.emit())
	add_child(continue_button)


func show_transition(lines: Array) -> void:
	_read_text.text = "\n\n".join(PackedStringArray(lines))


# 运行时资源直读（Maker 产图无需编辑器导入）；缺失静默回退纯色底
func _apply_illustration() -> void:
	if not FileAccess.file_exists(ILLUSTRATION_PATH):
		return
	var image := Image.load_from_file(ILLUSTRATION_PATH)
	if image == null:
		return
	_illustration.texture = ImageTexture.create_from_image(image)
	_illustration.visible = true
