class_name LayerConfig
extends RefCounted

# 层循环数据（design/design-round3.md；层内路线图＋分支随机化＋拉长/横滚见 design/design-round4.md，定案 2026-10-05）。
# 第 2–7 层名录＝design/design-round7.md（2026-10-06 定）；战斗数值实装＝design/design-round8.md。
# 层＝分支路线图：若干「列」（每列＝一步），列内多节点选一；层主战＝最后一列（净化的唯一发生点）。
# 路线进层随机生成（generate_route）：总列数随层数拉长、节点从该层池抽取（池容量＝该层单图最大需求）；死亡重掷。
# 事件玩法（design/design-round10.md，2026-10-08）：choices/feedback/effects 退役，统一 gameplay 键；
# 四模块 pick 择一／sort 分拣／balance 配平／reveal 揭示（结算＝EventGames 纯函数，本表只放数据）；
# 结果词汇 {hp, block, draw}——hp＝层内入场血修正，block＝下一战开局格挡，draw＝下一战起手多抽。
# 事件文案（道具名/读白/提示/汇总）＝【测试内容】，待定稿轮重写。
# 第 1 层（懒惰·贝尔芬格）＝教程层特化编排，不走本表路线；第 8 层（同位体）＝终局专轮，has_content=false。

const TUTORIAL_LAYER := 1
const MAX_LAYER := 8
# demo 边界：有内容的最后一层（教程层另计）；第 8 层留终局专轮
const LAST_PLAYABLE_LAYER := 7
# 同行者人名表（双名制，用户定 2026-10-05；design-round11 扩至第 2 层）：
# 人身名＝净化后同行显示；层表/地图层行/层主战节点仍显示恶魔名＝污染形态名。
# 第 3–7 层净化后同行层主仍沿恶魔名，待各自专轮改人名。
const LAYER_COMPANIONS := {1: "菲戈蕾", 2: "莉维娅"}

const TYPE_BATTLE := "battle"
const TYPE_EVENT := "event"

# 路线长度随层数拉长（用户定 2026-10-05「线要拉长」）：
# 总列数区间（含末列层主战）——每两层 +1 列：第 2–3 层 2–4 · 第 4–5 层 3–5 · 第 6–7 层 4–6 · 第 8 层 5–7
const ROUTE_LENGTH := {
	2: Vector2i(2, 4),
	3: Vector2i(2, 4),
	4: Vector2i(3, 5),
	5: Vector2i(3, 5),
	6: Vector2i(4, 6),
	7: Vector2i(4, 6),
	8: Vector2i(5, 7),
}
# 每列节点数（分支上限 3）
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

# —— 各层敌牌组（小怪与层主共用；design-round7.md 决案 3：敌人差异＝数值＋专属敌牌组）——
# 期望伤/轮 ≈ 3×a（稳态每轮出牌 ~3 张）：a(L2..L7) = 1.0 / 1.125 / 1.25 / 1.25 / 1.375 / 1.5（温和爬升）
const LAYER2_ENEMY_DECK := {"enemy_strike": 8}
const LAYER3_ENEMY_DECK := {"enemy_strike": 7, "gnaw": 1}
const LAYER4_ENEMY_DECK := {"enemy_strike": 6, "gold_smash": 2}
const LAYER5_ENEMY_DECK := {"enemy_strike": 6, "mirror_cut": 2}
const LAYER6_ENEMY_DECK := {"enemy_strike": 6, "piercing_light": 1, "falling_debris": 1}
const LAYER7_ENEMY_DECK := {"enemy_strike": 5, "ember_lash": 2, "flame_burst": 1}

# —— 第 2 层 · 色欲（池 9 ＝ 4 战 ＋ 5 事；节奏：一场不断挽留你的演出——雾越来越甜，直到歌忽然停下）——
const LAYER2_BATTLES := [
	{"type": "battle", "enemy": "粉雾歌者", "enemy_hp": 16, "enemy_deck": LAYER2_ENEMY_DECK},
	{"type": "battle", "enemy": "糖丝傀儡", "enemy_hp": 18, "enemy_deck": LAYER2_ENEMY_DECK},
	{"type": "battle", "enemy": "镜前舞者", "enemy_hp": 20, "enemy_deck": LAYER2_ENEMY_DECK},
	{"type": "battle", "enemy": "缠丝泡影", "enemy_hp": 22, "enemy_deck": LAYER2_ENEMY_DECK},
]

const LAYER2_EVENTS := [
	{
		"type": "event",
		"title": "试衣镜",
		"scene": "更衣间里立着一面试衣镜。镜中挂着一件不属于你的演出服，裙摆轻轻晃着，像有人在里面呼吸。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "抚平演出服",
					"sub": "把演出服抚平挂好",
					"text": "布料软得像雾。你抚平它，镜里的灯亮了一格——照得你肩上暖了一小块。",
					"outcome": {"hp": 1},
				},
				{
					"name": "问镜中的自己",
					"sub": "问镜中的自己：我是谁",
					"text": "镜里的你张了张嘴，发出的却是别人的声音：「快了，快轮到你登场了。」",
					"outcome": {},
				},
				{
					"name": "后退离开",
					"sub": "后退，离开更衣间",
					"text": "你退到门口。镜子在你身后转了个角度，一直照着你，直到门合上。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "糖果摊",
		"scene": "走道边支着一个小糖果摊，摊主不在。粉色的糖在玻璃罐里轻轻翻动，像一群想出来的蝴蝶。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它——翻开即记账，随时可以停下。",
			"stop_label": "不尝了，走",
			"cards": [
				{
					"name": "甜糖",
					"sub": "玻璃罐最上层，糖纸亮闪闪的。",
					"text": "糖化在舌尖，甜得头发晕。那股甜坠在胸口，闷闷的。",
					"outcome": {"hp": -1},
				},
				{
					"name": "糖纸",
					"sub": "打翻在台面上，皱成一团。",
					"text": "你把糖纸一张张叠成小摞。风穿过摊位时，那摞纸轻轻拍了拍你的手背——手背于是轻快了一点。",
					"outcome": {"hp": 1},
				},
				{
					"name": "罐底字条",
					"sub": "压在罐底，被糖埋了半截。",
					"text": "字条上只写着一行小字：「先学会挡住的，才尝得到最里面的甜。」",
					"outcome": {"block": 1},
				},
				{
					"name": "空玻璃纸",
					"sub": "最下面一层，什么也没包。",
					"text": "玻璃纸里空空荡荡，对着光一照，什么也没有。你把空的手心摊开，又合上。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "合唱席",
		"scene": "一排排空椅子上方飘着整齐的哼唱，声部齐全，只是一个人也没有。正中间留着一个空位，椅背上搭着副耳返。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "听一整段",
					"sub": "坐下来听一整段",
					"text": "歌声顺着椅背爬上来，把你的力气也卷进和声里。起身时，腿是软的。",
					"outcome": {"hp": -1},
				},
				{
					"name": "站上指挥台",
					"sub": "站上指挥台挥手",
					"text": "你抬手一挥，合唱齐齐停了半拍，又接上。空椅子上轻轻起了一阵笑意——那笑意拂过你，把你托稳了些。",
					"outcome": {"hp": 1},
				},
				{
					"name": "绕过椅子",
					"sub": "绕过椅子继续走",
					"text": "你贴着墙绕过去。歌声一直唱到你看不见的地方。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "粉焰之墙",
		"scene": "通道尽头立着一面墙，粉色的火沿墙根慢慢烧，没有烟，也不烫人，只把去路映得发软。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它；全部翻开，还有额外的回报。",
			"stop_label": "穿过去",
			"cards": [
				{
					"name": "温",
					"sub": "墙根最外侧的火，暖融融的。",
					"text": "火舌擦过你的手臂，不疼，像被谁拽了一下袖子。你出了一层薄汗，收回了手。",
					"outcome": {},
				},
				{
					"name": "火舌",
					"sub": "最亮的那一簇，跳得很急。",
					"text": "热浪扑面，你被燎得偏过头，手腕上留了一道浅浅的红。",
					"outcome": {"hp": -1},
				},
				{
					"name": "甜的挽留",
					"sub": "一团粘在指尖的粉，甜得发闷。",
					"text": "火缠上指尖，温暖的、甜的，像谁在挽留。你抽回手，掌心留了一小片粉，拍不掉。",
					"outcome": {},
				},
			],
			"finish": {
				"text": "你伸手碰过每一簇火。墙从中间让开一条缝——你侧身穿过，后背暖暖的，像有什么替你挡在了后面。",
				"outcome": {"block": 1},
			},
		},
	},
	{
		"type": "event",
		"title": "献花台",
		"scene": "楼梯转角摆着一个小小的献花台，花是新的，卡片是空的。台前的地面被脚步磨得发亮，像有很多人来过。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "摆正花，鞠躬",
					"sub": "把花摆正，鞠一躬",
					"text": "你把花摆正，弯下腰。起身时，胸口那片发紧的地方松开些了。",
					"outcome": {"hp": 1},
				},
				{
					"name": "写下名字",
					"sub": "在卡片上写下名字",
					"text": "你握着笔站了会儿，最后把空卡片放了回去——这里的名字，终究不是你的位置。",
					"outcome": {},
				},
				{
					"name": "直接上楼",
					"sub": "直接上楼",
					"text": "你直接上楼。身后很安静，花一直摆在那里，谁也没等到。",
					"outcome": {},
				},
			],
		},
	},
]

