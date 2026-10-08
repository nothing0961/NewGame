class_name EventGames
extends RefCounted

# 事件小玩法纯结算（design/design-round10.md）：UI 只做交互与呈现，这里只算结果，可单测。
# outcome 词汇 {hp, block, draw}（缺键＝0；hp＝层内入场血修正，block＝下一战开局格挡，draw＝下一战起手多抽）。
# 数值全部 int 归一（JSON 存档往返 float 兜底）；数据守护 validate() 供测试与实装校验。

const MODULE_PICK := "pick"
const MODULE_SORT := "sort"
const MODULE_BALANCE := "balance"
const MODULE_REVEAL := "reveal"
const MODULES := [MODULE_PICK, MODULE_SORT, MODULE_BALANCE, MODULE_REVEAL]

const OUTCOME_KEYS := ["hp", "block", "draw"]
# 数值守护区间（design-round10 §3：hp 重扣 −2 封顶、回报 +2 封顶；block/draw 只增不减）
const HP_RANGE := Vector2i(-3, 3)
const BLOCK_RANGE := Vector2i(0, 3)
const DRAW_RANGE := Vector2i(0, 1)

# 配平默认分档：|差| 0 → hp+1；1 → 无；≥2 → hp−1（事件数据可给 bands 覆盖）
const BALANCE_DEFAULT_BANDS := [
	{"max_diff": 0, "outcome": {"hp": 1}, "text": "分毫不差——天平轻轻归位，你心里也跟着平了。"},
	{"max_diff": 1, "outcome": {}, "text": "差一点。天平晃了晃，将就着稳住了。"},
	{"max_diff": 99, "outcome": {"hp": -1}, "text": "差得有些远。天平重重地磕了一下。"},
]

const OUTCOME_LABELS := {
	"hp": "生命 %+d",
	"block": "开局格挡 %+d",
	"draw": "起手多抽 %+d",
}


