class_name MapPage
extends Control

# 层地图页（design/design-round3.md §2；层内路线图见 design/design-round4.md）：
# 八层竖向（第 8 层顶、第 1 层底），四态——已过层点亮「已净化」；当前层高亮并展开
# 分支路线图（横向列，列内节点竖排；节点四态：✓已走／✕错失／当前可选／未到置灰）；
# 未解锁层暗色锁定（有内容＝「未解锁」，无内容＝「待续」＝本段内容边界）。
# 实现形态：程序化绘制（正式美术属美术轮）。

signal node_requested(index: int)
signal practice_requested()
signal menu_requested()

const COLOR_CLEARED := Color(0.96, 0.86, 0.62)
const COLOR_CURRENT := Color(1.0, 0.93, 0.72)
const COLOR_LOCKED := Color(0.5, 0.49, 0.58)

const ROUTE_HINT := "每列选一个节点前进"
# 长线（随层拉长）溢出可视区时的提示（design-round4.md §4）
const ROUTE_HINT_SCROLL := "每列选一个节点前进　（可左右拖动查看全图）"

var _list: VBoxContainer
var _toast: Label
var _route_hint: Label


func _ready() -> void:
	_build_static_ui()


func _build_static_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "层地图"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	var practice_button := Button.new()
	practice_button.text = "进入练习站"
	practice_button.custom_minimum_size = Vector2(180, 44)
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	buttons.add_child(practice_button)
	var menu_button := Button.new()
	menu_button.text = "返回主菜单"
	menu_button.custom_minimum_size = Vector2(180, 44)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(menu_button)
	vbox.add_child(buttons)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.visible = false
	vbox.add_child(_toast)


func build(run_state: RunState) -> void:
	for child in _list.get_children():
		child.hide()
		child.queue_free()
	_toast.visible = false
	for layer in range(LayerConfig.MAX_LAYER, 0, -1):
		_list.add_child(_make_layer_row(layer, run_state))
		if layer == run_state.current_layer and run_state.is_layer_unlocked(layer):
			_list.add_child(_make_route_section(run_state))


# 层行四态：已净化／当前／未解锁（有内容、前面未走完）/ 待续（无内容＝本段内容边界）
func _make_layer_row(layer: int, run_state: RunState) -> Control:
	var cleared := run_state.is_layer_cleared(layer)
	var current := layer == run_state.current_layer and run_state.is_layer_unlocked(layer)
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 18)
	var line := "第 %d 层·%s　%s" % [layer, LayerConfig.layer_name(layer), LayerConfig.demon_name(layer)]
	button.disabled = true
	if cleared:
		line += "　已净化"
		button.add_theme_color_override("font_disabled_color", COLOR_CLEARED)
	elif current:
		line += "　当前"
		button.add_theme_color_override("font_disabled_color", COLOR_CURRENT)
	else:
		button.add_theme_color_override("font_disabled_color", COLOR_LOCKED)
		button.disabled = false
		button.add_theme_color_override("font_color", COLOR_LOCKED)
		if LayerConfig.has_content(layer):
			line += "　未解锁"
			button.pressed.connect(_show_toast.bind("先走完前面的层，这里才会亮起来。"))
		else:
			line += "　待续"
			button.pressed.connect(_show_toast.bind("这一层的路还没亮起来——待续。"))
	button.text = line
	return button


# 当前层展开：分支路线图（每列一步、列内节点选一；层主战＝最后一列）。
# 线随层拉长后可超页宽——包横向滚动容器（拖空白处/滚轮，design-round4.md §4）。
func _make_route_section(run_state: RunState) -> Control:
	var section := VBoxContainer.new()
	section.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_theme_constant_override("separation", 6)
	_route_hint = Label.new()
	_route_hint.text = ROUTE_HINT
	_route_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_route_hint.add_theme_font_size_override("font_size", 14)
	_route_hint.add_theme_color_override("font_color", COLOR_LOCKED)
	section.add_child(_route_hint)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section.add_child(scroll)
	var route := RouteView.new(run_state)
	route.node_pressed.connect(func(index: int) -> void: node_requested.emit(index))
	route.overflow_changed.connect(func(overflow: bool) -> void:
		_route_hint.text = ROUTE_HINT_SCROLL if overflow else ROUTE_HINT)
	scroll.add_child(route)
	# 返回地图时把当前列带进视野（长线不必每次手动拖）
	route.focus_column(run_state.column_index)
	return section


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	get_tree().create_timer(1.8).timeout.connect(_hide_toast)


func _hide_toast() -> void:
	if is_instance_valid(_toast):
		_toast.visible = false


