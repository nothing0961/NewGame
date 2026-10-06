class_name LayerConfig
extends RefCounted

# 层循环数据（design/design-round3.md；层内路线图＋分支随机化＋拉长/横滚见 design/design-round4.md，定案 2026-10-05）。
# 第 2–7 层名录＝design/design-round7.md（2026-10-06 定）；数值与事件效果实装＝design/design-round8.md。
# 层＝分支路线图：若干「列」（每列＝一步），列内多节点选一；层主战＝最后一列（净化的唯一发生点）。
# 路线进层随机生成（generate_route）：总列数随层数拉长、节点从该层池抽取（池容量＝该层单图最大需求）；死亡重掷。
# 事件选项效果（design-round8.md §4）：effects 与 choices 下标对齐；本轮词汇仅 {"hp": ±n}＝入场 HP 修正（负伤/疗愈）。
# 第 1 层（懒惰·贝尔芬格）＝教程层特化编排，不走本表路线；第 8 层（同位体）＝终局专轮，has_content=false。

const TUTORIAL_LAYER := 1
const MAX_LAYER := 8
# demo 边界：有内容的最后一层（教程层另计）；第 8 层留终局专轮
const LAST_PLAYABLE_LAYER := 7
# 第 1 层同行者＝净化后恢复人身的菲戈蕾（双名制，用户定 2026-10-05）；
# 层表/地图层行仍显示「贝尔芬格」＝污染形态名。第 2–7 层净化后同行层主用恶魔名（design-round7.md 决案 2）
const LAYER1_COMPANION := "菲戈蕾"

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
		"choices": ["把演出服抚平挂好", "问镜中的自己：我是谁", "后退，离开更衣间"],
		"feedback": [
			"布料软得像雾。你抚平它，镜里的灯亮了一格——照得你肩上暖了一小块。",
			"镜里的你张了张嘴，发出的却是别人的声音：「快了，快轮到你登场了。」",
			"你退到门口。镜子在你身后转了个角度，一直照着你，直到门合上。",
		],
		"effects": [{"hp": 1}, {}, {}],
	},
	{
		"type": "event",
		"title": "糖果摊",
		"scene": "走道边支着一个小糖果摊，摊主不在。粉色的糖在玻璃罐里轻轻翻动，像一群想出来的蝴蝶。",
		"choices": ["拿一颗尝尝", "把打翻的糖纸叠好", "快步走开"],
		"feedback": [
			"糖化在舌尖，甜得头发晕。走出去好远，那股甜还坠在胸口，闷闷的。",
			"你把糖纸一张张叠成小摞。风穿过摊位时，那摞纸轻轻拍了拍你的手背，手背于是轻快了一点。",
			"你目不斜视地走过。玻璃罐在身后晃了晃，像叹了口气。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "合唱席",
		"scene": "一排排空椅子上方飘着整齐的哼唱，声部齐全，只是一个人也没有。正中间留着一个空位，椅背上搭着副耳返。",
		"choices": ["坐下来听一整段", "站上指挥台挥手", "绕过椅子继续走"],
		"feedback": [
			"歌声顺着椅背爬上来，把你的力气也卷进和声里。起身时，腿是软的。",
			"你抬手一挥，合唱齐齐停了半拍，又接上。空椅子上轻轻起了一阵笑意——那笑意拂过你，把你托稳了些。",
			"你贴着墙绕过去。歌声一直唱到你看不见的地方。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "粉焰之墙",
		"scene": "通道尽头立着一面墙，粉色的火沿墙根慢慢烧，没有烟，也不烫人，只把去路映得发软。",
		"choices": ["屏住呼吸穿过去", "绕远路", "伸手碰一碰火苗"],
		"feedback": [
			"火舌擦过你的手臂，不疼，像被谁拽了一下袖子。穿过去时，你出了一层薄汗。",
			"绕开的路多了半炷香时间，但你身上干干净净。",
			"火缠上指尖，温暖的、甜的，像谁在挽留。你抽回手，掌心留了一小片粉，拍不掉。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "献花台",
		"scene": "楼梯转角摆着一个小小的献花台，花是新的，卡片是空的。台前的地面被脚步磨得发亮，像有很多人来过。",
		"choices": ["把花摆正，鞠一躬", "在卡片上写下名字", "直接上楼"],
		"feedback": [
			"你把花摆正，弯下腰。起身时，胸口那片发紧的地方松开些了。",
			"你握着笔站了会儿，最后把空卡片放了回去——这里的名字，终究不是你的位置。",
			"你直接上楼。身后很安静，花一直摆在那里，谁也没等到。",
		],
		"effects": [{"hp": 1}, {}, {}],
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
		"阿斯莫德揉着额头坐起来，眼里的雾退了下去。",
		"「原来你把它接住了。」她凑近看你手里的牌，忽然笑了。「它很粘人的，你辛苦啦。」",
		"她掂着裙角转了个圈。「这一层没意思了。走吧走吧——上边那位，比我难缠得多哦。」",
	],
}

# 层完成后的上行过渡读白（同行层主）
const LAYER2_TRANSITION := [
	"通往第三层的台阶上，多了两个人的脚步声——你的，和菲戈蕾的——不，现在是三个人了。",
	"「哈——欠。」菲戈蕾走在最后面，阿斯莫德走在最前面，嘴里还哼着那首听不清的歌。",
	"「上面那层是『暴食』。」阿斯莫德回头，「那边的家伙，是真的什么都想吃哦。」",
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
		"choices": ["坐到空位上一起吃", "给最近的影子夹一筷菜", "沿桌边绕过去"],
		"feedback": [
			"菜进了嘴就化了，只剩满口的饿。你越吃，越饿。",
			"影子停了停，把菜吃了。它没有脸，你却觉得它朝你点了一下头。你心里的空处，被填了一小块。",
			"你沿桌边绕。影子们一起停了筷子，等你走远了，才重新响起整齐的咀嚼声。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "一碗汤",
		"scene": "灶上只剩一碗汤，还热着。碗底压着张字条，字被水汽洇开了：「先到的人，留给后来的人。」",
		"choices": ["趁热喝掉", "留给下一个影子", "把汤倒回锅里"],
		"feedback": [
			"汤暖到胃里，一路暖到手心。你舒服地呼出一口气。",
			"你把碗推回桌心。走远时回头，字条上的字迹好像又清楚了一点。",
			"汤倒回去，火舌一舔，锅底发出很响的咕噜声。你的胃跟着抽了一下——那是饿。",
		],
		"effects": [{"hp": 1}, {}, {"hp": -1}],
	},
	{
		"type": "event",
		"title": "果子树",
		"scene": "走廊正中长着一棵树，枝头挂满熟透的果子。树下躺着一个瘦长的影子，仰着头，就是够不着。",
		"choices": ["摘一颗递到影子手边", "摘一颗自己吃", "继续走，别去够"],
		"feedback": [
			"影子捧着果子，慢慢地、慢慢地吃完了，朝你蜷了蜷，像鞠了一躬。你也觉得饱了一点点。",
			"果子甜得发苦。你咽下去，喉咙里却像塞进了一块石头。",
			"你从树边走开。身后传来影子一次又一次伸手的声音。",
		],
		"effects": [{"hp": 1}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "后厨门",
		"scene": "走廊尽头是后厨的门，门缝里涌出滚烫的香味。门后传来切菜声，一下，一下，不快，也不停。",
		"choices": ["推门看一眼", "在门外道声谢", "捂紧鼻子快走"],
		"feedback": [
			"门后是空的，只有案板在响。香味扑出来把你浇透了，走出好远还饿。",
			"你说「多谢款待」，转身要走。切菜声顿了半拍，从门缝里飘出一小股好闻的热气，扑在你脸上，像回礼。",
			"你捂着鼻子冲过去。香味在身后追了很久，才停下来。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
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
		"choices": ["挖开金子走向窄门", "抓两枚金币揣好", "贴边走，尽量不踩"],
		"feedback": [
			"金子沉得出乎意料。挖到窄门前，你的手指已经抖了。",
			"金币落进兜里，沉甸甸的。走出没多远，你总觉得背后有数数的声音跟着。",
			"你几乎是踮着脚过去的。金子在脚边闪闪发亮，没有一锭跟着你走。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "计数台",
		"scene": "一张高高的柜台横在路中间，台后悬着一本翻开的大账簿。路过的影子都在台前排队，报自己的名字。",
		"choices": ["老老实实排队", "直接跳过柜台", "替前面的影子写一笔"],
		"feedback": [
			"队伍一步一挪，账页翻得哗哗响。轮到你时，你的名字早就被写好了。",
			"你从柜台侧边翻了进去。笔尖在你身后追着划了一道，没够着。",
			"你替它写下名字。它回头的方向朝你顿了很久，把手里攥着的一颗小铜珠塞给你。攥着铜珠，你心里莫名踏实。",
		],
		"effects": [{}, {}, {"hp": 1}],
	},
	{
		"type": "event",
		"title": "抵押行",
		"scene": "一间小抵押行，窗口挂着铃。柜台上摆着天平，一头压着别人的旧物，另一头空着，正等着什么。",
		"choices": ["押上自己的一样东西", "什么也不押，问个路就走", "把天平拨平"],
		"feedback": [
			"你放上去的不是物件，更像一段记忆。天平平了，你心里空出一小块，风灌进来，凉飕飕的。",
			"柜里传来一声哼：「没有押品，就没有路条。」但铃响了，侧门开了一条缝。",
			"你伸手把天平拨平。柜台后没人出声，铃却轻轻地、像是笑了。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "保险柜",
		"scene": "墙里嵌着一排保险柜，柜门大多虚掩，只有一个锁得死死的。锁孔里透出一点温热的、金红色的光。",
		"choices": ["试试打开锁着的那个", "检查虚掩的柜子", "什么也不碰"],
		"feedback": [
			"你拧了很久。咔嚓一声，柜门开了条缝，金光涌出来割了你一下——柜子里只有更深的黑，和一个咕噜声。",
			"虚掩的柜子都是空的，只有最下面一格留着一小瓶温水。你喝了两口，精神了些。",
			"你收回手，径直走过。锁孔里的光盯着你的背影，慢慢暗下去。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "账房的灯",
		"scene": "账房的窗亮着，里面有人打算盘，响声又密又急。窗台上放着一盏多余的灯，还没有点。",
		"choices": ["把窗台的灯点亮", "隔着窗看一会儿", "不打扰，走过去"],
		"feedback": [
			"你点亮窗台的灯。算盘声忽然慢了下来，像有人隔窗朝你这边看了一眼，又低下头。灯暖着你的侧脸。",
			"影子打算盘的手快得看不清，账本摞得比人还高——它一步也走不出来。",
			"你放轻脚步走过去。算盘声追到墙根，停住了。",
		],
		"effects": [{"hp": 1}, {}, {}],
	},
	{
		"type": "event",
		"title": "朝下的石像",
		"scene": "墙上嵌着一尊脸朝下的石像，双手伸向前方，像要抓住什么，又像被什么按住了。石像脚边散着几枚真金。",
		"choices": ["把石像的脸抬起来", "捡走脚边的金币", "学它的姿势站一会儿"],
		"feedback": [
			"石像太沉，你只把它的脸抬起一点。石缝里落下些细灰，像一声很长的叹气终于呼了出来，你的心口也跟着松了松。",
			"金币入手时，石像的指缝里渗出一缕黑气，缠上你的手腕。沉。",
			"你弯下腰，脸朝下。世界倒了过来——金币、灰、脚下的路，全从眼前落下去。你赶紧站直。",
		],
		"effects": [{"hp": 1}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "天平房",
		"scene": "一间空屋，正中立着一架巨大的天平：一端压着一座小小的金山，另一端是同样大的空盘，铁丝映着光。",
		"choices": ["往空盘里放一枚金币", "站上空盘试试", "把金山推下天平"],
		"feedback": [
			"一枚金币落进空盘，天平纹丝不动。第二枚、第三枚……你回过神时，兜已经空了。你翻过最后一个口袋，笑了自己一声，转身上楼。",
			"你刚站上去，整架天平就沉沉往下坠。你赶紧跨下来——它还在等你。",
			"金山滚落，轰的一声。天平空转了许久，指针晃来晃去，找不到平衡。",
		],
		"effects": [{"hp": -1}, {}, {}],
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
		"choices": ["走上台，替他们谢幕", "站在侧幕看着", "掀开幕布走到台后去"],
		"feedback": [
			"你走上台，朝空座位鞠了一躬。聚光灯终于满意地暗下去，掌声也散成了风。你直起腰，肩背松快了些。",
			"你站在侧幕。聚光灯一遍遍扫过，每一次都差一点照到你，每一次都停住。",
			"幕布后面是一条安静的走道。你回头最后看了一眼舞台，它正等着下一场谢幕。",
		],
		"effects": [{"hp": 1}, {}, {}],
	},
	{
		"type": "event",
		"title": "针线长廊",
		"scene": "两侧墙上插满针，线在廊顶织成一张稀薄的网。走到中段，你发现自己的影子被一根线轻轻勾住了。",
		"choices": ["停下来把线解开", "假装没看见，快步穿过", "把勾住影子的线编进衣角"],
		"feedback": [
			"你一点点解开线头。线绷紧了又松开，影子回到了你脚下。解开的瞬间，胸口某处也跟着松开了。",
			"你走得飞快。线在身后拉成一道长长的弧，终于断了。你没敢回头看影子缺没缺角。",
			"你把线编进衣角带着走。那根线的另一头不知牵着谁——走出长廊，你总觉得身上多了半份重量。",
		],
		"effects": [{"hp": 1}, {}, {"hp": -1}],
	},
	{
		"type": "event",
		"title": "重影卧室",
		"scene": "卧室的床铺得整整齐齐，墙上钉着一排一模一样的照片。照片里的人笑得一样，穿得一样，连影子都折在同一个角度。",
		"choices": ["把照片逐一翻过去", "躺到床上合眼休息一会", "对着照片里的笑练习"],
		"feedback": [
			"你一张张翻面。翻到最后一张，背面有一行小字：「我也想做我自己。」照片贴回墙面时，屋里的光正了过来。",
			"床很软，一躺下就睡沉了。醒的时候，你分不清是自己醒的，还是照片里的人替你醒的。",
			"你对着练习笑。练着练着，照片里的人也跟着你换了个笑法。房间安静了一下。",
		],
		"effects": [{"hp": 1}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "榜单",
		"scene": "楼梯口贴着一张长长的榜单，从上到下写满了名字。你的名字在很下面的地方，紧挨着一条被反复涂改的横线。",
		"choices": ["在横线上写下自己的名字", "看着别人的名字出神", "把榜单揭下来叠好"],
		"feedback": [
			"你添上自己的名字，笔迹压过涂改的痕迹。榜单轻轻抖了抖，你耳边那点嗡嗡声停了。",
			"你看得太久，那些名字一个个往上爬——你觉得自己在往下沉。",
			"你把榜单叠成小方块收好。墙上留下一道浅印，像谁松了口气的痕。",
		],
		"effects": [{"hp": 1}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "望远镜",
		"scene": "窗台上架着一副望远镜，镜筒正对着楼下的什么地方。凑近看，视野里全是别人：别人走在前面，别人被簇拥着，别人笑得很好。",
		"choices": ["把镜筒转向别的地方", "看很久，直到眼睛发酸", "把望远镜收起来"],
		"feedback": [
			"你把镜筒转了一圈——先是一堵墙，然后是树，最后停住了：镜里出现了你走过的台阶。",
			"你看了很久。眼睛酸得厉害，远方的笑声却越来越清楚。",
			"你收好望远镜。支架上刻着一小行字：「看久了，会丢。」",
		],
		"effects": [{}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "回声井",
		"scene": "回廊正中有一口井。所有掉进去的声音都会先变成别人的声音，再弹回来——连你刚才的脚步声，回上来的也是陌生的腔调。",
		"choices": ["对着井口喊自己的名字", "把耳朵贴在井沿听", "绕过井走"],
		"feedback": [
			"你喊了名字。井里先回了一串七嘴八舌的声音，把你的名字念得又碎又长。你站了很久，终于听见最底下那一层：是你自己的声音，很小，但很真。",
			"你听了很久。别人的声音一层一层从井里涌上来，把你说过的每句话都换了腔调。等你直起腰，耳朵里全是别人，自己的声音找不到了。你晃了晃头，才把脚下站稳。",
			"你绕远走了。井里传来许多个「你」，在替你道别。",
		],
		"effects": [{"hp": 1}, {"hp": -2}, {}],
	},
	{
		"type": "event",
		"title": "空椅子",
		"scene": "楼梯平台上并排摆着两张椅子，一张坐着一个安静的孩子，另一张空着。孩子的目光望着空椅子，像在等一个总也不来的人。",
		"choices": ["坐到空椅子上", "蹲下来陪孩子等一会", "轻手轻脚绕过椅子"],
		"feedback": [
			"你坐下。孩子转过头看你，看了很久，忽然说：「你好久没来了。」你没有辩解，只是坐着。起身时，那把椅子已经凉了。",
			"你蹲下来，陪它等。等了很久，孩子轻轻靠过来，在你肩上睡着了。你把它扶稳，站起身，心里软了一块。",
			"你绕过去。两把椅子在你身后并排站着，影子叠成一个。",
		],
		"effects": [{}, {"hp": 1}, {}],
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
		"choices": ["在椅子上坐一会", "把窗口推开透透气", "只看一眼就转身下楼"],
		"feedback": [
			"你坐下。椅子比想象中矮，视线一下子低下去——和你千辛万苦爬上来时想的一点也不一样。坐了没一会儿，你扶着桌沿才把自己拔起来，腿是麻的。",
			"窗户开了。风大得吓人，楼下的一切都被吹得晃，只有你站的地方稳稳的。你扶着窗框站了很久才关上。",
			"你只瞥了一眼就转身。身后的房间在你离开时，轻轻把门带上了。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "空王座",
		"scene": "大厅尽头是一张高背王座，扶手磨得发亮，座面上落着一根羽毛。没有人在，但整个大厅都在朝那个方向安静着。",
		"choices": ["走上去，坐一次试试", "把羽毛放回座面", "远远地看一会就走开"],
		"feedback": [
			"你坐上去，风从四面八方朝你朝拜。起身时你晃了一下——有种什么东西留在了座位上，没跟你下来。",
			"你捡起羽毛，轻轻放回座面。羽毛落稳，大厅里有什么东西松了下来，你也是。",
			"你在门槛外站了会，看那根羽毛在光里慢慢转。然后退了出去。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "聚光灯",
		"scene": "楼梯间的穹顶垂下一束聚光灯，正打在一段空台阶上。它不照亮别处，也照不到别处。",
		"choices": ["走到光里试试", "贴着墙避开光柱", "抬头找灯的开关"],
		"feedback": [
			"你站进光里，所有的影子都退到了你身后。暖是暖的，可你很快发现——站在这里，什么都看不清，只看得到自己。",
			"你贴着墙根走。光柱在你身边笔直地立着，像一根够不着任何东西的手指。",
			"你仰头找开关，只看到垂下来的灯线，上面没有按钮，也没有灯座。那束光就这么悬着，谁都没点。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "雕像广场",
		"scene": "天台是一片广场，广场上立满了石像，每一尊都昂着头，望向更高处。没有一尊低头，也没有一尊看身边的人。",
		"choices": ["仰头陪石像们望一会", "把一尊石像扶得坐下来", "从石像之间穿过去"],
		"feedback": [
			"你陪它们望了很久。高处只有云，云后面什么都没有。脖子酸的时候，你低下了头。",
			"你使劲扳动石像。石像坐下的一瞬，它的视线第一次落在了旁边的石像身上。石屑簌簌往下掉，像卸了一口气。你的手臂酸得发胀，心口却松快。",
			"你从石像之间走过。它们的影子在你脚下拼成了一条路，路的尽头还是更高处。",
		],
		"effects": [{}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "坠落点",
		"scene": "广场边缘的地面上有一个浅浅的坑，坑里嵌着一颗石头，烧得发黑，边缘还残留着划开天空的痕迹。",
		"choices": ["把石头捧出来看看", "往坑里放一朵野花", "绕开坑，继续往上"],
		"feedback": [
			"石头烫得钻心。你捧着它，忽然看见了它来的那条路——从最高最高处一路烧下来，孤零零的，没有人接。你眼前发黑，膝盖磕在坑沿才没跪下去。松开手，掌心烫掉了一层皮。",
			"你把野花放进坑里，挨着那颗黑石头。风从坑底轻轻卷上来，卷走了一层你看不见的灰。手上暖了。",
			"你绕开坑往上走。身后那一小块焦黑的地面，在你离开后才慢慢凉下去。",
		],
		"effects": [{"hp": -2}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "负重阶梯",
		"scene": "一段台阶斜插进塔身，台阶上排着一列影子，每人背上都压着一块大石头，一级一级地往上挪。",
		"choices": ["帮最前面那个托一把石头", "自己也被压一块试试", "空着手快步走上去"],
		"feedback": [
			"你从下面托住石头的底，帮它挪上三级台阶。影子回不了头，只在台阶上顿了顿。你收回手时，自己的肩膀轻得很奇怪，像也被谁托过。",
			"石头压上背的瞬间，你懂了什么叫一步千斤。你扛着它走了五级，把石头卸在阶石上，喘得直不起腰。",
			"你空着手飞快地上楼。影子们一级一级让开，没人拦你，也没人看你。",
		],
		"effects": [{"hp": 1}, {"hp": -1}, {}],
	},
	{
		"type": "event",
		"title": "报幕台",
		"scene": "半层平台搭着一个小小的报幕台，台本摊开着，上面写着你的名字，后面跟着一段没写完的定语。",
		"choices": ["接着那半句话写下去", "把「你」改成「她」", "合上台本"],
		"feedback": [
			"你提笔把定语写完——写的是你自己的字。台本亮了一下，纸页间的褶皱展开了大半。",
			"你把「你」划掉，写上「她」。台本困惑地翻了两页，最后把那一行整段删掉了。",
			"你合上台本。台下没有观众，你却还是朝台下亮了亮手掌，像谢了幕。",
		],
		"effects": [{"hp": 1}, {}, {}],
	},
	{
		"type": "event",
		"title": "加冕台",
		"scene": "塔顶正中立着一座圆台，台上悬着一顶冠冕，金漆剥落，里衬却是软的，像被人试戴过很多次。",
		"choices": ["走上台，一个人站定", "把冠冕摆正扶稳", "从台下绕一圈离开"],
		"feedback": [
			"你在台上站定，风停了，一切都望着你。你站了很久，久到忘了自己原本要往哪里去。走下台时，腿是麻的。",
			"你踮起脚，把冠冕摆正。里衬柔软，贴着你的指尖。安心的一小团温度，顺着手心传上来。",
			"你从台下绕过去。冠冕在台上轻轻转着，像在挑人。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
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
		"choices": ["伸手按上最浅的那个记号", "拾起一块烙铁看看", "吹熄炉火"],
		"feedback": [
			"记号的形状贴着你的掌心，一下烙进皮肉里。你咬住牙没出声，眼前白了一阵。再看时，墙上多了一道很浅的新痕。",
			"烙铁比预想的重。你捏了一下就赶紧放下，指尖燎起一个亮晶晶的泡。",
			"你对着炉膛吹气，火晃了晃，真的暗下去一格。屋里暗下来，你手上的影子也安静了。",
		],
		"effects": [{"hp": -2}, {"hp": -1}, {"hp": 1}],
	},
	{
		"type": "event",
		"title": "黑烟走廊",
		"scene": "走廊里全是黑烟，浓得能看见它的流动。烟里偶尔亮起一双眼睛，看一眼，又熄掉。",
		"choices": ["屏住呼吸直穿过去", "对着烟里的眼睛说话", "点一盏火把照过去"],
		"feedback": [
			"你屏着气冲过去。烟灌进肺里，又苦又呛，咳了半天才咳干净。",
			"你轻声说「借过」。烟顿了顿，朝两边分开，留出一步宽的缝。那双眼睛亮了一下，是道谢的意思。",
			"你点起火把。烟被照得退了退，又缓缓围回来。火光里，你看见烟并不想烧谁，只是太浓了，散不开。",
		],
		"effects": [{"hp": -1}, {}, {}],
	},
	{
		"type": "event",
		"title": "无人裁判的擂台",
		"scene": "山谷里搭着一座擂台，围绳歪着，地上有新旧交叠的脚印。台角坐着一个影子，抱着膝盖，肩背一鼓一鼓的。",
		"choices": ["上台，陪影子打一场", "坐到台边等它自己站起来", "把歪掉的围绳重新绷直"],
		"feedback": [
			"你们打了很久。拳头砸到影子上像砸进雾里，它的每一拳却都落实。终场哨没人吹，你扶着围绳下来，浑身是汗。",
			"你坐在台边等。等到风把山谷吹凉，影子慢慢抬起头，自己站了起来。它朝你低了低头，你胸口那股闷劲也跟着落下去。",
			"你把围绳一根根绷直。擂台在你手下颤了颤，像是很多年了，第一次有人肯碰这些绳子。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "碎片拼盘",
		"scene": "石桌上摊着一堆碎片，来自某种很贵的东西。旁边立着一张小卡：「是谁摔的，就由谁来拼。」",
		"choices": ["坐下把碎片拼完", "找一找还缺哪些片", "把碎片扫到一起"],
		"feedback": [
			"你一片一片地拼。拼到最后，还缺中间一块。你把手指按在缺口上，拼盘亮了亮，认了。你吁出一口气，堵了一路的东西顺了顺。",
			"你翻检了半天，缺的那片始终找不到。小卡在你手里渐渐发烫，最后自己翻了个面：「算了。」",
			"你把碎片扫成一堆。它们磕碰着响，像在互相道歉，谁也没再碎。",
		],
		"effects": [{"hp": 1}, {}, {}],
	},
	{
		"type": "event",
		"title": "沸水缸",
		"scene": "路中间架着一口大缸，水滚得翻花，缸沿上搁着两只碗，一只盛着凉水，一只扣着盖子。",
		"choices": ["舀一碗凉水压进滚水里", "盖上盖子，把火抽掉", "远远绕开"],
		"feedback": [
			"凉水入缸，响了一大阵，白汽扑了你满脸，烫得你偏过头。缸里的水还是滚的，白汽撩过的地方火辣辣的。",
			"你把柴火一根根抽出来踩灭。缸里的滚声慢慢地、慢慢地，变成了一点点冒泡的呼吸声。",
			"你绕着走。热气追着你的后颈，一直到台阶口才散。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "揉皱的信",
		"scene": "台阶上落着一封揉皱的信，纸面被攥得发亮。展开一看，字全是同一个字压着同一个字写的，浓得透纸。",
		"choices": ["把它抚平读完", "照原样揉回去放好", "把信折好收进衣袋"],
		"feedback": [
			"你一个字一个字地认。满纸的火从字里窜出来，烧得你眼睛发酸、指尖发抖。读完最后一个字，你发现自己攥紧了拳头。",
			"你照着原来的褶皱把它揉回去，放回原处。纸页服帖地躺在台阶上，仿佛松了口气。你心里的褶皱，也平了一点。",
			"你把信折成小方块收好。衣袋里从此暖着一小团，你说不清是安慰，还是催促。",
		],
		"effects": [{"hp": -1}, {"hp": 1}, {}],
	},
	{
		"type": "event",
		"title": "先吼的谷",
		"scene": "山谷两侧的岩壁一层叠着一层，越往深处走，回声越响。这里只有一个规矩：谁先吼，谁的回声可以盖过别人的。",
		"choices": ["朝谷里吼一嗓子", "捂紧耳朵快走", "对着谷底轻轻哼一句"],
		"feedback": [
			"你吼了。回声一浪一浪地压回来，把你的声音变成了别人的、更大的、更凶的。你站在声浪里，耳朵嗡嗡作响。",
			"你捂着耳朵小跑。各处没吵完的旧架，在耳朵外面打来打去。",
			"你轻轻哼了一句。山谷顿了顿，把它原样送了回来——不轻不重，是你自己的调子。你忍不住又走稳了些。",
		],
		"effects": [{"hp": -1}, {}, {"hp": 1}],
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