# 过滤 hp/block/draw 并 int 化；其他键忽略（unknown 键在 validate 里报错，运行时宽容）
static func normalize_outcome(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key in OUTCOME_KEYS:
			if raw.has(key):
				out[key] = int(raw[key])
	return out


static func add_outcome(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for key in OUTCOME_KEYS:
		var sum := int(a.get(key, 0)) + int(b.get(key, 0))
		if sum != 0:
			out[key] = sum
	return out


static func is_empty_outcome(outcome: Dictionary) -> bool:
	for key in OUTCOME_KEYS:
		if int(outcome.get(key, 0)) != 0:
			return false
	return true


# 「生命 +1 · 开局格挡 +1」式自动结果行；无变化给固定读白
static func outcome_line(outcome: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in OUTCOME_KEYS:
		var amount := int(outcome.get(key, 0))
		if amount != 0:
			parts.append(OUTCOME_LABELS[key] % amount)
	if parts.is_empty():
		return "（这一趟没有留下什么，也没有带走什么。）"
	return " · ".join(parts)


# —— 结算：各返回 {outcome: Dictionary, text: String}；非法输入返回 {} ——

# 择一：index 选定卡
static func resolve_pick(gameplay: Dictionary, index: int) -> Dictionary:
	var cards: Array = gameplay.get("cards", [])
	if index < 0 or index >= cards.size():
		return {}
	var card: Dictionary = cards[index]
	return {"outcome": normalize_outcome(card.get("outcome", {})), "text": String(card.get("text", ""))}


# 分拣：sides[i] ∈ {"left","right"}，与 cards 下标对齐；Σ 各卡所属侧
static func resolve_sort(gameplay: Dictionary, sides: Array) -> Dictionary:
	var cards: Array = gameplay.get("cards", [])
	if sides.size() != cards.size():
		return {}
	var outcome := {}
	for i in cards.size():
		var side := String(sides[i])
		if side != "left" and side != "right":
			return {}
		outcome = add_outcome(outcome, normalize_outcome((cards[i] as Dictionary).get(side, {})))
	return {"outcome": outcome, "text": String(gameplay.get("settle", ""))}


# 配平：Σ 上盘 weight 与目标之差 → 分档查表
static func resolve_balance(gameplay: Dictionary, indices: Array) -> Dictionary:
	var sum := balance_sum(gameplay, indices)
	var target := int(gameplay.get("target", 0))
	var diff := absi(sum - target)
	var bands: Array = gameplay.get("bands", BALANCE_DEFAULT_BANDS)
	for band in bands:
		if diff <= int(band.get("max_diff", 0)):
			return {"outcome": normalize_outcome(band.get("outcome", {})), "text": String(band.get("text", ""))}
	return {"outcome": {}, "text": ""}


static func balance_sum(gameplay: Dictionary, indices: Array) -> int:
	var cards: Array = gameplay.get("cards", [])
	var total := 0
	for raw_index in indices:
		var index := int(raw_index)
		if index >= 0 and index < cards.size():
			total += int((cards[index] as Dictionary).get("weight", 0))
	return total


# 揭示：单张翻面即结算（可继续翻或收手）
static func resolve_reveal_flip(gameplay: Dictionary, index: int) -> Dictionary:
	var cards: Array = gameplay.get("cards", [])
	if index < 0 or index >= cards.size():
		return {}
	var card: Dictionary = cards[index]
	return {"outcome": normalize_outcome(card.get("outcome", {})), "text": String(card.get("text", ""))}


# 揭示变体：全部翻完的追加奖励；无 finish 键返回 {}（调用方不追加）
static func resolve_reveal_finish(gameplay: Dictionary) -> Dictionary:
	var finish: Variant = gameplay.get("finish")
	if not (finish is Dictionary) or (finish as Dictionary).is_empty():
		return {}
	var finish_dict: Dictionary = finish
	return {"outcome": normalize_outcome(finish_dict.get("outcome", {})), "text": String(finish_dict.get("text", ""))}


# —— 数据守护：返回错误串列表（空＝通过）。事件池/路线测试与实装校验共用 ——

static func validate(gameplay: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var module := String(gameplay.get("module", ""))
	if not MODULES.has(module):
		errors.append("未知模块：%s" % module)
		return errors
	var cards: Array = gameplay.get("cards", [])
	if cards.is_empty():
		errors.append("cards 为空")
		return errors
	var draw_sources := 0
	match module:
		MODULE_PICK:
			for i in cards.size():
				draw_sources += _check_outcome_at(cards[i], ["outcome"], "卡 %d" % i, errors)
			if not _has_mild_pick(cards):
				errors.append("择一无温和路径（没有 hp ≥ 0 的卡）")
		MODULE_SORT:
			if not gameplay.has("left_label") or not gameplay.has("right_label"):
				errors.append("分拣缺筐标签")
			for i in cards.size():
				draw_sources += _check_outcome_at(cards[i], ["left", "right"], "卡 %d" % i, errors)
			if int(gameplay.get("capacity", 0)) > 0:
				var side := String(gameplay.get("capacity_side", ""))
				if side != "left" and side != "right":
					errors.append("分拣设了容量但缺 capacity_side")
				elif int(gameplay.get("capacity", 0)) > cards.size():
					errors.append("分拣容量大于卡数")
			if not _has_mild_sort(gameplay, cards):
				errors.append("分拣无温和路径（不存在总 hp ≥ 0 的摆法）")
		MODULE_BALANCE:
			if not gameplay.has("target"):
				errors.append("配平缺 target")
			for i in cards.size():
				var card: Dictionary = cards[i]
				if not card.has("weight"):
					errors.append("配平卡 %d 缺 weight" % i)
				elif typeof(card["weight"]) != TYPE_INT and typeof(card["weight"]) != TYPE_FLOAT:
					errors.append("配平卡 %d weight 非数值" % i)
			var bands: Array = gameplay.get("bands", BALANCE_DEFAULT_BANDS)
			for i in bands.size():
				draw_sources += _check_outcome_at(bands[i], ["outcome"], "档 %d" % i, errors)
			if not _has_mild_balance(gameplay, cards):
				errors.append("配平无温和路径（不存在可及的非负档位）")
		MODULE_REVEAL:
			for i in cards.size():
				draw_sources += _check_outcome_at(cards[i], ["outcome"], "卡 %d" % i, errors)
			if gameplay.has("finish"):
				var finish: Variant = gameplay["finish"]
				if not (finish is Dictionary):
					errors.append("全翻奖励非字典")
				else:
					draw_sources += _check_outcome_at(finish, ["outcome"], "全翻奖励", errors)
	if draw_sources > 1:
		errors.append("单事件 draw 多于 1 处（%d）" % draw_sources)
	return errors


# 校验一份 outcome（sub_keys 指定字典里放 outcome 的键，如 ["outcome"] 或 ["left","right"]）；返回 draw>0 处数
static func _check_outcome_at(container: Dictionary, sub_keys: Array, where: String, errors: Array[String]) -> int:
	var draw_sources := 0
	for sub_key in sub_keys:
		if not container.has(sub_key):
			errors.append("%s 缺 %s" % [where, sub_key])
			continue
		var raw: Variant = container[sub_key]
		if not (raw is Dictionary):
			errors.append("%s 的 %s 非字典" % [where, sub_key])
			continue
		var outcome: Dictionary = raw
		for key in outcome:
			if not OUTCOME_KEYS.has(String(key)):
				errors.append("%s 的结果词汇非法：%s" % [where, key])
				continue
			var value: Variant = outcome[key]
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				errors.append("%s 的 %s 非数值" % [where, key])
				continue
			if _range_for(String(key)).x > int(value) or int(value) > _range_for(String(key)).y:
				errors.append("%s 的 %s=%s 超出区间" % [where, key, value])
			if String(key) == "draw" and int(value) > 0:
				draw_sources += 1
	return draw_sources


static func _range_for(key: String) -> Vector2i:
	match key:
		"block":
			return BLOCK_RANGE
		"draw":
			return DRAW_RANGE
		_:
			return HP_RANGE


# 温和路径：择一＝存在 hp ≥ 0 的卡
static func _has_mild_pick(cards: Array) -> bool:
	for card in cards:
		if int(normalize_outcome((card as Dictionary).get("outcome", {})).get("hp", 0)) >= 0:
			return true
	return false


# 温和路径：分拣＝存在容量内的整盘摆法总 hp ≥ 0（卡数 ≤6，穷举）
static func _has_mild_sort(gameplay: Dictionary, cards: Array) -> bool:
	var capacity := int(gameplay.get("capacity", 0))
	var capacity_side := String(gameplay.get("capacity_side", ""))
	var total := 1 << cards.size()
	for mask in total:  # 每个位＝该卡去右侧；mask 覆盖全左（0）到全右
		var right_count := 0
		for i in cards.size():
			if (mask >> i) & 1 == 1:
				right_count += 1
		if capacity > 0:
			var side_count := right_count if capacity_side == "right" else cards.size() - right_count
			if side_count > capacity:
				continue
		var hp := 0
		for i in cards.size():
			var side := "right" if (mask >> i) & 1 == 1 else "left"
			hp += int(normalize_outcome((cards[i] as Dictionary).get(side, {})).get("hp", 0))
		if hp >= 0:
			return true
	return false


# 温和路径：配平＝存在非空上盘组合落在 hp ≥ 0 的档位（卡数 ≤5，穷举）
static func _has_mild_balance(gameplay: Dictionary, cards: Array) -> bool:
	var total := 1 << cards.size()
	for mask in range(1, total):
		var indices: Array = []
		for i in cards.size():
			if (mask >> i) & 1 == 1:
				indices.append(i)
		if int(normalize_outcome(resolve_balance(gameplay, indices).get("outcome", {})).get("hp", 0)) >= 0:
			return true
	return false