# 路线图呈现：横向列、列内节点竖排（借《明日方舟》集成战略节点图语法，design-round4.md）。
# 仅当前列节点可点；列间连线三色：已走＝金线／当前列出发＝淡紫线／其余＝暗线。
# 线随层拉长（design-round4.md §4）：父级为横向滚动容器时——内容不足视口宽＝撑满居中，
# 超出＝按内容宽可滚；空白处按住拖动／滚轮横向滚动；返回地图时聚焦当前列。
class RouteView extends Control:
	const NODE_SIZE := Vector2(168, 40)
	const NODE_GAP_Y := 10
	const COLUMN_GAP_X := 72
	const WHEEL_STEP := 180.0

	const LINE_TAKEN := Color(0.96, 0.86, 0.62, 0.85)
	const LINE_OPEN := Color(0.66, 0.63, 0.78, 0.55)
	const LINE_DEAD := Color(0.4, 0.39, 0.47, 0.3)

	const FONT_DONE := Color(0.62, 0.78, 0.6)
	const FONT_CURRENT := Color(1.0, 0.93, 0.72)
	const FONT_DIM := Color(0.5, 0.49, 0.58)

	const BOX_BG := Color(0.16, 0.15, 0.2, 0.85)
	const BOX_BG_CURRENT := Color(0.33, 0.28, 0.47, 0.95)
	const BORDER_DIM := Color(0.36, 0.34, 0.44, 0.7)
	const BORDER_CURRENT := Color(0.78, 0.7, 1.0, 0.9)

	signal node_pressed(index: int)
	signal overflow_changed(overflow: bool)

	var _run: RunState
	var _columns: Array
	var _nodes: Array = []
	var _content_size := Vector2.ZERO
	var _max_col_h := 0.0
	var _scroll: ScrollContainer = null
	var _overflowing := false
	var _focus_pending := -1
	var _dragging := false

	func _init(run_state: RunState) -> void:
		_run = run_state
		_columns = run_state.current_columns()
		_build_nodes()
		resized.connect(_layout)
		_layout()

	func _ready() -> void:
		_scroll = get_parent() as ScrollContainer
		if _scroll != null:
			_scroll.resized.connect(_update_min_size)
			# 视口宽变化（初次撑开/窗口缩放）也要重判溢出：路线自身尺寸可能不变，不会触发 _layout
			_scroll.resized.connect(_refresh_overflow)
		_update_min_size()

	# 内容不足视口宽→撑满视口（内部居中）；超出→按内容宽（可横向滚动）
	func _update_min_size() -> void:
		var want := _content_size.x
		if _scroll != null:
			want = maxf(want, _scroll.size.x)
		if absf(custom_minimum_size.x - want) > 0.5:
			custom_minimum_size.x = want

	# 请求初始把第 c 列带进视野。容器排序逐级级联（本帧内滚动条尺寸与 range 均未就绪），
	# 用 _process 等下一帧布局稳定后一次性应用
	func focus_column(c: int) -> void:
		_focus_pending = maxi(0, c)
		set_process(true)

	func _process(_delta: float) -> void:
		if _focus_pending < 0:
			set_process(false)
			return
		if _scroll == null or _scroll.size.x <= 0.0:
			return
		var col_x := _center_offset().x + _focus_pending * (NODE_SIZE.x + COLUMN_GAP_X)
		var view := _scroll.size.x
		var want := clampf(col_x - (view - NODE_SIZE.x) / 2.0, 0.0, maxf(0.0, _content_size.x - view))
		_scroll.scroll_horizontal = int(want)
		_focus_pending = -1
		set_process(false)

	func _refresh_overflow() -> void:
		var view := size.x
		if _scroll != null:
			view = _scroll.size.x
		if view <= 0.5:
			return
		var overflow := _content_size.x > view + 0.5
		# 横向滚动条交给本判定统一裁决：AUTO 模式下 Godot 会把「内容恰撑满容器」按滚动条
		# 主题边距（实测差 4px）误判为可滚、短线也常显滚动条；无溢出时 SHOW_NEVER 收回
		# （DISABLED 会按内容尺寸传播不滚轴尺寸，与撑满用的 min 宽互相顶成 400000，勿用）
		if _scroll != null:
			_scroll.horizontal_scroll_mode = (ScrollContainer.SCROLL_MODE_AUTO if overflow
					else ScrollContainer.SCROLL_MODE_SHOW_NEVER)
		if overflow != _overflowing:
			_overflowing = overflow
			overflow_changed.emit(overflow)

	# 空白处按下拖动／滚轮＝横向拉动（节点按钮本体的按下会被按钮消费，拖动只从空白起手；
	# 按钮为 PASS，滚轮事件冒泡到这里）
	func _gui_input(event: InputEvent) -> void:
		if _scroll == null:
			return
		if event is InputEventMouseButton:
			var button_event := event as InputEventMouseButton
			if button_event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = button_event.pressed
				if button_event.pressed:
					accept_event()
			elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll.scroll_horizontal += int(WHEEL_STEP)
				accept_event()
			elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll.scroll_horizontal -= int(WHEEL_STEP)
				accept_event()
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_dragging = false
			elif _dragging:
				_scroll.scroll_horizontal -= int(motion.relative.x)
				accept_event()

	func _build_nodes() -> void:
		var max_nodes := 1
		for column in _columns:
			max_nodes = maxi(max_nodes, column.size())
		_max_col_h = max_nodes * NODE_SIZE.y + (max_nodes - 1) * NODE_GAP_Y
		var width := _columns.size() * NODE_SIZE.x + maxi(0, _columns.size() - 1) * COLUMN_GAP_X
		_content_size = Vector2(width, _max_col_h)
		custom_minimum_size = _content_size
		for c in _columns.size():
			var column: Array = _columns[c]
			var column_nodes: Array = []
			for n in column.size():
				var button := _make_node_button(c, n)
				add_child(button)
				column_nodes.append(button)
			_nodes.append(column_nodes)

	func _make_node_button(c: int, n: int) -> Button:
		var state := _run.node_state(c, n)
		var stage: Dictionary = _columns[c][n]
		var label := LayerConfig.node_label(stage)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size = NODE_SIZE
		# PASS：未处理的滚轮/移动事件冒泡到 RouteView（横向滚动用）
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.add_theme_stylebox_override("disabled", _make_box(BOX_BG, BORDER_DIM))
		match state:
			RunState.NodeState.DONE:
				button.text = "✓ " + label
				button.disabled = true
				button.add_theme_color_override("font_disabled_color", FONT_DONE)
			RunState.NodeState.MISSED:
				button.text = "✕ " + label
				button.disabled = true
				button.add_theme_color_override("font_disabled_color", FONT_DIM)
			RunState.NodeState.CURRENT:
				button.text = label
				button.add_theme_color_override("font_color", FONT_CURRENT)
				button.add_theme_color_override("font_hover_color", FONT_CURRENT)
				button.add_theme_stylebox_override("normal", _make_box(BOX_BG_CURRENT, BORDER_CURRENT))
				button.add_theme_stylebox_override("hover", _make_box(BOX_BG_CURRENT, BORDER_CURRENT))
				button.add_theme_stylebox_override("pressed", _make_box(BOX_BG_CURRENT, BORDER_CURRENT))
				button.pressed.connect(func() -> void: node_pressed.emit(n))
			_:
				button.text = label
				button.disabled = true
				button.add_theme_color_override("font_disabled_color", FONT_DIM)
		return button

	func _make_box(bg: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = border
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		return box

	func _base_position(c: int, n: int) -> Vector2:
		var column: Array = _columns[c]
		var col_h := column.size() * NODE_SIZE.y + maxi(0, column.size() - 1) * NODE_GAP_Y
		var start_y := (_max_col_h - col_h) / 2.0
		return Vector2(c * (NODE_SIZE.x + COLUMN_GAP_X), start_y + n * (NODE_SIZE.y + NODE_GAP_Y))

	func _center_offset() -> Vector2:
		return Vector2(maxf(0.0, (size.x - _content_size.x) / 2.0), 0.0)

	func _layout() -> void:
		var offset := _center_offset()
		for c in _nodes.size():
			var column_nodes: Array = _nodes[c]
			for n in column_nodes.size():
				var button: Button = column_nodes[n]
				button.position = _base_position(c, n) + offset
				button.size = NODE_SIZE
		queue_redraw()
		_refresh_overflow()

	func _draw() -> void:
		var offset := _center_offset()
		for c in maxi(0, _columns.size() - 1):
			for n in (_nodes[c] as Array).size():
				for m in (_nodes[c + 1] as Array).size():
					var a := _run.node_state(c, n)
					var b := _run.node_state(c + 1, m)
					var color := LINE_DEAD
					var width := 2.0
					if a == RunState.NodeState.DONE and b == RunState.NodeState.DONE:
						color = LINE_TAKEN
						width = 3.0
					elif a == RunState.NodeState.DONE and b == RunState.NodeState.CURRENT:
						color = LINE_OPEN
					elif a == RunState.NodeState.CURRENT and b == RunState.NodeState.FUTURE:
						color = LINE_OPEN
					var from := offset + _base_position(c, n) + NODE_SIZE / 2.0
					var to := offset + _base_position(c + 1, m) + NODE_SIZE / 2.0
					draw_line(from, to, color, width)
