class_name LayerConfig
extends RefCounted

# 层循环数据（design/design-round3.md；层内路线图＋分支随机化见 design/design-round4.md，定案 2026-10-05）。
# 层＝分支路线图：若干「列」（每列＝一步），列内多节点选一；层主战＝最后一列（净化的唯一发生点）。
# 路线进层随机生成（generate_route）：列数随机、节点从池抽取（同一张地图内不重复）；死亡重掷。
# 第 1 层（懒惰·贝尔芬格）＝教程层特化编排，不走本表路线；
# 第 2 层＝可玩占位（本文件全部文本/数值＝【测试内容】，第二层设计轮整体替换）；
# 第 3 层起只有层名/恶魔名，内容待各层设计轮。

const TUTORIAL_LAYER := 1
const MAX_LAYER := 8
# demo 边界：有内容的最后一层（教程层另计）
const LAST_PLAYABLE_LAYER := 2

const TYPE_BATTLE := "battle"
const TYPE_EVENT := "event"

# 路线形状（【测试内容】占位口径）：列数 2–4（含末列层主战），普通列每列 1–3 节点
const ROUTE_MIN_COLUMNS := 2
const ROUTE_MAX_COLUMNS := 4
const ROUTE_MIN_NODES := 1
const ROUTE_MAX_NODES := 3

const LAYERS := {
	1: {"name": "懒惰", "demon": "贝尔芬格"},
	2: {"name": "色欲", "demon": "阿斯莫德"},
	3: {"name": "暴食", "demon": "别西卜"},
	4: {"name": "贪婪", "demon": "玛门"},
	5: {"name": "嫉妒", "demon": "利维坦"},
	6: {"name": "傲慢", "demon": "路西法"},
	7: {"name": "暴怒", "demon": "萨麦尔"},
	8: {"name": "同位体", "demon": "贝嘉"},
}

# 第 2 层占位池（【测试内容】；第二层设计轮整体替换）——作战 4＋事件 5＝9 个普通节点，
# ≥ 单图最大需求（3 普通列 × 最多 3 节点＝9），保证「全图不重复抽取」不耗尽
const LAYER2_BATTLES := [
	{
		"type": "battle",
		"enemy": "污染体",
		"enemy_hp": 20,
		"enemy_deck": {"enemy_strike": 8},
	},
	{
		"type": "battle",
		"enemy": "残响回廊",
		"enemy_hp": 16,
		"enemy_deck": {"enemy_strike": 8},
	},
	{
		"type": "battle",
		"enemy": "糖霜傀儡",
		"enemy_hp": 18,
		"enemy_deck": {"enemy_strike": 8},
	},
	{
		"type": "battle",
		"enemy": "雾中合唱",
		"enemy_hp": 22,
		"enemy_deck": {"enemy_strike": 8},
	},
]

const LAYER2_EVENTS := [
	{
		"type": "event",
		"title": "粉雾",
		"scene": "楼梯的尽头浮着一层淡粉色的雾。雾里有人在唱歌，调子很轻，听着听着就不想走了。",
		"choices": ["穿过雾去", "捂住耳朵快走", "站在原地听"],
		"feedback": [
			"你走了进去。歌声散开，雾让出一条路——前方便是这一层的守关者。",
			"你捂着耳朵冲过去。歌声在背后淡了，但心里像被挠了一下。",
			"你听着，越听越困。一只「污染体」从雾里爬了出来——它不喜欢听众。",
		],
	},
	{
		"type": "event",
		"title": "镜阶",
		"scene": "楼道两侧镶满了镜子。镜子里的你穿着不一样的裙子，正冲你笑。",
		"choices": ["对镜子里的自己点头", "快走，别看", "伸手碰一碰镜面"],
		"feedback": [
			"镜子里的你也点了点头，然后碎了。碎片里透出往上的路。",
			"你低着头走过去，镜子里的笑声一直追到楼梯口。",
			"镜面凉得像水，漾开一圈波纹——后面的路清楚了一点。",
		],
	},
	{
		"type": "event",
		"title": "烛台走廊",
		"scene": "拐角有一排矮烛台，火苗一动不动。走近才发现，每根蜡烛底下都刻着一个名字。",
		"choices": ["吹熄最近的一根", "伸手护住火苗", "贴着墙绕过去"],
		"feedback": [
			"火苗晃了晃，没有灭。走廊深处传来一声很轻的叹气。",
			"火苗贴着你的手心发烫，暖得让人想哭。",
			"你贴着墙走。身后的火光一起转过头来，看着你。",
		],
	},
	{
		"type": "event",
		"title": "糖罐",
		"scene": "楼梯转角的矮柜上摆着一只糖罐。罐子没有盖子，里边的糖却在慢慢变少。",
		"choices": ["伸手拿一颗", "把盖子找回来", "把糖罐倒过来"],
		"feedback": [
			"糖是粉色的，含进嘴里像一小口雾。你在原地站了一会儿，才发现自己笑了。",
			"你在柜子底下摸到盖子，覆回去。糖安静下来，不再变少。",
			"糖撒了一地，滚进缝隙里。墙里头传来一声小小的、心满意足的叹息。",
		],
	},
	{
		"type": "event",
		"title": "低语信箱",
		"scene": "墙里嵌着一只旧信箱，投信口里传出很轻的说话声，像在念一串名单。念到一半，停住了。",
		"choices": ["把耳朵贴上去听", "投一枚硬币进去", "快步走开"],
		"feedback": [
			"你听见自己的名字。声音顿了顿，又说：「还早呢。」",
			"信箱咔哒响了一声。投信口吐出一小片暖的糖纸，像句谢谢。",
			"你走出很远，身后的声音还在继续念，一遍一遍，把名单念得又慢又长。",
		],
	},
]

