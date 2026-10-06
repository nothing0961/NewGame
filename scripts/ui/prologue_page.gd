class_name ProloguePage
extends Control

# 初幕演出页（design-round6）：按 PrologueData.BEATS 逐拍推进；纯代码构建，
# 底图/立绘运行时直读（Maker 产图无需编辑器导入），文件缺失静默回退纯色底。

signal finished()

const PORTRAIT_WIDTH := 420.0
const SPEAKER_COLOR := Color(1.0, 0.87, 0.55, 1.0)

var _bg_fallback: ColorRect
var _bg_rect: TextureRect
var _portrait: TextureRect
var _speaker_label: Label
var _text_label: Label
var _continue_button: Button
var _beat_index := 0
var _texture_cache := {}


func _ready() -> void:
	_build_static_ui()


# 从头开始演出（main_flow 每次进入初幕调用）
func start() -> void:
	_beat_index = 0
	_refresh()


func _build_static_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_fallback = ColorRect.new()
	_bg_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_fallback.color = Color(0.07, 0.06, 0.1, 1.0)
	add_child(_bg_fallback)
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.visible = false
	add_child(_bg_rect)
	_portrait = TextureRect.new()
	_portrait.anchor_left = 0.0
	_portrait.anchor_top = 1.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = 40.0
	_portrait.offset_top = -640.0
	_portrait.offset_right = 40.0 + PORTRAIT_WIDTH
	_portrait.offset_bottom = -180.0
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	add_child(_portrait)
	var text_panel := PanelContainer.new()
	text_panel.anchor_left = 0.08
	text_panel.anchor_top = 1.0
	text_panel.anchor_right = 0.92
	text_panel.anchor_bottom = 1.0
	text_panel.offset_top = -340.0
	text_panel.offset_bottom = -140.0
	add_child(text_panel)
	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 24)
	text_margin.add_theme_constant_override("margin_top", 16)
	text_margin.add_theme_constant_override("margin_right", 24)
	text_margin.add_theme_constant_override("margin_bottom", 16)
	text_panel.add_child(text_margin)
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 8)
	text_margin.add_child(text_vbox)
	_speaker_label = Label.new()
	_speaker_label.visible = false
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
	text_vbox.add_child(_speaker_label)
	var text_scroll := ScrollContainer.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_vbox.add_child(text_scroll)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 19)
	_text_label.add_theme_constant_override("line_spacing", 8)
	text_scroll.add_child(_text_label)
	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(240, 52)
	_continue_button.anchor_left = 0.5
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_right = 0.5
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_left = -120.0
	_continue_button.offset_top = -110.0
	_continue_button.offset_right = 120.0
	_continue_button.offset_bottom = -58.0
	_continue_button.pressed.connect(_on_continue_pressed)
	add_child(_continue_button)


func _on_continue_pressed() -> void:
	_beat_index += 1
	if _beat_index >= PrologueData.BEATS.size():
		finished.emit()
	else:
		_refresh()


func _refresh() -> void:
	var beat: Dictionary = PrologueData.BEATS[_beat_index]
	_bg_fallback.color = beat.get("bg_color", Color(0.07, 0.06, 0.1, 1.0))
	_apply_texture(_bg_rect, String(beat.get("bg", "")))
	_apply_texture(_portrait, String(beat.get("portrait", "")))
	var speaker := String(beat.get("speaker", ""))
	_speaker_label.visible = speaker != ""
	_speaker_label.text = speaker
	_text_label.text = String(beat.get("text", ""))
	_continue_button.text = String(beat.get("button_label", "继续"))


# 运行时资源直读（Maker 产图无需编辑器导入，与音频 load_from_file 同法）；缺失静默隐藏
func _apply_texture(rect: TextureRect, file_name: String) -> void:
	if file_name == "":
		rect.texture = null
		rect.visible = false
		return
	var path := PrologueData.BG_DIR + file_name + ".png"
	if not _texture_cache.has(path):
		var texture: Texture2D = null
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
		_texture_cache[path] = texture
	var cached := _texture_cache[path] as Texture2D
	rect.texture = cached
	rect.visible = cached != null