# 层主不入池：固定为末列唯一节点
const LAYER2_BOSS := {
	"type": "battle",
	"enemy": "阿斯莫德",
	"enemy_hp": 24,
	"enemy_deck": LAYER2_ENEMY_DECK,
	"boss": true,
	"sin_card": "lust",
	"strip_lines": [
		"「呀……结束了呀。」她跌坐下去，粉色的裙摆散了一地。",
		"一团泛着甜味的白光从她心口浮出来，垂在你们中间，像一颗舍不得化的糖。",
		"它试探着凑近你——不像攻击，更像撒娇。",
	],
	"purify_lines": [
		"莉维娅揉着额头坐起来，眼里的雾退了下去。",
		"「原来你把它接住了。」她凑近看你手里的牌，忽然笑了。「它很粘人的，你辛苦啦。」",
		"「找到我了。……谢谢。」她很小声地说，像是说给自己听。",
		"她掂着裙角转了个圈。「这一层没意思了。走吧走吧——上边那位，比我难缠得多哦。」",
	],
}

# 层完成后的上行过渡读白（同行层主；净化后＝人身莉维娅）
const LAYER2_TRANSITION := [
	"通往第三层的台阶上，多了两个人的脚步声——你的，和菲戈蕾的——不，现在是三个人了。",
	"「哈——欠。」菲戈蕾走在最后面，莉维娅走在最前面，正把散下来的金发一圈一圈绕回发绳里。",
	"「上面那层是『暴食』。」莉维娅回头，「那边的家伙，是真的什么都想吃哦。」",
]

# —— 第 3 层 · 暴食（池 9 ＝ 5 战 ＋ 4 事；节奏：先闻到香气，再感到饿，最后站到还开着火的灶前）——
const LAYER3_BATTLES := [
	{"type": "battle", "enemy": "空胃食客", "enemy_hp": 18, "enemy_deck": LAYER3_ENEMY_DECK},
	{"type": "battle", "enemy": "餐铃偶", "enemy_hp": 20, "enemy_deck": LAYER3_ENEMY_DECK},
	{"type": "battle", "enemy": "匙叉傀儡", "enemy_hp": 22, "enemy_deck": LAYER3_ENEMY_DECK},
	{"type": "battle", "enemy": "驮汤行者", "enemy_hp": 24, "enemy_deck": LAYER3_ENEMY_DECK},
	{"type": "battle", "enemy": "残羹聚合", "enemy_hp": 26, "enemy_deck": LAYER3_ENEMY_DECK},
]

