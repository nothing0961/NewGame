class_name BattleConfig
extends RefCounted

# 文案现状：【测试内容】。初幕与新手教程已按小组脚本（2026-10-05【正典】）对齐：
# 初幕演出 → 蜗牛教学战 → 教学说明 → 练习站 → 追及段 → 层主战·贝尔芬格 → 净化 → 收下 → 三问 → 同行。
# 双名制：初幕白发少女＝菲戈蕾（人身）；被懒惰之力彻底污染后＝贝尔芬格（战斗形态）；净化后恢复菲戈蕾同行。
# 读白使用全角标点。告知边界：净化前的所有文本只说「打倒／清空血量」，不解释「怎么救」。

const PLAYER_MAX_HP := 20
const PLAYER_MAX_COST := 6
# 层主战为短局：玩家打贝尔芬格时手里还没有罪卡（收下发生在战斗之后），5 回合保底的拉长无意义
# 2026-10-07 数值紧缩制（design/design-round9.md）：此 HP 裁决保持 16 不加长
const ENEMY_MAX_HP := 16
const ENEMY_NAME := "贝尔芬格"
const HAND_SIZE := 5
# 紧缩制：上限 7——单回合出牌 ≤1 张时触发强制弃牌（满出牌回合不触发）；教学战不参与，见 TEACHING_HAND_LIMIT
const HAND_LIMIT := 7
const PLAY_ZONE_SIZE := 4
const TURN_TIME_LIMIT := 45.0
const DECK_SIZE := 10
# 默认卡组（组卡缺省回退用）：红攻×6＋蓝防×3＋金功能×1
const DECK_COMPOSITION := {
	"strike": 4,
	"heavy_strike": 2,
	"guard": 3,
	"heal": 1,
}
# 仓库初始卡池（24 张）：四色体系（红攻／蓝防／金功能／紫核心）＋增幅类，总量 > 卡组 10，组卡为真取舍
const WAREHOUSE_INITIAL := {
	"strike": 5,
	"heavy_strike": 3,
	"guard": 4,
	"strong_guard": 2,
	"call": 2,
	"shift": 2,
	"heal": 1,
	"cleanse": 1,
	"greed_shot": 1,
	"quench": 1,
	"surge": 1,
	"bulwark": 1,
}
# 堆叠：把一张牌叠到出牌区同类已摆牌上，合成牌费用＝各原牌费用之和＋每多一张收 STACK_FEE
const STACK_FEE := 1
# 一轮结束（玩家回合＋敌人回合都结束）后，双方各从各自牌组摸四张；供给不足时能摸几张是几张
const ROUND_GAIN := 4
# 敌方每回合出牌封顶（紧缩制：玩家承伤期望 = 2 张 × 2 伤；验收「层主战 5–6 回合 / 单回合承伤 4 点」）
const ENEMY_MAX_PLAYS_PER_TURN := 2
const ENEMY_DECK_COMPOSITION := {
	"enemy_strike": 8,
}

# 事件轻增益上限（design-round10 §0-⑧）：防单条路线事件滚雪球
const PREP_BLOCK_CAP := 3
const PREP_DRAW_CAP := 2

const PRACTICE_ENEMY_NAME := "木桩"
const PRACTICE_ENEMY_HP := 60

# —— 蜗牛教学战（小组脚本新手教程段）——
# 单位制仅此一战：魔力总量 4；教学牌组钉死（不洗牌）；过完教学战恢复 Cost 6 体系
# 教学战不参与紧缩制：摸牌/手牌上限沿用旧值（3/8），保证 8 张钉死牌序的水位与演出节拍不变
const TEACHING_MAX_COST := 4
# 摔伤 8／上限 10：教学战治疗回满 10，演出节拍不随常规 20 体系统一（design-round9.md）
const TEACHING_PLAYER_HP := 8
const TEACHING_PLAYER_MAX_HP := 10
const TEACHING_TURN_TIME_LIMIT := 90.0
const TEACHING_ROUND_GAIN := 3
const TEACHING_HAND_LIMIT := 8
# 波 1 五血＝两发魔弹打剩一口气，让它有机会照脚本出手一次（防御卡正好挡下）
const TEACHING_WAVES := [
	{"name": "蜗牛怪物", "hp": 5},
	{"name": "蜗牛群怪", "hp": 3, "count": 3},
]
const TEACHING_ENEMY_DECK := {
	"snail_bite": 3,
}
# 钉死节拍：数组顺序＝摸牌顺序（代码反向入堆配合 pop_back）
# 开局手＝普通防御＋普通魔弹×2＋治疗术＋普通魔弹；牌堆＝净化＋强欲魔弹＋普通魔弹
const TEACHING_DECK := ["guard", "strike", "strike", "heal", "strike", "cleanse", "greed_shot", "strike"]
# 波 2 登场后，睡意倒计时＝当前回合 + 2：到时仍未免疫则跳过一个回合（一次），走完即解
const TEACHING_SLEEP_DELAY := 2

