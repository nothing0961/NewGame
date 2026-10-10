class_name RunState
extends RefCounted

# 局内进度（design/design-round3.md §6；层内路线图＋分支随机化见 design/design-round4.md；存档不在本轮——纯内存态，随进程消亡）。

# 节点四态（地图呈现用）
enum NodeState { DONE, MISSED, CURRENT, FUTURE }

var tutorial_done := false
# 第二幕演出已看（design-round11）：旧档缺键＝false＝补看一次第二幕演出
var act2_done := false
# 第二层入场演出已看（design-round12）：旧档缺键＝false＝补看一场入场（仅层初列未开走时补）
var l2_entry_done := false
# 教程完成后＝第 2 层；完成第 N 层后＝N+1（超出 MAX_LAYER 视作 demo 边界）
var current_layer := LayerConfig.TUTORIAL_LAYER + 1
# 层内逐列进度：当前列索引（0 起）
var column_index := 0
# 已走节点记录（chosen[列] = 该列所选节点下标）；死亡回层首＝一并清空重选
var chosen: Array[int] = []
# 已收下的罪卡 id（收集顺序）
var sin_cards: Array[String] = []
# 同行层主恶魔名（收集顺序）
var companions: Array[String] = []
# 路线随机源＋当前层路线缓存：进层生成一次、层内保持不变；测试可注入种子或夹具
var rng := RandomNumberGenerator.new()
var route: Array = []
var route_layer := -1
# 层内续航修正（design-round8）：事件选项合入；掉血为负、回血抵消至多 0
var pending_hp_delta := 0
# 下一战轻增益（design-round10 §4）：事件得、story 开局消费；教学/练习/教程战不消耗；上限见 BattleConfig.PREP_*
var pending_block := 0
var pending_draw := 0


func _init() -> void:
	rng.randomize()


# 当前层路线（懒生成：首次读取时确定；route_layer 与 current_layer 不符＝失效重生成）
func current_columns() -> Array:
	if route_layer != current_layer:
		route = LayerConfig.generate_route(current_layer, rng)
		route_layer = current_layer
	return route


# 当前可选的列（越界＝空）
func current_column() -> Array:
	var columns := current_columns()
	if column_index < 0 or column_index >= columns.size():
		return []
	return columns[column_index]


# 入关即记录选择并推进（调用方随后用返回的关卡字典入关）；越界返回空字典
func choose(node_index: int) -> Dictionary:
	var column := current_column()
	if node_index < 0 or node_index >= column.size():
		return {}
	while chosen.size() <= column_index:
		chosen.append(-1)
	chosen[column_index] = node_index
	column_index += 1
	return column[node_index]


func node_state(column: int, node: int) -> int:
	if column < column_index:
		var taken := chosen[column] if column < chosen.size() else -1
		return NodeState.DONE if taken == node else NodeState.MISSED
	if column == column_index:
		return NodeState.CURRENT
	return NodeState.FUTURE


# 路线走完（已过最后一列）＝层完成，可上行
func is_route_finished() -> bool:
	var columns := current_columns()
	return not columns.is_empty() and column_index >= columns.size()


func reset_layer() -> void:
	column_index = 0
	chosen.clear()
	# 死亡重掷：路线缓存失效，下次读取时重新生成（design-round4.md §3）
	route = []
	route_layer = -1
	# 层开始（complete_layer 内）/死亡重掷/层完成共用此入口：入场 HP 修正与轻增益统一清零
	pending_hp_delta = 0
	pending_block = 0
	pending_draw = 0


# 事件效果合入层内续航修正：clamp 到 [1 - PLAYER_MAX_HP, 0]（入场 HP 至少留 1）
func apply_hp_delta(delta: int) -> void:
	pending_hp_delta = clampi(pending_hp_delta + delta, 1 - BattleConfig.PLAYER_MAX_HP, 0)


func entry_hp() -> int:
	return BattleConfig.PLAYER_MAX_HP + pending_hp_delta


# 事件结果统一入口（design-round10 §4）：hp 走层内续航；block/draw 累加并按上限 clamp
func apply_outcome(outcome: Dictionary) -> void:
	apply_hp_delta(int(outcome.get("hp", 0)))
	pending_block = clampi(pending_block + int(outcome.get("block", 0)), 0, BattleConfig.PREP_BLOCK_CAP)
	pending_draw = clampi(pending_draw + int(outcome.get("draw", 0)), 0, BattleConfig.PREP_DRAW_CAP)


func entry_block() -> int:
	return pending_block


func entry_draw() -> int:
	return pending_draw


# story 开战的消费点（main_flow 在战斗子节点入场后调用；教学/练习/教程战不调用）
func consume_buffs() -> void:
	pending_block = 0
	pending_draw = 0


# 层内路线打完 → 上行；超过 MAX_LAYER 后停在 MAX_LAYER + 1（demo 边界）
func complete_layer() -> void:
	current_layer += 1
	reset_layer()


func collect_sin(card_id: String) -> void:
	if not sin_cards.has(card_id):
		sin_cards.append(card_id)


func add_companion(demon: String) -> void:
	if not companions.has(demon):
		companions.append(demon)


func is_layer_unlocked(layer: int) -> bool:
	if layer <= LayerConfig.TUTORIAL_LAYER:
		return true
	return tutorial_done and layer <= current_layer and LayerConfig.has_content(layer)


func is_layer_cleared(layer: int) -> bool:
	if layer <= LayerConfig.TUTORIAL_LAYER:
		return tutorial_done
	return tutorial_done and layer < current_layer


# 教程完成后的地图是否已到内容边界（第 8 层·同位体终局待专轮）
func is_demo_end() -> bool:
	return tutorial_done and not LayerConfig.has_content(current_layer)