# 层主不入池：固定为末列唯一节点
const LAYER2_BOSS := {
	"type": "battle",
	"enemy": "阿斯莫德",
	"enemy_hp": 24,
	"enemy_deck": {"enemy_strike": 8},
	"boss": true,
	"sin_card": "lust",
	# 层主战净化段（【测试内容】占位；结构同教程：打倒 → 白火离体 → 收下 → 净化读白）
	"strip_lines": [
		"「呀……结束了呀。」她跌坐下去，粉色的裙摆散了一地。",
		"一团泛着甜味的白光从她心口浮出来，垂在你们中间，像一颗舍不得化的糖。",
		"它试探着凑近你——不像攻击，更像撒娇。",
	],
	"purify_lines": [
		"阿斯莫德揉着额头坐起来，眼里的雾退了下去。",
		"「原来你把它接住了。」她凑近看你手里的牌，忽然笑了。「它很粘人的，你辛苦啦。」",
		"她掂着裙角转了个圈。「这一层没意思了。走吧走吧——上边那位，比我难缠得多哦。」",
	],
}

# 层完成后的上行过渡读白（同行层主）【测试内容】
const LAYER2_TRANSITION := [
	"通往第三层的台阶上，多了两个人的脚步声——你的，和贝尔芬格的——不，现在是三个人了。",
	"「哈——欠。」贝尔芬格走在最后面，阿斯莫德走在最前面，嘴里还哼着那首听不清的歌。",
	"「上面那层是『暴食』。」阿斯莫德回头，「那边的家伙，是真的什么都想吃哦。」",
]


static func layer_name(layer: int) -> String:
	return String(LAYERS.get(layer, {}).get("name", ""))


static func demon_name(layer: int) -> String:
	return String(LAYERS.get(layer, {}).get("demon", ""))


# 进层随机生成路线：普通列 1–3 个（列数 2–4 含末列）＋末列层主战唯一节点；层无内容＝空路线。
# 战斗/事件从池洗牌后顺序取——同一张地图内不重复（池规模 ≥ 最大需求，见池注释）。
static func generate_route(layer: int, rng: RandomNumberGenerator) -> Array:
	if layer != 2:
		return []
	var pool: Array = []
	pool.append_array(LAYER2_BATTLES)
	pool.append_array(LAYER2_EVENTS)
	var order := _shuffled_indices(pool.size(), rng)
	var cursor := 0
	var normal_columns := rng.randi_range(ROUTE_MIN_COLUMNS - 1, ROUTE_MAX_COLUMNS - 1)
	var route: Array = []
	for c in normal_columns:
		var node_count := rng.randi_range(ROUTE_MIN_NODES, ROUTE_MAX_NODES)
		var column: Array = []
		for n in node_count:
			column.append(pool[order[cursor]])
			cursor += 1
		route.append(column)
	route.append([LAYER2_BOSS])
	return route


# Fisher–Yates 洗牌（用注入的 rng，保证同种子可复现）
static func _shuffled_indices(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = []
	for i in count:
		order.append(i)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	return order


static func transition_lines(layer: int) -> Array:
	if layer == 2:
		return LAYER2_TRANSITION
	return []


static func has_content(layer: int) -> bool:
	return layer == TUTORIAL_LAYER or layer <= LAST_PLAYABLE_LAYER