# —— 笔筒污染体遭遇战（design-round12：第二幕后半·雾中公路入场战）——
# 真实战斗照教学战模式：钉死牌组、不洗牌、不检定罪卡；魔力体系沿用 Cost 6
# T1 强攻上限 9（三魔弹＋强欲魔弹＝6 单位）对 10 血留一口气 → T2 补刀，呼应「僵直→欲望魔弹」
const AMBUSH_ENEMY_NAME := "笔筒污染体"
const AMBUSH_ENEMY_HP := 10
const AMBUSH_ENEMY_DECK := {
	"enemy_strike": 6,
}
# 钉死节拍：数组顺序＝摸牌顺序；开局手＝防御＋魔弹×3＋强欲魔弹，牌堆＝防御＋魔弹×2（5＋3 水位）
const AMBUSH_DECK := ["guard", "strike", "strike", "strike", "greed_shot", "guard", "strike", "strike"]
const AMBUSH_ROUND_GAIN := 3
const AMBUSH_HAND_LIMIT := 8
const AMBUSH_TURN_TIME_LIMIT := 90.0
const TEXT_AMBUSH_START := [
	"雾里，那个身影身上的污染亮得像一盏灯。",
	"菲戈蕾不在身边了——先解决眼前这个污染体。",
]
const TEXT_AMBUSH_WIN := "污染体散了架，身上的零件落了一地。"

# 罪卡规则（design/design-round1.md §1）：任务达成或第 SIN_ROUND_FALLBACK 回合保底解锁；每场战斗仅出现并使用一次
# 任务/保底参数按卡配置（design/design-round3.md §6：按牌组中的罪卡逐卡检定；
# gluttony–anger 为 design-round8 先行版数值，待罪卡专轮替换）
const SIN_CARD_ID := "wrath"
const SIN_ROUND_FALLBACK := 5
const SIN_TASK_ATTACK := "attack_plays"
const SIN_TASK_CONFIG := {
	"wrath": {"task": SIN_TASK_ATTACK, "count": 3},
	"lust": {"task": SIN_TASK_ATTACK, "count": 2},
	"gluttony": {"task": SIN_TASK_ATTACK, "count": 3},
	"greed": {"task": SIN_TASK_ATTACK, "count": 3},
	"envy": {"task": SIN_TASK_ATTACK, "count": 2},
	"pride": {"task": SIN_TASK_ATTACK, "count": 3},
	"anger": {"task": SIN_TASK_ATTACK, "count": 4},
}
const TEXT_SIN_TASK := "本场战斗中累计打出 %d 张攻击牌"
const TEXT_SIN_PROGRESS := "（%d/%d）"
const TEXT_SIN_UNLOCKED := "「%s」的封印解开了——它现在可以打出了。"
const TEXT_SIN_USED := "「%s」已经用过了。这一场，它不会再回来。"
const TEXT_SIN_BLOCKED := "「%s」被封印着——%s%s，或撑到第 %d 回合，它才会醒。"  # 4 参数：牌名、任务文案、进度、保底回合

# —— 教学战提示（莉维娅引导语注入战斗日志；_setup/_spawn_wave/_start_player_turn 三处发）——
const TEXT_TEACHING_START := [
	"莉维娅：「先认识你的四种颜色——蓝的防御，红的攻击，金的功能，紫的核心。」",
	"莉维娅：「魔力按单位算，牌左上角的数字就是花费。你现在有 4 个单位的魔力。随着身体对魔力的适应，之后你的魔力总量还会更高。」",
	"莉维娅：「敌人要发起攻击了——先把蓝色防御卡拖进出牌区，一张就够了。」",
]
const TEXT_TEACHING_TURN_KILL := "莉维娅：「它只剩一口气了——再补一张红的攻击牌。」"
const TEXT_TEACHING_FIRST_FELL := "第一只蜗牛怪物倒下了——又有三只蜗牛怪物涌了上来。"
const TEXT_TEACHING_SLEEP_EVENT := "森林深处传来一股力量——你和怪物，都想要沉睡。"
const TEXT_TEACHING_SLEEP_HINT := "莉维娅：「那是懒惰的力量。先用金色的净化，来免疫这种负面状态。」"
const TEXT_TEACHING_TURN_WAVE2 := "莉维娅：「先净化免疫睡意，再用紫色核心牌『强欲魔弹』——3 个单位的群体攻击，对沉睡的敌人追加伤害。」"
const TEXT_TEACHING_WIN := "三只蜗牛怪物都倒下了。森林重新安静下来。"