const LAYER3_EVENTS := [
	{
		"type": "event",
		"title": "长桌宴席",
		"scene": "一张望不到头的长桌摆满了菜，热气都是新的。桌边坐着许多影子，正认真地吃，谁也不说话。",
		"gameplay": {
			"module": "sort",
			"hint": "把每张牌拖进一只筐；全部放好后按「收好」。",
			"left_label": "吃下",
			"right_label": "留下",
			"settle": "你按自己的分量挑完了这一桌。桌上的热气慢慢降下来，影子们仍在认真地吃，谁也没抬头。",
			"cards": [
				{
					"name": "热汤",
					"sub": "刚出锅，热气扑脸。",
					"left": {"hp": 1},
					"right": {},
				},
				{
					"name": "硬菜",
					"sub": "油光发亮，分量很沉。",
					"left": {"hp": -1},
					"right": {},
				},
				{
					"name": "新米",
					"sub": "新蒸的饭，粒粒分明。",
					"left": {},
					"right": {"hp": 1},
				},
				{
					"name": "糖霜点心",
					"sub": "甜得发黏，一碰一手糖霜。",
					"left": {"hp": -1, "draw": 1},
					"right": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "一碗汤",
		"scene": "灶上只剩一碗汤，还热着。碗底压着张字条，字被水汽洇开了：「先到的人，留给后来的人。」",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "趁热喝掉",
					"sub": "趁热喝掉",
					"text": "汤暖到胃里，一路暖到手心。你舒服地呼出一口气。",
					"outcome": {"hp": 1},
				},
				{
					"name": "留给下一个影子",
					"sub": "留给下一个影子",
					"text": "你把碗推回桌心。走远时回头，字条上的字迹好像又清楚了一点。",
					"outcome": {},
				},
				{
					"name": "倒回锅里",
					"sub": "把汤倒回锅里",
					"text": "汤倒回去，火舌一舔，锅底发出很响的咕噜声。你的胃跟着抽了一下——那是饿。",
					"outcome": {"hp": -1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "果子树",
		"scene": "走廊正中长着一棵树，枝头挂满熟透的果子。树下躺着一个瘦长的影子，仰着头，就是够不着。",
		"gameplay": {
			"module": "sort",
			"hint": "把每张牌拖进一只筐；全部放好后按「收好」。",
			"left_label": "摘下来",
			"right_label": "留在树上",
			"capacity": 2,
			"capacity_side": "left",
			"settle": "果子归了各自的地方。影子仰头看看树上剩的，又蜷了蜷——像鞠了一躬，也像道别。",
			"cards": [
				{
					"name": "熟透",
					"sub": "红得发亮，压弯了枝。",
					"left": {"hp": 1},
					"right": {},
				},
				{
					"name": "半熟",
					"sub": "一半红一半青，捏着结实。",
					"left": {"hp": -1},
					"right": {"hp": 1},
				},
				{
					"name": "青果",
					"sub": "又小又硬，藏在高处。",
					"left": {"hp": -1},
					"right": {},
				},
				{
					"name": "树顶",
					"sub": "最高的那几颗，影子够不着。",
					"left": {"block": 1},
					"right": {"draw": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "后厨门",
		"scene": "走廊尽头是后厨的门，门缝里涌出滚烫的香味。门后传来切菜声，一下，一下，不快，也不停。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "推门看一眼",
					"sub": "推门看一眼",
					"text": "门后是空的，只有案板在响。香味扑出来把你浇透了，走出好远还饿。",
					"outcome": {"hp": -1},
				},
				{
					"name": "门外道谢",
					"sub": "在门外道声谢",
					"text": "你说「多谢款待」，转身要走。切菜声顿了半拍，从门缝里飘出一小股好闻的热气，扑在你脸上，像回礼。",
					"outcome": {"hp": 1},
				},
				{
					"name": "捂鼻快走",
					"sub": "捂紧鼻子快走",
					"text": "你捂着鼻子冲过去。香味在身后追了很久，才停下来。",
					"outcome": {},
				},
			],
		},
	},
]

const LAYER3_BOSS := {
	"type": "battle",
	"enemy": "别西卜",
	"enemy_hp": 28,
	"enemy_deck": LAYER3_ENEMY_DECK,
	"boss": true,
	"sin_card": "gluttony",
	"strip_lines": [
		"「吃饱了……」她捂着肚子跪坐下去，长桌一路退潮般空了出来。",
		"一团泛着油光的白影从她嘴里浮出来，还嚼着点什么，慢慢朝你飘。",
		"它闻了闻你，像在估量够不够分量。",
	],
	"purify_lines": [
		"别西卜打了个很响的饱嗝，睁开眼。",
		"「原来这东西不交出去，会越积越沉。」她拍拍肚子，苦笑，「谢谢，轻多了。」",
		"她抄起桌上最后一块点心塞给你：「拿着路上吃。上面那位更抠门——呃，我是说，更『讲究』。」",
		"长桌收了起来。她跟着你，往楼上走。",
	],
}

const LAYER3_TRANSITION := [
	"通往第四层的甬道口，脚步声又多了一道——三个人变成四个，别西卜走在最后，手指上还沾着糖霜。",
	"「提前说好：到了上面，谁都不许捡地上的钱。」她舔了舔手指，「捡了会走不动的，真的。」",
	"甬道尽头亮着金光。你隐约听见很远的地方，有人在数数。",
]

# —— 第 4 层 · 贪婪（池 12 ＝ 5 战 ＋ 7 事；节奏：从「拿走」到「放不下」——越走，身上越沉）——
const LAYER4_BATTLES := [
	{"type": "battle", "enemy": "守财偶", "enemy_hp": 20, "enemy_deck": LAYER4_ENEMY_DECK},
	{"type": "battle", "enemy": "金币堆", "enemy_hp": 22, "enemy_deck": LAYER4_ENEMY_DECK},
	{"type": "battle", "enemy": "账簿鬼", "enemy_hp": 24, "enemy_deck": LAYER4_ENEMY_DECK},
	{"type": "battle", "enemy": "上锁者", "enemy_hp": 26, "enemy_deck": LAYER4_ENEMY_DECK},
	{"type": "battle", "enemy": "拾遗者", "enemy_hp": 28, "enemy_deck": LAYER4_ENEMY_DECK},
]

const LAYER4_EVENTS := [
	{
		"type": "event",
		"title": "金山房",
		"scene": "整间屋子的地面铺满金币，一直没到脚踝。金堆尽头有一扇窄门，门上没有把手。",
		"gameplay": {
			"module": "sort",
			"hint": "把每张牌拖进一只筐；全部放好后按「收好」。",
			"left_label": "背走",
			"right_label": "留在原地",
			"capacity": 2,
			"capacity_side": "left",
			"settle": "你挑完了这一屋的金子。门在身后合上时，金币还在闪——跟你走的，只有你亲手拿的那些。",
			"cards": [
				{
					"name": "金锭",
					"sub": "压手，凉，沉得让人心安。",
					"left": {"hp": -1},
					"right": {},
				},
				{
					"name": "碎银",
					"sub": "散在金币缝里，闪着碎光。",
					"left": {},
					"right": {},
				},
				{
					"name": "怀表",
					"sub": "表盖刻着别人的名字，还在走。",
					"left": {"hp": -1, "draw": 1},
					"right": {},
				},
				{
					"name": "鹅卵石",
					"sub": "金堆里唯一一块普通石头。",
					"left": {"hp": -1, "block": 1},
					"right": {},
				},
				{
					"name": "金像",
					"sub": "巴掌高的小金像，重得离谱。",
					"left": {"hp": -2},
					"right": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "计数台",
		"scene": "一张高高的柜台横在路中间，台后悬着一本翻开的大账簿。路过的影子都在台前排队，报自己的名字。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "排队",
					"sub": "老老实实排队",
					"text": "队伍一步一挪，账页翻得哗哗响。轮到你时，你的名字早就被写好了。",
					"outcome": {},
				},
				{
					"name": "跳过柜台",
					"sub": "直接跳过柜台",
					"text": "你从柜台侧边翻了进去。笔尖在你身后追着划了一道，没够着。",
					"outcome": {},
				},
				{
					"name": "替影子写一笔",
					"sub": "替前面的影子写一笔",
					"text": "你替它写下名字。它回头的方向朝你顿了很久，把手里攥着的一颗小铜珠塞给你。攥着铜珠，你心里莫名踏实。",
					"outcome": {"hp": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "抵押行",
		"scene": "一间小抵押行，窗口挂着铃。柜台上摆着天平，一头压着别人的旧物，另一头空着，正等着什么。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "押上一样东西",
					"sub": "押上自己的一样东西",
					"text": "你放上去的不是物件，更像一段记忆。天平平了，你心里空出一小块，风灌进来，凉飕飕的。",
					"outcome": {"hp": -1, "draw": 1},
				},
				{
					"name": "问个路就走",
					"sub": "什么也不押，问个路就走",
					"text": "柜里传来一声哼：「没有押品，就没有路条。」但铃响了，侧门开了一条缝。",
					"outcome": {},
				},
				{
					"name": "把天平拨平",
					"sub": "把天平拨平",
					"text": "你伸手把天平拨平。柜台后没人出声，铃却轻轻地、像是笑了。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "保险柜",
		"scene": "墙里嵌着一排保险柜，柜门大多虚掩，只有一个锁得死死的。锁孔里透出一点温热的、金红色的光。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它——翻开即记账，随时可以停下。",
			"stop_label": "收手",
			"cards": [
				{
					"name": "一杯温水",
					"sub": "最下面一格，瓶壁还温。",
					"text": "虚掩的柜子大多空着，只有这瓶温水留了下来。你喝了两口，精神了些。",
					"outcome": {"hp": 1},
				},
				{
					"name": "金光",
					"sub": "锁孔里透出的那一点红金色。",
					"text": "你拧了很久。咔嚓一声，柜门开了条缝，金光涌出来割了你一下——柜子里只有更深的黑，和一个咕噜声。",
					"outcome": {"hp": -1},
				},
				{
					"name": "空柜",
					"sub": "虚掩着，一眼望到底。",
					"text": "柜里什么都没有，连灰都没有。你顺手替它合上了门。",
					"outcome": {},
				},
				{
					"name": "暗格",
					"sub": "柜底的夹层，你不确定里面有没有东西。",
					"text": "夹层里没有钱，只有一张折好的字条：「快的人先到。」你把字条收进袖口，脚步不知不觉快了起来。",
					"outcome": {"draw": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "账房的灯",
		"scene": "账房的窗亮着，里面有人打算盘，响声又密又急。窗台上放着一盏多余的灯，还没有点。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "点亮窗台的灯",
					"sub": "把窗台的灯点亮",
					"text": "你点亮窗台的灯。算盘声忽然慢了下来，像有人隔窗朝你这边看了一眼，又低下头。灯暖着你的侧脸。",
					"outcome": {"hp": 1},
				},
				{
					"name": "隔窗看一会儿",
					"sub": "隔着窗看一会儿",
					"text": "影子打算盘的手快得看不清，账本摞得比人还高——它一步也走不出来。",
					"outcome": {},
				},
				{
					"name": "不打扰，走过",
					"sub": "不打扰，走过去",
					"text": "你放轻脚步走过去。算盘声追到墙根，停住了。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "朝下的石像",
		"scene": "墙上嵌着一尊脸朝下的石像，双手伸向前方，像要抓住什么，又像被什么按住了。石像脚边散着几枚真金。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "抬起石像的脸",
					"sub": "把石像的脸抬起来",
					"text": "石像太沉，你只把它的脸抬起一点。石缝里落下些细灰，像一声很长的叹气终于呼了出来，你的心口也跟着松了松。",
					"outcome": {"hp": 1},
				},
				{
					"name": "捡走金币",
					"sub": "捡走脚边的金币",
					"text": "金币入手时，石像的指缝里渗出一缕黑气，缠上你的手腕。沉。",
					"outcome": {"hp": -1},
				},
				{
					"name": "学它站一会儿",
					"sub": "学它的姿势站一会儿",
					"text": "你弯下腰，脸朝下。世界倒了过来——金币、灰、脚下的路，全从眼前落下去。你赶紧站直。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "天平房",
		"scene": "一间空屋，正中立着一架巨大的天平：一端压着一座小小的金山，另一端是同样大的空盘，铁丝映着光。",
		"gameplay": {
			"module": "balance",
			"hint": "把牌拖上秤盘凑到目标值；拖回架上可以取下，凑好了按「称量」。",
			"target": 6,
			"settle": "你把东西一件件放上空盘。指针晃着，慢慢朝该停的地方落。",
			"cards": [
				{
					"name": "金币",
					"sub": "兜里翻出来的，只有一枚。",
					"weight": 1,
				},
				{
					"name": "一沓账纸",
					"sub": "用细绳捆着，潮乎乎的。",
					"weight": 2,
				},
				{
					"name": "小石像",
					"sub": "巴掌大的石像，掂着压手。",
					"weight": 3,
				},
				{
					"name": "金杯",
					"sub": "杯口干了一圈酒渍。",
					"weight": 2,
				},
				{
					"name": "一捧灰",
					"sub": "不知道是谁的，轻得几乎没有。",
					"weight": 1,
				},
			],
		},
	},
]

const LAYER4_BOSS := {
	"type": "battle",
	"enemy": "玛门",
	"enemy_hp": 32,
	"enemy_deck": LAYER4_ENEMY_DECK,
	"boss": true,
	"sin_card": "greed",
	"strip_lines": [
		"「……数不清了。」金币从她袖里一路滚出来，她不再伸手去拢。",
		"一团沉甸甸的金红色光影被她吐出来，压得地板吱呀作响。",
		"它在地上滚了半圈，停在你鞋前，像一枚等人捡起的硬币。",
	],
	"purify_lines": [
		"玛门站起来，抖了抖袖子，里面早已空空荡荡。",
		"「攥着的时候，什么都硌手；松开的时候，什么都不硌。」她把手摊开给你看，第一次笑了。",
		"「上面那层住着个照镜子的，看谁都像欠了她的。你见了就知道。」",
		"她把门推开，跟着你往上一层去——轻得像没人跟着。",
	],
}

const LAYER4_TRANSITION := [
	"上楼前，玛门忽然停下，把身上最后一点金屑弹掉：「空着手上路，第一次觉得不亏。」",
	"「上面那位照镜子照得入迷。」他头也不抬地提示，「你要是拿自己和镜子里的比，就永远走不完那段路。」",
	"第五层的风里有一种很轻的哼唱，忽远忽近，谁也没听懂是什么调子。",
]

# —— 第 5 层 · 嫉妒（池 12 ＝ 5 战 ＋ 7 事；节奏：走进一场不属于你的演出——越看，越分不清哪个是自己）——
const LAYER5_BATTLES := [
	{"type": "battle", "enemy": "效颦影", "enemy_hp": 22, "enemy_deck": LAYER5_ENEMY_DECK},
	{"type": "battle", "enemy": "镜中来客", "enemy_hp": 24, "enemy_deck": LAYER5_ENEMY_DECK},
	{"type": "battle", "enemy": "低语复读", "enemy_hp": 26, "enemy_deck": LAYER5_ENEMY_DECK},
	{"type": "battle", "enemy": "缝目者", "enemy_hp": 28, "enemy_deck": LAYER5_ENEMY_DECK},
	{"type": "battle", "enemy": "替补之影", "enemy_hp": 30, "enemy_deck": LAYER5_ENEMY_DECK},
]

const LAYER5_EVENTS := [
	{
		"type": "event",
		"title": "谢幕的舞台",
		"scene": "舞台的幕布刚落下一半，掌声还在响，台上却空无一人。聚光灯恋恋不舍地扫来扫去，像在等谁来谢幕。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "替他们谢幕",
					"sub": "走上台，替他们谢幕",
					"text": "你走上台，朝空座位鞠了一躬。聚光灯终于满意地暗下去，掌声也散成了风。你直起腰，肩背松快了些。",
					"outcome": {"hp": 1},
				},
				{
					"name": "站在侧幕",
					"sub": "站在侧幕看着",
					"text": "你站在侧幕。聚光灯一遍遍扫过，每一次都差一点照到你，每一次都停住。",
					"outcome": {},
				},
				{
					"name": "走到台后",
					"sub": "掀开幕布走到台后去",
					"text": "幕布后面是一条安静的走道。你回头最后看了一眼舞台，它正等着下一场谢幕。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "针线长廊",
		"scene": "两侧墙上插满针，线在廊顶织成一张稀薄的网。走到中段，你发现自己的影子被一根线轻轻勾住了。",
		"gameplay": {
			"module": "sort",
			"hint": "把每张牌拖进一只筐；全部放好后按「收好」。",
			"left_label": "带走",
			"right_label": "留下",
			"capacity": 1,
			"capacity_side": "left",
			"settle": "长廊尽头，线网轻轻晃着。你的影子还跟着你——完不完整，只有你自己知道。",
			"cards": [
				{
					"name": "银线",
					"sub": "细得几乎看不见，泛着凉光。",
					"left": {"draw": 1},
					"right": {},
				},
				{
					"name": "金线",
					"sub": "绷得很直，像随时会断。",
					"left": {"block": 1},
					"right": {},
				},
				{
					"name": "灰线",
					"sub": "最粗的一根，另一头不知牵着谁。",
					"left": {"hp": -1},
					"right": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "重影卧室",
		"scene": "卧室的床铺得整整齐齐，墙上钉着一排一模一样的照片。照片里的人笑得一样，穿得一样，连影子都折在同一个角度。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "翻过照片",
					"sub": "把照片逐一翻过去",
					"text": "你一张张翻面。翻到最后一张，背面有一行小字：「我也想做我自己。」照片贴回墙面时，屋里的光正了过来。",
					"outcome": {"hp": 1},
				},
				{
					"name": "躺下休息",
					"sub": "躺到床上合眼休息一会",
					"text": "床很软，一躺下就睡沉了。醒的时候，你分不清是自己醒的，还是照片里的人替你醒的。",
					"outcome": {"hp": -1},
				},
				{
					"name": "练习他们的笑",
					"sub": "对着照片里的笑练习",
					"text": "你对着练习笑。练着练着，照片里的人也跟着你换了个笑法。房间安静了一下。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "榜单",
		"scene": "楼梯口贴着一张长长的榜单，从上到下写满了名字。你的名字在很下面的地方，紧挨着一条被反复涂改的横线。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "写下自己的名字",
					"sub": "在横线上写下自己的名字",
					"text": "你添上自己的名字，笔迹压过涂改的痕迹。榜单轻轻抖了抖，你耳边那点嗡嗡声停了。",
					"outcome": {"hp": 1},
				},
				{
					"name": "看着出神",
					"sub": "看着别人的名字出神",
					"text": "你看得太久，那些名字一个个往上爬——你觉得自己在往下沉。",
					"outcome": {"hp": -1},
				},
				{
					"name": "揭下榜单叠好",
					"sub": "把榜单揭下来叠好",
					"text": "你把榜单叠成小方块收好。墙上留下一道浅印，像谁松了口气的痕。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "望远镜",
		"scene": "窗台上架着一副望远镜，镜筒正对着楼下的什么地方。凑近看，视野里全是别人：别人走在前面，别人被簇拥着，别人笑得很好。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它——翻开即记账，随时可以停下。",
			"stop_label": "放下望远镜",
			"cards": [
				{
					"name": "别人的笑",
					"sub": "聚在楼下，笑得很亮。",
					"text": "你看了很久。眼睛酸得厉害，远方的笑声却越来越清楚——清楚得不像别人的。",
					"outcome": {"hp": -1},
				},
				{
					"name": "别人的位置",
					"sub": "前排正中，一直有人站着。",
					"text": "那个位置站着人，换了一个又一个，都站得很稳。你放下了望远镜。",
					"outcome": {},
				},
				{
					"name": "树",
					"sub": "窗外最近的东西，一直被忽略。",
					"text": "树就在那儿，不声不响。叶子被风翻过来，又翻回去——看了会儿，眼睛舒服了些。",
					"outcome": {},
				},
				{
					"name": "台阶",
					"sub": "镜筒转到最后，停住的地方。",
					"text": "镜里出现了你走过的台阶：一段一段，都是你自己踩出来的。你把望远镜扶正——下一次上路，你会走得更快些。",
					"outcome": {"hp": 1, "draw": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "回声井",
		"scene": "回廊正中有一口井。所有掉进去的声音都会先变成别人的声音，再弹回来——连你刚才的脚步声，回上来的也是陌生的腔调。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它——翻开即记账，随时可以停下。",
			"stop_label": "离开井边",
			"cards": [
				{
					"name": "碎声",
					"sub": "七嘴八舌，把你的名字念得又碎又长。",
					"text": "你喊了名字。井里先回了一串七嘴八舌的声音，把你的名字念得又碎又长。你眼前晃了晃，扶住了井沿。",
					"outcome": {"hp": -1},
				},
				{
					"name": "换腔调",
					"sub": "你听过的每句话，都被换了腔调。",
					"text": "别人的声音一层一层从井里涌上来，把你说过的每句话都换了腔调。你听着，像在听别人的一生。",
					"outcome": {},
				},
				{
					"name": "别人的名字",
					"sub": "井里替你喊出的那些名字。",
					"text": "一张嘴在井里喊你的名字，喊到一半，换成了别人的。你没有纠正它，只是听着。",
					"outcome": {},
				},
				{
					"name": "越往下",
					"sub": "再下面一层，听不真切。",
					"text": "你越把耳朵往里贴，声音越低。最下面那层像是有什么在等着回应——你直起了腰。",
					"outcome": {},
				},
				{
					"name": "自己的声音",
					"sub": "最底下那一层，很小，但很真。",
					"text": "你站了很久，终于听见最底下那一层：是你自己的声音，很小，但很真。你把它从井里捞了上来——往后的路，你说了算。",
					"outcome": {"hp": 1, "draw": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "空椅子",
		"scene": "楼梯平台上并排摆着两张椅子，一张坐着一个安静的孩子，另一张空着。孩子的目光望着空椅子，像在等一个总也不来的人。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "坐到空椅子上",
					"sub": "坐到空椅子上",
					"text": "你坐下。孩子转过头看你，看了很久，忽然说：「你好久没来了。」你没有辩解，只是坐着。起身时，那把椅子已经凉了。",
					"outcome": {},
				},
				{
					"name": "陪它等一会",
					"sub": "蹲下来陪孩子等一会",
					"text": "你蹲下来，陪它等。等了很久，孩子轻轻靠过来，在你肩上睡着了。你把它扶稳，站起身，心里软了一块。",
					"outcome": {"hp": 1},
				},
				{
					"name": "绕过椅子",
					"sub": "轻手轻脚绕过椅子",
					"text": "你绕过去。两把椅子在你身后并排站着，影子叠成一个。",
					"outcome": {},
				},
			],
		},
	},
]

const LAYER5_BOSS := {
	"type": "battle",
	"enemy": "利维坦",
	"enemy_hp": 36,
	"enemy_deck": LAYER5_ENEMY_DECK,
	"boss": true,
	"sin_card": "envy",
	"strip_lines": [
		"「原来我不是她……」她的影子散了又聚，聚了又散。",
		"一团泛着冷光的白影从影子里剥离出来，像撕下的一张薄薄的纸。",
		"它贴着地面挪向你，纸边抖得很轻，像在问：像不像？",
	],
	"purify_lines": [
		"利维坦捡起自己的影子重新披上，这回纹路和谁都不重了。",
		"「我照着别人活了好多年。」她低头看了看自己的手。「现在这双手，是我的。」",
		"她替你拂掉肩上的线头：「上面那位，把自己看成天上的星星。你帮我把她也叫下来吧。」",
		"走廊上，你们的脚步声一前一后——一不一样，都听得出来是两个人在走。",
	],
}

const LAYER5_TRANSITION := [
	"通往第六层的台阶开始变窄，开始变亮，亮得像是有人在上面擦了又擦。",
	"「她站在最高处，把我们都看成台阶。」利维坦把针线收进袖口，「你上去的时候别抬头看她，看她身后的路就好。」",
	"光越来越亮。你眯起眼，看见台阶的尽头有一束笔直的聚光灯。",
]

# —— 第 6 层 · 傲慢（池 15 ＝ 7 战 ＋ 8 事；节奏：一路向上——台阶变窄、光变亮，直到只剩一束聚光灯打在你身上）——
const LAYER6_BATTLES := [
	{"type": "battle", "enemy": "高塔守望", "enemy_hp": 24, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "折光使", "enemy_hp": 25, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "台阶卫", "enemy_hp": 27, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "背石傀", "enemy_hp": 28, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "晨星残影", "enemy_hp": 30, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "俯瞰群", "enemy_hp": 31, "enemy_deck": LAYER6_ENEMY_DECK},
	{"type": "battle", "enemy": "灯影卫", "enemy_hp": 32, "enemy_deck": LAYER6_ENEMY_DECK},
]

const LAYER6_EVENTS := [
	{
		"type": "event",
		"title": "最高处的房间",
		"scene": "塔顶的房间小得出奇，一桌一椅一窗。从窗口望出去，来时所有的层都踩在脚下，小得像积木。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它——翻开即记账，随时可以停下。",
			"stop_label": "离开房间",
			"cards": [
				{
					"name": "森林",
					"sub": "窗外最远处，绿得像假的。",
					"text": "你趴在窗沿上看了很久。风把森林的气味带上来——是活的。你站直的时候，呼吸顺了。",
					"outcome": {"hp": 1},
				},
				{
					"name": "粉雾",
					"sub": "楼下的一切都泡在雾里。",
					"text": "雾浮在楼下，慢慢淌。看久了，那些层数都模糊了，分不清哪层是哪层。",
					"outcome": {},
				},
				{
					"name": "坠落错觉",
					"sub": "盯着楼下看，脚下会发软。",
					"text": "你盯着最底下看，地板忽然像变成了云。你抓住窗框——只是错觉，可心跳了很久。",
					"outcome": {"hp": -1},
				},
				{
					"name": "台阶",
					"sub": "来时的台阶，一阶不落。",
					"text": "你数了数来时的台阶，一阶一阶，都还在。你扶着窗框站了很久才关上窗——关窗的时候，手很稳。",
					"outcome": {"block": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "空王座",
		"scene": "大厅尽头是一张高背王座，扶手磨得发亮，座面上落着一根羽毛。没有人在，但整个大厅都在朝那个方向安静着。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "坐一次试试",
					"sub": "走上去，坐一次试试",
					"text": "你坐上去，风从四面八方朝你朝拜。起身时你晃了一下——有种什么东西留在了座位上，没跟你下来。",
					"outcome": {"hp": -1},
				},
				{
					"name": "放回羽毛",
					"sub": "把羽毛放回座面",
					"text": "你捡起羽毛，轻轻放回座面。羽毛落稳，大厅里有什么东西松了下来，你也是。",
					"outcome": {"hp": 1},
				},
				{
					"name": "看一会走开",
					"sub": "远远地看一会就走开",
					"text": "你在门槛外站了会，看那根羽毛在光里慢慢转。然后退了出去。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "聚光灯",
		"scene": "楼梯间的穹顶垂下一束聚光灯，正打在一段空台阶上。它不照亮别处，也照不到别处。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "站进光里",
					"sub": "走到光里试试",
					"text": "你站进光里，所有的影子都退到了你身后。暖是暖的，可你很快发现——站在这里，什么都看不清，只看得到自己。",
					"outcome": {"hp": -1},
				},
				{
					"name": "贴墙避开",
					"sub": "贴着墙避开光柱",
					"text": "你贴着墙根走。光柱在你身边笔直地立着，像一根够不着任何东西的手指。",
					"outcome": {},
				},
				{
					"name": "找灯的开关",
					"sub": "抬头找灯的开关",
					"text": "你仰头找开关，只看到垂下来的灯线，上面没有按钮，也没有灯座。那束光就这么悬着，谁都没点。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "雕像广场",
		"scene": "天台是一片广场，广场上立满了石像，每一尊都昂着头，望向更高处。没有一尊低头，也没有一尊看身边的人。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "陪它们望一会",
					"sub": "仰头陪石像们望一会",
					"text": "你陪它们望了很久。高处只有云，云后面什么都没有。脖子酸的时候，你低下了头。",
					"outcome": {},
				},
				{
					"name": "扶石像坐下",
					"sub": "把一尊石像扶得坐下来",
					"text": "你使劲扳动石像。石像坐下的一瞬，它的视线第一次落在了旁边的石像身上。石屑簌簌往下掉，像卸了一口气。你的手臂酸得发胀，心口却松快。",
					"outcome": {"hp": 1},
				},
				{
					"name": "穿过石像",
					"sub": "从石像之间穿过去",
					"text": "你从石像之间走过。它们的影子在你脚下拼成了一条路，路的尽头还是更高处。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "坠落点",
		"scene": "广场边缘的地面上有一个浅浅的坑，坑里嵌着一颗石头，烧得发黑，边缘还残留着划开天空的痕迹。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它；全部翻开，还有额外的回报。",
			"stop_label": "离开坑边",
			"cards": [
				{
					"name": "很高",
					"sub": "石头上残留的划痕，指向最顶上。",
					"text": "你抚着那道划痕往上看——高得看不见头。石头是从那么高的地方掉下来的，孤零零的。",
					"outcome": {},
				},
				{
					"name": "一路烧下来",
					"sub": "焦黑的边缘，一路烧到这里。",
					"text": "你看见了它来的那条路——从最高最高处一路烧下来，每块蹭过的石头都还留着焦痕。你的手抖了一下。",
					"outcome": {"hp": -1},
				},
				{
					"name": "没有人接",
					"sub": "坑底很平，没有人站过的痕迹。",
					"text": "你是第一个到这坑边的人。它落在这么深的地方，谁也没接住它。你膝盖磕在坑沿上才没跪下去。",
					"outcome": {"hp": -1},
				},
			],
			"finish": {
				"text": "你把石头从坑里捧出来，又轻轻放回——这一次，它是被放下的。掌心热热的，你站起身，决定走快些。",
				"outcome": {"hp": 1, "draw": 1},
			},
		},
	},
	{
		"type": "event",
		"title": "负重阶梯",
		"scene": "一段台阶斜插进塔身，台阶上排着一列影子，每人背上都压着一块大石头，一级一级地往上挪。",
		"gameplay": {
			"module": "balance",
			"hint": "把牌拖上秤盘凑到目标值；拖回架上可以取下，凑好了按「称量」。",
			"target": 4,
			"settle": "你从台阶边挑出要替影子捎上的分量。压肩，但走得动。",
			"cards": [
				{
					"name": "一根手杖",
					"sub": "靠在台阶边，木质发亮。",
					"weight": 1,
				},
				{
					"name": "一摞旧书",
					"sub": "用皮带捆着，沉甸甸。",
					"weight": 2,
				},
				{
					"name": "满水的水壶",
					"sub": "一提就晃，水声很满。",
					"weight": 2,
				},
				{
					"name": "压肩的石枕",
					"sub": "影子的行囊，磨得圆圆润润。",
					"weight": 3,
				},
			],
		},
	},
	{
		"type": "event",
		"title": "报幕台",
		"scene": "半层平台搭着一个小小的报幕台，台本摊开着，上面写着你的名字，后面跟着一段没写完的定语。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "接着写下去",
					"sub": "接着那半句话写下去",
					"text": "你提笔把定语写完——写的是你自己的字。台本亮了一下，纸页间的褶皱展开了大半。",
					"outcome": {"hp": 1},
				},
				{
					"name": "改成「她」",
					"sub": "把「你」改成「她」",
					"text": "你把「你」划掉，写上「她」。台本困惑地翻了两页，最后把那一行整段删掉了。",
					"outcome": {},
				},
				{
					"name": "合上台本",
					"sub": "合上台本",
					"text": "你合上台本。台下没有观众，你却还是朝台下亮了亮手掌，像谢了幕。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "加冕台",
		"scene": "塔顶正中立着一座圆台，台上悬着一顶冠冕，金漆剥落，里衬却是软的，像被人试戴过很多次。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "走到台上站定",
					"sub": "走上台，一个人站定",
					"text": "你在台上站定，风停了，一切都望着你。你站了很久，久到忘了自己原本要往哪里去。走下台时，腿是麻的。",
					"outcome": {"hp": -1},
				},
				{
					"name": "摆正冠冕",
					"sub": "把冠冕摆正扶稳",
					"text": "你踮起脚，把冠冕摆正。里衬柔软，贴着你的指尖。安心的一小团温度，顺着手心传上来。",
					"outcome": {"hp": 1},
				},
				{
					"name": "从台下绕开",
					"sub": "从台下绕一圈离开",
					"text": "你从台下绕过去。冠冕在台上轻轻转着，像在挑人。",
					"outcome": {},
				},
			],
		},
	},
]

const LAYER6_BOSS := {
	"type": "battle",
	"enemy": "路西法",
	"enemy_hp": 40,
	"enemy_deck": LAYER6_ENEMY_DECK,
	"boss": true,
	"sin_card": "pride",
	"strip_lines": [
		"「……落下来了。」她缓缓跪下去，塔顶的风忽然柔了。",
		"一团亮得刺眼的白影从她背后展开——像收不拢的翅膀，又像一件不肯脱下的礼服。",
		"它悬在半空，居高临下地打量你，像在考虑要不要搭理。",
	],
	"purify_lines": [
		"路西法撑着膝盖站起来，背后空荡荡的，人却站得很直。",
		"「站得越高，越觉得风是自己生的。」她自嘲地哼了一声。「刚才摔那一下，看清楚了。」",
		"「最后一位在最底下烧着，火气比谁都大。」她往下看了一眼。「我们陪你到底。」",
		"她与你并肩下楼，脚步和台阶一样平。",
	],
}

const LAYER6_TRANSITION := [
	"第六层到第七层的路是往下走的——火焰在低处烧，热是从脚下漫上来的。",
	"「她是最早来的，也是烧得最久的。」路西法走在你身侧，「火熄那天，她自己都忘了怎么不生气。你下去的时候，小心烫。」",
	"台阶尽头，黑烟贴着地面翻滚。远处一声很闷的响，像有什么在忍着。",
]

# —— 第 7 层 · 暴怒（池 15 ＝ 8 战 ＋ 7 事；节奏：火一路烧到山顶——最后只剩你和她）——
const LAYER7_BATTLES := [
	{"type": "battle", "enemy": "余烬行者", "enemy_hp": 26, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "怒号", "enemy_hp": 27, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "焚印傀儡", "enemy_hp": 29, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "烟幕行者", "enemy_hp": 30, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "钟摆", "enemy_hp": 32, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "引线鼠", "enemy_hp": 33, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "攥拳偶", "enemy_hp": 35, "enemy_deck": LAYER7_ENEMY_DECK},
	{"type": "battle", "enemy": "闷雷", "enemy_hp": 36, "enemy_deck": LAYER7_ENEMY_DECK},
]

const LAYER7_EVENTS := [
	{
		"type": "event",
		"title": "烙印室",
		"scene": "屋里摆着一排烙铁，都还红着。墙上密密麻麻烙满了记号，最深的一道，还冒着细烟。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "按下最浅的记号",
					"sub": "伸手按上最浅的那个记号",
					"text": "记号的形状贴着你的掌心，一下烙进皮肉里。你咬住牙没出声，眼前白了一阵。再看时，墙上多了一道很浅的新痕。",
					"outcome": {"hp": -2},
				},
				{
					"name": "拾起烙铁",
					"sub": "拾起一块烙铁看看",
					"text": "烙铁比预想的重。你捏了一下就赶紧放下，指尖燎起一个亮晶晶的泡。",
					"outcome": {"hp": -1},
				},
				{
					"name": "吹熄炉火",
					"sub": "吹熄炉火",
					"text": "你对着炉膛吹气，火晃了晃，真的暗下去一格。屋里暗下来，你手上的影子也安静了。",
					"outcome": {"hp": 1},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "黑烟走廊",
		"scene": "走廊里全是黑烟，浓得能看见它的流动。烟里偶尔亮起一双眼睛，看一眼，又熄掉。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "屏息穿过去",
					"sub": "屏住呼吸直穿过去",
					"text": "你屏着气冲过去。烟灌进肺里，又苦又呛，咳了半天才咳干净。",
					"outcome": {"hp": -1},
				},
				{
					"name": "对眼睛说话",
					"sub": "对着烟里的眼睛说话",
					"text": "你轻声说「借过」。烟顿了顿，朝两边分开，留出一步宽的缝。那双眼睛亮了一下，是道谢的意思。",
					"outcome": {},
				},
				{
					"name": "点起火把",
					"sub": "点一盏火把照过去",
					"text": "你点起火把。烟被照得退了退，又缓缓围回来。火光里，你看见烟并不想烧谁，只是太浓了，散不开。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "无人裁判的擂台",
		"scene": "山谷里搭着一座擂台，围绳歪着，地上有新旧交叠的脚印。台角坐着一个影子，抱着膝盖，肩背一鼓一鼓的。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "陪影子打一场",
					"sub": "上台，陪影子打一场",
					"text": "你们打了很久。拳头砸到影子上像砸进雾里，它的每一拳却都落实。终场哨没人吹，你扶着围绳下来，浑身是汗。",
					"outcome": {"hp": -1},
				},
				{
					"name": "台边等它",
					"sub": "坐到台边等它自己站起来",
					"text": "你坐在台边等。等到风把山谷吹凉，影子慢慢抬起头，自己站了起来。它朝你低了低头，你胸口那股闷劲也跟着落下去。",
					"outcome": {"hp": 1},
				},
				{
					"name": "绷直围绳",
					"sub": "把歪掉的围绳重新绷直",
					"text": "你把围绳一根根绷直。擂台在你手下颤了颤，像是很多年了，第一次有人肯碰这些绳子。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "碎片拼盘",
		"scene": "石桌上摊着一堆碎片，来自某种很贵的东西。旁边立着一张小卡：「是谁摔的，就由谁来拼。」",
		"gameplay": {
			"module": "balance",
			"hint": "把牌拖上秤盘凑到目标值；拖回架上可以取下，凑好了按「称量」。",
			"target": 5,
			"settle": "你挑出碎片，一块块往石桌上的缺口上比。轮廓渐渐清楚起来。",
			"cards": [
				{
					"name": "小碎片",
					"sub": "指甲盖大，边缘锋利。",
					"weight": 1,
				},
				{
					"name": "带花纹的碎片",
					"sub": "釉面上缠着半朵花。",
					"weight": 2,
				},
				{
					"name": "温热的碎片",
					"sub": "攥在手里，居然不凉。",
					"weight": 2,
				},
				{
					"name": "最大的那块",
					"sub": "断口很新，像刚摔的。",
					"weight": 3,
				},
			],
		},
	},
	{
		"type": "event",
		"title": "沸水缸",
		"scene": "路中间架着一口大缸，水滚得翻花，缸沿上搁着两只碗，一只盛着凉水，一只扣着盖子。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它；全部翻开，还有额外的回报。",
			"stop_label": "绕开",
			"cards": [
				{
					"name": "湿柴",
					"sub": "泡得发胀，扔在缸边。",
					"text": "湿柴上还挂着水。你捏了捏——这样的柴，点不着，只能冒着白气慢慢地熬。",
					"outcome": {},
				},
				{
					"name": "干柴",
					"sub": "劈得整整齐齐，码在火边。",
					"text": "干柴裂着新茬，就等着被送进火里。你看了一眼，没有动它。",
					"outcome": {},
				},
				{
					"name": "火星柴",
					"sub": "烧了一半，火星一明一暗。",
					"text": "你去够它，火星跳上你的手背——烫。缸里的水还滚着，白汽撩过的地方火辣辣的。",
					"outcome": {"hp": -1},
				},
			],
			"finish": {
				"text": "你把柴一根根从火里抽出来。缸里的滚声慢慢地、慢慢地，变成了一点点冒泡的呼吸声——火熄了。刚才烫过的地方，像被谁吹过一口凉气。",
				"outcome": {"hp": 1, "block": 1},
			},
		},
	},
	{
		"type": "event",
		"title": "揉皱的信",
		"scene": "台阶上落着一封揉皱的信，纸面被攥得发亮。展开一看，字全是同一个字压着同一个字写的，浓得透纸。",
		"gameplay": {
			"module": "pick",
			"hint": "把一张牌拖进行动槽，再按「执行」——选哪张由你。",
			"cards": [
				{
					"name": "抚平读完",
					"sub": "把它抚平读完",
					"text": "你一个字一个字地认。满纸的火从字里窜出来，烧得你眼睛发酸、指尖发抖。读完最后一个字，你发现自己攥紧了拳头。",
					"outcome": {"hp": -1},
				},
				{
					"name": "揉回去放好",
					"sub": "照原样揉回去放好",
					"text": "你照着原来的褶皱把它揉回去，放回原处。纸页服帖地躺在台阶上，仿佛松了口气。你心里的褶皱，也平了一点。",
					"outcome": {"hp": 1},
				},
				{
					"name": "收进衣袋",
					"sub": "把信折好收进衣袋",
					"text": "你把信折成小方块收好。衣袋里从此暖着一小团，你说不清是安慰，还是催促。",
					"outcome": {},
				},
			],
		},
	},
	{
		"type": "event",
		"title": "先吼的谷",
		"scene": "山谷两侧的岩壁一层叠着一层，越往深处走，回声越响。这里只有一个规矩：谁先吼，谁的回声可以盖过别人的。",
		"gameplay": {
			"module": "reveal",
			"hint": "拖走一张牌就翻开它；全部翻开，还有额外的回报。",
			"stop_label": "走出谷口",
			"cards": [
				{
					"name": "你的声音",
					"sub": "第一嗓子出去，弹回来的回声。",
					"text": "你朝谷里吼了一嗓子。回声弹回来——第一层还是你的声音，直直的，没有拐弯。",
					"outcome": {},
				},
				{
					"name": "别人的",
					"sub": "第二层回声，听着耳生。",
					"text": "再往深处，回声变成了别人的、陌生的腔调。它们学着你吼，学得不像，还越学越凶。",
					"outcome": {"hp": -1},
				},
				{
					"name": "更大的",
					"sub": "压回来的那一浪，比你吼的大。",
					"text": "一浪一浪压回来，把你的声音盖成了别人的、更大的、更凶的。你站在声浪里，耳朵嗡嗡作响。",
					"outcome": {"hp": -1},
				},
			],
			"finish": {
				"text": "你不再吼了。你压低嗓子轻轻哼了一句——山谷顿了顿，把它原样送回来：不轻不重，是你自己的调子。最底下那层回音里，你的名字被稳稳托着。",
				"outcome": {"hp": 2, "block": 1},
			},
		},
	},
]

const LAYER7_BOSS := {
	"type": "battle",
	"enemy": "萨麦尔",
	"enemy_hp": 44,
	"enemy_deck": LAYER7_ENEMY_DECK,
	"boss": true,
	"sin_card": "anger",
	"strip_lines": [
		"「……烧完了。」火焰一层层从她身上褪去，黑烟散进塔顶的夜空。",
		"一团还烫着的白影被她按在掌心里，挣扎了两下，安静了。",
		"她摊开手，让你看清楚：它还在烧，只是不烫人了。",
	],
	"purify_lines": [
		"萨麦尔松了松肩膀，骨节响了一串，像火在烧尽的柴上最后回了个声。",
		"「恨这种东西，攥着烧手，交出去才知道自己拎了多久。」她把手插进口袋。「给你了。」",
		"她走到塔边，望向结界最深处的方向：「下面……就剩最后一位了。」",
		"「歇一晚吧。」她背对着夜色说，「从底下到这里，你已经走得够远了。」",
	],
}

# 第 7 层完成＝本段内容边界：过渡读白兼待续钩子（第 8 层＝同位体终局专轮）
const LAYER7_TRANSITION := [
	"通往第八层的台阶从塔顶升起，一阶一阶，通向结界最深的夜色里。",
	"「上面那位……」萨麦尔望着夜色，难得顿了顿，「见了你就知道了。」",
	"风从最深处卷上来，卷着一点很轻的、熟悉的气息。你们往上走——台阶很长，但已经没有回头路。",
]

# —— 按层汇总（generate_route/_boss_node/transition_lines 的取数入口）——
const LAYER_BATTLES := {2: LAYER2_BATTLES, 3: LAYER3_BATTLES, 4: LAYER4_BATTLES, 5: LAYER5_BATTLES, 6: LAYER6_BATTLES, 7: LAYER7_BATTLES}
const LAYER_EVENTS := {2: LAYER2_EVENTS, 3: LAYER3_EVENTS, 4: LAYER4_EVENTS, 5: LAYER5_EVENTS, 6: LAYER6_EVENTS, 7: LAYER7_EVENTS}
const LAYER_BOSSES := {2: LAYER2_BOSS, 3: LAYER3_BOSS, 4: LAYER4_BOSS, 5: LAYER5_BOSS, 6: LAYER6_BOSS, 7: LAYER7_BOSS}
const LAYER_TRANSITIONS := {2: LAYER2_TRANSITION, 3: LAYER3_TRANSITION, 4: LAYER4_TRANSITION, 5: LAYER5_TRANSITION, 6: LAYER6_TRANSITION, 7: LAYER7_TRANSITION}


# 各层路线总列数区间（含末列层主战）
static func route_length_range(layer: int) -> Vector2i:
	var bounds: Vector2i = ROUTE_LENGTH.get(layer, ROUTE_LENGTH[2])
	return bounds


static func layer_name(layer: int) -> String:
	return String(LAYERS.get(layer, {}).get("name", ""))


static func demon_name(layer: int) -> String:
	return String(LAYERS.get(layer, {}).get("demon", ""))


# 净化后同行显示名（双名制）：有登记用人身名，否则回退恶魔名（design-round11）
static func companion_name(layer: int) -> String:
	return String(LAYER_COMPANIONS.get(layer, demon_name(layer)))


# 节点显示名「类型·名称」（地图节点按钮与确认窗标题共用；design-round5.md §1）
static func node_label(stage: Dictionary) -> String:
	var type_label := "事件"
	if stage.get("boss", false):
		type_label = "层主战"
	elif String(stage.get("type", "")) == TYPE_BATTLE:
		type_label = "作战"
	var node_name := String(stage.get("enemy", stage.get("title", "")))
	return "%s·%s" % [type_label, node_name]


# 进层随机生成路线：总列数＝route_length_range(layer)（随层拉长；末列＝层主战唯一节点），
# 普通列每列 1–3 节点（分支上限 3）。节点从该层池洗牌后顺序取：同列必不重复；全图尽量不重复，
# 池耗尽后循环补足（层高线长时需求可等于池容量×循环）。教程层／第 8 层（待专轮）＝空路线。
static func generate_route(layer: int, rng: RandomNumberGenerator) -> Array:
	if layer == TUTORIAL_LAYER or layer > LAST_PLAYABLE_LAYER:
		return []
	var pool: Array = []
	pool.append_array(LAYER_BATTLES.get(layer, []))
	pool.append_array(LAYER_EVENTS.get(layer, []))
	if pool.is_empty():
		return []
	var route := _build_route(pool, route_length_range(layer), rng)
	route.append([_boss_node(layer)])
	return route


static func _build_route(pool: Array, bounds: Vector2i, rng: RandomNumberGenerator) -> Array:
	var normal_columns := rng.randi_range(bounds.x, bounds.y) - 1
	var order := _shuffled_indices(pool.size(), rng)
	var cursor := 0
	var used := {}
	var route: Array = []
	for c in normal_columns:
		var node_count := rng.randi_range(ROUTE_MIN_NODES, ROUTE_MAX_NODES)
		var column: Array = []
		var column_indices: Array[int] = []
		for n in node_count:
			if used.size() >= pool.size():
				used.clear()
			while true:
				var index: int = order[cursor % order.size()]
				cursor += 1
				if column_indices.has(index) or used.has(index):
					continue
				used[index] = true
				column_indices.append(index)
				column.append(pool[index])
				break
		route.append(column)
	return route


# 末列层主：各层三键（sin_card／strip_lines／purify_lines）必填——缺失会让 STRIP 阶段卡死
static func _boss_node(layer: int) -> Dictionary:
	var boss: Dictionary = LAYER_BOSSES.get(layer, {})
	return boss


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
	var lines: Array = LAYER_TRANSITIONS.get(layer, [])
	return lines


static func has_content(layer: int) -> bool:
	return layer == TUTORIAL_LAYER or layer <= LAST_PLAYABLE_LAYER
