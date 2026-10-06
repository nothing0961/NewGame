class_name SaveGame
extends RefCounted

# 进度存档（design/design-round5.md §1）：教程完成后开始写盘——开始游戏直达路线，跨启动保留。
# 只存教程后的局内进度；tutorial_done=false 不写（教学阶段视作未开局）。
# 测试：置 disabled=true 屏蔽自动读写；需要真读写的用例改 save_path 到独立文件。

const DEFAULT_SAVE_PATH := "user://save.json"
# VERSION 2（design-round6）：仓库新增 治疗术/净化/强欲魔弹，旧档（v1）拒载重走教程
const VERSION := 2

static var save_path := DEFAULT_SAVE_PATH
static var disabled := false


static func save_progress(run: RunState, pool: CardPool) -> void:
	if disabled or not run.tutorial_done:
		return
	var data := {
		"version": VERSION,
		"tutorial_done": run.tutorial_done,
		"current_layer": run.current_layer,
		"column_index": run.column_index,
		"chosen": run.chosen,
		"sin_cards": run.sin_cards,
		"companions": run.companions,
		"route": run.route,
		"route_layer": run.route_layer,
		"pool_owned": pool.owned,
		"pool_deck": pool.deck,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


# 坏档/无档/版本不符 → 空字典（拒载不崩，从教程走）
static func load_progress() -> Dictionary:
	if disabled:
		return {}
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data


# JSON 数字回读统一为 float：进度标量 int()、路线节点内 int 字段归一化（enemy_hp/enemy_deck 计数）
static func apply_progress(data: Dictionary, run: RunState, pool: CardPool) -> void:
	run.tutorial_done = bool(data.get("tutorial_done", false))
	run.current_layer = int(data.get("current_layer", run.current_layer))
	run.column_index = int(data.get("column_index", 0))
	run.chosen = _to_int_array(data.get("chosen", []))
	run.sin_cards = _to_string_array(data.get("sin_cards", []))
	run.companions = _to_string_array(data.get("companions", []))
	run.route = _normalize_route(data.get("route", []))
	run.route_layer = int(data.get("route_layer", -1))
	if data.has("pool_owned"):
		var owned := {}
		var raw: Variant = data["pool_owned"]
		if raw is Dictionary:
			for key in raw:
				owned[String(key)] = int(raw[key])
		pool.owned = owned
	if data.has("pool_deck"):
		pool.deck = _to_string_array(data["pool_deck"])


static func _to_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for value in raw:
			out.append(int(value))
	return out


static func _to_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for value in raw:
			out.append(String(value))
	return out


static func _normalize_route(raw: Variant) -> Array:
	var route: Array = []
	if not (raw is Array):
		return route
	for column in raw:
		if not (column is Array):
			continue
		var out_column: Array = []
		for node in column:
			out_column.append(_normalize_stage(node) if node is Dictionary else node)
		route.append(out_column)
	return route


static func _normalize_stage(stage: Dictionary) -> Dictionary:
	var out := stage.duplicate(true)
	if out.has("enemy_hp"):
		out["enemy_hp"] = int(out["enemy_hp"])
	if out.has("enemy_deck") and out["enemy_deck"] is Dictionary:
		var deck: Dictionary = out["enemy_deck"]
		var fixed := {}
		for card_id in deck:
			fixed[String(card_id)] = int(deck[card_id])
		out["enemy_deck"] = fixed
	return out