const TEXT_ENEMY_SLEEPING := "%s沉在睡意里，没有动作。"
const TEXT_SLEEP_SKIP := "睡意漫了上来——这一回合，你动不了。"
const TEXT_CLEANSE_SLEEP := "睡意被挡在身体外面——净化生效了。"
const TEXT_CLEANSE := "净化生效了。本场战斗中，负面状态不会再找上你。"

# 教学说明（蜗牛教学战后→练习站；练习站为既有结构，非脚本内容）
const TEXT_TEACH := [
	"蜗牛群安静了下去。莉维娅的声音重新从水晶里浮出来：「基础的战斗方式，你已经会了。」",
	"「还差一点手感——前面不远有一处练习站。在那儿重新配一副卡组，打到顺手为止。」",
	"「里面的牌都归你，挑十张。接下来的战斗里，魔力会放开到六个单位。」",
	"「准备好了，就顺着森林往深处走——菲戈蕾还在等着我们。」",
]

# 层主战前读白（异化的贝尔芬格形态）；接近过程与树洞入口已移入追及演出
# StoryBeats.CHASE_BEATS（design-round11），本条仅保留临战两句（失败重试回到这里）
const TEXT_TRANSFORM := [
	"「菲戈蕾……」你刚要开口，她抬起了脸——那双丁香紫的眼睛里，正翻涌着不属于她的东西。",
	"「趁我还认得你——」声音很轻，像从很远的地方传来。「打倒我。把这条血条，清空。」",
]

const TEXT_STRIP := [
	"「……够了。」她忽然笑了，笑得很轻。",
	"一团沉沉的白雾，从她胸口被拽出来，悬在你们中间。",
	"它想缩回去——做不到。它盯着你。",
]

const TEXT_PURIFY := [
	"白雾散尽。她撑着膝盖喘匀了气，再抬起头时，那双丁香紫的眼睛已经清亮起来。",
	"「听见了吗？净化不会让罪消失。」她盯着你手里那张牌。「它得去个地方。刚才——它去了你那儿。」",
	"最后一发魔弹清掉了她身上最后的污染。菲戈蕾瘫坐下去，贝嘉快步走过去，把她扶了起来。\n\n(ᗜ ᴗ ᗜ)\n\n「要跟你们走吗？」她声调没什么起伏地问。",
	"莉维娅伸出手，想确认她的情况——菲戈蕾避开了，躲到贝嘉身后，扯了扯她的衣角。莉维娅尴尬地放下手。\n\n「跟我们走吧，最后的战斗，还是要靠大家的力量。」贝嘉也点点头：「我需要菲戈蕾。」\n\n菲戈蕾扬了扬嘴角——解除污染后，她的表情比以前要丰富了一点。「好，我跟贝嘉走。」",
]

const TEXT_DEBRIEF := [
	"「她归零的那一下，到底发生了什么？」",
	"「这张牌现在摆在你面前。什么感觉？」",
	"「路上还有更多这样的人。想继续吗？为什么？」",
]

const TEXT_DISCARD := "手里的牌超出了上限（最多 %d 张）——选牌弃掉，还差 %d 张。"
const TEXT_PRACTICE_START := "练习开始——对面是木桩。"
const TEXT_PRACTICE_IDLE := "木桩纹丝不动。"
const TEXT_PRACTICE_END := "木桩倒下了。"
const TEXT_PRACTICE_DEFEAT := "你倒下了。练习到此结束。"  # 训练场不参与死亡规则：失败即结束，无惩罚
# 死亡规则（design/design-round3.md §5）：生命归零＝判负；层战回层首，教程层回追及段（design-round6.md）
const TEXT_DEFEAT := "你倒下了。手里的牌散了一地——这一层，得从头再来。"  # 【测试内容】层战
const TEXT_DEFEAT_BUTTON := "重新开始本层"
const TEXT_DEFEAT_TEACHING := "你倒下了。唔——没关系，站起来，再来一次。"  # 【测试内容】教学战/层主战
const TEXT_DEFEAT_RETRY := "再来一次"
const TEXT_STAGE_WIN := "挡路的东西倒了下去。前路清楚了一些。"  # 【测试内容】层内小怪战胜利
const TEXT_SUPPRESSED := "她没有打你，只是小声说：「……对不起。」"
const TEXT_ENEMY_IDLE := "%s没有出牌。"
const TEXT_ENEMY_DOMINANT := "「它」占上风。"
const TEXT_ENEMY_RESISTING := "「她」还在挣，用很轻的声音说：「……对不起。」"
const TEXT_ROUND_GAIN_PLAYER := "新的一轮——你获得 %d 张牌。"
const TEXT_ROUND_GAIN_ENEMY := "%s也获得 %d 张牌。"
const TEXT_PREPARE_BUFF := "备战：%s。"  # 1 参数：如「开局 +1 格挡，起手多抽 1 张」
const TEXT_END := "这一场，到此结束。"
